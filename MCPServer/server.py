#!/usr/bin/env python3
"""
Claude Watch MCP Server

An MCP server that bridges Claude Code to your Apple Watch.
Provides real-time updates via WebSocket and push notifications via APNs.

Run as MCP server:
    Add to Claude Code settings.json:
    {
      "mcpServers": {
        "watch": {
          "command": "python",
          "args": ["/path/to/server.py"]
        }
      }
    }

Run standalone (for testing):
    python server.py --standalone --port 8787
"""

import asyncio
import json
import os
import sys
import uuid
import logging
from datetime import datetime
from enum import Enum
from dataclasses import dataclass, field, asdict
from typing import Optional, Callable, Any
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger("claude-watch")

# Try imports for full functionality
try:
    import websockets
    from websockets.server import serve as ws_serve
    HAS_WEBSOCKETS = True
except ImportError:
    HAS_WEBSOCKETS = False
    logger.warning("websockets not installed - WebSocket support disabled")

try:
    from aiohttp import web
    HAS_AIOHTTP = True
except ImportError:
    HAS_AIOHTTP = False
    logger.warning("aiohttp not installed - REST API disabled")


# =============================================================================
# Data Models
# =============================================================================

class ActionType(str, Enum):
    FILE_EDIT = "file_edit"
    FILE_CREATE = "file_create"
    FILE_DELETE = "file_delete"
    BASH = "bash"
    TOOL_USE = "tool_use"
    APPROVAL = "approval"

class ActionStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    TIMEOUT = "timeout"

class SessionStatus(str, Enum):
    IDLE = "idle"
    RUNNING = "running"
    WAITING = "waiting"
    COMPLETED = "completed"
    FAILED = "failed"

@dataclass
class PendingAction:
    id: str
    type: ActionType
    title: str
    description: str
    file_path: Optional[str] = None
    command: Optional[str] = None
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    status: ActionStatus = ActionStatus.PENDING

    def to_dict(self):
        return {
            "id": self.id,
            "type": self.type.value,
            "title": self.title,
            "description": self.description,
            "file_path": self.file_path,
            "command": self.command,
            "timestamp": self.timestamp,
            "status": self.status.value,
        }

@dataclass
class SessionState:
    task_name: str = ""
    task_description: str = ""
    progress: float = 0.0
    status: SessionStatus = SessionStatus.IDLE
    pending_actions: list = field(default_factory=list)
    model: str = "opus"
    yolo_mode: bool = False
    started_at: Optional[str] = None

    def to_dict(self):
        return {
            "task_name": self.task_name,
            "task_description": self.task_description,
            "progress": self.progress,
            "status": self.status.value,
            "pending_actions": [a.to_dict() for a in self.pending_actions],
            "model": self.model,
            "yolo_mode": self.yolo_mode,
            "started_at": self.started_at,
        }


# =============================================================================
# Watch Connection Manager
# =============================================================================

