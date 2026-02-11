"""
Progress tracker for Claude CLI sessions.

Extracts progress information from native NDJSON protocol messages — no hooks
needed. This module provides:

- TodoWrite extraction from assistant messages
- Progress computation (completed / total)
- Context window usage percentage from result messages
- Friendly tool activity descriptions
- A unified dispatcher (update_session_progress) that updates a Session
  from any incoming message dict
- A formatter (session_to_watch_progress) that produces the watch-API payload

Reference: .claude/plans/sdk-url-agent-execution-spec.md — Task A5
"""
from __future__ import annotations

import logging
from typing import Any

from MCPServer.bridge.session import Session, TodoItem

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Friendly tool name mapping
# ---------------------------------------------------------------------------

_TOOL_FRIENDLY_NAMES: dict[str, str] = {
    "Read": "Reading files",
    "Write": "Writing code",
    "Edit": "Editing code",
    "Bash": "Running command",
    "Grep": "Searching code",
    "Glob": "Finding files",
}


# ---------------------------------------------------------------------------
# 1. extract_todos_from_assistant
# ---------------------------------------------------------------------------

def extract_todos_from_assistant(msg: dict) -> list[dict] | None:
    """Extract todo items from an assistant message containing a TodoWrite tool call.

    Scans ``msg["message"]["content"]`` for a content block where
    ``type == "tool_use"`` and ``name == "TodoWrite"``.  If found, returns
    the ``input["todos"]`` list.  Each todo dict has keys: ``content``,
    ``status``, ``activeForm``.

    Args:
        msg: A parsed AssistantMessage dict (``type == "assistant"``).

    Returns:
        The list of todo dicts, or ``None`` if no TodoWrite block is present.
    """
    message = msg.get("message", {})
    content_blocks: list[dict] = message.get("content", [])

    for block in content_blocks:
        if (
            isinstance(block, dict)
            and block.get("type") == "tool_use"
            and block.get("name") == "TodoWrite"
        ):
            block_input = block.get("input", {})
            todos = block_input.get("todos")
            if isinstance(todos, list):
                return todos

    return None


# ---------------------------------------------------------------------------
# 2. compute_progress
# ---------------------------------------------------------------------------

def compute_progress(todos: list[dict]) -> tuple[float, int, int, str | None]:
    """Compute progress metrics from a list of todo dicts.

    Args:
        todos: List of todo dicts, each with ``content``, ``status``,
               and ``activeForm`` keys.

    Returns:
        A tuple of ``(progress, completed, total, current_activity)`` where:
        - *progress* is ``completed / total`` (0.0 if *total* is 0).
        - *completed* is the number of items with ``status == "completed"``.
        - *total* is ``len(todos)``.
        - *current_activity* is the ``activeForm`` of the first item with
          ``status == "in_progress"``, or ``None``.
    """
    total = len(todos)
    completed = sum(1 for t in todos if t.get("status") == "completed")
    progress = completed / total if total > 0 else 0.0

    current_activity: str | None = None
    for t in todos:
        if t.get("status") == "in_progress":
            current_activity = t.get("activeForm")
            break

    return progress, completed, total, current_activity


# ---------------------------------------------------------------------------
# 3. compute_context_percent
# ---------------------------------------------------------------------------

def compute_context_percent(result_msg: dict) -> int | None:
    """Compute context window usage percentage from a result message.

    Looks for ``modelUsage`` (or ``model_usage``) in *result_msg*.  For each
    model entry, computes ``(inputTokens + outputTokens) / contextWindow * 100``
    and returns the highest percentage found.

    Args:
        result_msg: A parsed result message dict.

    Returns:
        The highest context usage percentage (int), or ``None`` if no usage
        data with a non-zero context window is available.
    """
    model_usage = result_msg.get("modelUsage") or result_msg.get("model_usage")
    if not model_usage or not isinstance(model_usage, dict):
        return None

    max_percent: int | None = None

    for _model_name, usage in model_usage.items():
        if not isinstance(usage, dict):
            continue
        input_tokens = usage.get("inputTokens", 0)
        output_tokens = usage.get("outputTokens", 0)
        context_window = usage.get("contextWindow", 0)
        if context_window > 0:
            percent = int((input_tokens + output_tokens) / context_window * 100)
            if max_percent is None or percent > max_percent:
                max_percent = percent

    return max_percent


