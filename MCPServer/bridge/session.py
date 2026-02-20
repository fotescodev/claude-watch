"""
Session state management for a single Claude CLI connection.

Tracks all runtime state: model info, cost, turns, context usage,
pending permissions, todo tasks, and message history. Designed to be
updated incrementally as NDJSON messages arrive from the CLI.
"""
from __future__ import annotations

import collections
import logging
import time
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)

from MCPServer.bridge.types import (
    ResultMessage,
    SystemInitMessage,
    SystemStatusMessage,
)


# ---------------------------------------------------------------------------
# Supporting dataclasses
# ---------------------------------------------------------------------------

@dataclass
class PermissionRequest:
    """A pending tool-use permission request from the CLI."""
    request_id: str
    tool_name: str
    input: dict
    tool_use_id: str
    description: str | None = None
    agent_id: str | None = None
    timestamp: float = field(default_factory=time.time)


@dataclass
class TodoItem:
    """A single task from a TodoWrite tool invocation."""
    content: str
    status: str  # "pending" | "in_progress" | "completed"
    active_form: str | None = None


# ---------------------------------------------------------------------------
# Session
# ---------------------------------------------------------------------------

class Session:
    """Tracks all state for a single Claude CLI session.

    Instantiated when a CLI connects (or when a session is pre-created for
    a pairing id). Updated by message handlers as NDJSON messages arrive.
    """

    def __init__(self, session_id: str) -> None:
        self.id: str = session_id
        self.cli_session_id: str | None = None
        self.cli_socket: Any = None  # WebSocket connection (typed loosely to avoid hard dep)

        # From system/init ---------------------------------------------------
        self.model: str = ""
        self.cwd: str = ""
        self.tools: list[str] = []
        self.permission_mode: str = "default"
        self.claude_code_version: str = ""
        self.mcp_servers: list[dict] = []

        # From result messages -----------------------------------------------
        self.total_cost_usd: float = 0.0
        self.num_turns: int = 0
        self.context_used_percent: int = 0
        self.is_compacting: bool = False

        # Permission tracking ------------------------------------------------
        self.pending_permissions: dict[str, PermissionRequest] = {}

        # Progress tracking --------------------------------------------------
        self.todo_tasks: list[TodoItem] = []
        self.current_activity: str | None = None
        self.session_start_time: float = time.time()
        self.status: str = "idle"  # idle | running | waiting | completed | failed
        self.context_warning: bool = False

        # Message history (for late-joining clients) -------------------------
        self.message_history: collections.deque[dict] = collections.deque(maxlen=500)

        # Queue for messages before CLI connects -----------------------------
        self.pending_messages: list[str] = []

    # ------------------------------------------------------------------
    # Update helpers
    # ------------------------------------------------------------------

    def update_from_init(self, msg: SystemInitMessage) -> None:
        """Update session state from a system/init message."""
        self.cli_session_id = msg.session_id
        self.model = msg.model
        self.cwd = msg.cwd
        self.tools = list(msg.tools)
        self.permission_mode = msg.permission_mode
        self.claude_code_version = msg.claude_code_version
        self.mcp_servers = list(msg.mcp_servers)
        self.status = "running"

    def update_from_result(self, msg: ResultMessage) -> None:
        """Update cost, turns, and context % from a result message."""
        self.total_cost_usd = msg.total_cost_usd
        self.num_turns = msg.num_turns

        # Compute context usage from modelUsage if present
        if msg.model_usage:
            self._compute_context_percent(msg.model_usage)

        # Update session status based on result subtype
        if msg.subtype == "success":
            # Only mark completed if all todos are done (or no todos)
            if not self.todo_tasks or all(t.status == "completed" for t in self.todo_tasks):
                self.status = "completed"
            else:
                self.status = "idle"
        elif msg.subtype.startswith("error_"):
            self.status = "failed"

    def update_from_status(self, msg: SystemStatusMessage) -> None:
        """Update compaction state from a system/status message."""
        if msg.status == "compacting":
            self.is_compacting = True
        else:
            self.is_compacting = False
        # Update permission mode if provided
        if msg.permission_mode is not None:
            self.permission_mode = msg.permission_mode

    # ------------------------------------------------------------------
    # Permission management
    # ------------------------------------------------------------------

    def add_permission(self, perm: PermissionRequest) -> None:
        """Add a pending permission request."""
        self.pending_permissions[perm.request_id] = perm
        self.status = "waiting"

    def resolve_permission(self, request_id: str) -> PermissionRequest | None:
        """Remove and return a pending permission, or None if not found."""
        perm = self.pending_permissions.pop(request_id, None)
        if not self.pending_permissions:
            self.status = "running"
        return perm

    def cancel_all_permissions(self) -> list[str]:
        """Cancel all pending permissions. Returns their request_ids."""
        request_ids = list(self.pending_permissions.keys())
        self.pending_permissions.clear()
        return request_ids

    # ------------------------------------------------------------------
    # Todo / progress tracking
    # ------------------------------------------------------------------

    def update_todos(self, todos: list[dict]) -> None:
        """Update the todo list from a TodoWrite tool input.

        Each dict should have: content, status, and optionally activeForm.
        """
        self.todo_tasks = [
            TodoItem(
                content=t.get("content", ""),
                status=t.get("status", "pending"),
                active_form=t.get("activeForm"),
            )
            for t in todos
        ]
        # Set current_activity from the in_progress task
        in_progress = [t for t in self.todo_tasks if t.status == "in_progress"]
        if in_progress:
            self.current_activity = in_progress[0].active_form

    @property
    def progress(self) -> float:
        """Compute progress as fraction of completed todos (0.0 - 1.0)."""
        if not self.todo_tasks:
            return 0.0
        completed = sum(1 for t in self.todo_tasks if t.status == "completed")
        return completed / len(self.todo_tasks)

    @property
    def completed_count(self) -> int:
        """Number of completed todo tasks."""
        return sum(1 for t in self.todo_tasks if t.status == "completed")

    @property
    def elapsed_seconds(self) -> int:
        """Seconds since session start."""
        return int(time.time() - self.session_start_time)

    # ------------------------------------------------------------------
    # Context % computation
    # ------------------------------------------------------------------

    def _compute_context_percent(self, model_usage: dict) -> None:
        """Compute context usage percentage from modelUsage data.

        model_usage is a dict keyed by model name, each value containing:
            inputTokens, outputTokens, contextWindow, etc.
        We take the max usage across all models (typically there's just one).
        """
        max_percent = 0
        for _model_name, usage in model_usage.items():
            input_tokens = usage.get("inputTokens", 0)
            output_tokens = usage.get("outputTokens", 0)
            context_window = usage.get("contextWindow", 0)
            if context_window > 0:
                used = input_tokens + output_tokens
                percent = int((used / context_window) * 100)
                max_percent = max(max_percent, percent)

        self.context_used_percent = max_percent
        self.context_warning = max_percent >= 85

    # ------------------------------------------------------------------
    # Export for watch
    # ------------------------------------------------------------------

    def to_watch_state(self) -> dict:
        """Export session state in a watch-compatible format.

        This is the payload sent to watch clients via the REST API or WebSocket.
        """
        # Find the current in-progress task name
        current_task: str | None = None
        for t in self.todo_tasks:
            if t.status == "in_progress":
                current_task = t.content
                break

        return {
            "sessionId": self.id,
            "cliSessionId": self.cli_session_id,
            "model": self.model,
            "cwd": self.cwd,
            "permissionMode": self.permission_mode,
            "status": self.status,
            "totalCostUsd": self.total_cost_usd,
            "numTurns": self.num_turns,
            "contextUsedPercent": self.context_used_percent,
            "contextWarning": self.context_warning,
            "isCompacting": self.is_compacting,
            "pendingPermissions": len(self.pending_permissions),
            "progress": {
                "currentTask": current_task,
                "currentActivity": self.current_activity,
                "progress": round(self.progress, 4),
                "completedCount": self.completed_count,
                "totalCount": len(self.todo_tasks),
                "elapsedSeconds": self.elapsed_seconds,
                "tasks": [
                    {
                        "content": t.content,
                        "status": t.status,
                        "activeForm": t.active_form,
                    }
                    for t in self.todo_tasks
                ],
            },
        }
