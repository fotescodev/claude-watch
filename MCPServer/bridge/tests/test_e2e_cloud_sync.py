"""
E2E integration tests for cloud sync (Workstream B2).

Tests the full flow:
  Bridge receives permission → pushes to mock cloud → watch approves on cloud
  → bridge polls cloud → bridge resolves permission → CLI gets control_response

Uses:
  - Real Bridge (NDJSON WS + HTTP API)
  - MockCLI (WebSocket client pretending to be Claude)
  - MockCloudServer (simulates cloud worker endpoints)
  - CloudClient in bridge (auto-push + poll)
"""
from __future__ import annotations

import asyncio
import json
import uuid

import pytest
import pytest_asyncio
import aiohttp
from aiohttp import web
from websockets.asyncio.client import connect as ws_connect

from MCPServer.bridge.main import Bridge
from MCPServer.bridge.tests.conftest import MockCLI, _next_port


# ---------------------------------------------------------------------------
# Mock Cloud Worker
# ---------------------------------------------------------------------------


class MockCloudServer:
    """Simulates cloud worker endpoints for E2E testing.

    Stores approvals, questions, progress, and interrupt state in memory.
    The bridge pushes to it, and the test can set responses that the
    bridge's poll loop will discover.
    """

    def __init__(self) -> None:
        self.approval_queue: dict[str, dict] = {}  # id -> request
        self.question_queue: dict[str, dict] = {}  # id -> question
        self.progress: dict[str, dict] = {}  # pairingId -> progress
        self.interrupt_state: dict[str, dict] = {}  # pairingId -> state
        self.session_active: dict[str, bool] = {}  # pairingId -> active
        self.port: int = 0

    def create_app(self) -> web.Application:
        app = web.Application()
        # Push endpoints (bridge → cloud)
        app.router.add_post("/approval", self._handle_push_approval)
        app.router.add_post("/question", self._handle_push_question)
        app.router.add_post("/session-progress", self._handle_push_progress)
        # Poll endpoints (bridge polls cloud)
        app.router.add_get(
            "/approval/{pairing_id}/{request_id}",
            self._handle_poll_approval,
        )
        app.router.add_get(
            "/question/{pairing_id}/{question_id}",
            self._handle_poll_question,
        )
        app.router.add_get(
            "/session-interrupt/{pairing_id}",
            self._handle_poll_interrupt,
        )
        app.router.add_get(
            "/session-status/{pairing_id}",
            self._handle_poll_session,
        )
        return app

    # --- Push handlers ---

    async def _handle_push_approval(self, request: web.Request) -> web.Response:
        body = await request.json()
        self.approval_queue[body["id"]] = {
            **body,
            "status": "pending",
        }
        return web.json_response({"success": True})

    async def _handle_push_question(self, request: web.Request) -> web.Response:
        body = await request.json()
        self.question_queue[body["questionId"]] = {
            **body,
            "status": "pending",
        }
        return web.json_response({"success": True, "questionId": body["questionId"]})

    async def _handle_push_progress(self, request: web.Request) -> web.Response:
        body = await request.json()
        self.progress[body["pairingId"]] = body
        return web.json_response({"success": True})

    # --- Poll handlers ---

    async def _handle_poll_approval(self, request: web.Request) -> web.Response:
        request_id = request.match_info["request_id"]
        entry = self.approval_queue.get(request_id)
        if not entry:
            return web.json_response(
                {"error": "not found", "status": "not_found"}, status=404
            )
        return web.json_response(
            {
                "id": entry["id"],
                "status": entry["status"],
                "type": entry.get("type", ""),
                "title": entry.get("title", ""),
            }
        )

    async def _handle_poll_question(self, request: web.Request) -> web.Response:
        question_id = request.match_info["question_id"]
        entry = self.question_queue.get(question_id)
        if not entry:
            return web.json_response(
                {"error": "not found", "status": "not_found"}, status=404
            )
        return web.json_response(
            {
                "questionId": entry["questionId"],
                "status": entry["status"],
                "question": entry.get("question", ""),
                "answer": entry.get("answer"),
            }
        )

    async def _handle_poll_interrupt(self, request: web.Request) -> web.Response:
        pairing_id = request.match_info["pairing_id"]
        state = self.interrupt_state.get(
            pairing_id, {"interrupted": False, "action": None}
        )
        return web.json_response(state)

    async def _handle_poll_session(self, request: web.Request) -> web.Response:
        pairing_id = request.match_info["pairing_id"]
        active = self.session_active.get(pairing_id, True)
        return web.json_response({"sessionActive": active})

    # --- Test helpers ---

    def approve(self, request_id: str) -> None:
        """Simulate watch approving a request on the cloud."""
        if request_id in self.approval_queue:
            self.approval_queue[request_id]["status"] = "approved"

    def reject(self, request_id: str) -> None:
        """Simulate watch rejecting a request on the cloud."""
        if request_id in self.approval_queue:
            self.approval_queue[request_id]["status"] = "rejected"

    def answer_question(self, question_id: str, answer: str) -> None:
        """Simulate watch answering a question on the cloud."""
        if question_id in self.question_queue:
            self.question_queue[question_id]["status"] = "answered"
            self.question_queue[question_id]["answer"] = answer

    def set_interrupt(self, pairing_id: str, action: str = "stop") -> None:
        """Simulate watch sending interrupt."""
        self.interrupt_state[pairing_id] = {
            "interrupted": True,
            "action": action,
        }

    def end_session(self, pairing_id: str) -> None:
        """Simulate watch ending session."""
        self.session_active[pairing_id] = False


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def mock_cloud():
    """Start a mock cloud worker."""
    cloud = MockCloudServer()
    app = cloud.create_app()
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "localhost", 0, reuse_address=True)
    await site.start()
    cloud.port = site._server.sockets[0].getsockname()[1]
    yield cloud
    await runner.cleanup()


