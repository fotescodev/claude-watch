"""
Bridge server main entrypoint.

Wires together:
- NDJSONServer (WebSocket for CLI)
- BridgeAPI (HTTP for watch) [optional, requires aiohttp]
- CloudClient (cloud relay sync) [optional, requires cloud_url]
- CLILauncher (process management)
- Message handlers (route CLI messages to appropriate handlers)

Usage:
    python -m MCPServer.bridge --port 8787 --pairing-id PAIR-123
    python -m MCPServer.bridge --port 8787 --pairing-id PAIR-123 --cloud-url https://remmy.watch
    python -m MCPServer.bridge --port 8787 --pairing-id PAIR-123 --launch --cwd /path/to/project
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
import uuid
from typing import Any

from MCPServer.bridge.ndjson_server import NDJSONServer
from MCPServer.bridge.session import Session
from MCPServer.bridge.types import parse_cli_message
from MCPServer.bridge.permissions import handle_can_use_tool, approve_permission, deny_permission
from MCPServer.bridge.questions import (
    build_approve_response,
    build_deny_response,
    is_ask_user_question,
)
from MCPServer.bridge.progress import session_to_watch_progress, update_session_progress

logger = logging.getLogger("bridge")


class Bridge:
    """Main bridge coordinating CLI WebSocket, HTTP API, and message routing.

    The bridge is the central orchestration layer:

    1. **NDJSONServer** listens for Claude CLI WebSocket connections and
       dispatches parsed messages to type-specific handlers registered here.
    2. **BridgeAPI** (optional, requires ``aiohttp``) exposes HTTP endpoints
       consumed by the watch (via cloud relay) for approvals, questions,
       progress, and interrupts.
    3. **CLILauncher** (optional, ``--launch`` mode) spawns the Claude Code CLI
       with ``--sdk-url`` pointing back at this bridge.

    Message routing flow::

        CLI --ws--> NDJSONServer --dispatch--> Bridge._handle_* methods
                                                   |
                                                   +--> Session state updates
                                                   +--> Permission queue (watch polls via API)
                                                   +--> Progress tracking
    """

    def __init__(
        self,
        port: int = 8787,
        pairing_id: str | None = None,
        cloud_url: str | None = None,
    ) -> None:
        self.port = port
        self.pairing_id = pairing_id or str(uuid.uuid4())
        self.cloud_url = cloud_url

        self._sessions: dict[str, Session] = {}  # session_id -> Session
        self._ndjson = NDJSONServer(host="127.0.0.1", port=port)
        self._launcher: Any = None  # CLILauncher, set if --launch mode
        self._api: Any = None  # BridgeAPI instance, set if aiohttp available
        self._http_runner: Any = None  # aiohttp AppRunner, for cleanup
        self._cloud_client: Any = None  # CloudClient, set if cloud_url provided
        self._cloud_poll_task: asyncio.Task | None = None
        self._cloud_poll_running = False
        self._last_progress_push: float = 0.0  # monotonic time of last push

        # Wire NDJSON handlers
        self._ndjson.on_connect(self._on_cli_connect)
        self._ndjson.on_disconnect(self._on_cli_disconnect)
        self._ndjson.on_message("system", self._handle_system)
        self._ndjson.on_message("assistant", self._handle_assistant)
        self._ndjson.on_message("result", self._handle_result)
        self._ndjson.on_message("control_request", self._handle_control_request)
        self._ndjson.on_message("stream_event", self._handle_stream_event)
        self._ndjson.on_message("tool_progress", self._handle_tool_progress)
        self._ndjson.on_message("tool_use_summary", self._handle_tool_use_summary)
        self._ndjson.on_message("auth_status", self._handle_auth_status)

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def sessions(self) -> dict[str, Session]:
        """All active sessions keyed by session_id."""
        return self._sessions

    @property
    def ndjson_server(self) -> NDJSONServer:
        """The underlying NDJSON WebSocket server."""
        return self._ndjson

    # ------------------------------------------------------------------
    # CLI lifecycle callbacks
    # ------------------------------------------------------------------

    async def _on_cli_connect(self, session_id: str, websocket: Any) -> None:
        """Called when CLI connects via WebSocket.

        If a ``pairing_id`` was configured and the API is active, the session
        is auto-registered so that watch-facing REST endpoints resolve
        immediately — no ``--launch`` mode required.
        """
        session = Session(session_id)
        self._sessions[session_id] = session
        session.cli_socket = websocket
        logger.info("CLI connected: session=%s", session_id)

        if self._launcher:
            self._launcher.mark_connected(session_id)

        # Auto-register with REST API so watch endpoints work even when
        # the CLI was launched externally (e.g. by remmy-watch CLI).
        if self._api and self.pairing_id:
            self._api.register_session(self.pairing_id, session_id, session)
            logger.info(
                "Auto-registered session %s for pairing %s",
                session_id,
                self.pairing_id,
            )

    async def _on_cli_disconnect(self, session_id: str) -> None:
        """Called when CLI WebSocket disconnects."""
        session = self._sessions.get(session_id)
        if session:
            cancelled = session.cancel_all_permissions()
            session.cli_socket = None
            logger.info(
                "CLI disconnected: session=%s, cancelled %d permissions",
                session_id,
                len(cancelled),
            )

    # ------------------------------------------------------------------
    # Message handlers
    # ------------------------------------------------------------------

    async def _handle_system(self, session_id: str, msg: dict) -> None:
        """Handle system messages (init, status, etc.)."""
        session = self._sessions.get(session_id)
        if not session:
            return

        parsed = parse_cli_message(msg)
        subtype = msg.get("subtype")

        if subtype == "init":
            session.update_from_init(parsed)
            # Store CLI's internal session ID for --resume
            cli_sid = msg.get("session_id")
            if cli_sid and self._launcher:
                self._launcher.set_cli_session_id(session_id, cli_sid)
            logger.info(
                "Session %s initialized: model=%s, tools=%d",
                session_id,
                session.model,
                len(session.tools),
            )
            # Send initialize control_request with watch-mode system prompt
            await self._send_initialize(session_id)

        elif subtype == "status":
            session.update_from_status(parsed)

        # Update progress tracking
        update_session_progress(session, msg)

    async def _handle_assistant(self, session_id: str, msg: dict) -> None:
        """Handle assistant messages (model responses)."""
        session = self._sessions.get(session_id)
        if not session:
            return
        session.status = "running"
        session.message_history.append({"type": "assistant", "data": msg})
        old_tasks = list(session.todo_tasks)
        update_session_progress(session, msg)
        # Push to cloud immediately if todo list changed
        if session.todo_tasks != old_tasks:
            await self._cloud_push_progress(session)

    async def _handle_result(self, session_id: str, msg: dict) -> None:
        """Handle result messages (query completion)."""
        session = self._sessions.get(session_id)
        if not session:
            return
        parsed = parse_cli_message(msg)
        session.update_from_result(parsed)
        session.message_history.append({"type": "result", "data": msg})
        update_session_progress(session, msg)
        # Always push progress on result (session complete)
        await self._cloud_push_progress(session)

    async def _handle_control_request(self, session_id: str, msg: dict) -> None:
        """Handle control requests (permission prompts from CLI).

        For ``can_use_tool`` requests:
        - In auto-accept mode: immediately sends the allow response back.
        - In normal mode: queues the permission for watch polling.
        - AskUserQuestion tool calls are logged distinctly.
        - If cloud sync is active, pushes the request to the cloud worker.
        """
        session = self._sessions.get(session_id)
        if not session:
            return

        request = msg.get("request", {})
        if request.get("subtype") == "can_use_tool":
            perm, auto_response = handle_can_use_tool(session, msg)

            if auto_response:
                # Auto-accept mode -- send response immediately
                await self._ndjson.send_to_cli(session_id, auto_response)
            else:
                # Route to watch (logged; picked up by API polling)
                tool_name = perm.tool_name
                if is_ask_user_question(tool_name):
                    logger.info("Question pending: %s", perm.request_id)
                    await self._cloud_push_question(perm)
                else:
                    logger.info(
                        "Permission pending: %s (%s)", tool_name, perm.request_id
                    )
                    await self._cloud_push_approval(perm)

    async def _handle_stream_event(self, session_id: str, msg: dict) -> None:
        """Handle stream events (real-time token streaming, post-MVP)."""
        # Stream events are forwarded to watch in real-time (post-MVP)
        pass

    async def _handle_tool_progress(self, session_id: str, msg: dict) -> None:
        """Handle tool_progress heartbeat messages."""
        session = self._sessions.get(session_id)
        if session:
            update_session_progress(session, msg)
            await self._cloud_push_progress_debounced(session)

    async def _handle_tool_use_summary(self, session_id: str, msg: dict) -> None:
        """Handle tool_use_summary messages (post-MVP forwarding)."""
        pass  # Can be forwarded to watch in future

    async def _handle_auth_status(self, session_id: str, msg: dict) -> None:
        """Handle auth_status messages (post-MVP forwarding)."""
        pass  # Can be forwarded to watch in future

    # ------------------------------------------------------------------
    # Cloud sync helpers
    # ------------------------------------------------------------------

    async def _cloud_push_approval(self, perm: Any) -> None:
        """Push a tool approval to the cloud worker (fire-and-forget)."""
        if not self._cloud_client or not self._cloud_client.is_enabled:
            return
        try:
            await self._cloud_client.push_approval(
                perm.request_id, perm.tool_name, perm.input
            )
        except Exception as exc:
            logger.debug("Cloud push approval failed: %s", exc)

    async def _cloud_push_question(self, perm: Any) -> None:
        """Push an AskUserQuestion to the cloud worker (fire-and-forget)."""
        if not self._cloud_client or not self._cloud_client.is_enabled:
            return
        try:
            await self._cloud_client.push_question(
                perm.request_id, perm.input
            )
        except Exception as exc:
            logger.debug("Cloud push question failed: %s", exc)

    async def _cloud_push_progress(self, session: Session) -> None:
        """Push session progress to cloud immediately."""
        if not self._cloud_client or not self._cloud_client.is_enabled:
            return
        try:
            progress = session_to_watch_progress(session)
            await self._cloud_client.push_progress(progress)
            self._last_progress_push = asyncio.get_event_loop().time()
        except Exception as exc:
            logger.debug("Cloud push progress failed: %s", exc)

    async def _cloud_push_progress_debounced(self, session: Session) -> None:
        """Push progress to cloud at most every 5 seconds."""
        if not self._cloud_client or not self._cloud_client.is_enabled:
            return
        now = asyncio.get_event_loop().time()
        if now - self._last_progress_push < 5.0:
            return
        await self._cloud_push_progress(session)

    async def _cloud_poll_loop(self) -> None:
        """Background loop: poll cloud for watch responses.

        Checks for:
        - Approval decisions (approved/rejected)
        - Question answers
        - Interrupt state changes (stop/resume from watch)
        - Session-end from watch
        """
        assert self._cloud_client is not None
        interval = self._cloud_client.poll_interval

        while self._cloud_poll_running:
            try:
                await self._cloud_poll_once()
            except Exception as exc:
                logger.debug("Cloud poll error: %s", exc)
            await asyncio.sleep(interval)

    async def _cloud_poll_once(self) -> None:
        """Single cloud poll iteration for all active sessions."""
        assert self._cloud_client is not None

        for session_id, session in list(self._sessions.items()):
            # Poll pending permissions
            for req_id in list(session.pending_permissions.keys()):
                perm = session.pending_permissions.get(req_id)
                if not perm:
                    continue

                if is_ask_user_question(perm.tool_name):
                    result = await self._cloud_client.poll_question_status(req_id)
                    if result and result.get("status") == "answered":
                        # Guard: REST API may have resolved this concurrently
                        if session.pending_permissions.get(req_id) is None:
                            continue
                        resp = build_approve_response(req_id, perm.input)
                        session.resolve_permission(req_id)
                        await self._ndjson.send_to_cli(session_id, resp)
                        logger.info("Cloud: question %s answered", req_id)
                else:
                    status = await self._cloud_client.poll_approval_status(req_id)
                    if status == "approved":
                        # Guard: REST API may have resolved this concurrently
                        if session.pending_permissions.get(req_id) is None:
                            continue
                        resp = approve_permission(session, req_id)
                        if resp:
                            await self._ndjson.send_to_cli(session_id, resp)
                            logger.info("Cloud: approval %s approved", req_id)
                    elif status == "rejected":
                        # Guard: REST API may have resolved this concurrently
                        if session.pending_permissions.get(req_id) is None:
                            continue
                        resp = deny_permission(session, req_id)
                        if resp:
                            await self._ndjson.send_to_cli(session_id, resp)
                            logger.info("Cloud: approval %s rejected", req_id)

        # Poll interrupt state
        interrupt = await self._cloud_client.poll_interrupt_state()
        if interrupt.get("interrupted") and interrupt.get("action") == "stop":
            # Find active session and send interrupt
            for session_id in self._sessions:
                interrupt_msg: dict[str, Any] = {
                    "type": "control_request",
                    "request_id": str(uuid.uuid4()),
                    "request": {"subtype": "interrupt"},
                }
                await self._ndjson.send_to_cli(session_id, interrupt_msg)
                logger.info("Cloud: interrupt stop received")
                break  # only interrupt the first active session

        # Poll session-end
        if not await self._cloud_client.poll_session_active():
            logger.info("Cloud: session ended by watch")
            # Stop the CLI launcher if running
            if self._launcher:
                await self._launcher.kill_all()

    # ------------------------------------------------------------------
    # Outbound control
    # ------------------------------------------------------------------

    async def _send_initialize(self, session_id: str) -> None:
        """Send initialize control_request with watch-mode system prompt.

        This tells the CLI to append instructions that constrain its output
        to yes/no questions suitable for the Apple Watch interface.
        """
        init_request: dict[str, Any] = {
            "type": "control_request",
            "request_id": str(uuid.uuid4()),
            "request": {
                "subtype": "initialize",
                "appendSystemPrompt": (
                    "You are being controlled from an Apple Watch. "
                    "The watch can ONLY approve or reject. "
                    "When asking questions, recommend ONE approach and ask 'Proceed? (y/n)'. "
                    "NEVER present numbered option lists. "
                    "If the user says no, offer the next best alternative."
                ),
            },
        }
        await self._ndjson.send_to_cli(session_id, init_request)

    # ------------------------------------------------------------------
    # Server lifecycle
    # ------------------------------------------------------------------

    async def start(
        self,
        launch: bool = False,
        cwd: str | None = None,
        model: str | None = None,
    ) -> None:
        """Start the bridge server.

        1. Starts the NDJSON WebSocket server for CLI connections.
        2. Optionally starts the HTTP REST API for watch polling.
        3. Optionally launches a Claude CLI process with ``--sdk-url``.

        Args:
            launch: If True, auto-spawn Claude CLI with ``--sdk-url``.
            cwd: Working directory for the launched CLI process.
            model: Model override for the launched CLI process.
        """
        # Start NDJSON WebSocket server
        await self._ndjson.start()

        # Start HTTP API server (import here to avoid circular deps)
        try:
            from MCPServer.bridge.api import BridgeAPI
            from aiohttp import web

            self._api = BridgeAPI()
            self._api.set_send_to_cli(self._ndjson.send_to_cli)

            # The API needs access to sessions
            self._api._sessions = self._sessions
            self._api._pairing_to_session = {}

            app = self._api.create_app()
            runner = web.AppRunner(app)
            await runner.setup()
            self._http_runner = runner
            # Run HTTP on port+1 to avoid conflict with WebSocket
            http_port = self.port + 1
            site = web.TCPSite(runner, "127.0.0.1", http_port, reuse_address=True)
            await site.start()
            logger.info("HTTP API listening on http://127.0.0.1:%d", http_port)
        except ImportError:
            logger.warning("aiohttp not available, HTTP API disabled")

        # Optionally launch CLI
        if launch:
            from MCPServer.bridge.launcher import CLILauncher

            self._launcher = CLILauncher(self.port)
            info = await self._launcher.launch(cwd=cwd, model=model)
            logger.info("Launched CLI session: %s", info.session_id)

            # Register pairing mapping
            if self._api:
                session = self._sessions.get(info.session_id) or Session(
                    info.session_id
                )
                self._api.register_session(
                    self.pairing_id, info.session_id, session
                )

        # Start cloud sync if cloud_url was provided
        if self.cloud_url:
            from MCPServer.bridge.cloud_client import CloudClient

            self._cloud_client = CloudClient(self.cloud_url, self.pairing_id)
            await self._cloud_client.start()
            self._cloud_poll_running = True
            self._cloud_poll_task = asyncio.ensure_future(self._cloud_poll_loop())
            logger.info("Cloud sync enabled: %s", self.cloud_url)

        logger.info("Bridge ready. pairing_id=%s", self.pairing_id)
        logger.info(
            "  CLI WebSocket: ws://localhost:%d/ws/cli/{session_id}", self.port
        )
        if self._api:
            logger.info(
                "  Watch API:     http://localhost:%d/approval-queue/%s",
                self.port + 1,
                self.pairing_id,
            )
        if self._cloud_client:
            logger.info("  Cloud relay:   %s", self.cloud_url)

    async def stop(self) -> None:
        """Stop everything gracefully."""
        # Stop cloud sync
        self._cloud_poll_running = False
        if self._cloud_poll_task:
            self._cloud_poll_task.cancel()
            try:
                await self._cloud_poll_task
            except (asyncio.CancelledError, Exception):
                pass
            self._cloud_poll_task = None
        if self._cloud_client:
            await self._cloud_client.stop()
            self._cloud_client = None
        # Stop launcher, HTTP, and WebSocket
        if self._launcher:
            await self._launcher.kill_all()
        if self._http_runner:
            await self._http_runner.cleanup()
            self._http_runner = None
        await self._ndjson.stop()


def main() -> None:
    """CLI entrypoint for ``python -m MCPServer.bridge``."""
    parser = argparse.ArgumentParser(description="Claude Watch Bridge Server")
    parser.add_argument(
        "--port",
        type=int,
        default=8787,
        help="WebSocket port (HTTP = port+1)",
    )
    parser.add_argument(
        "--pairing-id",
        type=str,
        default=None,
        help="Pairing ID for watch API routing",
    )
    parser.add_argument(
        "--cloud-url",
        type=str,
        default=None,
        help="Cloud worker URL for relay sync (e.g. https://remmy.watch)",
    )
    parser.add_argument(
        "--launch",
        action="store_true",
        help="Auto-launch Claude CLI",
    )
    parser.add_argument(
        "--cwd",
        type=str,
        default=None,
        help="Working directory for CLI",
    )
    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Model override",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Debug logging",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    bridge = Bridge(
        port=args.port,
        pairing_id=args.pairing_id,
        cloud_url=args.cloud_url,
    )

    loop = asyncio.new_event_loop()
    try:
        loop.run_until_complete(
            bridge.start(
                launch=args.launch,
                cwd=args.cwd,
                model=args.model,
            )
        )
        loop.run_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        loop.run_until_complete(bridge.stop())
    finally:
        loop.close()


if __name__ == "__main__":
    main()
