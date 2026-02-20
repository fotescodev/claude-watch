"""
Tests for MCPServer.bridge.permissions — permission handler for can_use_tool
control requests.

Tests follow the spec naming from sdk-url-agent-execution-spec.md task A3:
  A3.1  approve_permission returns correct control_response format
  A3.2  deny_permission returns correct format with custom message
  A3.3  Auto-accept mode — permission created and immediately approved
  A3.4  approve_all with 3 pending — returns 3 response dicts, session empty
  A3.5  approve with updated_input — response uses modified input, not original
  A3.6  resolve unknown request_id — returns None, no crash
  A3.7  handle_can_use_tool normal mode — returns (perm, None)
  A3.8  handle_can_use_tool auto mode — returns (perm, response)
"""
from __future__ import annotations

import pytest

from MCPServer.bridge.session import PermissionRequest, Session
from MCPServer.bridge.permissions import (
    approve_all,
    approve_permission,
    deny_permission,
    handle_can_use_tool,
    should_auto_accept,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_session(permission_mode: str = "default") -> Session:
    """Create a fresh session with the given permission mode."""
    s = Session("test-session")
    s.permission_mode = permission_mode
    return s


def _add_perm(
    session: Session,
    request_id: str = "r1",
    tool_name: str = "Bash",
    tool_input: dict | None = None,
) -> PermissionRequest:
    """Add a PermissionRequest to the session and return it."""
    perm = PermissionRequest(
        request_id=request_id,
        tool_name=tool_name,
        input=tool_input or {"command": "ls"},
        tool_use_id=f"tu-{request_id}",
    )
    session.add_permission(perm)
    return perm


def _make_control_request(
    request_id: str = "r1",
    tool_name: str = "Bash",
    tool_input: dict | None = None,
    description: str | None = None,
    tool_use_id: str = "tu-r1",
    agent_id: str | None = None,
) -> dict:
    """Build a raw control_request dict as the CLI would send it."""
    return {
        "type": "control_request",
        "request_id": request_id,
        "request": {
            "subtype": "can_use_tool",
            "tool_name": tool_name,
            "input": tool_input or {"command": "ls"},
            "description": description,
            "tool_use_id": tool_use_id,
            "agent_id": agent_id,
        },
    }


# ---------------------------------------------------------------------------
# TEST A3.1: approve_permission returns correct control_response format
# ---------------------------------------------------------------------------

class TestApprovePermission:
    def test_returns_correct_format(self) -> None:
        session = _make_session()
        _add_perm(session, "r1", "Bash", {"command": "ls"})

        resp = approve_permission(session, "r1")

        assert resp is not None
        assert resp["type"] == "control_response"
        assert resp["response"]["subtype"] == "success"
        assert resp["response"]["request_id"] == "r1"
        assert resp["response"]["response"]["behavior"] == "allow"
        assert resp["response"]["response"]["updatedInput"] == {"command": "ls"}

    def test_removes_from_pending(self) -> None:
        session = _make_session()
        _add_perm(session, "r1")

        approve_permission(session, "r1")

        assert "r1" not in session.pending_permissions
        assert len(session.pending_permissions) == 0


# ---------------------------------------------------------------------------
# TEST A3.2: deny_permission returns correct format with custom message
# ---------------------------------------------------------------------------

class TestDenyPermission:
    def test_returns_correct_format_default_message(self) -> None:
        session = _make_session()
        _add_perm(session, "r2", "Bash", {"command": "rm -rf /"})

        resp = deny_permission(session, "r2")

        assert resp is not None
        assert resp["type"] == "control_response"
        assert resp["response"]["subtype"] == "success"
        assert resp["response"]["request_id"] == "r2"
        assert resp["response"]["response"]["behavior"] == "deny"
        assert resp["response"]["response"]["message"] == "Denied by user"

    def test_returns_correct_format_custom_message(self) -> None:
        session = _make_session()
        _add_perm(session, "r2", "Bash", {"command": "rm -rf /"})

        resp = deny_permission(session, "r2", "Too dangerous")

        assert resp is not None
        assert resp["response"]["response"]["behavior"] == "deny"
        assert resp["response"]["response"]["message"] == "Too dangerous"

    def test_removes_from_pending(self) -> None:
        session = _make_session()
        _add_perm(session, "r2")

        deny_permission(session, "r2")

        assert "r2" not in session.pending_permissions
        assert len(session.pending_permissions) == 0


# ---------------------------------------------------------------------------
# TEST A3.3: Auto-accept mode — permission created and immediately approved
# ---------------------------------------------------------------------------

class TestAutoAccept:
    @pytest.mark.parametrize("mode", ["autoAccept", "bypassPermissions"])
    def test_should_auto_accept(self, mode: str) -> None:
        session = _make_session(permission_mode=mode)
        assert should_auto_accept(session) is True

    def test_should_not_auto_accept_default(self) -> None:
        session = _make_session(permission_mode="default")
        assert should_auto_accept(session) is False

    def test_auto_accept_via_handle(self) -> None:
        session = _make_session(permission_mode="autoAccept")
        msg = _make_control_request("r1", "Edit", {"file_path": "/src/main.py"})

        perm, resp = handle_can_use_tool(session, msg)

        # Permission was created
        assert perm.request_id == "r1"
        assert perm.tool_name == "Edit"
        assert perm.input == {"file_path": "/src/main.py"}

        # Response was generated immediately
        assert resp is not None
        assert resp["response"]["response"]["behavior"] == "allow"
        assert resp["response"]["response"]["updatedInput"] == {"file_path": "/src/main.py"}

        # Pending permissions are empty (resolved immediately)
        assert len(session.pending_permissions) == 0


# ---------------------------------------------------------------------------
# TEST A3.4: approve_all with 3 pending — returns 3 response dicts, session
#            empty
# ---------------------------------------------------------------------------

class TestApproveAll:
    def test_approves_all_pending(self) -> None:
        session = _make_session()
        _add_perm(session, "r1", "Bash", {"command": "ls"})
        _add_perm(session, "r2", "Edit", {"file_path": "/a.py"})
        _add_perm(session, "r3", "Write", {"file_path": "/b.py", "content": "hello"})

        responses = approve_all(session)

        assert len(responses) == 3
        assert len(session.pending_permissions) == 0

        # Each response should be a valid control_response with "allow"
        response_ids = set()
        for resp in responses:
            assert resp["type"] == "control_response"
            assert resp["response"]["response"]["behavior"] == "allow"
            response_ids.add(resp["response"]["request_id"])

        assert response_ids == {"r1", "r2", "r3"}

    def test_approve_all_empty(self) -> None:
        session = _make_session()

        responses = approve_all(session)

        assert responses == []


# ---------------------------------------------------------------------------
# TEST A3.5: approve with updated_input — response uses modified input,
#            not original
# ---------------------------------------------------------------------------

class TestUpdatedInput:
    def test_approve_with_updated_input(self) -> None:
        session = _make_session()
        _add_perm(session, "r1", "Bash", {"command": "ls"})

        modified = {"command": "ls -la", "extra": True}
        resp = approve_permission(session, "r1", updated_input=modified)

        assert resp is not None
        assert resp["response"]["response"]["updatedInput"] == modified
        # The response must NOT contain the original input
        assert resp["response"]["response"]["updatedInput"] != {"command": "ls"}

    def test_approve_without_updated_input_uses_original(self) -> None:
        session = _make_session()
        original = {"command": "git status"}
        _add_perm(session, "r1", "Bash", original)

        resp = approve_permission(session, "r1")

        assert resp is not None
        assert resp["response"]["response"]["updatedInput"] == original


# ---------------------------------------------------------------------------
# TEST A3.6: resolve unknown request_id — returns None, no crash
# ---------------------------------------------------------------------------

class TestUnknownRequestId:
    def test_approve_unknown(self) -> None:
        session = _make_session()

        resp = approve_permission(session, "nonexistent")

        assert resp is None

    def test_deny_unknown(self) -> None:
        session = _make_session()

        resp = deny_permission(session, "nonexistent")

        assert resp is None

    def test_approve_already_resolved(self) -> None:
        session = _make_session()
        _add_perm(session, "r1")

        # First approval succeeds
        resp1 = approve_permission(session, "r1")
        assert resp1 is not None

        # Second approval for same id returns None (already resolved)
        resp2 = approve_permission(session, "r1")
        assert resp2 is None


# ---------------------------------------------------------------------------
# TEST A3.7: handle_can_use_tool normal mode — returns (perm, None)
# ---------------------------------------------------------------------------

class TestHandleCanUseToolNormal:
    def test_returns_perm_and_none(self) -> None:
        session = _make_session(permission_mode="default")
        msg = _make_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "ls"},
            description="List files",
            tool_use_id="tu-r1",
            agent_id="agent-0",
        )

        perm, resp = handle_can_use_tool(session, msg)

        # PermissionRequest is correctly populated
        assert perm.request_id == "r1"
        assert perm.tool_name == "Bash"
        assert perm.input == {"command": "ls"}
        assert perm.description == "List files"
        assert perm.tool_use_id == "tu-r1"
        assert perm.agent_id == "agent-0"
        assert perm.timestamp > 0

        # No response — caller must route to watch
        assert resp is None

        # Permission is pending in session
        assert "r1" in session.pending_permissions
        assert session.pending_permissions["r1"] is perm

    def test_session_status_set_to_waiting(self) -> None:
        session = _make_session()
        msg = _make_control_request("r1")

        handle_can_use_tool(session, msg)

        assert session.status == "waiting"


