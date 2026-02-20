"""
Tests for MCPServer.bridge.types and MCPServer.bridge.session.

Covers:
  - TEST A2.1: Session state update from init
  - TEST A2.2: Context % computation from result with modelUsage
  - TEST A2.3: Pending permission lifecycle (add, resolve, cancel_all)
  - parse_cli_message for each message type
  - TodoItem update and progress computation
  - elapsed_seconds computation
"""
from __future__ import annotations

import time

import pytest

from MCPServer.bridge.types import (
    AssistantMessage,
    AuthStatusMessage,
    ControlRequestMessage,
    KeepAliveMessage,
    ResultMessage,
    StreamEventMessage,
    SystemInitMessage,
    SystemStatusMessage,
    ToolProgressMessage,
    ToolUseSummaryMessage,
    parse_cli_message,
)
from MCPServer.bridge.session import (
    PermissionRequest,
    Session,
    TodoItem,
)


# =====================================================================
# TEST A2.1 — Session state update from init
# =====================================================================

class TestSessionUpdateFromInit:
    """Verify that Session.update_from_init() correctly populates fields
    from a SystemInitMessage."""

    def test_basic_fields(self):
        session = Session("test-session")
        msg = SystemInitMessage(
            type="system",
            subtype="init",
            session_id="cli-session-abc",
            model="sonnet",
            cwd="/proj",
            tools=["Bash", "Edit"],
            permission_mode="default",
            claude_code_version="2.1.37",
            mcp_servers=[],
            slash_commands=["/help"],
            uuid="u1",
        )
        session.update_from_init(msg)

        assert session.model == "sonnet"
        assert session.cwd == "/proj"
        assert session.tools == ["Bash", "Edit"]
        assert session.permission_mode == "default"
        assert session.claude_code_version == "2.1.37"
        assert session.cli_session_id == "cli-session-abc"
        assert session.status == "running"

    def test_with_agents_and_skills(self):
        session = Session("test-session")
        msg = SystemInitMessage(
            type="system",
            subtype="init",
            session_id="cli-123",
            model="opus",
            cwd="/home/user",
            tools=["Bash", "Edit", "Read", "Write"],
            permission_mode="acceptEdits",
            claude_code_version="2.1.40",
            mcp_servers=[{"name": "test", "status": "connected"}],
            slash_commands=["/help", "/build"],
            uuid="u2",
            agents=["sub-agent-1"],
            skills=["commit", "review-pr"],
        )
        session.update_from_init(msg)

        assert session.model == "opus"
        assert session.tools == ["Bash", "Edit", "Read", "Write"]
        assert session.mcp_servers == [{"name": "test", "status": "connected"}]
        assert session.permission_mode == "acceptEdits"

    def test_tools_are_copied(self):
        """Ensure tools list is a copy, not a reference to the message's list."""
        session = Session("test-session")
        original_tools = ["Bash", "Edit"]
        msg = SystemInitMessage(
            type="system",
            subtype="init",
            session_id="cli-123",
            model="sonnet",
            cwd="/proj",
            tools=original_tools,
            permission_mode="default",
            claude_code_version="2.1.37",
            mcp_servers=[],
            slash_commands=[],
            uuid="u1",
        )
        session.update_from_init(msg)
        original_tools.append("Write")
        assert "Write" not in session.tools


# =====================================================================
# TEST A2.2 — Context % computation from result with modelUsage
# =====================================================================