class WatchConnectionManager:
    """Manages WebSocket connections to Apple Watches"""

    def __init__(self):
        self.connections: set = set()
        self.state = SessionState()
        self.action_responses: dict[str, asyncio.Future] = {}
        self.apns_sender: Optional['APNsSender'] = None

    async def register(self, websocket):
        """Register a new watch connection"""
        self.connections.add(websocket)
        logger.info(f"Watch connected. Total connections: {len(self.connections)}")
        # Send current state immediately
        await self.send_to(websocket, {
            "type": "state_sync",
            "state": self.state.to_dict()
        })

    async def unregister(self, websocket):
        """Unregister a watch connection"""
        self.connections.discard(websocket)
        logger.info(f"Watch disconnected. Total connections: {len(self.connections)}")

    async def broadcast(self, message: dict):
        """Send message to all connected watches"""
        if not self.connections:
            return

        data = json.dumps(message)
        await asyncio.gather(
            *[ws.send(data) for ws in self.connections],
            return_exceptions=True
        )

    async def send_to(self, websocket, message: dict):
        """Send message to specific watch"""
        try:
            await websocket.send(json.dumps(message))
        except Exception as e:
            logger.error(f"Failed to send to watch: {e}")

    async def request_approval(self, action: PendingAction, timeout: float = 300) -> ActionStatus:
        """
        Request approval from watch for an action.
        Returns the approval status.
        """
        # Add to pending actions
        self.state.pending_actions.append(action)
        self.state.status = SessionStatus.WAITING

        # Create future for response
        future = asyncio.Future()
        self.action_responses[action.id] = future

        # Broadcast to watches
        await self.broadcast({
            "type": "action_requested",
            "action": action.to_dict()
        })

        # Send push notification
        if self.apns_sender:
            await self.apns_sender.send_action_notification(action)

        try:
            # Wait for response with timeout
            status = await asyncio.wait_for(future, timeout=timeout)
            return status
        except asyncio.TimeoutError:
            action.status = ActionStatus.TIMEOUT
            return ActionStatus.TIMEOUT
        finally:
            # Clean up
            self.action_responses.pop(action.id, None)
            self.state.pending_actions = [
                a for a in self.state.pending_actions if a.id != action.id
            ]
            if not self.state.pending_actions:
                self.state.status = SessionStatus.RUNNING

    def handle_action_response(self, action_id: str, approved: bool):
        """Handle approval/rejection from watch"""
        if action_id in self.action_responses:
            status = ActionStatus.APPROVED if approved else ActionStatus.REJECTED
            self.action_responses[action_id].set_result(status)

            # Update action status
            for action in self.state.pending_actions:
                if action.id == action_id:
                    action.status = status
                    break

    async def update_progress(self, progress: float, task_name: str = None):
        """Update task progress"""
        self.state.progress = progress
        if task_name:
            self.state.task_name = task_name

        await self.broadcast({
            "type": "progress_update",
            "progress": progress,
            "task_name": self.state.task_name
        })

    async def set_task(self, name: str, description: str = ""):
        """Set current task"""
        self.state.task_name = name
        self.state.task_description = description
        self.state.progress = 0.0
        self.state.status = SessionStatus.RUNNING
        self.state.started_at = datetime.now().isoformat()

        await self.broadcast({
            "type": "task_started",
            "task_name": name,
            "task_description": description
        })

    async def complete_task(self, success: bool = True):
        """Mark task as complete"""
        self.state.status = SessionStatus.COMPLETED if success else SessionStatus.FAILED
        self.state.progress = 1.0 if success else self.state.progress

        await self.broadcast({
            "type": "task_completed",
            "success": success,
            "task_name": self.state.task_name
        })

        # Send push notification
        if self.apns_sender:
            await self.apns_sender.send_completion_notification(
                self.state.task_name, success
            )


# =============================================================================
# APNs Push Notifications
# =============================================================================

class APNsSender:
    """Send push notifications to Apple Watch via APNs"""

    def __init__(self, key_path: str, key_id: str, team_id: str, bundle_id: str):
        self.key_path = key_path
        self.key_id = key_id
        self.team_id = team_id
        self.bundle_id = bundle_id
        self.device_tokens: set[str] = set()
        self._jwt_token: Optional[str] = None
        self._jwt_expires: float = 0

    def register_device(self, token: str):
        """Register a device token for push notifications"""
        self.device_tokens.add(token)
        logger.info(f"Registered device token: {token[:20]}...")

    async def send_action_notification(self, action: PendingAction):
        """Send actionable notification for pending action"""
        payload = {
            "aps": {
                "alert": {
                    "title": f"Claude: {action.type.value.replace('_', ' ').title()}",
                    "subtitle": action.title,
                    "body": action.description[:100],
                },
                "category": "CLAUDE_ACTION",
                "sound": "default",
                "interruption-level": "time-sensitive",
            },
            "action_id": action.id,
            "action_type": action.type.value,
            "file_path": action.file_path,
        }
        await self._send_to_all(payload)

    async def send_completion_notification(self, task_name: str, success: bool):
        """Send notification when task completes"""
        payload = {
            "aps": {
                "alert": {
                    "title": "Task Complete" if success else "Task Failed",
                    "body": task_name,
                },
                "sound": "default",
            }
        }
        await self._send_to_all(payload)

    async def send_prompt_response(self, response: str):
        """Send notification with Claude's response to a prompt"""
        payload = {
            "aps": {
                "alert": {
                    "title": "Claude",
                    "body": response[:200] + ("..." if len(response) > 200 else ""),
                },
                "sound": "default",
            }
        }
        await self._send_to_all(payload)

    async def _send_to_all(self, payload: dict):
        """Send notification to all registered devices"""
        if not self.device_tokens:
            logger.debug("No device tokens registered, skipping push")
            return

        # In production, implement actual APNs HTTP/2 connection
        # For now, log the payload
        logger.info(f"Would send push notification: {json.dumps(payload, indent=2)}")

        # TODO: Implement actual APNs sending with:
        # - JWT authentication
        # - HTTP/2 connection to api.push.apple.com
        # - Device token iteration
        # - Error handling and token cleanup


