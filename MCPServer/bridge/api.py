"""
Watch-facing REST API for the Claude Watch bridge.

Exposes HTTP endpoints that match the current Cloudflare Worker API contracts
so the watch needs ZERO changes. The bridge translates between these REST
calls and the NDJSON WebSocket protocol to the CLI.

Endpoints:
  GET  /approval-queue/{pairing_id}     -- Pending tool approvals
  POST /approval/{request_id}            -- Approve/reject a tool call
  GET  /session-progress/{pairing_id}    -- Current progress + todo list
  GET  /question-queue/{pairing_id}      -- Pending AskUserQuestion items
  POST /question/{question_id}           -- Answer a question
  POST /session-interrupt                -- Pause/resume session
  GET  /session-interrupt/{pairing_id}   -- Check interrupt state
  GET  /state                            -- Full debug state snapshot
  GET  /health                           -- Health check

Reference: .claude/plans/sdk-url-agent-execution-spec.md -- Task A7
"""
from __future__ import annotations

import logging
import os
import uuid
from typing import Any, Callable, Awaitable

from aiohttp import web

from MCPServer.bridge.permissions import approve_permission, deny_permission
from MCPServer.bridge.progress import session_to_watch_progress
from MCPServer.bridge.questions import (
    build_approve_response,
    build_deny_response,
    is_ask_user_question,
    to_watch_question,
)
from MCPServer.bridge.session import Session

logger = logging.getLogger("bridge.api")

# Type alias for the async function that sends NDJSON to a CLI session.
SendToCliFn = Callable[[str, dict[str, Any]], Awaitable[bool]]


# ---------------------------------------------------------------------------
# Tool-name -> watch type mapping
# ---------------------------------------------------------------------------

_TOOL_TYPE_MAP: dict[str, str] = {
    "Bash": "bash",
    "Edit": "file_edit",
    "MultiEdit": "file_edit",
    "NotebookEdit": "file_edit",
    "Write": "file_create",
    "AskUserQuestion": "question",
}


def _tool_name_to_type(tool_name: str) -> str:
    """Map a CLI tool name to the watch-compatible ``type`` string."""
    return _TOOL_TYPE_MAP.get(tool_name, tool_name.lower())


def _permission_to_watch_request(request_id: str, perm: Any) -> dict:
    """Transform a :class:`PermissionRequest` into the watch REST schema.

    Returns a dict matching the ``requests[]`` items in
    ``GET /approval-queue/{pairing_id}``.
    """
    tool_name = perm.tool_name
    tool_input = perm.input
    req_type = _tool_name_to_type(tool_name)

    # Title and description vary by tool type.
    title: str
    description: str
    file_path: str | None = None
    command: str | None = None

    if tool_name == "Bash":
        raw_cmd = tool_input.get("command", "")
        title = raw_cmd[:50] if raw_cmd else "Run command"
        description = raw_cmd
        command = raw_cmd
    elif tool_name in ("Edit", "MultiEdit", "NotebookEdit"):
        fp = tool_input.get("file_path", "")
        file_path = fp
        title = os.path.basename(fp) if fp else "Edit file"
        description = f"Edit {fp}" if fp else "Edit file"
    elif tool_name == "Write":
        fp = tool_input.get("file_path", "")
        file_path = fp
        title = os.path.basename(fp) if fp else "Create file"
        description = f"Create {fp}" if fp else "Create file"
    else:
        # Generic fallback
        title = tool_name
        description = str(tool_input)[:200]

    return {
        "id": request_id,
        "type": req_type,
        "title": title,
        "description": description,
        "filePath": file_path,
        "command": command,
    }


# ---------------------------------------------------------------------------
# BridgeAPI
# ---------------------------------------------------------------------------