class TestContextPercentComputation:
    """Verify that Session.update_from_result() correctly computes
    context_used_percent from modelUsage data."""

    def test_fifty_percent_usage(self):
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=5000,
            duration_api_ms=4000,
            num_turns=3,
            total_cost_usd=0.05,
            stop_reason="end_turn",
            usage={"input_tokens": 80000, "output_tokens": 20000},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage={
                "sonnet": {
                    "inputTokens": 80000,
                    "outputTokens": 20000,
                    "contextWindow": 200000,
                }
            },
        )
        session.update_from_result(msg)

        assert session.context_used_percent == 50
        assert session.context_warning is False

    def test_ninety_percent_triggers_warning(self):
        """TEST A5.2 equivalent: 90% usage should set context_warning=True."""
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=10000,
            duration_api_ms=8000,
            num_turns=10,
            total_cost_usd=0.15,
            stop_reason="end_turn",
            usage={"input_tokens": 170000, "output_tokens": 10000},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage={
                "claude-sonnet-4-5-20250929": {
                    "inputTokens": 170000,
                    "outputTokens": 10000,
                    "contextWindow": 200000,
                }
            },
        )
        session.update_from_result(msg)

        assert session.context_used_percent == 90
        assert session.context_warning is True

    def test_eighty_five_percent_threshold(self):
        """Exactly 85% should trigger the warning."""
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=5000,
            duration_api_ms=4000,
            num_turns=5,
            total_cost_usd=0.10,
            stop_reason="end_turn",
            usage={},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage={
                "sonnet": {
                    "inputTokens": 150000,
                    "outputTokens": 20000,
                    "contextWindow": 200000,
                }
            },
        )
        session.update_from_result(msg)

        assert session.context_used_percent == 85
        assert session.context_warning is True

    def test_no_model_usage(self):
        """When modelUsage is None, context_used_percent stays at 0."""
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=1000,
            duration_api_ms=800,
            num_turns=1,
            total_cost_usd=0.01,
            stop_reason="end_turn",
            usage={},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage=None,
        )
        session.update_from_result(msg)

        assert session.context_used_percent == 0
        assert session.context_warning is False

    def test_cost_and_turns_updated(self):
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=5000,
            duration_api_ms=4000,
            num_turns=7,
            total_cost_usd=0.42,
            stop_reason="end_turn",
            usage={},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage=None,
        )
        session.update_from_result(msg)

        assert session.total_cost_usd == 0.42
        assert session.num_turns == 7

    def test_error_result_sets_failed_status(self):
        session = Session("test-session")
        msg = ResultMessage(
            type="result",
            subtype="error_during_execution",
            is_error=True,
            duration_ms=2000,
            duration_api_ms=1500,
            num_turns=2,
            total_cost_usd=0.03,
            stop_reason=None,
            usage={},
            uuid="u1",
            session_id="cli-123",
            errors=["Something went wrong"],
            model_usage=None,
        )
        session.update_from_result(msg)

        assert session.status == "failed"

    def test_success_with_pending_todos_sets_idle(self):
        """If there are incomplete todos, success should set status to idle, not completed."""
        session = Session("test-session")
        session.update_todos([
            {"content": "Task 1", "status": "completed", "activeForm": "Doing task 1"},
            {"content": "Task 2", "status": "pending", "activeForm": "Doing task 2"},
        ])
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=5000,
            duration_api_ms=4000,
            num_turns=3,
            total_cost_usd=0.05,
            stop_reason="end_turn",
            usage={},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage=None,
        )
        session.update_from_result(msg)

        assert session.status == "idle"

    def test_success_with_all_todos_completed(self):
        """If all todos are completed, success should set status to completed."""
        session = Session("test-session")
        session.update_todos([
            {"content": "Task 1", "status": "completed", "activeForm": "Doing task 1"},
            {"content": "Task 2", "status": "completed", "activeForm": "Doing task 2"},
        ])
        msg = ResultMessage(
            type="result",
            subtype="success",
            is_error=False,
            duration_ms=5000,
            duration_api_ms=4000,
            num_turns=3,
            total_cost_usd=0.05,
            stop_reason="end_turn",
            usage={},
            uuid="u1",
            session_id="cli-123",
            result="Done",
            model_usage=None,
        )
        session.update_from_result(msg)

        assert session.status == "completed"


# =====================================================================
# TEST A2.3 — Pending permission lifecycle
# =====================================================================