# =============================================================================
# MCP Protocol Handler
# =============================================================================

class MCPServer:
    """MCP Server implementation for Claude Code integration"""

    def __init__(self, watch_manager: WatchConnectionManager):
        self.watch_manager = watch_manager
        self.tools = self._register_tools()

    def _register_tools(self) -> dict:
        """Register available MCP tools"""
        return {
            "watch_notify": {
                "description": "Send a notification to the connected Apple Watch",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {"type": "string", "description": "Notification title"},
                        "message": {"type": "string", "description": "Notification message"},
                    },
                    "required": ["title", "message"]
                },
                "handler": self._handle_notify
            },
            "watch_request_approval": {
                "description": "Request approval from watch for an action. Blocks until approved/rejected.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "action_type": {
                            "type": "string",
                            "enum": ["file_edit", "file_create", "file_delete", "bash", "tool_use"],
                            "description": "Type of action requiring approval"
                        },
                        "title": {"type": "string", "description": "Short title for the action"},
                        "description": {"type": "string", "description": "Detailed description"},
                        "file_path": {"type": "string", "description": "File path if applicable"},
                        "command": {"type": "string", "description": "Command if bash action"},
                    },
                    "required": ["action_type", "title", "description"]
                },
                "handler": self._handle_request_approval
            },
            "watch_update_progress": {
                "description": "Update task progress shown on watch",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "progress": {"type": "number", "minimum": 0, "maximum": 1},
                        "task_name": {"type": "string"},
                    },
                    "required": ["progress"]
                },
                "handler": self._handle_update_progress
            },
            "watch_set_task": {
                "description": "Set the current task being worked on",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string", "description": "Task name"},
                        "description": {"type": "string", "description": "Task description"},
                    },
                    "required": ["name"]
                },
                "handler": self._handle_set_task
            },
            "watch_complete_task": {
                "description": "Mark current task as complete",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "success": {"type": "boolean", "default": True},
                    }
                },
                "handler": self._handle_complete_task
            },
            "watch_get_state": {
                "description": "Get current watch/session state",
                "parameters": {"type": "object", "properties": {}},
                "handler": self._handle_get_state
            },
        }

    async def _handle_notify(self, title: str, message: str) -> dict:
        await self.watch_manager.broadcast({
            "type": "notification",
            "title": title,
            "message": message
        })
        return {"success": True}

    async def _handle_request_approval(
        self,
        action_type: str,
        title: str,
        description: str,
        file_path: str = None,
        command: str = None
    ) -> dict:
        # Check YOLO mode
        if self.watch_manager.state.yolo_mode:
            return {"approved": True, "yolo_mode": True}

        action = PendingAction(
            id=str(uuid.uuid4())[:8],
            type=ActionType(action_type),
            title=title,
            description=description,
            file_path=file_path,
            command=command,
        )

        status = await self.watch_manager.request_approval(action)
        return {
            "approved": status == ActionStatus.APPROVED,
            "status": status.value
        }

    async def _handle_update_progress(self, progress: float, task_name: str = None) -> dict:
        await self.watch_manager.update_progress(progress, task_name)
        return {"success": True}

    async def _handle_set_task(self, name: str, description: str = "") -> dict:
        await self.watch_manager.set_task(name, description)
        return {"success": True}

    async def _handle_complete_task(self, success: bool = True) -> dict:
        await self.watch_manager.complete_task(success)
        return {"success": True}

    async def _handle_get_state(self) -> dict:
        return self.watch_manager.state.to_dict()

    async def handle_message(self, message: dict) -> dict:
        """Handle incoming MCP message"""
        method = message.get("method")
        params = message.get("params", {})
        msg_id = message.get("id")

        if method == "initialize":
            return {
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {"name": "claude-watch", "version": "1.0.0"},
                    "capabilities": {"tools": {}},
                }
            }

        elif method == "tools/list":
            tools_list = [
                {
                    "name": name,
                    "description": tool["description"],
                    "inputSchema": tool["parameters"]
                }
                for name, tool in self.tools.items()
            ]
            return {"id": msg_id, "result": {"tools": tools_list}}

        elif method == "tools/call":
            tool_name = params.get("name")
            tool_args = params.get("arguments", {})

            if tool_name not in self.tools:
                return {
                    "id": msg_id,
                    "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"}
                }

            try:
                result = await self.tools[tool_name]["handler"](**tool_args)
                return {
                    "id": msg_id,
                    "result": {"content": [{"type": "text", "text": json.dumps(result)}]}
                }
            except Exception as e:
                return {
                    "id": msg_id,
                    "error": {"code": -32603, "message": str(e)}
                }

        return {"id": msg_id, "error": {"code": -32601, "message": "Method not found"}}

    async def run_stdio(self):
        """Run MCP server over stdio"""
        logger.info("Starting MCP server over stdio")

        reader = asyncio.StreamReader()
        protocol = asyncio.StreamReaderProtocol(reader)
        await asyncio.get_event_loop().connect_read_pipe(lambda: protocol, sys.stdin)

        writer_transport, writer_protocol = await asyncio.get_event_loop().connect_write_pipe(
            asyncio.streams.FlowControlMixin, sys.stdout
        )
        writer = asyncio.StreamWriter(writer_transport, writer_protocol, reader, asyncio.get_event_loop())

        while True:
            try:
                line = await reader.readline()
                if not line:
                    break

                message = json.loads(line.decode())
                response = await self.handle_message(message)

                writer.write((json.dumps(response) + "\n").encode())
                await writer.drain()

            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON: {e}")
            except Exception as e:
                logger.error(f"Error handling message: {e}")


