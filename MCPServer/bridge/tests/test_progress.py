"""
Tests for MCPServer.bridge.progress — Task A5 progress tracker.

Covers:
  - TEST A5.1: extract_todos_from_assistant with TodoWrite block -> returns 3 todos
  - TEST A5.2: compute_progress with 1 completed, 1 in_progress, 1 pending -> (0.33, 1, 3, "active form")
  - TEST A5.3: compute_context_percent with 90% usage -> returns 90, sets context_warning
  - TEST A5.4: Compaction lifecycle: status "compacting" -> is_compacting=True, status None -> False
  - TEST A5.5: Result with subtype "success" -> session.status = "completed"
  - TEST A5.6: Result with subtype "error_during_execution" -> session.status = "failed"
  - TEST A5.7: format_tool_activity("Bash", 5.2) -> "Running command (5s)"
  - TEST A5.8: extract_todos_from_assistant with NO TodoWrite block -> returns None
  - TEST A5.9: session_to_watch_progress format matches expected schema
"""
from __future__ import annotations

import time

import pytest

from MCPServer.bridge.session import Session, TodoItem
from MCPServer.bridge.progress import (
    compute_context_percent,
    compute_progress,
    extract_todos_from_assistant,
    format_tool_activity,
    session_to_watch_progress,
    update_session_progress,
)


# =====================================================================
# Helper: build an assistant message dict with content blocks
# =====================================================================

def _make_assistant_msg(content_blocks: list[dict]) -> dict:
    """Build a minimal assistant message dict with the given content blocks."""
    return {
        "type": "assistant",
        "message": {
            "id": "msg_01",
            "role": "assistant",
            "model": "sonnet",
            "content": content_blocks,
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 100, "output_tokens": 50},
        },
        "parent_tool_use_id": None,
        "uuid": "u1",
        "session_id": "abc",
    }


def _make_result_msg(
    subtype: str = "success",
    model_usage: dict | None = None,
    total_cost_usd: float = 0.05,
    num_turns: int = 3,
) -> dict:
    """Build a minimal result message dict."""
    msg: dict = {
        "type": "result",
        "subtype": subtype,
        "is_error": subtype.startswith("error_"),
        "duration_ms": 5000,
        "duration_api_ms": 4000,
        "num_turns": num_turns,
        "total_cost_usd": total_cost_usd,
        "stop_reason": "end_turn" if subtype == "success" else None,
        "usage": {},
        "uuid": "u1",
        "session_id": "abc",
    }
    if model_usage is not None:
        msg["modelUsage"] = model_usage
    return msg


# =====================================================================
# TEST A5.1 — extract_todos_from_assistant with TodoWrite block
# =====================================================================