class TestPermissionLifecycle:
    """Verify add_permission, resolve_permission, and cancel_all_permissions."""

    def test_add_and_resolve(self):
        session = Session("test-session")
        perm = PermissionRequest(
            request_id="r1",
            tool_name="Bash",
            input={"command": "ls"},
            tool_use_id="tu1",
        )
        session.add_permission(perm)

        assert "r1" in session.pending_permissions
        assert session.status == "waiting"

        resolved = session.resolve_permission("r1")

        assert resolved is not None
        assert resolved.request_id == "r1"
        assert resolved.tool_name == "Bash"
        assert resolved.input == {"command": "ls"}
        assert len(session.pending_permissions) == 0
        assert session.status == "running"

    def test_resolve_nonexistent(self):
        session = Session("test-session")
        result = session.resolve_permission("nonexistent")
        assert result is None

    def test_cancel_all(self):
        session = Session("test-session")
        for i in range(3):
            perm = PermissionRequest(
                request_id=f"r{i}",
                tool_name="Bash",
                input={"command": f"cmd{i}"},
                tool_use_id=f"tu{i}",
            )
            session.add_permission(perm)

        assert len(session.pending_permissions) == 3

        cancelled = session.cancel_all_permissions()

        assert len(cancelled) == 3
        assert set(cancelled) == {"r0", "r1", "r2"}
        assert len(session.pending_permissions) == 0

    def test_cancel_all_empty(self):
        session = Session("test-session")
        cancelled = session.cancel_all_permissions()
        assert cancelled == []

    def test_permission_with_optional_fields(self):
        perm = PermissionRequest(
            request_id="r1",
            tool_name="Edit",
            input={"file_path": "/src/main.py", "old_string": "foo", "new_string": "bar"},
            tool_use_id="tu1",
            description="Edit main.py",
            agent_id="agent-1",
        )
        assert perm.description == "Edit main.py"
        assert perm.agent_id == "agent-1"
        assert isinstance(perm.timestamp, float)

    def test_multiple_permissions_status_tracking(self):
        """Status should stay 'waiting' until ALL permissions are resolved."""
        session = Session("test-session")
        session.status = "running"

        perm1 = PermissionRequest(request_id="r1", tool_name="Bash", input={}, tool_use_id="tu1")
        perm2 = PermissionRequest(request_id="r2", tool_name="Edit", input={}, tool_use_id="tu2")
        session.add_permission(perm1)
        session.add_permission(perm2)

        assert session.status == "waiting"

        session.resolve_permission("r1")
        # Still one pending
        assert session.status == "waiting"

        session.resolve_permission("r2")
        # All resolved
        assert session.status == "running"


# =====================================================================
# parse_cli_message — all message types
# =====================================================================

