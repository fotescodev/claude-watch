"""
Tests for MCPServer.bridge.api -- Watch-facing REST API.

Tests follow the spec naming from sdk-url-agent-execution-spec.md task A7:
  A7.1   GET /approval-queue returns correct format for Bash and Edit pending perms
  A7.2   POST /approval/{id} with approved=true triggers allow response
  A7.3   POST /approval/{id} with approved=false triggers deny response
  A7.4   GET /session-progress returns correct schema
  A7.5   GET /questions returns AskUserQuestion items (not regular approvals)
  A7.6   POST /question/{id}/answer with accepted=true sends updatedInput
  A7.7   POST /session-interrupt with action=stop sends interrupt control_request
  A7.8   GET /health returns {"status": "ok"}
  A7.9   GET /approval-queue with unknown pairing_id returns 404
  A7.10  Tool name to type mapping (Bash->bash, Edit->file_edit, Write->file_create)
"""
from __future__ import annotations

import json
from typing import Any
from unittest.mock import AsyncMock

import pytest
from aiohttp import web
from aiohttp.test_utils import AioHTTPTestCase, TestClient, TestServer

from MCPServer.bridge.api import BridgeAPI, _tool_name_to_type
from MCPServer.bridge.session import PermissionRequest, Session


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_session(session_id: str = "sess-1") -> Session:
    """Create a fresh Session with sensible defaults."""
    s = Session(session_id)
    s.model = "claude-sonnet-4-5-20250929"
    s.cwd = "/home/user/project"
    s.tools = ["Bash", "Edit", "Write"]
    s.permission_mode = "default"
    return s


def _add_perm(
    session: Session,
    request_id: str,
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


# ---------------------------------------------------------------------------
# Fixture-based setup using pytest-aiohttp
# ---------------------------------------------------------------------------

@pytest.fixture
def bridge_api() -> BridgeAPI:
    """Return a fresh BridgeAPI instance."""
    return BridgeAPI()


@pytest.fixture
def mock_send() -> AsyncMock:
    """Return an AsyncMock that records send_to_cli calls."""
    return AsyncMock(return_value=True)


@pytest.fixture
def session() -> Session:
    """Return a Session pre-configured for pairing 'pair-123'."""
    return _make_session("sess-1")


@pytest.fixture
def wired_api(
    bridge_api: BridgeAPI, mock_send: AsyncMock, session: Session
) -> BridgeAPI:
    """Return a BridgeAPI with a session registered and send_to_cli wired."""
    bridge_api.set_send_to_cli(mock_send)
    bridge_api.register_session("pair-123", "sess-1", session)
    return bridge_api


@pytest.fixture
def cli(aiohttp_client, wired_api: BridgeAPI):
    """Create an aiohttp TestClient bound to the BridgeAPI app.

    ``aiohttp_client`` is provided by the ``pytest-aiohttp`` plugin.
    """
    app = wired_api.create_app()
    return aiohttp_client(app)


# ---------------------------------------------------------------------------
# TEST A7.1: GET /approval-queue returns correct format
# ---------------------------------------------------------------------------

class TestGetApprovalQueue:
    """GET /approval-queue/{pairing_id}."""

    @pytest.mark.asyncio
    async def test_bash_and_edit_format(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """A7.1 — Two pending permissions (Bash + Edit) return correct
        format with types 'bash' and 'file_edit'.
        """
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "ls -la"})
        _add_perm(session, "r2", "Edit", {"file_path": "/src/main.py"})

        resp = await client.get("/approval-queue/pair-123")
        assert resp.status == 200
        data = await resp.json()

        assert "requests" in data
        assert "totalCount" in data
        assert data["totalCount"] == 2

        by_id = {r["id"]: r for r in data["requests"]}

        # Bash request
        bash_req = by_id["r1"]
        assert bash_req["type"] == "bash"
        assert bash_req["title"] == "ls -la"
        assert bash_req["description"] == "ls -la"
        assert bash_req["command"] == "ls -la"
        assert bash_req["filePath"] is None

        # Edit request
        edit_req = by_id["r2"]
        assert edit_req["type"] == "file_edit"
        assert edit_req["title"] == "main.py"
        assert edit_req["description"] == "Edit /src/main.py"
        assert edit_req["filePath"] == "/src/main.py"
        assert edit_req["command"] is None

    @pytest.mark.asyncio
    async def test_excludes_ask_user_question(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """AskUserQuestion permissions must NOT appear in the approval queue."""
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "ls"})
        _add_perm(
            session,
            "r2",
            "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which database?",
                        "options": [{"label": "PostgreSQL", "description": "..."}],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await client.get("/approval-queue/pair-123")
        data = await resp.json()

        assert data["totalCount"] == 1
        assert data["requests"][0]["id"] == "r1"

    @pytest.mark.asyncio
    async def test_empty_queue(
        self, cli, wired_api: BridgeAPI
    ) -> None:
        """Empty queue returns totalCount=0 and empty requests list."""
        client: TestClient = await cli

        resp = await client.get("/approval-queue/pair-123")
        data = await resp.json()

        assert data == {"requests": [], "totalCount": 0}


# ---------------------------------------------------------------------------
# TEST A7.2: POST /approval with approved=true triggers allow response
# ---------------------------------------------------------------------------

class TestPostApprovalApprove:
    """POST /approval/{request_id} with approved=true."""

    @pytest.mark.asyncio
    async def test_approved_sends_allow(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """A7.2 — Approving a permission sends a control_response with
        behavior 'allow' to the CLI.
        """
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "ls"})

        resp = await client.post(
            "/approval/r1",
            json={"pairingId": "pair-123", "approved": True},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

        # Verify send_to_cli was called with the right message
        mock_send.assert_called_once()
        sent_sid, sent_msg = mock_send.call_args[0]
        assert sent_sid == "sess-1"
        assert sent_msg["type"] == "control_response"
        assert sent_msg["response"]["response"]["behavior"] == "allow"
        assert sent_msg["response"]["request_id"] == "r1"
        assert sent_msg["response"]["response"]["updatedInput"] == {"command": "ls"}

    @pytest.mark.asyncio
    async def test_approved_clears_from_queue(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """After approval, the request disappears from the queue."""
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "ls"})

        await client.post(
            "/approval/r1",
            json={"pairingId": "pair-123", "approved": True},
        )

        # Verify queue is now empty
        resp = await client.get("/approval-queue/pair-123")
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []


