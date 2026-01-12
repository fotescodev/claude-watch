#!/usr/bin/env python3
"""
Claude Watch Bridge Server

A lightweight HTTP server that bridges your Apple Watch to Claude Code web sessions.
Run this on your dev machine, expose via Tailscale/ngrok, and your watch can control
Claude Code from anywhere.

Usage:
    python server.py [--port 8787] [--host 0.0.0.0]

Endpoints:
    POST /session          - Start a new web session with a prompt
    GET  /session/:id      - Get session status
    GET  /sessions         - List active sessions
    POST /session/:id/approve    - Approve pending action
    POST /session/:id/discard    - Discard pending action
    POST /session/:id/approveAll - Approve all pending actions
    POST /session/:id/cancel     - Cancel session
    GET  /status           - Server health check
"""

import asyncio
import json
import os
import re
import subprocess
import uuid
from dataclasses import dataclass, field, asdict
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional
import shutil

# Try uvicorn/fastapi, fall back to basic http server
try:
    from fastapi import FastAPI, HTTPException, BackgroundTasks
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    import uvicorn
    USE_FASTAPI = True
except ImportError:
    USE_FASTAPI = False
    from http.server import HTTPServer, BaseHTTPRequestHandler


# =============================================================================
# Data Models
# =============================================================================

class SessionStatus(str, Enum):
    STARTING = "starting"
    RUNNING = "running"
    WAITING_APPROVAL = "waiting_approval"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class ActionType(str, Enum):
    FILE_EDIT = "file_edit"
    FILE_CREATE = "file_create"
    FILE_DELETE = "file_delete"
    BASH_COMMAND = "bash_command"
    TOOL_CALL = "tool_call"


@dataclass
class PendingAction:
    id: str
    type: ActionType
    description: str
    file_path: Optional[str] = None
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())


@dataclass
class Session:
    id: str
    prompt: str
    status: SessionStatus
    progress: float = 0.0
    task_name: str = ""
    pending_actions: list = field(default_factory=list)
    output_log: list = field(default_factory=list)
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    completed_at: Optional[str] = None
    process_pid: Optional[int] = None
    web_session_id: Optional[str] = None
    error: Optional[str] = None

    def to_dict(self):
        return {
            "id": self.id,
            "prompt": self.prompt,
            "status": self.status.value,
            "progress": self.progress,
            "task_name": self.task_name,
            "pending_actions": [asdict(a) if isinstance(a, PendingAction) else a for a in self.pending_actions],
            "output_log": self.output_log[-50:],  # Last 50 lines
            "created_at": self.created_at,
            "completed_at": self.completed_at,
            "web_session_id": self.web_session_id,
            "error": self.error,
        }


# =============================================================================
# Session Manager
# =============================================================================