class TestParseCliMessage:
    """Test parse_cli_message() for each recognized message type."""

    def test_system_init(self):
        raw = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "sonnet",
            "cwd": "/tmp",
            "tools": ["Bash"],
            "permissionMode": "default",
            "claude_code_version": "2.1.37",
            "mcp_servers": [],
            "slash_commands": [],
            "uuid": "u1",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemInitMessage)
        assert msg.type == "system"
        assert msg.subtype == "init"
        assert msg.session_id == "abc"
        assert msg.model == "sonnet"
        assert msg.cwd == "/tmp"
        assert msg.tools == ["Bash"]
        assert msg.permission_mode == "default"  # camelCase converted
        assert msg.claude_code_version == "2.1.37"
        assert msg.uuid == "u1"

    def test_system_init_with_agents(self):
        raw = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "opus",
            "cwd": "/proj",
            "tools": ["Bash", "Edit"],
            "permissionMode": "acceptEdits",
            "claude_code_version": "2.1.40",
            "mcp_servers": [{"name": "test", "status": "connected"}],
            "slash_commands": ["/help"],
            "uuid": "u2",
            "agents": ["agent-1"],
            "skills": ["commit"],
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemInitMessage)
        assert msg.agents == ["agent-1"]
        assert msg.skills == ["commit"]

    def test_system_status(self):
        raw = {
            "type": "system",
            "subtype": "status",
            "status": "compacting",
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemStatusMessage)
        assert msg.status == "compacting"
        assert msg.permission_mode is None

    def test_system_status_with_permission_mode(self):
        raw = {
            "type": "system",
            "subtype": "status",
            "status": None,
            "permissionMode": "acceptEdits",
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemStatusMessage)
        assert msg.status is None
        assert msg.permission_mode == "acceptEdits"

    def test_assistant(self):
        raw = {
            "type": "assistant",
            "message": {
                "id": "msg_01",
                "role": "assistant",
                "model": "sonnet",
                "content": [{"type": "text", "text": "Hello!"}],
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 100, "output_tokens": 50},
            },
            "parent_tool_use_id": None,
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, AssistantMessage)
        assert msg.message["content"][0]["text"] == "Hello!"
        assert msg.parent_tool_use_id is None
        assert msg.error is None

    def test_assistant_with_error(self):
        raw = {
            "type": "assistant",
            "message": {"id": "msg_01", "role": "assistant", "content": [], "model": "sonnet"},
            "parent_tool_use_id": None,
            "uuid": "u1",
            "session_id": "abc",
            "error": "rate_limit",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, AssistantMessage)
        assert msg.error == "rate_limit"

    def test_result_success(self):
        raw = {
            "type": "result",
            "subtype": "success",
            "is_error": False,
            "result": "All done!",
            "duration_ms": 5000,
            "duration_api_ms": 4000,
            "num_turns": 3,
            "total_cost_usd": 0.05,
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 1000, "output_tokens": 500},
            "modelUsage": {
                "sonnet": {
                    "inputTokens": 1000,
                    "outputTokens": 500,
                    "contextWindow": 200000,
                }
            },
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, ResultMessage)
        assert msg.subtype == "success"
        assert msg.is_error is False
        assert msg.result == "All done!"
        assert msg.total_cost_usd == 0.05
        assert msg.num_turns == 3
        assert msg.model_usage is not None  # camelCase converted
        assert msg.model_usage["sonnet"]["inputTokens"] == 1000

    def test_result_error(self):
        raw = {
            "type": "result",
            "subtype": "error_during_execution",
            "is_error": True,
            "errors": ["Something went wrong"],
            "duration_ms": 2000,
            "duration_api_ms": 1500,
            "num_turns": 2,
            "total_cost_usd": 0.03,
            "stop_reason": None,
            "usage": {},
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, ResultMessage)
        assert msg.is_error is True
        assert msg.errors == ["Something went wrong"]
        assert msg.result is None

    def test_control_request(self):
        raw = {
            "type": "control_request",
            "request_id": "req-1",
            "request": {
                "subtype": "can_use_tool",
                "tool_name": "Bash",
                "input": {"command": "ls -la"},
                "tool_use_id": "tu1",
            },
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, ControlRequestMessage)
        assert msg.request_id == "req-1"
        assert msg.request["subtype"] == "can_use_tool"
        assert msg.request["tool_name"] == "Bash"

    def test_stream_event(self):
        raw = {
            "type": "stream_event",
            "event": {"type": "content_block_delta", "delta": {"text": "Hello"}},
            "parent_tool_use_id": None,
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, StreamEventMessage)
        assert msg.event["type"] == "content_block_delta"

    def test_tool_progress(self):
        raw = {
            "type": "tool_progress",
            "tool_use_id": "tu1",
            "tool_name": "Bash",
            "parent_tool_use_id": None,
            "elapsed_time_seconds": 5.2,
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, ToolProgressMessage)
        assert msg.tool_name == "Bash"
        assert msg.elapsed_time_seconds == 5.2

    def test_tool_use_summary(self):
        raw = {
            "type": "tool_use_summary",
            "summary": "Ran ls command",
            "preceding_tool_use_ids": ["tu1", "tu2"],
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, ToolUseSummaryMessage)
        assert msg.summary == "Ran ls command"
        assert msg.preceding_tool_use_ids == ["tu1", "tu2"]

    def test_auth_status(self):
        raw = {
            "type": "auth_status",
            "isAuthenticating": True,
            "output": ["Authenticating..."],
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, AuthStatusMessage)
        assert msg.is_authenticating is True  # camelCase converted
        assert msg.output == ["Authenticating..."]
        assert msg.error is None

    def test_auth_status_with_error(self):
        raw = {
            "type": "auth_status",
            "isAuthenticating": False,
            "output": [],
            "error": "Invalid token",
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, AuthStatusMessage)
        assert msg.is_authenticating is False
        assert msg.error == "Invalid token"

    def test_keep_alive(self):
        raw = {"type": "keep_alive"}
        msg = parse_cli_message(raw)

        assert isinstance(msg, KeepAliveMessage)
        assert msg.type == "keep_alive"

    def test_unknown_type_returns_raw(self):
        raw = {"type": "some_future_type", "data": "hello"}
        msg = parse_cli_message(raw)

        assert isinstance(msg, dict)
        assert msg == raw

    def test_unknown_system_subtype_returns_raw(self):
        raw = {
            "type": "system",
            "subtype": "compact_boundary",
            "compact_metadata": {"trigger": "auto", "pre_tokens": 50000},
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, dict)
        assert msg["subtype"] == "compact_boundary"

    def test_extra_fields_ignored(self):
        """Unknown fields on a known message type should be silently dropped."""
        raw = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "sonnet",
            "cwd": "/tmp",
            "tools": ["Bash"],
            "permissionMode": "default",
            "claude_code_version": "2.1.37",
            "mcp_servers": [],
            "slash_commands": [],
            "uuid": "u1",
            "apiKeySource": "env",
            "output_style": "normal",
            "plugins": [],
            "extra_unknown_field": 42,
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemInitMessage)
        assert msg.model == "sonnet"
        # Extra fields should NOT cause an error

    def test_missing_optional_fields_get_defaults(self):
        """Optional fields that are absent should get their default values."""
        raw = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "sonnet",
            "cwd": "/tmp",
            "tools": ["Bash"],
            "permissionMode": "default",
            "claude_code_version": "2.1.37",
            "mcp_servers": [],
            "slash_commands": [],
            "uuid": "u1",
            # agents and skills omitted — should get default []
        }
        msg = parse_cli_message(raw)

        assert isinstance(msg, SystemInitMessage)
        assert msg.agents == []
        assert msg.skills == []