# ---------------------------------------------------------------------------
# TEST A3.8: handle_can_use_tool auto mode — returns (perm, response)
# ---------------------------------------------------------------------------

class TestHandleCanUseToolAuto:
    def test_auto_accept_returns_perm_and_response(self) -> None:
        session = _make_session(permission_mode="autoAccept")
        msg = _make_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "echo hello"},
        )

        perm, resp = handle_can_use_tool(session, msg)

        # PermissionRequest is populated
        assert perm.request_id == "r1"
        assert perm.tool_name == "Bash"
        assert perm.input == {"command": "echo hello"}

        # Response is immediately generated
        assert resp is not None
        assert resp["type"] == "control_response"
        assert resp["response"]["subtype"] == "success"
        assert resp["response"]["request_id"] == "r1"
        assert resp["response"]["response"]["behavior"] == "allow"
        assert resp["response"]["response"]["updatedInput"] == {"command": "echo hello"}

        # Session pending is empty (resolved immediately)
        assert len(session.pending_permissions) == 0

    def test_bypass_permissions_mode(self) -> None:
        session = _make_session(permission_mode="bypassPermissions")
        msg = _make_control_request("r1", "Write", {"file_path": "/tmp/x", "content": "y"})

        perm, resp = handle_can_use_tool(session, msg)

        assert resp is not None
        assert resp["response"]["response"]["behavior"] == "allow"
        assert len(session.pending_permissions) == 0

    def test_handles_camel_case_keys(self) -> None:
        """Verify that camelCase keys from the wire format are handled."""
        session = _make_session()
        msg = {
            "type": "control_request",
            "requestId": "r1",
            "request": {
                "subtype": "can_use_tool",
                "toolName": "Bash",
                "input": {"command": "pwd"},
                "toolUseId": "tu-abc",
                "agentId": "agent-1",
            },
        }

        perm, resp = handle_can_use_tool(session, msg)

        assert perm.request_id == "r1"
        assert perm.tool_name == "Bash"
        assert perm.tool_use_id == "tu-abc"
        assert perm.agent_id == "agent-1"
        assert resp is None  # default mode
