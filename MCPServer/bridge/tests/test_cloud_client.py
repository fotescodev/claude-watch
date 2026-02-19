"""
Comprehensive unit tests for CloudClient.

Uses a MockCloudApp (aiohttp.web) to simulate the cloud worker endpoints
so we can verify push payloads, poll responses, retry logic, and disabled
state without hitting a real server.
"""
from __future__ import annotations

import asyncio
import json
from typing import Any
from unittest.mock import patch, AsyncMock

import pytest
import pytest_asyncio
from aiohttp import web

from MCPServer.bridge.cloud_client import CloudClient


# ---------------------------------------------------------------------------
# Mock Cloud Worker
# ---------------------------------------------------------------------------


class MockCloudApp:
    """Simulates the remmy.watch cloud worker HTTP endpoints.

    Stores incoming payloads for assertion and lets tests configure
    responses per-endpoint.
    """

    def __init__(self) -> None:
        self.app = web.Application()
        self.url: str = ""  # Set after server start

        # Stores received payloads keyed by endpoint path.
        self.received_approvals: list[dict] = []
        self.received_questions: list[dict] = []
        self.received_progress: list[dict] = []
        self.received_session_end: list[dict] = []

        # Configurable responses for poll endpoints.
        self.approval_responses: dict[str, dict] = {}
        self.question_responses: dict[str, dict] = {}
        self.interrupt_response: dict = {"interrupted": False, "action": None}
        self.session_active_response: dict = {"sessionActive": True}

        # Error simulation.
        self.force_error: bool = False
        self.error_status: int = 500

        self._setup_routes()

    def _setup_routes(self) -> None:
        self.app.router.add_post("/approval", self._post_approval)
        self.app.router.add_post("/question", self._post_question)
        self.app.router.add_post("/session-progress", self._post_progress)
        self.app.router.add_post("/session-end", self._post_session_end)
        self.app.router.add_get(
            "/approval/{pairing_id}/{request_id}", self._get_approval
        )
        self.app.router.add_get(
            "/question/{pairing_id}/{question_id}", self._get_question
        )
        self.app.router.add_get(
            "/session-interrupt/{pairing_id}", self._get_interrupt
        )
        self.app.router.add_get(
            "/session-status/{pairing_id}", self._get_session_status
        )

    # -- POST handlers (push) -----------------------------------------------

    async def _post_approval(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        payload = await request.json()
        self.received_approvals.append(payload)
        return web.json_response({"ok": True})

    async def _post_question(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        payload = await request.json()
        self.received_questions.append(payload)
        return web.json_response({"ok": True})

    async def _post_progress(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        payload = await request.json()
        self.received_progress.append(payload)
        return web.json_response({"ok": True})

    async def _post_session_end(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        payload = await request.json()
        self.received_session_end.append(payload)
        return web.json_response({"ok": True})

    # -- GET handlers (poll) -------------------------------------------------

    async def _get_approval(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        request_id = request.match_info["request_id"]
        data = self.approval_responses.get(request_id, {"status": "pending"})
        return web.json_response(data)

    async def _get_question(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        question_id = request.match_info["question_id"]
        if question_id not in self.question_responses:
            return web.Response(status=404)
        return web.json_response(self.question_responses[question_id])

    async def _get_interrupt(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        return web.json_response(self.interrupt_response)

    async def _get_session_status(self, request: web.Request) -> web.Response:
        if self.force_error:
            return web.Response(status=self.error_status)
        return web.json_response(self.session_active_response)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def mock_cloud():
    """Start a mock cloud server on a random port."""
    cloud = MockCloudApp()
    runner = web.AppRunner(cloud.app)
    await runner.setup()
    site = web.TCPSite(runner, "localhost", 0)  # random port
    await site.start()
    port = site._server.sockets[0].getsockname()[1]
    cloud.url = f"http://localhost:{port}"
    yield cloud
    await runner.cleanup()


@pytest_asyncio.fixture
async def client(mock_cloud):
    """CloudClient pointed at mock cloud with fast retries."""
    c = CloudClient(
        mock_cloud.url,
        "test-pair-123",
        retry_attempts=1,
        retry_delay=0.01,
    )
    await c.start()
    yield c
    await c.stop()


# ===========================================================================
# 1. TestPushApproval
# ===========================================================================


class TestPushApproval:
    """Tests for CloudClient.push_approval()."""

    @pytest.mark.asyncio
    async def test_push_approval_success(self, client, mock_cloud):
        """push_approval returns True on 2xx and stores the request."""
        result = await client.push_approval(
            "req-001", "Bash", {"command": "ls -la"}
        )
        assert result is True
        assert len(mock_cloud.received_approvals) == 1

    @pytest.mark.asyncio
    async def test_push_approval_payload_format(self, client, mock_cloud):
        """Payload includes pairingId and fields from _permission_to_watch_request."""
        await client.push_approval(
            "req-002", "Bash", {"command": "echo hello"}
        )
        payload = mock_cloud.received_approvals[0]

        assert payload["pairingId"] == "test-pair-123"
        assert payload["id"] == "req-002"
        assert payload["type"] == "bash"
        assert "echo hello" in payload["description"]
        assert payload["command"] == "echo hello"

    @pytest.mark.asyncio
    async def test_push_approval_write_tool(self, client, mock_cloud):
        """Write tool produces correct type and filePath."""
        await client.push_approval(
            "req-003", "Write", {"file_path": "/tmp/foo.txt", "content": "bar"}
        )
        payload = mock_cloud.received_approvals[0]

        assert payload["pairingId"] == "test-pair-123"
        assert payload["id"] == "req-003"
        assert payload["type"] == "file_create"
        assert payload["filePath"] == "/tmp/foo.txt"
        assert payload["title"] == "foo.txt"

    @pytest.mark.asyncio
    async def test_push_approval_cloud_error(self, client, mock_cloud):
        """push_approval returns False when cloud returns 500."""
        mock_cloud.force_error = True
        mock_cloud.error_status = 500

        result = await client.push_approval(
            "req-004", "Bash", {"command": "rm -rf /"}
        )
        assert result is False
        assert len(mock_cloud.received_approvals) == 0


# ===========================================================================
# 2. TestPushQuestion
# ===========================================================================


class TestPushQuestion:
    """Tests for CloudClient.push_question()."""

    @pytest.mark.asyncio
    async def test_push_question_success(self, client, mock_cloud):
        """push_question returns True on 2xx."""
        input_data = {
            "questions": [{"question": "Continue?", "header": "", "options": []}],
        }
        result = await client.push_question("q-001", input_data)
        assert result is True
        assert len(mock_cloud.received_questions) == 1

    @pytest.mark.asyncio
    async def test_push_question_payload_with_options(self, client, mock_cloud):
        """Payload includes questionId, question text, options, and recommendation."""
        input_data = {
            "questions": [
                {
                    "question": "Which approach?",
                    "header": "Design Decision",
                    "options": [
                        {"label": "Option A", "description": "First approach"},
                        {"label": "Option B (Recommended)", "description": "Second approach"},
                    ],
                    "multiSelect": False,
                }
            ],
        }
        await client.push_question("q-002", input_data)
        payload = mock_cloud.received_questions[0]

        assert payload["pairingId"] == "test-pair-123"
        assert payload["questionId"] == "q-002"
        assert payload["question"] == "Which approach?"
        assert payload["header"] == "Design Decision"
        assert len(payload["options"]) == 2
        assert payload["options"][0]["label"] == "Option A"
        assert payload["options"][1]["label"] == "Option B (Recommended)"
        assert payload["multiSelect"] is False
        # extract_recommendation should strip "(Recommended)" suffix
        assert payload["recommendedAnswer"] == "Option B"

    @pytest.mark.asyncio
    async def test_push_question_empty_questions(self, client, mock_cloud):
        """Gracefully handles empty questions list."""
        input_data = {"questions": []}
        result = await client.push_question("q-003", input_data)
        assert result is True

        payload = mock_cloud.received_questions[0]
        assert payload["questionId"] == "q-003"
        assert payload["question"] == ""
        assert payload["header"] == ""
        assert payload["options"] == []

    @pytest.mark.asyncio
    async def test_push_question_cloud_error(self, client, mock_cloud):
        """push_question returns False when cloud returns an error."""
        mock_cloud.force_error = True
        mock_cloud.error_status = 502

        input_data = {
            "questions": [{"question": "OK?", "header": "", "options": []}],
        }
        result = await client.push_question("q-004", input_data)
        assert result is False


# ===========================================================================
# 3. TestPushProgress
# ===========================================================================


class TestPushProgress:
    """Tests for CloudClient.push_progress()."""

    @pytest.mark.asyncio
    async def test_push_progress_success(self, client, mock_cloud):
        """push_progress returns True on success."""
        progress = {
            "currentTask": "Implementing feature X",
            "currentActivity": "Writing tests",
            "progress": 0.6,
        }
        result = await client.push_progress(progress)
        assert result is True
        assert len(mock_cloud.received_progress) == 1

    @pytest.mark.asyncio
    async def test_push_progress_includes_pairing_id(self, client, mock_cloud):
        """Payload merges pairingId into the progress dict."""
        progress = {
            "currentTask": "Refactoring",
            "currentActivity": "Moving files",
            "progress": 0.3,
            "totalCostUsd": 0.42,
        }
        await client.push_progress(progress)
        payload = mock_cloud.received_progress[0]

        assert payload["pairingId"] == "test-pair-123"
        assert payload["currentTask"] == "Refactoring"
        assert payload["currentActivity"] == "Moving files"
        assert payload["progress"] == 0.3
        assert payload["totalCostUsd"] == 0.42

    @pytest.mark.asyncio
    async def test_push_progress_cloud_error(self, client, mock_cloud):
        """push_progress returns False when cloud returns an error."""
        mock_cloud.force_error = True
        result = await client.push_progress({"currentTask": "Testing"})
        assert result is False


# ===========================================================================
# 4. TestPushSessionEnd
# ===========================================================================


class TestPushSessionEnd:
    """Tests for CloudClient.push_session_end()."""

    @pytest.mark.asyncio
    async def test_push_session_end_success(self, client, mock_cloud):
        """push_session_end returns True and cloud receives the call."""
        result = await client.push_session_end()
        assert result is True
        assert len(mock_cloud.received_session_end) == 1

    @pytest.mark.asyncio
    async def test_push_session_end_includes_pairing_id(self, client, mock_cloud):
        """Payload contains pairingId."""
        await client.push_session_end()
        payload = mock_cloud.received_session_end[0]
        assert payload["pairingId"] == "test-pair-123"

    @pytest.mark.asyncio
    async def test_push_session_end_cloud_error_returns_false(self, client, mock_cloud):
        """push_session_end returns False when cloud returns an error."""
        mock_cloud.force_error = True
        result = await client.push_session_end()
        assert result is False


# ===========================================================================
# 5. TestPollApprovalStatus
# ===========================================================================


class TestPollApprovalStatus:
    """Tests for CloudClient.poll_approval_status()."""

    @pytest.mark.asyncio
    async def test_pending_returns_none(self, client, mock_cloud):
        """A pending approval returns None (no decision yet)."""
        mock_cloud.approval_responses["req-100"] = {"status": "pending"}
        result = await client.poll_approval_status("req-100")
        assert result is None

    @pytest.mark.asyncio
    async def test_approved_returns_approved(self, client, mock_cloud):
        """An approved request returns the string 'approved'."""
        mock_cloud.approval_responses["req-101"] = {"status": "approved"}
        result = await client.poll_approval_status("req-101")
        assert result == "approved"

    @pytest.mark.asyncio
    async def test_rejected_returns_rejected(self, client, mock_cloud):
        """A rejected request returns the string 'rejected'."""
        mock_cloud.approval_responses["req-102"] = {"status": "rejected"}
        result = await client.poll_approval_status("req-102")
        assert result == "rejected"


# ===========================================================================
# 5. TestPollQuestionStatus
# ===========================================================================


class TestPollQuestionStatus:
    """Tests for CloudClient.poll_question_status()."""

    @pytest.mark.asyncio
    async def test_pending_returns_none(self, client, mock_cloud):
        """A pending question returns None."""
        mock_cloud.question_responses["q-100"] = {"status": "pending"}
        result = await client.poll_question_status("q-100")
        assert result is None

    @pytest.mark.asyncio
    async def test_answered_returns_dict(self, client, mock_cloud):
        """An answered question returns the full response dict."""
        answer_data = {
            "status": "answered",
            "answer": "Option B",
            "answeredAt": "2026-02-13T10:00:00Z",
        }
        mock_cloud.question_responses["q-101"] = answer_data
        result = await client.poll_question_status("q-101")

        assert result is not None
        assert result["status"] == "answered"
        assert result["answer"] == "Option B"

    @pytest.mark.asyncio
    async def test_not_found_returns_none(self, client, mock_cloud):
        """A question ID that does not exist returns None (404)."""
        # Do NOT add "q-999" to question_responses -- handler returns 404.
        result = await client.poll_question_status("q-999")
        assert result is None


# ===========================================================================
# 6. TestPollInterruptState
# ===========================================================================


class TestPollInterruptState:
    """Tests for CloudClient.poll_interrupt_state()."""

    @pytest.mark.asyncio
    async def test_not_interrupted(self, client, mock_cloud):
        """Default state: not interrupted."""
        mock_cloud.interrupt_response = {"interrupted": False, "action": None}
        result = await client.poll_interrupt_state()
        assert result["interrupted"] is False
        assert result["action"] is None

    @pytest.mark.asyncio
    async def test_interrupted_with_stop_action(self, client, mock_cloud):
        """Watch triggered a stop interrupt."""
        mock_cloud.interrupt_response = {
            "interrupted": True,
            "action": "stop",
        }
        result = await client.poll_interrupt_state()
        assert result["interrupted"] is True
        assert result["action"] == "stop"


# ===========================================================================
# 7. TestPollSessionActive
# ===========================================================================


class TestPollSessionActive:
    """Tests for CloudClient.poll_session_active()."""

    @pytest.mark.asyncio
    async def test_session_active(self, client, mock_cloud):
        """Returns True when the watch session is active."""
        mock_cloud.session_active_response = {"sessionActive": True}
        result = await client.poll_session_active()
        assert result is True

    @pytest.mark.asyncio
    async def test_session_ended(self, client, mock_cloud):
        """Returns False when the watch has ended the session."""
        mock_cloud.session_active_response = {"sessionActive": False}
        result = await client.poll_session_active()
        assert result is False


# ===========================================================================
# 8. TestDisabledClient
# ===========================================================================


class TestDisabledClient:
    """Tests for CloudClient.disable() -- all operations short-circuit."""

    @pytest.mark.asyncio
    async def test_push_returns_false_when_disabled(self, client, mock_cloud):
        """All push methods return False without hitting the server."""
        client.disable()
        assert client.is_enabled is False

        assert await client.push_approval("x", "Bash", {"command": "ls"}) is False
        assert await client.push_question("x", {"questions": []}) is False
        assert await client.push_progress({"currentTask": "nope"}) is False

        # Nothing should have reached the server.
        assert len(mock_cloud.received_approvals) == 0
        assert len(mock_cloud.received_questions) == 0
        assert len(mock_cloud.received_progress) == 0

    @pytest.mark.asyncio
    async def test_poll_returns_defaults_when_disabled(self, client, mock_cloud):
        """Poll methods return None or safe defaults without hitting the server."""
        client.disable()

        assert await client.poll_approval_status("x") is None
        assert await client.poll_question_status("x") is None
        # poll_interrupt_state falls back to non-interrupted
        result = await client.poll_interrupt_state()
        assert result == {"interrupted": False, "action": None}
        # poll_session_active assumes active when cloud unreachable
        assert await client.poll_session_active() is True


# ===========================================================================
# 9. TestRetryLogic
# ===========================================================================


class TestRetryLogic:
    """Tests for retry behavior on transient failures.

    The CloudClient._post and ._get methods only retry on *exceptions*
    (e.g. connection errors), not on HTTP error status codes.  HTTP errors
    (like 500/503) return immediately with False/None.

    We test retry by monkey-patching the session to raise then succeed.
    """

    @pytest.mark.asyncio
    async def test_retries_on_connection_error_then_succeeds(self, client, mock_cloud):
        """Client retries on connection-level exception and succeeds on retry."""
        call_count = 0
        original_post = client._session.post

        class _FakeCtx:
            """Async context manager that fails once then delegates."""
            def __init__(self, *args, **kwargs):
                nonlocal call_count
                call_count += 1
                self._args = args
                self._kwargs = kwargs
                self._delegate = None

            async def __aenter__(self):
                if call_count <= 1:
                    raise ConnectionError("Simulated connection failure")
                self._delegate = original_post(*self._args, **self._kwargs)
                return await self._delegate.__aenter__()

            async def __aexit__(self, *exc):
                if self._delegate:
                    return await self._delegate.__aexit__(*exc)

        client._session.post = lambda *a, **kw: _FakeCtx(*a, **kw)

        result = await client.push_approval("r-1", "Bash", {"command": "ls"})
        assert result is True
        assert call_count == 2  # 1 fail + 1 success
        assert len(mock_cloud.received_approvals) == 1

    @pytest.mark.asyncio
    async def test_gives_up_after_max_attempts(self):
        """Client returns False after exhausting all retry attempts on connection errors."""
        c = CloudClient(
            "http://localhost:1",  # Nothing listening -- will raise connection error
            "retry-pair",
            retry_attempts=2,
            retry_delay=0.01,
        )
        await c.start()
        try:
            result = await c.push_approval("r-2", "Bash", {"command": "ls"})
            assert result is False
        finally:
            await c.stop()


# ===========================================================================
# 10. TestLifecycle
# ===========================================================================


class TestLifecycle:
    """Tests for start/stop lifecycle and is_enabled property."""

    @pytest.mark.asyncio
    async def test_not_enabled_before_start(self):
        """Client is not enabled until start() is called."""
        c = CloudClient("http://localhost:9999", "pair-x")
        assert c.is_enabled is False  # no session yet

    @pytest.mark.asyncio
    async def test_enabled_after_start(self, client):
        """Client is enabled after start()."""
        assert client.is_enabled is True

    @pytest.mark.asyncio
    async def test_not_enabled_after_stop(self, mock_cloud):
        """Client is not enabled after stop()."""
        c = CloudClient(mock_cloud.url, "pair-y")
        await c.start()
        assert c.is_enabled is True
        await c.stop()
        assert c.is_enabled is False

    @pytest.mark.asyncio
    async def test_disable_makes_not_enabled(self, client):
        """disable() sets is_enabled to False even with active session."""
        assert client.is_enabled is True
        client.disable()
        assert client.is_enabled is False


# ===========================================================================
# 11. TestEdgeCases
# ===========================================================================


class TestEdgeCases:
    """Edge case tests for unusual inputs and responses."""

    @pytest.mark.asyncio
    async def test_poll_approval_unknown_status(self, client, mock_cloud):
        """An unknown status string (not approved/rejected) returns None."""
        mock_cloud.approval_responses["req-unk"] = {"status": "in_review"}
        result = await client.poll_approval_status("req-unk")
        assert result is None

    @pytest.mark.asyncio
    async def test_poll_session_active_assumes_true_on_error(self):
        """When cloud is unreachable, poll_session_active assumes True."""
        c = CloudClient("http://localhost:1", "pair-z", retry_attempts=0, retry_delay=0.01)
        await c.start()
        try:
            result = await c.poll_session_active()
            assert result is True
        finally:
            await c.stop()

    @pytest.mark.asyncio
    async def test_poll_interrupt_falls_back_on_error(self):
        """When cloud is unreachable, poll_interrupt_state returns safe default."""
        c = CloudClient("http://localhost:1", "pair-z", retry_attempts=0, retry_delay=0.01)
        await c.start()
        try:
            result = await c.poll_interrupt_state()
            assert result == {"interrupted": False, "action": None}
        finally:
            await c.stop()

    @pytest.mark.asyncio
    async def test_push_approval_edit_tool(self, client, mock_cloud):
        """Edit tool produces type=file_edit with file path."""
        await client.push_approval(
            "req-edit", "Edit", {"file_path": "/src/main.py", "old_text": "a", "new_text": "b"}
        )
        payload = mock_cloud.received_approvals[0]
        assert payload["type"] == "file_edit"
        assert payload["filePath"] == "/src/main.py"
        assert payload["title"] == "main.py"

    @pytest.mark.asyncio
    async def test_push_approval_generic_tool(self, client, mock_cloud):
        """Unknown tool name produces a generic fallback (lowercased tool name)."""
        await client.push_approval(
            "req-gen", "CustomTool", {"arg1": "val1"}
        )
        payload = mock_cloud.received_approvals[0]
        assert payload["id"] == "req-gen"
        assert payload["title"] == "CustomTool"
        assert payload["type"] == "customtool"

    @pytest.mark.asyncio
    async def test_cloud_url_trailing_slash_stripped(self, mock_cloud):
        """Trailing slash in cloud_url does not cause double-slash in paths."""
        c = CloudClient(mock_cloud.url + "/", "test-pair-123", retry_attempts=0)
        await c.start()
        try:
            result = await c.push_progress({"currentTask": "test"})
            assert result is True
            assert len(mock_cloud.received_progress) == 1
        finally:
            await c.stop()

    @pytest.mark.asyncio
    async def test_push_approval_multi_edit_tool(self, client, mock_cloud):
        """MultiEdit tool also maps to file_edit type."""
        await client.push_approval(
            "req-me", "MultiEdit", {"file_path": "/src/app.py"}
        )
        payload = mock_cloud.received_approvals[0]
        assert payload["type"] == "file_edit"
        assert payload["filePath"] == "/src/app.py"

    @pytest.mark.asyncio
    async def test_push_question_no_recommendation(self, client, mock_cloud):
        """When no option has (Recommended), first option label is used."""
        input_data = {
            "questions": [
                {
                    "question": "Pick one",
                    "header": "",
                    "options": [
                        {"label": "Alpha", "description": ""},
                        {"label": "Beta", "description": ""},
                    ],
                    "multiSelect": False,
                }
            ],
        }
        await client.push_question("q-norec", input_data)
        payload = mock_cloud.received_questions[0]
        # Falls back to first option label
        assert payload["recommendedAnswer"] == "Alpha"

    @pytest.mark.asyncio
    async def test_poll_get_returns_none_on_http_error(self, client, mock_cloud):
        """GET returning non-2xx (e.g. 500) results in None from _get."""
        mock_cloud.force_error = True
        mock_cloud.error_status = 500
        result = await client.poll_approval_status("any-id")
        assert result is None

    @pytest.mark.asyncio
    async def test_post_returns_false_on_http_error_without_retry(self, client, mock_cloud):
        """POST returning non-2xx returns False immediately (no retry for HTTP errors)."""
        mock_cloud.force_error = True
        mock_cloud.error_status = 400

        result = await client.push_approval("x", "Bash", {"command": "ls"})
        assert result is False
        # Only 1 attempt (no retry on HTTP error status)
        assert len(mock_cloud.received_approvals) == 0