# =====================================================================
# TodoItem update and progress computation
# =====================================================================

class TestTodoProgress:
    """Test Session.update_todos() and progress-related properties."""

    def test_update_todos_basic(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        assert len(session.todo_tasks) == 3
        assert session.todo_tasks[0].content == "Fix bug"
        assert session.todo_tasks[0].status == "completed"
        assert session.todo_tasks[1].status == "in_progress"
        assert session.todo_tasks[2].status == "pending"

    def test_progress_one_third(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        assert session.progress == pytest.approx(1 / 3)
        assert session.completed_count == 1

    def test_progress_all_completed(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Task 1", "status": "completed"},
            {"content": "Task 2", "status": "completed"},
        ])

        assert session.progress == 1.0
        assert session.completed_count == 2

    def test_progress_none_completed(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Task 1", "status": "pending"},
            {"content": "Task 2", "status": "pending"},
        ])

        assert session.progress == 0.0
        assert session.completed_count == 0

    def test_progress_empty_list(self):
        session = Session("test-session")
        session.update_todos([])

        assert session.progress == 0.0
        assert session.completed_count == 0

    def test_current_activity_from_in_progress(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        assert session.current_activity == "Writing tests"

    def test_current_activity_no_in_progress(self):
        """If no task is in_progress, current_activity should not be changed by update_todos."""
        session = Session("test-session")
        session.current_activity = "Previous activity"
        session.update_todos([
            {"content": "Task 1", "status": "completed", "activeForm": "Doing task 1"},
            {"content": "Task 2", "status": "pending", "activeForm": "Doing task 2"},
        ])

        # No in_progress task, so current_activity stays as was
        assert session.current_activity == "Previous activity"

    def test_todo_item_without_active_form(self):
        session = Session("test-session")
        session.update_todos([
            {"content": "Task 1", "status": "pending"},
        ])

        assert session.todo_tasks[0].active_form is None

    def test_replace_todos_on_update(self):
        """update_todos should fully replace the todo list, not append."""
        session = Session("test-session")
        session.update_todos([
            {"content": "Old task", "status": "pending"},
        ])
        assert len(session.todo_tasks) == 1

        session.update_todos([
            {"content": "New task 1", "status": "pending"},
            {"content": "New task 2", "status": "pending"},
        ])
        assert len(session.todo_tasks) == 2
        assert session.todo_tasks[0].content == "New task 1"


# =====================================================================
# elapsed_seconds computation
# =====================================================================

class TestElapsedSeconds:
    """Test Session.elapsed_seconds property."""

    def test_elapsed_seconds_positive(self):
        session = Session("test-session")
        session.session_start_time = time.time() - 120  # 2 minutes ago

        elapsed = session.elapsed_seconds
        assert 119 <= elapsed <= 122  # allow small tolerance

    def test_elapsed_seconds_zero(self):
        session = Session("test-session")
        # Just created, should be near zero
        elapsed = session.elapsed_seconds
        assert 0 <= elapsed <= 2

    def test_elapsed_seconds_is_int(self):
        session = Session("test-session")
        assert isinstance(session.elapsed_seconds, int)


# =====================================================================
# Session.update_from_status
# =====================================================================

class TestUpdateFromStatus:
    """Test Session.update_from_status()."""

    def test_compacting_on(self):
        session = Session("test-session")
        msg = SystemStatusMessage(
            type="system",
            subtype="status",
            status="compacting",
            uuid="u1",
            session_id="abc",
        )
        session.update_from_status(msg)

        assert session.is_compacting is True

    def test_compacting_off(self):
        session = Session("test-session")
        session.is_compacting = True
        msg = SystemStatusMessage(
            type="system",
            subtype="status",
            status=None,
            uuid="u1",
            session_id="abc",
        )
        session.update_from_status(msg)

        assert session.is_compacting is False

    def test_permission_mode_update(self):
        session = Session("test-session")
        msg = SystemStatusMessage(
            type="system",
            subtype="status",
            status=None,
            uuid="u1",
            session_id="abc",
            permission_mode="acceptEdits",
        )
        session.update_from_status(msg)

        assert session.permission_mode == "acceptEdits"


# =====================================================================
# Session.to_watch_state
# =====================================================================

class TestToWatchState:
    """Test Session.to_watch_state() export format."""

    def test_basic_state_export(self):
        session = Session("sess-1")
        session.model = "sonnet"
        session.cwd = "/proj"
        session.total_cost_usd = 0.05
        session.num_turns = 3
        session.status = "running"

        state = session.to_watch_state()

        assert state["sessionId"] == "sess-1"
        assert state["model"] == "sonnet"
        assert state["cwd"] == "/proj"
        assert state["totalCostUsd"] == 0.05
        assert state["numTurns"] == 3
        assert state["status"] == "running"

    def test_progress_in_state(self):
        session = Session("sess-1")
        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        state = session.to_watch_state()

        progress = state["progress"]
        assert progress["currentTask"] == "Write tests"
        assert progress["currentActivity"] == "Writing tests"
        assert progress["progress"] == pytest.approx(1 / 3, abs=0.01)
        assert progress["completedCount"] == 1
        assert progress["totalCount"] == 3
        assert len(progress["tasks"]) == 3
        assert progress["tasks"][0]["content"] == "Fix bug"
        assert progress["tasks"][0]["status"] == "completed"

    def test_pending_permissions_count(self):
        session = Session("sess-1")
        session.add_permission(PermissionRequest(
            request_id="r1", tool_name="Bash", input={}, tool_use_id="tu1",
        ))
        session.add_permission(PermissionRequest(
            request_id="r2", tool_name="Edit", input={}, tool_use_id="tu2",
        ))

        state = session.to_watch_state()
        assert state["pendingPermissions"] == 2


# =====================================================================
# camelCase conversion edge cases in parse_cli_message
# =====================================================================

class TestCamelCaseConversion:
    """Test that camelCase -> snake_case conversion works correctly."""

    def test_permission_mode_converted(self):
        raw = {
            "type": "system",
            "subtype": "init",
            "session_id": "abc",
            "model": "sonnet",
            "cwd": "/tmp",
            "tools": [],
            "permissionMode": "bypassPermissions",
            "claude_code_version": "2.1.37",
            "mcp_servers": [],
            "slash_commands": [],
            "uuid": "u1",
        }
        msg = parse_cli_message(raw)
        assert isinstance(msg, SystemInitMessage)
        assert msg.permission_mode == "bypassPermissions"

    def test_is_authenticating_converted(self):
        raw = {
            "type": "auth_status",
            "isAuthenticating": True,
            "output": ["..."],
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)
        assert isinstance(msg, AuthStatusMessage)
        assert msg.is_authenticating is True

    def test_model_usage_converted(self):
        raw = {
            "type": "result",
            "subtype": "success",
            "is_error": False,
            "result": "Done",
            "duration_ms": 1000,
            "duration_api_ms": 800,
            "num_turns": 1,
            "total_cost_usd": 0.01,
            "stop_reason": "end_turn",
            "usage": {},
            "modelUsage": {"sonnet": {"inputTokens": 100}},
            "uuid": "u1",
            "session_id": "abc",
        }
        msg = parse_cli_message(raw)
        assert isinstance(msg, ResultMessage)
        assert msg.model_usage == {"sonnet": {"inputTokens": 100}}
