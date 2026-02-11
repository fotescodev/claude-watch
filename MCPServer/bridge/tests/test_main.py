"""
Tests for the Bridge entrypoint (spec task A8).

Tests A8.1-A8.6 validate the main Bridge class wiring: NDJSONServer creation,
system/init handling, control_request routing, auto-accept mode, initialize
control_request construction, and disconnect cleanup.

All tests use mocking — no real WebSocket connections are opened.
"""

from __future__ import annotations

import asyncio
import uuid
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio

from MCPServer.bridge.main import Bridge
from MCPServer.bridge.session import PermissionRequest, Session


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_system_init_msg(
    session_id: str = "cli-sess-001",
    model: str = "claude-sonnet-4-5-20250929",
    cwd: str = "/home/user/project",
    tools: list[str] | None = None,
    permission_mode: str = "default",
) -> dict:
    """Build a raw system/init message as the CLI would send it."""
    return {
        "type": "system",
        "subtype": "init",
        "session_id": session_id,
        "model": model,
        "cwd": cwd,
        "tools": tools or ["Bash", "Edit", "Read", "Write"],
        "permissionMode": permission_mode,
        "claude_code_version": "2.1.37",
        "mcp_servers": [],
        "slash_commands": [],
        "uuid": str(uuid.uuid4()),
    }


def _make_control_request(
    request_id: str = "r1",
    tool_name: str = "Bash",
    tool_input: dict | None = None,
    tool_use_id: str = "tu-r1",
) -> dict:
    """Build a raw control_request dict for can_use_tool."""
    return {
        "type": "control_request",
        "request_id": request_id,
        "request": {
            "subtype": "can_use_tool",
            "tool_name": tool_name,
            "input": tool_input or {"command": "ls -la"},
            "tool_use_id": tool_use_id,
        },
    }


def _make_system_status_msg(status: str | None = "compacting") -> dict:
    """Build a raw system/status message."""
    return {
        "type": "system",
        "subtype": "status",
        "status": status,
        "uuid": str(uuid.uuid4()),
        "session_id": "cli-sess-001",
        "permissionMode": "default",
    }


def _make_assistant_msg() -> dict:
    """Build a minimal assistant message."""
    return {
        "type": "assistant",
        "message": {
            "id": "msg-1",
            "role": "assistant",
            "content": [{"type": "text", "text": "Hello"}],
        },
        "parent_tool_use_id": None,
        "uuid": str(uuid.uuid4()),
        "session_id": "cli-sess-001",
    }


def _make_result_msg(
    subtype: str = "success",
    total_cost_usd: float = 0.05,
    num_turns: int = 3,
) -> dict:
    """Build a minimal result message."""
    return {
        "type": "result",
        "subtype": subtype,
        "is_error": subtype != "success",
        "duration_ms": 5000,
        "duration_api_ms": 4000,
        "num_turns": num_turns,
        "total_cost_usd": total_cost_usd,
        "stop_reason": "end_turn",
        "usage": {},
        "uuid": str(uuid.uuid4()),
        "session_id": "cli-sess-001",
        "modelUsage": {
            "claude-sonnet-4-5-20250929": {
                "inputTokens": 80000,
                "outputTokens": 20000,
                "contextWindow": 200000,
            }
        },
    }


# ---------------------------------------------------------------------------
# TEST A8.1: Bridge() creates NDJSONServer with correct port
# ---------------------------------------------------------------------------

