"""
Permission handler for can_use_tool control requests from the Claude CLI.

Receives control_request messages, queues them as PermissionRequests on the
session, and constructs control_response NDJSON messages when the watch
approves or denies.

Entry point: handle_can_use_tool(session, msg) — called by the NDJSON
dispatcher when a control_request with request.subtype == "can_use_tool"
arrives.
"""
from __future__ import annotations

import logging
import time
from typing import Any

from MCPServer.bridge.session import PermissionRequest, Session

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Auto-accept check
# ---------------------------------------------------------------------------

def should_auto_accept(session: Session) -> bool:
    """Return True if the session's permission mode allows auto-acceptance.

    Auto-accept modes skip the watch round-trip and immediately respond
    with ``allow`` for every tool-use request.
    """
    return session.permission_mode in ("autoAccept", "bypassPermissions")


# ---------------------------------------------------------------------------
# Approve / Deny helpers
# ---------------------------------------------------------------------------

def approve_permission(
    session: Session,
    request_id: str,
    updated_input: dict | None = None,
) -> dict | None:
    """Approve a pending permission and return the control_response message.

    If *updated_input* is provided it replaces the original tool input in the
    response (used by the question handler to inject ``answers``).  Otherwise
    the original input from the PermissionRequest is echoed back.

    Returns the NDJSON-ready dict, or ``None`` if *request_id* is not found
    in the session's pending permissions.
    """
    perm = session.resolve_permission(request_id)
    if perm is None:
        logger.warning("approve_permission: unknown request_id %s", request_id)
        return None

    response_input = updated_input if updated_input is not None else perm.input

    msg: dict[str, Any] = {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": request_id,
            "response": {
                "behavior": "allow",
                "updatedInput": response_input,
            },
        },
    }
    logger.info("Approved permission %s (tool=%s)", request_id, perm.tool_name)
    return msg


def deny_permission(
    session: Session,
    request_id: str,
    message: str = "Denied by user",
) -> dict | None:
    """Deny a pending permission and return the control_response message.

    Returns the NDJSON-ready dict, or ``None`` if *request_id* is not found.
    """
    perm = session.resolve_permission(request_id)
    if perm is None:
        logger.warning("deny_permission: unknown request_id %s", request_id)
        return None

    msg: dict[str, Any] = {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": request_id,
            "response": {
                "behavior": "deny",
                "message": message,
            },
        },
    }
    logger.info("Denied permission %s (tool=%s): %s", request_id, perm.tool_name, message)
    return msg


# ---------------------------------------------------------------------------
# Batch operations
# ---------------------------------------------------------------------------

def approve_all(session: Session) -> list[dict]:
    """Approve every pending permission in the session.

    Returns a list of control_response dicts (one per permission).  The
    session's ``pending_permissions`` will be empty after this call.
    """
    # Snapshot the request_ids first — approve_permission mutates the dict.
    request_ids = list(session.pending_permissions.keys())
    responses: list[dict] = []
    for rid in request_ids:
        resp = approve_permission(session, rid)
        if resp is not None:
            responses.append(resp)
    return responses


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def handle_can_use_tool(
    session: Session,
    msg: dict,
) -> tuple[PermissionRequest, dict | None]:
    """Handle an incoming ``control_request`` with ``request.subtype == "can_use_tool"``.

    Parses the message, creates a :class:`PermissionRequest`, and adds it to
    the session.  If the session is in auto-accept mode the permission is
    immediately approved and the response dict is returned alongside the
    PermissionRequest.

    Args:
        session: The active session.
        msg: The raw ``control_request`` dict from the CLI.

    Returns:
        A tuple of ``(perm, response)``:
        - *perm* is always the created :class:`PermissionRequest`.
        - *response* is a control_response dict if auto-accepted, otherwise
          ``None`` (the caller is responsible for routing to the watch).
    """
    request_id: str = msg.get("request_id") or msg.get("requestId", "")
    request: dict = msg.get("request", {})

    tool_name: str = request.get("tool_name") or request.get("toolName", "")
    tool_input: dict = request.get("input", {})
    description: str | None = request.get("description")
    tool_use_id: str = request.get("tool_use_id") or request.get("toolUseId", "")
    agent_id: str | None = request.get("agent_id") or request.get("agentId")

    perm = PermissionRequest(
        request_id=request_id,
        tool_name=tool_name,
        input=tool_input,
        tool_use_id=tool_use_id,
        description=description,
        agent_id=agent_id,
        timestamp=time.time(),
    )

    session.add_permission(perm)

    if should_auto_accept(session):
        # Immediately approve — no watch round-trip needed.
        response = approve_permission(session, request_id)
        return perm, response

    # Normal mode: caller routes the PermissionRequest to the watch.
    return perm, None