class ClaudeSessionManager:
    def __init__(self):
        self.sessions: dict[str, Session] = {}
        self.processes: dict[str, subprocess.Popen] = {}
        self._claude_path = self._find_claude()

    def _find_claude(self) -> str:
        """Find the claude CLI executable."""
        # Check common locations
        candidates = [
            shutil.which("claude"),
            os.path.expanduser("~/.claude/local/claude"),
            os.path.expanduser("~/.local/bin/claude"),
            "/usr/local/bin/claude",
        ]
        for path in candidates:
            if path and os.path.isfile(path):
                return path
        return "claude"  # Hope it's in PATH

    async def create_session(self, prompt: str, working_dir: Optional[str] = None) -> Session:
        """Create a new Claude web session."""
        session_id = str(uuid.uuid4())[:8]

        session = Session(
            id=session_id,
            prompt=prompt,
            status=SessionStatus.STARTING,
            task_name=self._extract_task_name(prompt),
        )
        self.sessions[session_id] = session

        # Start the claude process in background
        asyncio.create_task(self._run_session(session, working_dir))

        return session

    def _extract_task_name(self, prompt: str) -> str:
        """Extract a short task name from the prompt."""
        # Get first few words, uppercase
        words = prompt.split()[:3]
        name = " ".join(words).upper()
        if len(name) > 20:
            name = name[:17] + "..."
        return name

    async def _run_session(self, session: Session, working_dir: Optional[str] = None):
        """Run the Claude session as a subprocess."""
        try:
            # Build command - use & prefix for web session
            cmd = [self._claude_path, "--dangerously-skip-permissions"]

            # Create the process
            cwd = working_dir or os.getcwd()

            session.status = SessionStatus.RUNNING
            session.progress = 0.1

            # Use & prefix to send to web
            full_prompt = f'& {session.prompt}'

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,
                cwd=cwd,
            )

            session.process_pid = process.pid

            # Send the prompt
            process.stdin.write(full_prompt.encode() + b'\n')
            await process.stdin.drain()
            process.stdin.close()

            # Read output
            while True:
                line = await process.stdout.readline()
                if not line:
                    break

                decoded = line.decode('utf-8', errors='replace').strip()
                if decoded:
                    session.output_log.append(decoded)
                    self._parse_output_line(session, decoded)

            await process.wait()

            if process.returncode == 0:
                session.status = SessionStatus.COMPLETED
                session.progress = 1.0
            else:
                session.status = SessionStatus.FAILED
                session.error = f"Process exited with code {process.returncode}"

            session.completed_at = datetime.now().isoformat()

        except Exception as e:
            session.status = SessionStatus.FAILED
            session.error = str(e)
            session.completed_at = datetime.now().isoformat()

    def _parse_output_line(self, session: Session, line: str):
        """Parse Claude output to extract progress and pending actions."""
        # Look for progress indicators
        if "%" in line:
            match = re.search(r'(\d+)%', line)
            if match:
                session.progress = int(match.group(1)) / 100.0

        # Look for web session ID
        if "session" in line.lower() and "id" in line.lower():
            match = re.search(r'[a-f0-9-]{36}', line)
            if match:
                session.web_session_id = match.group(0)

        # Look for pending actions
        action_patterns = [
            (r'edit(?:ing)?\s+(\S+)', ActionType.FILE_EDIT),
            (r'creat(?:e|ing)\s+(\S+)', ActionType.FILE_CREATE),
            (r'delet(?:e|ing)\s+(\S+)', ActionType.FILE_DELETE),
            (r'run(?:ning)?\s+(.+)', ActionType.BASH_COMMAND),
        ]

        for pattern, action_type in action_patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                action = PendingAction(
                    id=str(uuid.uuid4())[:8],
                    type=action_type,
                    description=line[:100],
                    file_path=match.group(1) if action_type != ActionType.BASH_COMMAND else None,
                )
                session.pending_actions.append(action)
                session.status = SessionStatus.WAITING_APPROVAL
                break

        # Update task status
        if "complete" in line.lower() or "done" in line.lower():
            session.progress = 1.0

    def get_session(self, session_id: str) -> Optional[Session]:
        return self.sessions.get(session_id)

    def list_sessions(self) -> list[Session]:
        return list(self.sessions.values())

    async def approve_action(self, session_id: str, action_id: Optional[str] = None) -> bool:
        """Approve a pending action."""
        session = self.sessions.get(session_id)
        if not session:
            return False

        if action_id:
            session.pending_actions = [a for a in session.pending_actions if a.id != action_id]
        elif session.pending_actions:
            session.pending_actions.pop(0)

        if not session.pending_actions:
            session.status = SessionStatus.RUNNING

        return True

    async def approve_all(self, session_id: str) -> bool:
        """Approve all pending actions."""
        session = self.sessions.get(session_id)
        if not session:
            return False

        session.pending_actions = []
        session.status = SessionStatus.RUNNING
        return True

    async def discard_action(self, session_id: str, action_id: Optional[str] = None) -> bool:
        """Discard a pending action."""
        return await self.approve_action(session_id, action_id)  # Same logic for now

    async def cancel_session(self, session_id: str) -> bool:
        """Cancel a running session."""
        session = self.sessions.get(session_id)
        if not session:
            return False

        if session.process_pid:
            try:
                os.kill(session.process_pid, 9)
            except ProcessLookupError:
                pass

        session.status = SessionStatus.CANCELLED
        session.completed_at = datetime.now().isoformat()
        return True


# =============================================================================
# FastAPI Server (preferred)
# =============================================================================