class TestBridgeCreation:
    """A8.1: Bridge() creates NDJSONServer with correct port."""

    def test_creates_ndjson_server_with_port(self) -> None:
        bridge = Bridge(port=9999)

        assert bridge.ndjson_server.port == 9999
        assert bridge.ndjson_server.host == "0.0.0.0"

    def test_creates_ndjson_server_default_port(self) -> None:
        bridge = Bridge()

        assert bridge.ndjson_server.port == 8787

    def test_assigns_pairing_id(self) -> None:
        bridge = Bridge(port=8787, pairing_id="PAIR-XYZ")

        assert bridge.pairing_id == "PAIR-XYZ"

    def test_generates_pairing_id_if_not_provided(self) -> None:
        bridge = Bridge(port=8787)

        # Should be a valid UUID
        assert bridge.pairing_id is not None
        assert len(bridge.pairing_id) > 0
        uuid.UUID(bridge.pairing_id)  # Raises if not valid UUID

    def test_sessions_dict_starts_empty(self) -> None:
        bridge = Bridge(port=8787)

        assert bridge.sessions == {}

    def test_handlers_registered_on_ndjson_server(self) -> None:
        bridge = Bridge(port=8787)

        # Verify handlers are registered for all expected message types
        expected_types = [
            "system",
            "assistant",
            "result",
            "control_request",
            "stream_event",
            "tool_progress",
            "tool_use_summary",
            "auth_status",
        ]
        for msg_type in expected_types:
            assert msg_type in bridge.ndjson_server._handlers, (
                f"Handler for {msg_type!r} not registered"
            )

    def test_connect_disconnect_callbacks_registered(self) -> None:
        bridge = Bridge(port=8787)

        assert bridge.ndjson_server._on_connect is not None
        assert bridge.ndjson_server._on_disconnect is not None


# ---------------------------------------------------------------------------
# TEST A8.2: _handle_system with init message updates session state
# ---------------------------------------------------------------------------