# ---------------------------------------------------------------------------
# 4. format_tool_activity
# ---------------------------------------------------------------------------

def format_tool_activity(tool_name: str, elapsed_seconds: float) -> str:
    """Format a human-friendly tool activity string.

    Uses friendly names for well-known tools (e.g. ``"Bash"`` becomes
    ``"Running command"``).  If *elapsed_seconds* > 0 the elapsed time is
    appended in parentheses.

    Args:
        tool_name: The raw tool name from the CLI protocol.
        elapsed_seconds: Seconds the tool has been running.

    Returns:
        A formatted activity string, e.g. ``"Running command (5s)"``.
    """
    friendly = _TOOL_FRIENDLY_NAMES.get(tool_name, f"{tool_name} running...")

    if elapsed_seconds > 0:
        return f"{friendly} ({elapsed_seconds:.0f}s)"
    return friendly


# ---------------------------------------------------------------------------
# 5. update_session_progress
# ---------------------------------------------------------------------------

def update_session_progress(session: Session, msg: dict) -> None:
    """Update session progress state from an incoming CLI message.

    This is the main entry point — dispatches by ``msg["type"]``:

    - **assistant**: Extracts TodoWrite todos, updates ``session.todo_tasks``
      and ``session.current_activity``.
    - **tool_progress**: Updates ``session.current_activity`` via
      :func:`format_tool_activity`.
    - **result**: Computes context %, updates ``session.context_used_percent``,
      sets ``session.context_warning``, updates status / cost / turns.
    - **system** (subtype ``status``): Updates ``session.is_compacting``.

    Args:
        session: The session to update.
        msg: A raw NDJSON message dict from the CLI.
    """
    msg_type = msg.get("type")

    if msg_type == "assistant":
        todos = extract_todos_from_assistant(msg)
        if todos is not None:
            session.update_todos(todos)
            progress, completed, total, activity = compute_progress(todos)
            if activity is not None:
                session.current_activity = activity

    elif msg_type == "tool_progress":
        tool_name = msg.get("tool_name") or msg.get("toolName", "")
        elapsed = msg.get("elapsed_time_seconds") or msg.get("elapsedTimeSeconds", 0.0)
        session.current_activity = format_tool_activity(tool_name, elapsed)

    elif msg_type == "result":
        # Context usage
        ctx_pct = compute_context_percent(msg)
        if ctx_pct is not None:
            session.context_used_percent = ctx_pct
            session.context_warning = ctx_pct >= 85

        # Session status
        subtype = msg.get("subtype", "")
        if subtype == "success":
            session.status = "completed"
        elif subtype.startswith("error_"):
            session.status = "failed"

        # Cost and turns
        if "total_cost_usd" in msg or "totalCostUsd" in msg:
            session.total_cost_usd = msg.get("total_cost_usd") or msg.get("totalCostUsd", 0.0)
        if "num_turns" in msg or "numTurns" in msg:
            session.num_turns = msg.get("num_turns") or msg.get("numTurns", 0)

    elif msg_type == "system":
        subtype = msg.get("subtype")
        if subtype == "status":
            status_value = msg.get("status")
            session.is_compacting = (status_value == "compacting")


# ---------------------------------------------------------------------------
# 6. session_to_watch_progress
# ---------------------------------------------------------------------------

def session_to_watch_progress(session: Session) -> dict:
    """Format session state as a progress payload for the watch API.

    Returns a dict matching the ``GET /session-progress/{pairing_id}``
    contract from the REST API spec (A7):

    .. code-block:: python

        {
            "currentTask": "Write tests",       # content of in_progress task
            "currentActivity": "Writing tests",  # session.current_activity
            "progress": 0.67,
            "completedCount": 2,
            "totalCount": 3,
            "elapsedSeconds": 120,
            "tasks": [
                {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
                ...
            ]
        }
    """
    current_task: str | None = None
    for t in session.todo_tasks:
        if t.status == "in_progress":
            current_task = t.content
            break

    return {
        "currentTask": current_task,
        "currentActivity": session.current_activity,
        "progress": round(session.progress, 4),
        "completedCount": session.completed_count,
        "totalCount": len(session.todo_tasks),
        "elapsedSeconds": session.elapsed_seconds,
        "tasks": [
            {
                "content": t.content,
                "status": t.status,
                "activeForm": t.active_form,
            }
            for t in session.todo_tasks
        ],
    }