# =============================================================================
# WebSocket Server
# =============================================================================

async def websocket_handler(websocket, watch_manager: WatchConnectionManager):
    """Handle WebSocket connection from watch"""
    await watch_manager.register(websocket)

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get("type")

                if msg_type == "action_response":
                    action_id = data.get("action_id")
                    approved = data.get("approved", False)
                    watch_manager.handle_action_response(action_id, approved)

                elif msg_type == "prompt":
                    # Handle voice/text prompt from watch
                    prompt = data.get("text", "")
                    await watch_manager.broadcast({
                        "type": "prompt_received",
                        "text": prompt
                    })

                elif msg_type == "toggle_yolo":
                    watch_manager.state.yolo_mode = data.get("enabled", False)
                    await watch_manager.broadcast({
                        "type": "yolo_changed",
                        "enabled": watch_manager.state.yolo_mode
                    })
                    # Auto-approve all pending if YOLO enabled
                    if watch_manager.state.yolo_mode:
                        for action in watch_manager.state.pending_actions:
                            watch_manager.handle_action_response(action.id, True)

                elif msg_type == "approve_all":
                    for action in watch_manager.state.pending_actions:
                        watch_manager.handle_action_response(action.id, True)

                elif msg_type == "register_push_token":
                    token = data.get("token")
                    if token and watch_manager.apns_sender:
                        watch_manager.apns_sender.register_device(token)

                elif msg_type == "ping":
                    await watch_manager.send_to(websocket, {"type": "pong"})

            except json.JSONDecodeError:
                logger.error(f"Invalid JSON from watch: {message}")

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        await watch_manager.unregister(websocket)


# =============================================================================
# REST API (for watch fallback)
# =============================================================================

def create_rest_app(watch_manager: WatchConnectionManager) -> web.Application:
    """Create aiohttp REST application"""

    async def get_state(request):
        return web.json_response(watch_manager.state.to_dict())

    async def post_action_response(request):
        data = await request.json()
        action_id = data.get("action_id")
        approved = data.get("approved", False)
        watch_manager.handle_action_response(action_id, approved)
        return web.json_response({"success": True})

    async def post_approve_all(request):
        for action in watch_manager.state.pending_actions:
            watch_manager.handle_action_response(action.id, True)
        return web.json_response({"success": True})

    async def post_prompt(request):
        data = await request.json()
        prompt = data.get("text", "")
        await watch_manager.broadcast({
            "type": "prompt_received",
            "text": prompt
        })
        return web.json_response({"success": True})

    async def post_toggle_yolo(request):
        data = await request.json()
        watch_manager.state.yolo_mode = data.get("enabled", False)
        await watch_manager.broadcast({
            "type": "yolo_changed",
            "enabled": watch_manager.state.yolo_mode
        })
        return web.json_response({"success": True, "yolo_mode": watch_manager.state.yolo_mode})

    async def get_health(request):
        return web.json_response({
            "status": "ok",
            "connections": len(watch_manager.connections),
            "pending_actions": len(watch_manager.state.pending_actions),
        })

    async def post_test_action(request):
        """Create a test pending action for debugging"""
        data = await request.json()
        action = PendingAction(
            id=str(uuid.uuid4())[:8],
            type=ActionType(data.get("type", "bash")),
            title=data.get("title", "Test Action"),
            description=data.get("description", "This is a test action"),
            command=data.get("command"),
            file_path=data.get("file_path"),
        )
        asyncio.create_task(watch_manager.request_approval(action))
        return web.json_response({"success": True, "action_id": action.id})

    async def post_test_notify(request):
        """Send a test notification to all watches"""
        data = await request.json()
        await watch_manager.broadcast({
            "type": "notification",
            "title": data.get("title", "Test Notification"),
            "message": data.get("message", "This is a test")
        })
        return web.json_response({"success": True})

    app = web.Application()
    app.router.add_get("/state", get_state)
    app.router.add_post("/action/respond", post_action_response)
    app.router.add_post("/action/approve-all", post_approve_all)
    app.router.add_post("/prompt", post_prompt)
    app.router.add_post("/yolo", post_toggle_yolo)
    app.router.add_get("/health", get_health)
    app.router.add_post("/test/action", post_test_action)
    app.router.add_post("/test/notify", post_test_notify)

    return app