@pytest_asyncio.fixture
async def cloud_bridge(mock_cloud):
    """Start a Bridge with cloud sync enabled, pointed at mock cloud."""
    port = _next_port()
    pairing_id = f"cloud-pair-{uuid.uuid4().hex[:8]}"
    cloud_url = f"http://localhost:{mock_cloud.port}"
    bridge = Bridge(port=port, pairing_id=pairing_id, cloud_url=cloud_url)
    # Use fast poll interval for tests
    await bridge.start()
    if bridge._cloud_client:
        bridge._cloud_client.poll_interval = 0.1
        bridge._cloud_client._retry_delay = 0.01
    yield bridge
    await bridge.stop()


@pytest_asyncio.fixture
async def cloud_cli(cloud_bridge):
    """Connect a mock CLI to the cloud-synced bridge."""
    session_id = f"cli-{uuid.uuid4().hex[:8]}"
    url = f"ws://localhost:{cloud_bridge.port}/ws/cli/{session_id}"
    cli = MockCLI(url, session_id)
    await cli.connect()
    await asyncio.sleep(0.05)
    yield cli
    await cli.disconnect()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestCloudApprovalSync:
    """Bridge pushes approval to cloud, cloud responds, bridge resolves."""

    @pytest.mark.asyncio
    async def test_approval_pushed_to_cloud(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """When CLI sends a can_use_tool, bridge pushes it to cloud."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        req_id = f"req-{uuid.uuid4().hex[:8]}"
        await cloud_cli.send_control_request(
            req_id, tool_name="Bash", tool_input={"command": "ls -la"}
        )
        # Wait for push
        await asyncio.sleep(0.3)

        assert req_id in mock_cloud.approval_queue
        entry = mock_cloud.approval_queue[req_id]
        assert entry["pairingId"] == cloud_bridge.pairing_id
        assert entry["status"] == "pending"

    @pytest.mark.asyncio
    async def test_cloud_approve_resolves_permission(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """Watch approves on cloud → bridge polls → CLI gets allow response."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        req_id = f"req-{uuid.uuid4().hex[:8]}"
        await cloud_cli.send_control_request(
            req_id, tool_name="Bash", tool_input={"command": "echo test"}
        )
        await asyncio.sleep(0.3)

        # Watch approves on cloud
        mock_cloud.approve(req_id)

        # Wait for bridge poll to discover and resolve
        response = await cloud_cli.recv(timeout=3.0)
        # First message may be the initialize control_request; skip it
        while response and response.get("request", {}).get("subtype") == "initialize":
            response = await cloud_cli.recv(timeout=3.0)

        assert response is not None
        assert response["type"] == "control_response"
        resp_data = response["response"]["response"]
        assert resp_data["behavior"] == "allow"

    @pytest.mark.asyncio
    async def test_cloud_reject_resolves_permission(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """Watch rejects on cloud → bridge polls → CLI gets deny response."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        req_id = f"req-{uuid.uuid4().hex[:8]}"
        await cloud_cli.send_control_request(
            req_id, tool_name="Bash", tool_input={"command": "rm -rf /"}
        )
        await asyncio.sleep(0.3)

        # Watch rejects on cloud
        mock_cloud.reject(req_id)

        # Wait for bridge poll
        response = await cloud_cli.recv(timeout=3.0)
        while response and response.get("request", {}).get("subtype") == "initialize":
            response = await cloud_cli.recv(timeout=3.0)

        assert response is not None
        assert response["type"] == "control_response"
        resp_data = response["response"]["response"]
        assert resp_data["behavior"] == "deny"


class TestCloudQuestionSync:
    """Bridge pushes question to cloud, cloud responds, bridge resolves."""

    @pytest.mark.asyncio
    async def test_question_pushed_to_cloud(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """AskUserQuestion is pushed to cloud with options."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        req_id = f"q-{uuid.uuid4().hex[:8]}"
        await cloud_cli.send_control_request(
            req_id,
            tool_name="AskUserQuestion",
            tool_input={
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
        await asyncio.sleep(0.3)

        assert req_id in mock_cloud.question_queue
        entry = mock_cloud.question_queue[req_id]
        assert entry["question"] == "Which database?"
        assert entry["header"] == "DB"
        assert len(entry["options"]) == 2

    @pytest.mark.asyncio
    async def test_cloud_answer_resolves_question(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """Watch answers question on cloud → bridge polls → CLI gets response."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        req_id = f"q-{uuid.uuid4().hex[:8]}"
        await cloud_cli.send_control_request(
            req_id,
            tool_name="AskUserQuestion",
            tool_input={
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which database?",
                        "options": [
                            {"label": "PostgreSQL (Recommended)", "description": "Popular"},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )
        await asyncio.sleep(0.3)

        # Watch answers on cloud
        mock_cloud.answer_question(req_id, "PostgreSQL")

        # Wait for bridge poll
        response = await cloud_cli.recv(timeout=3.0)
        while response and response.get("request", {}).get("subtype") == "initialize":
            response = await cloud_cli.recv(timeout=3.0)

        assert response is not None
        assert response["type"] == "control_response"
        resp_data = response["response"]["response"]
        assert resp_data["behavior"] == "allow"
        assert "updatedInput" in resp_data


class TestCloudProgressSync:
    """Bridge pushes progress updates to cloud."""

    @pytest.mark.asyncio
    async def test_progress_pushed_on_todowrite(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """TodoWrite in assistant message triggers cloud progress push."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        # Send assistant message containing a TodoWrite tool_use
        await cloud_cli.send({
            "type": "assistant",
            "message": {
                "content": [
                    {
                        "type": "tool_use",
                        "name": "TodoWrite",
                        "input": {
                            "todos": [
                                {
                                    "content": "Fix bug",
                                    "status": "completed",
                                    "activeForm": "Fixing bug",
                                },
                                {
                                    "content": "Write tests",
                                    "status": "in_progress",
                                    "activeForm": "Writing tests",
                                },
                            ]
                        },
                    }
                ]
            },
            "uuid": str(uuid.uuid4()),
        })
        # Wait for push
        await asyncio.sleep(0.5)

        assert cloud_bridge.pairing_id in mock_cloud.progress
        progress = mock_cloud.progress[cloud_bridge.pairing_id]
        assert progress["completedCount"] == 1
        assert progress["totalCount"] == 2


class TestCloudInterruptSync:
    """Bridge detects interrupt from cloud."""

    @pytest.mark.asyncio
    async def test_cloud_interrupt_sends_to_cli(
        self, cloud_bridge, cloud_cli, mock_cloud
    ):
        """Watch sends interrupt via cloud → bridge poll → CLI gets interrupt."""
        await cloud_cli.send_init()
        await asyncio.sleep(0.1)

        # Watch sends interrupt on cloud
        mock_cloud.set_interrupt(cloud_bridge.pairing_id, "stop")

        # Wait for bridge poll to discover
        # The bridge should send an interrupt control_request to CLI
        found_interrupt = False
        deadline = asyncio.get_event_loop().time() + 3.0
        while asyncio.get_event_loop().time() < deadline:
            msgs = await cloud_cli.recv_all(timeout=0.2)
            for msg in msgs:
                if (
                    msg.get("type") == "control_request"
                    and msg.get("request", {}).get("subtype") == "interrupt"
                ):
                    found_interrupt = True
                    break
            if found_interrupt:
                break

        assert found_interrupt, "Bridge should send interrupt to CLI after cloud poll"