class TestExtractTodosFromAssistant:
    """Verify extraction of todo items from assistant messages containing
    TodoWrite tool_use blocks."""

    def test_a5_1_todowrite_block_returns_3_todos(self):
        """TEST A5.1: assistant message with TodoWrite block -> returns 3 todos."""
        msg = _make_assistant_msg([
            {"type": "text", "text": "Let me create a plan."},
            {
                "type": "tool_use",
                "id": "tu1",
                "name": "TodoWrite",
                "input": {
                    "todos": [
                        {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
                        {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
                        {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
                    ]
                },
            },
        ])

        todos = extract_todos_from_assistant(msg)

        assert todos is not None
        assert len(todos) == 3
        assert todos[0]["content"] == "Fix bug"
        assert todos[0]["status"] == "completed"
        assert todos[0]["activeForm"] == "Fixing bug"
        assert todos[1]["content"] == "Write tests"
        assert todos[1]["status"] == "in_progress"
        assert todos[2]["content"] == "Deploy"
        assert todos[2]["status"] == "pending"

    def test_a5_8_no_todowrite_block_returns_none(self):
        """TEST A5.8: assistant message with NO TodoWrite block -> returns None."""
        msg = _make_assistant_msg([
            {"type": "text", "text": "Hello, I can help with that."},
            {
                "type": "tool_use",
                "id": "tu1",
                "name": "Bash",
                "input": {"command": "ls -la"},
            },
        ])

        todos = extract_todos_from_assistant(msg)

        assert todos is None

    def test_text_only_message_returns_none(self):
        """An assistant message with only text blocks should return None."""
        msg = _make_assistant_msg([
            {"type": "text", "text": "Just a text response."},
        ])

        todos = extract_todos_from_assistant(msg)

        assert todos is None

    def test_empty_content_returns_none(self):
        """An assistant message with empty content should return None."""
        msg = _make_assistant_msg([])

        todos = extract_todos_from_assistant(msg)

        assert todos is None

    def test_missing_message_key_returns_none(self):
        """A malformed dict without the 'message' key should return None."""
        msg = {"type": "assistant", "uuid": "u1", "session_id": "abc"}

        todos = extract_todos_from_assistant(msg)

        assert todos is None

    def test_todowrite_with_empty_todos_returns_empty_list(self):
        """TodoWrite block with empty todos list should return []."""
        msg = _make_assistant_msg([
            {
                "type": "tool_use",
                "id": "tu1",
                "name": "TodoWrite",
                "input": {"todos": []},
            },
        ])

        todos = extract_todos_from_assistant(msg)

        assert todos is not None
        assert todos == []


# =====================================================================
# TEST A5.2 — compute_progress
# =====================================================================

class TestComputeProgress:
    """Verify progress computation from todo lists."""

    def test_a5_2_mixed_statuses(self):
        """TEST A5.2: 1 completed, 1 in_progress, 1 pending -> (0.33, 1, 3, active form)."""
        todos = [
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ]

        progress, completed, total, activity = compute_progress(todos)

        assert progress == pytest.approx(1 / 3)
        assert completed == 1
        assert total == 3
        assert activity == "Writing tests"

    def test_all_completed(self):
        todos = [
            {"content": "Task 1", "status": "completed", "activeForm": "Doing 1"},
            {"content": "Task 2", "status": "completed", "activeForm": "Doing 2"},
        ]

        progress, completed, total, activity = compute_progress(todos)

        assert progress == 1.0
        assert completed == 2
        assert total == 2
        assert activity is None

    def test_none_completed(self):
        todos = [
            {"content": "Task 1", "status": "pending", "activeForm": "Doing 1"},
            {"content": "Task 2", "status": "pending", "activeForm": "Doing 2"},
        ]

        progress, completed, total, activity = compute_progress(todos)

        assert progress == 0.0
        assert completed == 0
        assert total == 2
        assert activity is None

    def test_empty_list(self):
        progress, completed, total, activity = compute_progress([])

        assert progress == 0.0
        assert completed == 0
        assert total == 0
        assert activity is None

    def test_first_in_progress_wins(self):
        """If multiple items are in_progress, the first one's activeForm is used."""
        todos = [
            {"content": "Task 1", "status": "in_progress", "activeForm": "First activity"},
            {"content": "Task 2", "status": "in_progress", "activeForm": "Second activity"},
        ]

        _, _, _, activity = compute_progress(todos)

        assert activity == "First activity"


# =====================================================================
# TEST A5.3 — compute_context_percent
# =====================================================================

class TestComputeContextPercent:
    """Verify context window usage percentage computation."""

    def test_a5_3_ninety_percent(self):
        """TEST A5.3: 90% usage -> returns 90."""
        result_msg = _make_result_msg(
            model_usage={
                "claude-sonnet-4-5-20250929": {
                    "inputTokens": 170000,
                    "outputTokens": 10000,
                    "contextWindow": 200000,
                }
            }
        )

        pct = compute_context_percent(result_msg)

        assert pct == 90

    def test_fifty_percent(self):
        result_msg = _make_result_msg(
            model_usage={
                "sonnet": {
                    "inputTokens": 80000,
                    "outputTokens": 20000,
                    "contextWindow": 200000,
                }
            }
        )

        pct = compute_context_percent(result_msg)

        assert pct == 50

    def test_no_model_usage_returns_none(self):
        result_msg = _make_result_msg()
        # No modelUsage key at all

        pct = compute_context_percent(result_msg)

        assert pct is None

    def test_empty_model_usage_returns_none(self):
        result_msg = _make_result_msg(model_usage={})

        pct = compute_context_percent(result_msg)

        assert pct is None

    def test_zero_context_window_returns_none(self):
        """If contextWindow is 0, should not divide by zero."""
        result_msg = _make_result_msg(
            model_usage={
                "sonnet": {
                    "inputTokens": 1000,
                    "outputTokens": 500,
                    "contextWindow": 0,
                }
            }
        )

        pct = compute_context_percent(result_msg)

        assert pct is None

    def test_multiple_models_returns_highest(self):
        """When multiple models present, return the highest usage percentage."""
        result_msg = _make_result_msg(
            model_usage={
                "sonnet": {
                    "inputTokens": 50000,
                    "outputTokens": 10000,
                    "contextWindow": 200000,
                },
                "haiku": {
                    "inputTokens": 170000,
                    "outputTokens": 10000,
                    "contextWindow": 200000,
                },
            }
        )

        pct = compute_context_percent(result_msg)

        assert pct == 90  # haiku is at 90%

    def test_model_usage_snake_case_key(self):
        """Should also work with snake_case 'model_usage' key."""
        result_msg = {
            "type": "result",
            "subtype": "success",
            "model_usage": {
                "sonnet": {
                    "inputTokens": 80000,
                    "outputTokens": 20000,
                    "contextWindow": 200000,
                }
            },
        }

        pct = compute_context_percent(result_msg)

        assert pct == 50


# =====================================================================
# TEST A5.3 (continued) — context_warning via update_session_progress
# =====================================================================

class TestContextWarningViaDispatcher:
    """Verify that update_session_progress sets context_warning correctly."""

    def test_a5_3_context_warning_set_on_90_percent(self):
        """TEST A5.3 (full): 90% usage -> context_warning = True."""
        session = Session("test-session")
        result_msg = _make_result_msg(
            model_usage={
                "claude-sonnet-4-5-20250929": {
                    "inputTokens": 170000,
                    "outputTokens": 10000,
                    "contextWindow": 200000,
                }
            }
        )

        update_session_progress(session, result_msg)

        assert session.context_used_percent == 90
        assert session.context_warning is True

    def test_no_warning_below_85(self):
        session = Session("test-session")
        result_msg = _make_result_msg(
            model_usage={
                "sonnet": {
                    "inputTokens": 80000,
                    "outputTokens": 4000,
                    "contextWindow": 200000,
                }
            }
        )

        update_session_progress(session, result_msg)

        assert session.context_used_percent == 42
        assert session.context_warning is False


# =====================================================================
# TEST A5.4 — Compaction lifecycle
# =====================================================================

class TestCompactionLifecycle:
    """Verify is_compacting flag toggling via system/status messages."""

    def test_a5_4_compacting_on_then_off(self):
        """TEST A5.4: status 'compacting' -> is_compacting=True, status None -> False."""
        session = Session("test-session")
        assert session.is_compacting is False

        # Compacting starts
        msg_compacting = {
            "type": "system",
            "subtype": "status",
            "status": "compacting",
            "uuid": "u1",
            "session_id": "abc",
        }
        update_session_progress(session, msg_compacting)

        assert session.is_compacting is True

        # Compacting ends
        msg_done = {
            "type": "system",
            "subtype": "status",
            "status": None,
            "uuid": "u1",
            "session_id": "abc",
        }
        update_session_progress(session, msg_done)

        assert session.is_compacting is False

    def test_non_status_system_message_ignored(self):
        """System messages with subtype != 'status' should not affect is_compacting."""
        session = Session("test-session")
        session.is_compacting = True

        msg = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "sonnet",
        }
        update_session_progress(session, msg)

        # Should remain True — init messages don't toggle compaction
        assert session.is_compacting is True


# =====================================================================
# TEST A5.5 — Result success -> completed
# =====================================================================

class TestResultSuccess:
    """Verify session status transitions on successful result."""

    def test_a5_5_success_sets_completed(self):
        """TEST A5.5: result with subtype 'success' -> session.status = 'completed'."""
        session = Session("test-session")
        session.status = "running"

        result_msg = _make_result_msg(subtype="success")
        update_session_progress(session, result_msg)

        assert session.status == "completed"

    def test_success_updates_cost_and_turns(self):
        session = Session("test-session")
        session.status = "running"

        result_msg = _make_result_msg(
            subtype="success",
            total_cost_usd=0.42,
            num_turns=7,
        )
        update_session_progress(session, result_msg)

        assert session.total_cost_usd == 0.42
        assert session.num_turns == 7


# =====================================================================
# TEST A5.6 — Result error -> failed
# =====================================================================

class TestResultError:
    """Verify session status transitions on error result."""

    def test_a5_6_error_during_execution_sets_failed(self):
        """TEST A5.6: result with subtype 'error_during_execution' -> session.status = 'failed'."""
        session = Session("test-session")
        session.status = "running"

        result_msg = _make_result_msg(subtype="error_during_execution")
        update_session_progress(session, result_msg)

        assert session.status == "failed"

    def test_error_max_turns_sets_failed(self):
        session = Session("test-session")
        session.status = "running"

        result_msg = _make_result_msg(subtype="error_max_turns")
        update_session_progress(session, result_msg)

        assert session.status == "failed"

    def test_error_max_budget_sets_failed(self):
        session = Session("test-session")
        session.status = "running"

        result_msg = _make_result_msg(subtype="error_max_budget_usd")
        update_session_progress(session, result_msg)

        assert session.status == "failed"


# =====================================================================
# TEST A5.7 — format_tool_activity
# =====================================================================

class TestFormatToolActivity:
    """Verify human-friendly tool activity string formatting."""

    def test_a5_7_bash_with_elapsed(self):
        """TEST A5.7: format_tool_activity('Bash', 5.2) -> 'Running command (5s)'."""
        result = format_tool_activity("Bash", 5.2)
        assert result == "Running command (5s)"

    def test_read_tool(self):
        result = format_tool_activity("Read", 2.0)
        assert result == "Reading files (2s)"

    def test_write_tool(self):
        result = format_tool_activity("Write", 3.7)
        assert result == "Writing code (4s)"

    def test_edit_tool(self):
        result = format_tool_activity("Edit", 1.0)
        assert result == "Editing code (1s)"

    def test_grep_tool(self):
        result = format_tool_activity("Grep", 10.0)
        assert result == "Searching code (10s)"

    def test_glob_tool(self):
        result = format_tool_activity("Glob", 0.5)
        assert result == "Finding files (0s)"

    def test_unknown_tool_with_elapsed(self):
        """Unknown tools get the default '{name} running...' format."""
        result = format_tool_activity("CustomTool", 3.0)
        assert result == "CustomTool running... (3s)"

    def test_zero_elapsed_no_suffix(self):
        """When elapsed is 0, no time suffix should be appended."""
        result = format_tool_activity("Bash", 0.0)
        assert result == "Running command"

    def test_unknown_tool_zero_elapsed(self):
        result = format_tool_activity("CustomTool", 0.0)
        assert result == "CustomTool running..."


# =====================================================================
# TEST A5.7 (continued) — tool_progress via update_session_progress
# =====================================================================

class TestToolProgressViaDispatcher:
    """Verify that update_session_progress handles tool_progress messages."""

    def test_tool_progress_updates_current_activity(self):
        session = Session("test-session")

        msg = {
            "type": "tool_progress",
            "tool_use_id": "tu1",
            "tool_name": "Bash",
            "parent_tool_use_id": None,
            "elapsed_time_seconds": 5.2,
            "uuid": "u1",
            "session_id": "abc",
        }
        update_session_progress(session, msg)

        assert session.current_activity == "Running command (5s)"

    def test_tool_progress_camel_case_keys(self):
        """Should handle camelCase keys from the wire format."""
        session = Session("test-session")

        msg = {
            "type": "tool_progress",
            "toolUseId": "tu1",
            "toolName": "Edit",
            "parentToolUseId": None,
            "elapsedTimeSeconds": 2.3,
            "uuid": "u1",
            "sessionId": "abc",
        }
        update_session_progress(session, msg)

        assert session.current_activity == "Editing code (2s)"


# =====================================================================
# update_session_progress — assistant with TodoWrite
# =====================================================================

class TestAssistantTodoViaDispatcher:
    """Verify that update_session_progress handles assistant + TodoWrite messages."""

    def test_assistant_todowrite_updates_session(self):
        """Matches the spec TEST A5.1 scenario via the dispatcher."""
        session = Session("test-session")

        msg = _make_assistant_msg([
            {"type": "text", "text": "Creating tasks."},
            {
                "type": "tool_use",
                "id": "tu1",
                "name": "TodoWrite",
                "input": {
                    "todos": [
                        {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
                        {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
                        {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
                    ]
                },
            },
        ])

        update_session_progress(session, msg)

        assert len(session.todo_tasks) == 3
        assert session.todo_tasks[0].content == "Fix bug"
        assert session.todo_tasks[0].status == "completed"
        assert session.todo_tasks[1].status == "in_progress"
        assert session.todo_tasks[2].status == "pending"
        assert session.progress == pytest.approx(1 / 3)
        assert session.current_activity == "Writing tests"

    def test_assistant_without_todowrite_no_change(self):
        """Assistant message without TodoWrite should not clear existing todos."""
        session = Session("test-session")
        session.update_todos([
            {"content": "Existing", "status": "pending", "activeForm": "Working"},
        ])

        msg = _make_assistant_msg([
            {"type": "text", "text": "Just replying."},
        ])

        update_session_progress(session, msg)

        # Existing todos should remain
        assert len(session.todo_tasks) == 1
        assert session.todo_tasks[0].content == "Existing"


# =====================================================================
# TEST A5.9 — session_to_watch_progress
# =====================================================================

class TestSessionToWatchProgress:
    """Verify the watch-API progress payload format."""

    def test_a5_9_format_matches_expected_schema(self):
        """TEST A5.9: session_to_watch_progress format matches expected schema."""
        session = Session("test-session")
        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])
        session.current_activity = "Writing tests"

        result = session_to_watch_progress(session)

        # Verify all required keys exist
        assert "currentTask" in result
        assert "currentActivity" in result
        assert "progress" in result
        assert "completedCount" in result
        assert "totalCount" in result
        assert "elapsedSeconds" in result
        assert "tasks" in result

        # Verify values
        assert result["currentTask"] == "Write tests"
        assert result["currentActivity"] == "Writing tests"
        assert result["progress"] == pytest.approx(1 / 3, abs=0.01)
        assert result["completedCount"] == 1
        assert result["totalCount"] == 3
        assert isinstance(result["elapsedSeconds"], int)

        # Verify tasks list
        assert len(result["tasks"]) == 3
        assert result["tasks"][0] == {
            "content": "Fix bug",
            "status": "completed",
            "activeForm": "Fixing bug",
        }
        assert result["tasks"][1] == {
            "content": "Write tests",
            "status": "in_progress",
            "activeForm": "Writing tests",
        }
        assert result["tasks"][2] == {
            "content": "Deploy",
            "status": "pending",
            "activeForm": "Deploying",
        }

    def test_empty_session(self):
        """With no todos, the payload should have sensible defaults."""
        session = Session("test-session")

        result = session_to_watch_progress(session)

        assert result["currentTask"] is None
        assert result["currentActivity"] is None
        assert result["progress"] == 0.0
        assert result["completedCount"] == 0
        assert result["totalCount"] == 0
        assert result["tasks"] == []

    def test_elapsed_seconds_is_present(self):
        """Verify elapsedSeconds reflects actual session time."""
        session = Session("test-session")
        session.session_start_time = time.time() - 60  # 60 seconds ago

        result = session_to_watch_progress(session)

        assert 59 <= result["elapsedSeconds"] <= 62