class TestHandleSystemInit:
    """A8.2: _handle_system with init message updates session state."""

    @pytest.mark.asyncio
    async def test_init_updates_session_state(self) -> None:
        bridge = Bridge(port=8787)

        # Simulate CLI connect
        session_id = "test-session-1"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # Mock send_to_cli to capture the initialize message
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        # Send system/init
        init_msg = _make_system_init_msg(
            session_id="cli-internal-id",
            model="claude-sonnet-4-5-20250929",
            cwd="/home/user/project",
            tools=["Bash", "Edit"],
        )
        await bridge._handle_system(session_id, init_msg)

        session = bridge.sessions[session_id]
        assert session.model == "claude-sonnet-4-5-20250929"
        assert session.cwd == "/home/user/project"
        assert session.tools == ["Bash", "Edit"]
        assert session.status == "running"

    @pytest.mark.asyncio
    async def test_init_stores_cli_session_id_on_launcher(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-2"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # Set up a mock launcher
        bridge._launcher = MagicMock()
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        init_msg = _make_system_init_msg(session_id="cli-sess-abc")
        await bridge._handle_system(session_id, init_msg)

        bridge._launcher.set_cli_session_id.assert_called_once_with(
            session_id, "cli-sess-abc"
        )

    @pytest.mark.asyncio
    async def test_init_sends_initialize_control_request(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-3"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        init_msg = _make_system_init_msg()
        await bridge._handle_system(session_id, init_msg)

        # Verify send_to_cli was called with the initialize control_request
        bridge._ndjson.send_to_cli.assert_called()
        call_args = bridge._ndjson.send_to_cli.call_args
        sent_msg = call_args[0][1]  # Second positional arg is the message

        assert sent_msg["type"] == "control_request"
        assert sent_msg["request"]["subtype"] == "initialize"
        assert "appendSystemPrompt" in sent_msg["request"]

    @pytest.mark.asyncio
    async def test_status_message_updates_compaction(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-4"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        # First send init to set up the session properly
        init_msg = _make_system_init_msg()
        await bridge._handle_system(session_id, init_msg)

        # Then send a status/compacting message
        status_msg = _make_system_status_msg(status="compacting")
        await bridge._handle_system(session_id, status_msg)

        session = bridge.sessions[session_id]
        assert session.is_compacting is True

    @pytest.mark.asyncio
    async def test_no_session_is_noop(self) -> None:
        bridge = Bridge(port=8787)

        # Call _handle_system without a session -- should not raise
        init_msg = _make_system_init_msg()
        await bridge._handle_system("nonexistent", init_msg)


# ---------------------------------------------------------------------------
# TEST A8.3: _handle_control_request routes can_use_tool to pending
#            permissions
# ---------------------------------------------------------------------------

class TestHandleControlRequestNormal:
    """A8.3: _handle_control_request routes can_use_tool to pending permissions."""

    @pytest.mark.asyncio
    async def test_routes_to_pending_permissions(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-5"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # Send a can_use_tool control_request
        ctrl_msg = _make_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "ls -la"},
        )
        await bridge._handle_control_request(session_id, ctrl_msg)

        session = bridge.sessions[session_id]
        assert "r1" in session.pending_permissions
        perm = session.pending_permissions["r1"]
        assert perm.tool_name == "Bash"
        assert perm.input == {"command": "ls -la"}
        assert session.status == "waiting"

    @pytest.mark.asyncio
    async def test_does_not_send_response_in_normal_mode(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-6"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # Ensure permission_mode is default (not autoAccept)
        bridge.sessions[session_id].permission_mode = "default"

        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        ctrl_msg = _make_control_request(request_id="r2", tool_name="Edit")
        await bridge._handle_control_request(session_id, ctrl_msg)

        # In normal mode, send_to_cli should NOT be called (permission queued)
        bridge._ndjson.send_to_cli.assert_not_called()

    @pytest.mark.asyncio
    async def test_ask_user_question_is_logged(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-7"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        ctrl_msg = _make_control_request(
            request_id="q1",
            tool_name="AskUserQuestion",
            tool_input={
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which database?",
                        "options": [
                            {"label": "PostgreSQL (Recommended)", "description": ""},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )
        # Should not raise
        await bridge._handle_control_request(session_id, ctrl_msg)

        session = bridge.sessions[session_id]
        assert "q1" in session.pending_permissions
        assert session.pending_permissions["q1"].tool_name == "AskUserQuestion"

    @pytest.mark.asyncio
    async def test_no_session_is_noop(self) -> None:
        bridge = Bridge(port=8787)

        ctrl_msg = _make_control_request()
        # Should not raise when session does not exist
        await bridge._handle_control_request("nonexistent", ctrl_msg)


# ---------------------------------------------------------------------------
# TEST A8.4: _handle_control_request in auto-accept mode sends response
#            immediately
# ---------------------------------------------------------------------------

class TestHandleControlRequestAutoAccept:
    """A8.4: _handle_control_request in auto-accept mode sends response immediately."""

    @pytest.mark.asyncio
    async def test_auto_accept_sends_response(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-8"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # Set auto-accept mode
        bridge.sessions[session_id].permission_mode = "autoAccept"

        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        ctrl_msg = _make_control_request(
            request_id="r3",
            tool_name="Bash",
            tool_input={"command": "echo hello"},
        )
        await bridge._handle_control_request(session_id, ctrl_msg)

        # In auto-accept mode, send_to_cli IS called with the response
        bridge._ndjson.send_to_cli.assert_called_once()
        call_args = bridge._ndjson.send_to_cli.call_args
        sent_session_id = call_args[0][0]
        sent_msg = call_args[0][1]

        assert sent_session_id == session_id
        assert sent_msg["type"] == "control_response"
        assert sent_msg["response"]["subtype"] == "success"
        assert sent_msg["response"]["request_id"] == "r3"
        assert sent_msg["response"]["response"]["behavior"] == "allow"
        assert sent_msg["response"]["response"]["updatedInput"] == {
            "command": "echo hello"
        }

    @pytest.mark.asyncio
    async def test_auto_accept_clears_pending(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-9"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)
        bridge.sessions[session_id].permission_mode = "autoAccept"
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        ctrl_msg = _make_control_request(request_id="r4")
        await bridge._handle_control_request(session_id, ctrl_msg)

        # Permission should not remain pending (resolved immediately)
        session = bridge.sessions[session_id]
        assert "r4" not in session.pending_permissions
        assert len(session.pending_permissions) == 0

    @pytest.mark.asyncio
    async def test_bypass_permissions_mode(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-10"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)
        bridge.sessions[session_id].permission_mode = "bypassPermissions"
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        ctrl_msg = _make_control_request(request_id="r5", tool_name="Write")
        await bridge._handle_control_request(session_id, ctrl_msg)

        bridge._ndjson.send_to_cli.assert_called_once()
        sent_msg = bridge._ndjson.send_to_cli.call_args[0][1]
        assert sent_msg["response"]["response"]["behavior"] == "allow"
        assert len(bridge.sessions[session_id].pending_permissions) == 0


# ---------------------------------------------------------------------------
# TEST A8.5: _send_initialize constructs correct control_request with
#            appendSystemPrompt
# ---------------------------------------------------------------------------

class TestSendInitialize:
    """A8.5: _send_initialize constructs correct control_request with appendSystemPrompt."""

    @pytest.mark.asyncio
    async def test_constructs_correct_request(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-11"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        await bridge._send_initialize(session_id)

        bridge._ndjson.send_to_cli.assert_called_once()
        call_args = bridge._ndjson.send_to_cli.call_args
        sent_session_id = call_args[0][0]
        sent_msg = call_args[0][1]

        assert sent_session_id == session_id
        assert sent_msg["type"] == "control_request"
        assert "request_id" in sent_msg
        # request_id should be a valid UUID
        uuid.UUID(sent_msg["request_id"])

        request = sent_msg["request"]
        assert request["subtype"] == "initialize"
        assert "appendSystemPrompt" in request

    @pytest.mark.asyncio
    async def test_system_prompt_contains_watch_instructions(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-12"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        await bridge._send_initialize(session_id)

        sent_msg = bridge._ndjson.send_to_cli.call_args[0][1]
        prompt = sent_msg["request"]["appendSystemPrompt"]

        # Verify key instructions are present
        assert "Apple Watch" in prompt
        assert "approve or reject" in prompt
        assert "Proceed? (y/n)" in prompt
        assert "NEVER present numbered option lists" in prompt

    @pytest.mark.asyncio
    async def test_each_call_generates_unique_request_id(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-13"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)
        bridge._ndjson.send_to_cli = AsyncMock(return_value=True)

        await bridge._send_initialize(session_id)
        first_id = bridge._ndjson.send_to_cli.call_args[0][1]["request_id"]

        await bridge._send_initialize(session_id)
        second_id = bridge._ndjson.send_to_cli.call_args[0][1]["request_id"]

        assert first_id != second_id


# ---------------------------------------------------------------------------
# TEST A8.6: _on_cli_disconnect cancels all pending permissions
# ---------------------------------------------------------------------------

class TestCliDisconnect:
    """A8.6: _on_cli_disconnect cancels all pending permissions."""

    @pytest.mark.asyncio
    async def test_cancels_all_pending_permissions(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-14"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        session = bridge.sessions[session_id]

        # Add some pending permissions
        session.add_permission(
            PermissionRequest(
                request_id="r1",
                tool_name="Bash",
                input={"command": "ls"},
                tool_use_id="tu-1",
            )
        )
        session.add_permission(
            PermissionRequest(
                request_id="r2",
                tool_name="Edit",
                input={"file_path": "/a.py"},
                tool_use_id="tu-2",
            )
        )
        session.add_permission(
            PermissionRequest(
                request_id="r3",
                tool_name="Write",
                input={"file_path": "/b.py", "content": "x"},
                tool_use_id="tu-3",
            )
        )
        assert len(session.pending_permissions) == 3

        # Disconnect
        await bridge._on_cli_disconnect(session_id)

        assert len(session.pending_permissions) == 0

    @pytest.mark.asyncio
    async def test_clears_cli_socket(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-15"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        session = bridge.sessions[session_id]
        assert session.cli_socket is mock_ws

        await bridge._on_cli_disconnect(session_id)

        assert session.cli_socket is None

    @pytest.mark.asyncio
    async def test_disconnect_with_no_pending_does_not_error(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-16"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        # No pending permissions
        assert len(bridge.sessions[session_id].pending_permissions) == 0

        # Should not raise
        await bridge._on_cli_disconnect(session_id)

    @pytest.mark.asyncio
    async def test_disconnect_unknown_session_is_noop(self) -> None:
        bridge = Bridge(port=8787)

        # Should not raise when session does not exist
        await bridge._on_cli_disconnect("unknown-session")

    @pytest.mark.asyncio
    async def test_session_persists_after_disconnect(self) -> None:
        """After disconnect, the session still exists (for reconnect)."""
        bridge = Bridge(port=8787)

        session_id = "test-session-17"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        await bridge._on_cli_disconnect(session_id)

        # Session should still be in the dict
        assert session_id in bridge.sessions


# ---------------------------------------------------------------------------
# Additional tests: assistant and result handling
# ---------------------------------------------------------------------------

class TestHandleAssistant:
    """Verify _handle_assistant updates session state."""

    @pytest.mark.asyncio
    async def test_sets_status_to_running(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-20"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)
        bridge.sessions[session_id].status = "idle"

        await bridge._handle_assistant(session_id, _make_assistant_msg())

        assert bridge.sessions[session_id].status == "running"

    @pytest.mark.asyncio
    async def test_appends_to_message_history(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-21"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        msg = _make_assistant_msg()
        await bridge._handle_assistant(session_id, msg)

        history = bridge.sessions[session_id].message_history
        assert len(history) == 1
        assert history[0]["type"] == "assistant"
        assert history[0]["data"] is msg


class TestHandleResult:
    """Verify _handle_result updates session state."""

    @pytest.mark.asyncio
    async def test_updates_cost_and_context(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-22"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        result_msg = _make_result_msg(
            total_cost_usd=0.05,
            num_turns=3,
        )
        await bridge._handle_result(session_id, result_msg)

        session = bridge.sessions[session_id]
        # Context % = (80000 + 20000) / 200000 = 50%
        assert session.context_used_percent == 50
        assert session.context_warning is False

    @pytest.mark.asyncio
    async def test_appends_to_message_history(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "test-session-23"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        msg = _make_result_msg()
        await bridge._handle_result(session_id, msg)

        history = bridge.sessions[session_id].message_history
        assert len(history) == 1
        assert history[0]["type"] == "result"


# ---------------------------------------------------------------------------
# Test on_cli_connect
# ---------------------------------------------------------------------------

class TestOnCliConnect:
    """Verify _on_cli_connect creates session and marks launcher."""

    @pytest.mark.asyncio
    async def test_creates_session(self) -> None:
        bridge = Bridge(port=8787)

        session_id = "new-session"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        assert session_id in bridge.sessions
        session = bridge.sessions[session_id]
        assert session.id == session_id
        assert session.cli_socket is mock_ws

    @pytest.mark.asyncio
    async def test_marks_launcher_connected(self) -> None:
        bridge = Bridge(port=8787)
        bridge._launcher = MagicMock()

        session_id = "launcher-session"
        mock_ws = MagicMock()
        await bridge._on_cli_connect(session_id, mock_ws)

        bridge._launcher.mark_connected.assert_called_once_with(session_id)

    @pytest.mark.asyncio
    async def test_no_launcher_is_ok(self) -> None:
        bridge = Bridge(port=8787)
        assert bridge._launcher is None

        session_id = "no-launcher"
        mock_ws = MagicMock()
        # Should not raise
        await bridge._on_cli_connect(session_id, mock_ws)

        assert session_id in bridge.sessions