if USE_FASTAPI:
    app = FastAPI(
        title="Claude Watch Bridge",
        description="Bridge server connecting Apple Watch to Claude Code web sessions",
        version="1.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    manager = ClaudeSessionManager()

    class PromptRequest(BaseModel):
        prompt: str
        working_dir: Optional[str] = None

    class ActionRequest(BaseModel):
        action_id: Optional[str] = None

    @app.get("/status")
    async def health_check():
        """Server health check."""
        return {
            "status": "ok",
            "server": "claude-watch-bridge",
            "version": "1.0.0",
            "active_sessions": len([s for s in manager.sessions.values()
                                   if s.status in [SessionStatus.RUNNING, SessionStatus.WAITING_APPROVAL]]),
        }

    @app.post("/session")
    async def create_session(request: PromptRequest):
        """Start a new Claude web session."""
        session = await manager.create_session(request.prompt, request.working_dir)
        return session.to_dict()

    @app.get("/session/{session_id}")
    async def get_session(session_id: str):
        """Get session status."""
        session = manager.get_session(session_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        return session.to_dict()

    @app.get("/sessions")
    async def list_sessions():
        """List all sessions."""
        return [s.to_dict() for s in manager.list_sessions()]

    @app.post("/session/{session_id}/approve")
    async def approve_action(session_id: str, request: ActionRequest = ActionRequest()):
        """Approve a pending action."""
        success = await manager.approve_action(session_id, request.action_id)
        if not success:
            raise HTTPException(status_code=404, detail="Session not found")
        return {"status": "approved"}

    @app.post("/session/{session_id}/approveAll")
    async def approve_all(session_id: str):
        """Approve all pending actions."""
        success = await manager.approve_all(session_id)
        if not success:
            raise HTTPException(status_code=404, detail="Session not found")
        return {"status": "approved_all"}

    @app.post("/session/{session_id}/discard")
    async def discard_action(session_id: str, request: ActionRequest = ActionRequest()):
        """Discard a pending action."""
        success = await manager.discard_action(session_id, request.action_id)
        if not success:
            raise HTTPException(status_code=404, detail="Session not found")
        return {"status": "discarded"}

    @app.post("/session/{session_id}/cancel")
    async def cancel_session(session_id: str):
        """Cancel a running session."""
        success = await manager.cancel_session(session_id)
        if not success:
            raise HTTPException(status_code=404, detail="Session not found")
        return {"status": "cancelled"}

    def run_server(host: str = "0.0.0.0", port: int = 8787):
        print(f"""
╔══════════════════════════════════════════════════════════════╗
║               Claude Watch Bridge Server                      ║
╠══════════════════════════════════════════════════════════════╣
║  Local:    http://localhost:{port}                            ║
║  Network:  http://{host}:{port}                              ║
╠══════════════════════════════════════════════════════════════╣
║  To expose to your Apple Watch:                              ║
║                                                              ║
║  Option 1 - Tailscale:                                       ║
║    tailscale serve {port}                                     ║
║                                                              ║
║  Option 2 - ngrok:                                           ║
║    ngrok http {port}                                          ║
║                                                              ║
║  Option 3 - Cloudflare Tunnel:                               ║
║    cloudflared tunnel --url http://localhost:{port}           ║
╚══════════════════════════════════════════════════════════════╝
        """)
        uvicorn.run(app, host=host, port=port)


# =============================================================================
# Fallback HTTP Server (if FastAPI not installed)
# =============================================================================

else:
    class SimpleHandler(BaseHTTPRequestHandler):
        manager = ClaudeSessionManager()

        def _send_json(self, data, status=200):
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())

        def do_GET(self):
            if self.path == "/status":
                self._send_json({"status": "ok", "server": "claude-watch-bridge"})
            elif self.path == "/sessions":
                self._send_json([s.to_dict() for s in self.manager.list_sessions()])
            elif self.path.startswith("/session/"):
                session_id = self.path.split("/")[2]
                session = self.manager.get_session(session_id)
                if session:
                    self._send_json(session.to_dict())
                else:
                    self._send_json({"error": "Not found"}, 404)
            else:
                self._send_json({"error": "Not found"}, 404)

        def do_POST(self):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode() if content_length else "{}"
            data = json.loads(body) if body else {}

            if self.path == "/session":
                prompt = data.get("prompt", "")
                # Note: async won't work properly in simple server
                session = Session(
                    id=str(uuid.uuid4())[:8],
                    prompt=prompt,
                    status=SessionStatus.STARTING,
                    task_name=prompt[:20].upper(),
                )
                self.manager.sessions[session.id] = session
                self._send_json(session.to_dict())
            else:
                self._send_json({"error": "Not found"}, 404)

        def do_OPTIONS(self):
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')
            self.end_headers()

    def run_server(host: str = "0.0.0.0", port: int = 8787):
        print(f"[!] FastAPI not installed. Using basic HTTP server (limited functionality)")
        print(f"[!] Install FastAPI for full features: pip install fastapi uvicorn")
        print(f"\nClaude Watch Bridge running on http://{host}:{port}")
        server = HTTPServer((host, port), SimpleHandler)
        server.serve_forever()


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Claude Watch Bridge Server")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--port", type=int, default=8787, help="Port to listen on")
    args = parser.parse_args()

    run_server(args.host, args.port)