class BridgeAPI:
    """Watch-facing REST API backed by ``aiohttp.web``.

    Provides HTTP endpoints that mirror the current Cloudflare Worker API so
    the watch app needs zero changes.  Internally the API maps pairing IDs to
    :class:`Session` objects and delegates permission / question / progress
    logic to the existing bridge modules.
    """

    def __init__(self) -> None:
        # pairing_id -> session_id
        self._pairing_to_session: dict[str, str] = {}

        # session_id -> Session
        self._sessions: dict[str, Session] = {}

        # Async function that sends an NDJSON dict to the CLI for a session_id.
        self._send_to_cli: SendToCliFn | None = None

        # pairing_id -> {"interrupted": bool, "action": str|None}
        self._interrupt_state: dict[str, dict] = {}

    # ------------------------------------------------------------------
    # Wiring helpers
    # ------------------------------------------------------------------

    def set_send_to_cli(self, fn: SendToCliFn) -> None:
        """Register the async function used to send NDJSON messages to the CLI."""
        self._send_to_cli = fn

    def register_session(
        self, pairing_id: str, session_id: str, session: Session
    ) -> None:
        """Map a *pairing_id* to a :class:`Session`."""
        self._pairing_to_session[pairing_id] = session_id
        self._sessions[session_id] = session
        # Initialise interrupt state for this pairing.
        self._interrupt_state.setdefault(
            pairing_id, {"interrupted": False, "action": None}
        )

    def get_session_by_pairing(self, pairing_id: str) -> Session | None:
        """Look up a :class:`Session` by *pairing_id*."""
        session_id = self._pairing_to_session.get(pairing_id)
        if session_id is None:
            return None
        return self._sessions.get(session_id)

    def _session_id_for_pairing(self, pairing_id: str) -> str | None:
        """Return the session_id mapped to *pairing_id*, or ``None``."""
        return self._pairing_to_session.get(pairing_id)

    # ------------------------------------------------------------------
    # aiohttp Application factory
    # ------------------------------------------------------------------

    def create_app(self) -> web.Application:
        """Create and return the :class:`aiohttp.web.Application` with all routes."""
        app = web.Application()
        app.router.add_get(
            "/approval-queue/{pairing_id}", self.handle_get_approval_queue
        )
        app.router.add_post("/approval/{request_id}", self.handle_post_approval)
        app.router.add_get(
            "/session-progress/{pairing_id}", self.handle_get_progress
        )
        app.router.add_get(
            "/question-queue/{pairing_id}", self.handle_get_questions
        )
        app.router.add_post(
            "/question/{question_id}", self.handle_post_question_answer
        )
        app.router.add_post("/session-interrupt", self.handle_post_interrupt)
        app.router.add_get(
            "/session-interrupt/{pairing_id}", self.handle_get_interrupt
        )
        app.router.add_get("/state", self.handle_get_state)
        app.router.add_get("/health", self.handle_health)
        return app

    # ------------------------------------------------------------------
    # Handlers
    # ------------------------------------------------------------------

    async def handle_get_approval_queue(
        self, request: web.Request
    ) -> web.Response:
        """``GET /approval-queue/{pairing_id}``

        Returns pending tool-use approval requests formatted for the watch.
        AskUserQuestion items are excluded (they appear in ``/questions``).
        """
        pairing_id = request.match_info["pairing_id"]
        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        requests: list[dict] = []
        for req_id, perm in session.pending_permissions.items():
            # Exclude AskUserQuestion from the approval queue.
            if is_ask_user_question(perm.tool_name):
                continue
            requests.append(_permission_to_watch_request(req_id, perm))

        return web.json_response(
            {"requests": requests, "totalCount": len(requests)}
        )

    async def handle_post_approval(self, request: web.Request) -> web.Response:
        """``POST /approval/{request_id}``

        Body: ``{"pairingId": "...", "approved": true|false}``

        Approves or denies a pending tool-use permission and sends the
        corresponding ``control_response`` to the CLI.
        """
        request_id = request.match_info["request_id"]
        try:
            body = await request.json()
        except Exception:
            return web.json_response(
                {"error": "Invalid JSON body"}, status=400
            )

        pairing_id: str = body.get("pairingId", "")
        approved: bool = body.get("approved", False)

        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        if request_id not in session.pending_permissions:
            return web.json_response(
                {"error": "Unknown request_id", "requestId": request_id},
                status=404,
            )

        if approved:
            resp_msg = approve_permission(session, request_id)
        else:
            resp_msg = deny_permission(session, request_id)

        if resp_msg is not None:
            await self._send_control_response(pairing_id, resp_msg)

        return web.json_response({"success": True})

    async def handle_get_progress(self, request: web.Request) -> web.Response:
        """``GET /session-progress/{pairing_id}``

        Returns the session's progress payload (tasks, activity, context %).
        """
        pairing_id = request.match_info["pairing_id"]
        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        progress = session_to_watch_progress(session)
        return web.json_response({"progress": progress})

    async def handle_get_questions(self, request: web.Request) -> web.Response:
        """``GET /question-queue/{pairing_id}``

        Returns pending AskUserQuestion items (these are *not* in the
        approval queue).
        """
        pairing_id = request.match_info["pairing_id"]
        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        questions: list[dict] = []
        for req_id, perm in session.pending_permissions.items():
            if is_ask_user_question(perm.tool_name):
                questions.append(to_watch_question(req_id, perm.input))

        return web.json_response({"questions": questions})

    async def handle_post_question_answer(
        self, request: web.Request
    ) -> web.Response:
        """``POST /question/{question_id}``

        Body: ``{"pairingId": "...", "answer": "selected option"}``

        Matches the cloud worker contract.  The watch sends ``answer``
        as the selected option text, or ``"handle_on_mac"`` to defer
        to the terminal.
        """
        question_id = request.match_info["question_id"]
        try:
            body = await request.json()
        except Exception:
            return web.json_response(
                {"error": "Invalid JSON body"}, status=400
            )

        pairing_id: str = body.get("pairingId", "")
        answer: str | None = body.get("answer")

        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        perm = session.pending_permissions.get(question_id)
        if perm is None:
            return web.json_response(
                {"error": "Unknown question_id", "questionId": question_id},
                status=404,
            )

        if answer == "handle_on_mac":
            resp_msg = build_deny_response(question_id)
        elif answer:
            resp_msg = build_approve_response(question_id, perm.input)
        else:
            resp_msg = build_deny_response(question_id)

        # Resolve the permission from the session.
        session.resolve_permission(question_id)

        await self._send_control_response(pairing_id, resp_msg)
        return web.json_response({"success": True})

    async def handle_post_interrupt(self, request: web.Request) -> web.Response:
        """``POST /session-interrupt``

        Body: ``{"pairingId": "...", "action": "stop"|"resume"}``

        Sends an interrupt ``control_request`` to the CLI when ``action``
        is ``"stop"``.  ``"resume"`` clears the interrupt state.
        """
        try:
            body = await request.json()
        except Exception:
            return web.json_response(
                {"error": "Invalid JSON body"}, status=400
            )

        pairing_id: str = body.get("pairingId", "")
        action: str = body.get("action", "")

        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        if action == "stop":
            interrupt_msg: dict[str, Any] = {
                "type": "control_request",
                "request_id": str(uuid.uuid4()),
                "request": {"subtype": "interrupt"},
            }
            await self._send_control_response(pairing_id, interrupt_msg)
            self._interrupt_state[pairing_id] = {
                "interrupted": True,
                "action": "stop",
            }
        elif action == "resume":
            self._interrupt_state[pairing_id] = {
                "interrupted": False,
                "action": None,
            }
        else:
            return web.json_response(
                {"error": f"Unknown action: {action}"}, status=400
            )

        return web.json_response({"success": True})

    async def handle_get_interrupt(self, request: web.Request) -> web.Response:
        """``GET /session-interrupt/{pairing_id}``

        Returns the current interrupt state for the session.
        """
        pairing_id = request.match_info["pairing_id"]
        session = self.get_session_by_pairing(pairing_id)
        if session is None:
            return web.json_response(
                {"error": "Unknown pairing_id", "pairingId": pairing_id},
                status=404,
            )

        state = self._interrupt_state.get(
            pairing_id, {"interrupted": False, "action": None}
        )
        return web.json_response(state)

    async def handle_get_state(self, request: web.Request) -> web.Response:
        """``GET /state``

        Returns a full debug snapshot of every session.
        """
        sessions_snapshot: dict[str, Any] = {}
        for sid, session in self._sessions.items():
            sessions_snapshot[sid] = session.to_watch_state()

        return web.json_response(
            {
                "pairingMap": dict(self._pairing_to_session),
                "sessions": sessions_snapshot,
                "interruptState": dict(self._interrupt_state),
            }
        )

    async def handle_health(self, request: web.Request) -> web.Response:
        """``GET /health``

        Simple liveness probe.
        """
        return web.json_response({"status": "ok"})

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _send_control_response(
        self, pairing_id: str, msg: dict[str, Any]
    ) -> bool:
        """Send *msg* to the CLI associated with *pairing_id*.

        Returns ``True`` on success, ``False`` if the send function is not
        registered or the session_id is unknown.
        """
        if self._send_to_cli is None:
            logger.warning(
                "send_to_cli not registered; cannot send message for pairing %s",
                pairing_id,
            )
            return False
        session_id = self._session_id_for_pairing(pairing_id)
        if session_id is None:
            logger.warning("No session_id for pairing %s", pairing_id)
            return False
        return await self._send_to_cli(session_id, msg)
