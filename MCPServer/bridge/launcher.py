"""
CLI Launcher for Claude Code with --sdk-url.

Spawns Claude Code CLI processes that connect back to our bridge server
via WebSocket. Manages process lifecycle, session resume, and graceful
shutdown.
"""
from __future__ import annotations

import asyncio
import logging
import os
import shutil
import time
import uuid
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger("bridge.launcher")


@dataclass
class CLISessionInfo:
    """Metadata about a launched CLI process."""

    session_id: str
    pid: int | None = None
    state: str = "starting"  # starting | connected | running | exited
    exit_code: int | None = None
    model: str | None = None
    permission_mode: str | None = None
    cwd: str = ""
    created_at: float = field(default_factory=time.time)
    cli_session_id: str | None = None  # CLI's internal session ID for --resume


class CLILauncher:
    """Manages Claude Code CLI processes launched with --sdk-url."""

    def __init__(self, port: int) -> None:
        self.port = port
        self._sessions: dict[str, CLISessionInfo] = {}
        self._processes: dict[str, asyncio.subprocess.Process] = {}

    async def launch(
        self,
        cwd: str | None = None,
        model: str | None = None,
        permission_mode: str | None = None,
        claude_binary: str | None = None,
    ) -> CLISessionInfo:
        """Launch a new Claude Code CLI session.

        Returns CLISessionInfo with the session_id that the CLI will
        connect back to via ws://localhost:{port}/ws/cli/{session_id}
        """
        session_id = str(uuid.uuid4())
        effective_cwd = cwd or os.getcwd()

        info = CLISessionInfo(
            session_id=session_id,
            model=model,
            permission_mode=permission_mode,
            cwd=effective_cwd,
        )
        self._sessions[session_id] = info

        await self._spawn_cli(session_id, info, claude_binary=claude_binary)
        return info

    async def relaunch(self, session_id: str) -> bool:
        """Kill old process and relaunch with --resume if cli_session_id known."""
        info = self._sessions.get(session_id)
        if not info:
            return False

        # Kill old process
        await self._kill_process(session_id)

        info.state = "starting"
        info.exit_code = None
        await self._spawn_cli(
            session_id,
            info,
            resume_session_id=info.cli_session_id,
        )
        return True

    async def kill(self, session_id: str) -> bool:
        """Kill a session's CLI process."""
        return await self._kill_process(session_id)

    def mark_connected(self, session_id: str) -> None:
        """Mark session as connected (called when CLI establishes WS)."""
        info = self._sessions.get(session_id)
        if info and info.state in ("starting", "connected"):
            info.state = "connected"
            logger.info(f"Session {session_id} connected via WebSocket")

    def set_cli_session_id(self, session_id: str, cli_session_id: str) -> None:
        """Store CLI's internal session ID for --resume."""
        info = self._sessions.get(session_id)
        if info:
            info.cli_session_id = cli_session_id

    def get_session(self, session_id: str) -> CLISessionInfo | None:
        """Get a specific session by ID."""
        return self._sessions.get(session_id)

    def list_sessions(self) -> list[CLISessionInfo]:
        """List all tracked sessions."""
        return list(self._sessions.values())

    def is_alive(self, session_id: str) -> bool:
        """Check if a session exists and is not exited."""
        info = self._sessions.get(session_id)
        return bool(info and info.state != "exited")

    async def kill_all(self) -> None:
        """Kill all CLI processes."""
        ids = list(self._processes.keys())
        await asyncio.gather(*(self._kill_process(sid) for sid in ids))

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _spawn_cli(
        self,
        session_id: str,
        info: CLISessionInfo,
        claude_binary: str | None = None,
        resume_session_id: str | None = None,
    ) -> None:
        binary = claude_binary or shutil.which("claude") or "claude"

        sdk_url = f"ws://localhost:{self.port}/ws/cli/{session_id}"

        args = [
            binary,
            "--sdk-url",
            sdk_url,
            "--print",
            "--output-format",
            "stream-json",
            "--input-format",
            "stream-json",
            "--verbose",
        ]

        if info.model:
            args.extend(["--model", info.model])
        if info.permission_mode:
            args.extend(["--permission-mode", info.permission_mode])
        if resume_session_id:
            args.extend(["--resume", resume_session_id])

        args.extend(["-p", ""])

        logger.info(f"Spawning session {session_id}: {' '.join(args)}")

        proc = await asyncio.create_subprocess_exec(
            *args,
            cwd=info.cwd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        info.pid = proc.pid
        self._processes[session_id] = proc

        # Monitor process exit in background
        asyncio.create_task(
            self._monitor_exit(session_id, proc, resume_session_id),
        )
        # Pipe stderr for debugging
        asyncio.create_task(self._pipe_stderr(session_id, proc))

    async def _monitor_exit(
        self,
        session_id: str,
        proc: asyncio.subprocess.Process,
        resume_session_id: str | None = None,
    ) -> None:
        spawned_at = time.time()
        exit_code = await proc.wait()
        uptime = time.time() - spawned_at

        logger.info(
            f"Session {session_id} exited (code={exit_code}, uptime={uptime:.1f}s)",
        )

        info = self._sessions.get(session_id)
        if info:
            info.state = "exited"
            info.exit_code = exit_code

            # If exited almost immediately with --resume, resume likely failed
            if uptime < 5.0 and resume_session_id:
                logger.error(
                    f"Session {session_id} exited immediately after --resume. "
                    f"Clearing cli_session_id.",
                )
                info.cli_session_id = None

        self._processes.pop(session_id, None)

    async def _pipe_stderr(
        self,
        session_id: str,
        proc: asyncio.subprocess.Process,
    ) -> None:
        if not proc.stderr:
            return
        while True:
            line = await proc.stderr.readline()
            if not line:
                break
            text = line.decode("utf-8", errors="replace").strip()
            if text:
                logger.debug(f"[session:{session_id}:stderr] {text}")

    async def _kill_process(self, session_id: str) -> bool:
        proc = self._processes.get(session_id)
        if not proc:
            return False

        try:
            proc.terminate()  # SIGTERM
            try:
                await asyncio.wait_for(proc.wait(), timeout=5.0)
            except asyncio.TimeoutError:
                logger.warning(f"Force-killing session {session_id}")
                proc.kill()  # SIGKILL
                await proc.wait()
        except ProcessLookupError:
            pass  # Already dead

        self._processes.pop(session_id, None)
        info = self._sessions.get(session_id)
        if info:
            info.state = "exited"
            info.exit_code = -1
        return True