# =============================================================================
# Main Entry Point
# =============================================================================

async def main():
    import argparse

    parser = argparse.ArgumentParser(description="Claude Watch MCP Server")
    parser.add_argument("--standalone", action="store_true", help="Run in standalone mode (not as MCP)")
    parser.add_argument("--port", type=int, default=8787, help="WebSocket/HTTP port")
    parser.add_argument("--host", default="0.0.0.0", help="Host to bind to")
    parser.add_argument("--apns-key", help="Path to APNs key file")
    parser.add_argument("--apns-key-id", help="APNs key ID")
    parser.add_argument("--apns-team-id", help="Apple Team ID")
    parser.add_argument("--bundle-id", default="com.example.claudewatch", help="App bundle ID")
    args = parser.parse_args()

    # Initialize watch manager
    watch_manager = WatchConnectionManager()

    # Initialize APNs if configured
    if args.apns_key and args.apns_key_id and args.apns_team_id:
        watch_manager.apns_sender = APNsSender(
            args.apns_key, args.apns_key_id, args.apns_team_id, args.bundle_id
        )

    # Initialize MCP server
    mcp_server = MCPServer(watch_manager)

    if args.standalone:
        # Run in standalone mode with WebSocket + REST
        tasks = []

        if HAS_WEBSOCKETS:
            async def ws_server():
                async with ws_serve(
                    lambda ws: websocket_handler(ws, watch_manager),
                    args.host,
                    args.port
                ):
                    logger.info(f"WebSocket server running on ws://{args.host}:{args.port}")
                    await asyncio.Future()  # Run forever

            tasks.append(ws_server())

        if HAS_AIOHTTP:
            async def rest_server():
                app = create_rest_app(watch_manager)
                runner = web.AppRunner(app)
                await runner.setup()
                site = web.TCPSite(runner, args.host, args.port + 1)
                await site.start()
                logger.info(f"REST API running on http://{args.host}:{args.port + 1}")
                await asyncio.Future()  # Run forever

            tasks.append(rest_server())

        if tasks:
            print(f"""
╔══════════════════════════════════════════════════════════════╗
║                 Claude Watch Server                          ║
╠══════════════════════════════════════════════════════════════╣
║  WebSocket:  ws://{args.host}:{args.port:<5}                           ║
║  REST API:   http://{args.host}:{args.port + 1:<5}                          ║
╠══════════════════════════════════════════════════════════════╣
║  Expose via: tailscale serve {args.port}                        ║
║          or: ngrok http {args.port}                              ║
╚══════════════════════════════════════════════════════════════╝
            """)
            await asyncio.gather(*tasks)
        else:
            logger.error("No server dependencies installed. Install: pip install websockets aiohttp")

    else:
        # Run as MCP server over stdio
        # Also start WebSocket server in background for watch connections
        tasks = [mcp_server.run_stdio()]

        if HAS_WEBSOCKETS:
            async def ws_server():
                async with ws_serve(
                    lambda ws: websocket_handler(ws, watch_manager),
                    "0.0.0.0",
                    args.port
                ):
                    await asyncio.Future()

            tasks.append(ws_server())

        await asyncio.gather(*tasks)


if __name__ == "__main__":
    asyncio.run(main())