# ---------------------------------------------------------------------------
# TEST A7.3: POST /approval with approved=false triggers deny response
# ---------------------------------------------------------------------------

class TestPostApprovalDeny:
    """POST /approval/{request_id} with approved=false."""

    @pytest.mark.asyncio
    async def test_denied_sends_deny(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """A7.3 — Denying a permission sends a control_response with
        behavior 'deny' to the CLI.
        """
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "rm -rf /"})

        resp = await client.post(
            "/approval/r1",
            json={"pairingId": "pair-123", "approved": False},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

        mock_send.assert_called_once()
        sent_sid, sent_msg = mock_send.call_args[0]
        assert sent_sid == "sess-1"
        assert sent_msg["type"] == "control_response"
        assert sent_msg["response"]["response"]["behavior"] == "deny"
        assert sent_msg["response"]["request_id"] == "r1"
        assert "message" in sent_msg["response"]["response"]


# ---------------------------------------------------------------------------
# TEST A7.4: GET /session-progress returns correct schema
# ---------------------------------------------------------------------------

class TestGetProgress:
    """GET /session-progress/{pairing_id}."""

    @pytest.mark.asyncio
    async def test_progress_schema(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """A7.4 — Response has correct schema with tasks and progress fields."""
        client: TestClient = await cli

        session.update_todos([
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {
                "content": "Write tests",
                "status": "in_progress",
                "activeForm": "Writing tests",
            },
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        resp = await client.get("/session-progress/pair-123")
        assert resp.status == 200
        data = await resp.json()

        assert "progress" in data
        p = data["progress"]

        assert p["currentTask"] == "Write tests"
        assert p["currentActivity"] == "Writing tests"
        # 1 out of 3 completed
        assert abs(p["progress"] - (1 / 3)) < 0.01
        assert p["completedCount"] == 1
        assert p["totalCount"] == 3
        assert isinstance(p["elapsedSeconds"], int)
        assert len(p["tasks"]) == 3
        assert p["tasks"][0]["content"] == "Fix bug"
        assert p["tasks"][0]["status"] == "completed"


# ---------------------------------------------------------------------------
# TEST A7.5: GET /questions returns AskUserQuestion items
# ---------------------------------------------------------------------------

class TestGetQuestions:
    """GET /questions/{pairing_id}."""

    @pytest.mark.asyncio
    async def test_returns_ask_user_questions_only(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """A7.5 — Only AskUserQuestion items appear in /questions, not
        regular tool approvals.
        """
        client: TestClient = await cli

        # Regular tool approval
        _add_perm(session, "r1", "Bash", {"command": "ls"})

        # AskUserQuestion
        _add_perm(
            session,
            "q1",
            "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which database?",
                        "options": [
                            {"label": "PostgreSQL (Recommended)", "description": "Popular"},
                            {"label": "MySQL", "description": "Alternative"},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await client.get("/questions/pair-123")
        assert resp.status == 200
        data = await resp.json()

        assert len(data["questions"]) == 1
        q = data["questions"][0]
        assert q["questionId"] == "q1"
        assert q["question"] == "Which database?"
        assert q["recommendedAnswer"] == "PostgreSQL"
        assert q["optionCount"] == 2
        assert "PostgreSQL (Recommended)" in q["allOptions"]
        assert "MySQL" in q["allOptions"]

    @pytest.mark.asyncio
    async def test_no_questions_returns_empty(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """When there are no AskUserQuestion items, /questions returns empty."""
        client: TestClient = await cli

        _add_perm(session, "r1", "Bash", {"command": "ls"})

        resp = await client.get("/questions/pair-123")
        data = await resp.json()
        assert data == {"questions": []}


# ---------------------------------------------------------------------------
# TEST A7.6: POST /question/{id}/answer with accepted=true
# ---------------------------------------------------------------------------

class TestPostQuestionAnswer:
    """POST /question/{question_id}/answer."""

    @pytest.mark.asyncio
    async def test_accepted_sends_updated_input(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """A7.6 — Accepting a question sends a control_response with
        updatedInput containing the recommended answers.
        """
        client: TestClient = await cli

        _add_perm(
            session,
            "q1",
            "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which database?",
                        "options": [
                            {"label": "PostgreSQL (Recommended)", "description": "Popular"},
                            {"label": "MySQL", "description": "Alternative"},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await client.post(
            "/question/q1/answer",
            json={"pairingId": "pair-123", "accepted": True, "handleOnMac": False},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

        mock_send.assert_called_once()
        sent_sid, sent_msg = mock_send.call_args[0]
        assert sent_sid == "sess-1"
        assert sent_msg["type"] == "control_response"
        assert sent_msg["response"]["response"]["behavior"] == "allow"
        updated = sent_msg["response"]["response"]["updatedInput"]
        assert updated["answers"] == {"DB": "PostgreSQL"}
        # Original questions preserved in updatedInput
        assert "questions" in updated

    @pytest.mark.asyncio
    async def test_handle_on_mac_sends_deny(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """handleOnMac=true defers the question to the terminal."""
        client: TestClient = await cli

        _add_perm(
            session,
            "q1",
            "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "Auth",
                        "question": "Auth method?",
                        "options": [
                            {"label": "OAuth", "description": "..."},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await client.post(
            "/question/q1/answer",
            json={"pairingId": "pair-123", "accepted": False, "handleOnMac": True},
        )
        assert resp.status == 200

        mock_send.assert_called_once()
        sent_sid, sent_msg = mock_send.call_args[0]
        assert sent_msg["response"]["response"]["behavior"] == "deny"
        assert sent_msg["response"]["response"]["message"] == "Deferred to terminal by user"

    @pytest.mark.asyncio
    async def test_question_removed_after_answer(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """After answering, the question no longer appears in /questions."""
        client: TestClient = await cli

        _add_perm(
            session,
            "q1",
            "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which?",
                        "options": [{"label": "PG", "description": ""}],
                        "multiSelect": False,
                    }
                ]
            },
        )

        await client.post(
            "/question/q1/answer",
            json={"pairingId": "pair-123", "accepted": True, "handleOnMac": False},
        )

        resp = await client.get("/questions/pair-123")
        data = await resp.json()
        assert data == {"questions": []}


# ---------------------------------------------------------------------------
# TEST A7.7: POST /session-interrupt with action=stop
# ---------------------------------------------------------------------------

class TestPostInterrupt:
    """POST /session-interrupt."""

    @pytest.mark.asyncio
    async def test_stop_sends_interrupt_control_request(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """A7.7 — action 'stop' sends a control_request with subtype
        'interrupt' to the CLI.
        """
        client: TestClient = await cli

        resp = await client.post(
            "/session-interrupt",
            json={"pairingId": "pair-123", "action": "stop"},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

        mock_send.assert_called_once()
        sent_sid, sent_msg = mock_send.call_args[0]
        assert sent_sid == "sess-1"
        assert sent_msg["type"] == "control_request"
        assert sent_msg["request"]["subtype"] == "interrupt"
        assert "request_id" in sent_msg  # UUID generated

    @pytest.mark.asyncio
    async def test_stop_updates_interrupt_state(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """After stop, GET /session-interrupt returns interrupted=true."""
        client: TestClient = await cli

        await client.post(
            "/session-interrupt",
            json={"pairingId": "pair-123", "action": "stop"},
        )

        resp = await client.get("/session-interrupt/pair-123")
        data = await resp.json()
        assert data["interrupted"] is True
        assert data["action"] == "stop"

    @pytest.mark.asyncio
    async def test_resume_clears_interrupt_state(
        self,
        cli,
        wired_api: BridgeAPI,
        session: Session,
        mock_send: AsyncMock,
    ) -> None:
        """After resume, interrupt state is cleared."""
        client: TestClient = await cli

        # First stop
        await client.post(
            "/session-interrupt",
            json={"pairingId": "pair-123", "action": "stop"},
        )

        # Then resume
        resp = await client.post(
            "/session-interrupt",
            json={"pairingId": "pair-123", "action": "resume"},
        )
        assert resp.status == 200

        # Verify cleared
        resp = await client.get("/session-interrupt/pair-123")
        data = await resp.json()
        assert data["interrupted"] is False
        assert data["action"] is None


# ---------------------------------------------------------------------------
# TEST A7.8: GET /health returns {"status": "ok"}
# ---------------------------------------------------------------------------

class TestHealth:
    """GET /health."""

    @pytest.mark.asyncio
    async def test_health(self, cli) -> None:
        """A7.8 — Health endpoint returns expected payload."""
        client: TestClient = await cli

        resp = await client.get("/health")
        assert resp.status == 200
        data = await resp.json()
        assert data == {"status": "ok"}


# ---------------------------------------------------------------------------
# TEST A7.9: GET /approval-queue with unknown pairing_id returns 404
# ---------------------------------------------------------------------------

class TestUnknownPairingId:
    """Requests with an unknown pairing_id should return 404."""

    @pytest.mark.asyncio
    async def test_approval_queue_404(self, cli) -> None:
        """A7.9 — Unknown pairing_id in approval queue returns 404."""
        client: TestClient = await cli

        resp = await client.get("/approval-queue/unknown-pair")
        assert resp.status == 404
        data = await resp.json()
        assert "error" in data

    @pytest.mark.asyncio
    async def test_progress_404(self, cli) -> None:
        """Unknown pairing_id in session-progress returns 404."""
        client: TestClient = await cli

        resp = await client.get("/session-progress/unknown-pair")
        assert resp.status == 404

    @pytest.mark.asyncio
    async def test_questions_404(self, cli) -> None:
        """Unknown pairing_id in questions returns 404."""
        client: TestClient = await cli

        resp = await client.get("/questions/unknown-pair")
        assert resp.status == 404

    @pytest.mark.asyncio
    async def test_interrupt_get_404(self, cli) -> None:
        """Unknown pairing_id in GET session-interrupt returns 404."""
        client: TestClient = await cli

        resp = await client.get("/session-interrupt/unknown-pair")
        assert resp.status == 404

    @pytest.mark.asyncio
    async def test_approval_post_unknown_pairing(self, cli) -> None:
        """POST /approval with unknown pairingId returns 404."""
        client: TestClient = await cli

        resp = await client.post(
            "/approval/r1",
            json={"pairingId": "unknown-pair", "approved": True},
        )
        assert resp.status == 404

    @pytest.mark.asyncio
    async def test_approval_post_unknown_request_id(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """POST /approval with unknown request_id returns 404."""
        client: TestClient = await cli

        resp = await client.post(
            "/approval/nonexistent",
            json={"pairingId": "pair-123", "approved": True},
        )
        assert resp.status == 404


# ---------------------------------------------------------------------------
# TEST A7.10: Tool name to type mapping
# ---------------------------------------------------------------------------

class TestToolNameToType:
    """Verify the _tool_name_to_type mapping function."""

    @pytest.mark.parametrize(
        "tool_name,expected_type",
        [
            ("Bash", "bash"),
            ("Edit", "file_edit"),
            ("MultiEdit", "file_edit"),
            ("NotebookEdit", "file_edit"),
            ("Write", "file_create"),
            ("AskUserQuestion", "question"),
        ],
    )
    def test_known_mappings(self, tool_name: str, expected_type: str) -> None:
        """A7.10 — Known tool names map to the correct types."""
        assert _tool_name_to_type(tool_name) == expected_type

    def test_unknown_tool_lowered(self) -> None:
        """Unknown tools fall back to lowercased tool name."""
        assert _tool_name_to_type("SomeCustomTool") == "somecustomtool"


# ---------------------------------------------------------------------------
# Additional tests: GET /state, registration, edge cases
# ---------------------------------------------------------------------------

class TestGetState:
    """GET /state — debug snapshot."""

    @pytest.mark.asyncio
    async def test_state_snapshot(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """GET /state returns a snapshot of pairings, sessions, and interrupts."""
        client: TestClient = await cli

        resp = await client.get("/state")
        assert resp.status == 200
        data = await resp.json()

        assert "pairingMap" in data
        assert data["pairingMap"]["pair-123"] == "sess-1"
        assert "sessions" in data
        assert "sess-1" in data["sessions"]
        assert "interruptState" in data


class TestRegistration:
    """BridgeAPI session registration."""

    def test_register_and_lookup(self) -> None:
        api = BridgeAPI()
        session = _make_session("sess-1")
        api.register_session("pair-123", "sess-1", session)

        assert api.get_session_by_pairing("pair-123") is session

    def test_lookup_unknown_returns_none(self) -> None:
        api = BridgeAPI()
        assert api.get_session_by_pairing("unknown") is None


class TestWritePermissionFormat:
    """Verify Write tool format in approval queue."""

    @pytest.mark.asyncio
    async def test_write_format(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """Write tool should appear as type 'file_create'."""
        client: TestClient = await cli

        _add_perm(
            session,
            "r1",
            "Write",
            {"file_path": "/src/new_module.py", "content": "# new file"},
        )

        resp = await client.get("/approval-queue/pair-123")
        data = await resp.json()

        assert data["totalCount"] == 1
        r = data["requests"][0]
        assert r["type"] == "file_create"
        assert r["title"] == "new_module.py"
        assert r["description"] == "Create /src/new_module.py"
        assert r["filePath"] == "/src/new_module.py"
        assert r["command"] is None


class TestBashTitleTruncation:
    """Verify long Bash commands are truncated in title."""

    @pytest.mark.asyncio
    async def test_long_command_truncated(
        self, cli, wired_api: BridgeAPI, session: Session
    ) -> None:
        """Bash title is truncated to 50 characters."""
        client: TestClient = await cli

        long_cmd = "a" * 100
        _add_perm(session, "r1", "Bash", {"command": long_cmd})

        resp = await client.get("/approval-queue/pair-123")
        data = await resp.json()

        r = data["requests"][0]
        assert len(r["title"]) == 50
        # Description retains full command
        assert r["description"] == long_cmd
        assert len(r["description"]) == 100
