"""
End-to-End Approval Flow integration tests (Workstream D, Task D1).

These tests exercise the full round-trip:

    mock CLI  --ws-->  Bridge  --http-->  Watch API  --http-->  Bridge  --ws-->  mock CLI

Using real servers (no mocks) on ephemeral ports to verify that the
WebSocket NDJSON server and the HTTP REST API cooperate correctly for
the tool-approval lifecycle.

Tests:
  D1.1  Happy path approval    (Bash: send → queue → approve → allow response)
  D1.2  Rejection path         (Bash: send → queue → reject  → deny response)
  D1.3  Multiple concurrent    (3 tools → queue all 3 → approve one-by-one)
  D1.4  CLI disconnect         (pending request vanishes when CLI drops)
  D1.5  Latency check          (POST approval → control_response < 200 ms)
"""
from __future__ import annotations

import asyncio
import time

import pytest

from MCPServer.bridge.tests.conftest import E2EBridge, MockCLI


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _init_session(mock_cli: MockCLI) -> None:
    """Send system/init and drain the bridge's automatic ``initialize``
    control_request that arrives in response.
    """
    await mock_cli.send_init()
    # Give bridge time to process init and send initialize back
    await asyncio.sleep(0.15)
    # Drain the initialize control_request the bridge sends
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None, "Expected initialize control_request from bridge"
    assert init_msg["type"] == "control_request"
    assert init_msg["request"]["subtype"] == "initialize"


# ---------------------------------------------------------------------------
# D1.1: Happy path approval
# ---------------------------------------------------------------------------

class TestD1_1_HappyPathApproval:
    """CLI sends a Bash control_request, watch polls queue, approves it,
    and the CLI receives a control_response with behavior='allow'.
    """

    @pytest.mark.asyncio
    async def test_approve_bash_command(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        await _init_session(mock_cli)

        # CLI sends a can_use_tool control_request for Bash
        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "ls -la"},
        )
        await asyncio.sleep(0.1)

        # Watch polls the approval queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert data["totalCount"] == 1
        req = data["requests"][0]
        assert req["id"] == "r1"
        assert req["type"] == "bash"
        assert req["command"] == "ls -la"

        # Watch approves
        resp = await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": True,
            },
        )
        assert resp.status == 200
        result = await resp.json()
        assert result["success"] is True

        # CLI receives the control_response
        msg = await mock_cli.recv(timeout=2.0)
        assert msg is not None, "Expected control_response from bridge"
        assert msg["type"] == "control_response"
        assert msg["response"]["request_id"] == "r1"
        assert msg["response"]["response"]["behavior"] == "allow"
        assert msg["response"]["response"]["updatedInput"] == {
            "command": "ls -la"
        }

    @pytest.mark.asyncio
    async def test_queue_empty_after_approval(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """After approval the request is gone from the queue."""
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "echo hello"},
        )
        await asyncio.sleep(0.1)

        # Approve
        await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": True,
            },
        )
        # Drain the response on the CLI side
        await mock_cli.recv(timeout=1.0)

        # Queue should be empty
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []


# ---------------------------------------------------------------------------
# D1.2: Rejection path
# ---------------------------------------------------------------------------

class TestD1_2_RejectionPath:
    """CLI sends a control_request, watch rejects it, CLI receives
    a control_response with behavior='deny'.
    """

    @pytest.mark.asyncio
    async def test_reject_bash_command(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "rm -rf /"},
        )
        await asyncio.sleep(0.1)

        # Verify it appears in the queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 1

        # Watch rejects
        resp = await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": False,
            },
        )
        assert resp.status == 200
        result = await resp.json()
        assert result["success"] is True

        # CLI receives deny
        msg = await mock_cli.recv(timeout=2.0)
        assert msg is not None, "Expected control_response from bridge"
        assert msg["type"] == "control_response"
        assert msg["response"]["request_id"] == "r1"
        assert msg["response"]["response"]["behavior"] == "deny"
        assert "message" in msg["response"]["response"]

    @pytest.mark.asyncio
    async def test_queue_empty_after_rejection(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """The request disappears from the queue after rejection too."""
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "rm -rf /"},
        )
        await asyncio.sleep(0.1)

        await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": False,
            },
        )
        await mock_cli.recv(timeout=1.0)

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []


# ---------------------------------------------------------------------------
# D1.3: Multiple concurrent requests + batch approve
# ---------------------------------------------------------------------------

class TestD1_3_MultipleConcurrent:
    """Three control_requests with different tools arrive. The queue
    shows all three with correct types. Approving each one-by-one
    delivers all three control_responses.
    """

    @pytest.mark.asyncio
    async def test_three_tools_queued(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        await _init_session(mock_cli)

        # Send three different tool requests
        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "ls -la"},
        )
        await mock_cli.send_control_request(
            request_id="r2",
            tool_name="Edit",
            tool_input={"file_path": "/src/main.py", "old_string": "foo", "new_string": "bar"},
        )
        await mock_cli.send_control_request(
            request_id="r3",
            tool_name="Write",
            tool_input={"file_path": "/src/new_file.py", "content": "# new"},
        )
        await asyncio.sleep(0.15)

        # Poll approval queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert data["totalCount"] == 3
        by_id = {r["id"]: r for r in data["requests"]}

        # Verify types
        assert by_id["r1"]["type"] == "bash"
        assert by_id["r1"]["command"] == "ls -la"

        assert by_id["r2"]["type"] == "file_edit"
        assert by_id["r2"]["filePath"] == "/src/main.py"

        assert by_id["r3"]["type"] == "file_create"
        assert by_id["r3"]["filePath"] == "/src/new_file.py"

    @pytest.mark.asyncio
    async def test_approve_all_one_by_one(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """Approve each of the 3 requests individually and verify all
        control_responses are delivered.
        """
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "ls -la"},
        )
        await mock_cli.send_control_request(
            request_id="r2",
            tool_name="Edit",
            tool_input={"file_path": "/src/main.py", "old_string": "foo", "new_string": "bar"},
        )
        await mock_cli.send_control_request(
            request_id="r3",
            tool_name="Write",
            tool_input={"file_path": "/src/new_file.py", "content": "# new"},
        )
        await asyncio.sleep(0.15)

        # Approve each one
        for rid in ("r1", "r2", "r3"):
            resp = await api_client.post(
                f"/approval/{rid}",
                json={
                    "pairingId": e2e_bridge.pairing_id,
                    "approved": True,
                },
            )
            assert resp.status == 200

        # Collect all responses
        responses = await mock_cli.recv_all(timeout=1.0)
        assert len(responses) == 3

        # Verify all are allow control_responses with the right request_ids
        received_ids = set()
        for msg in responses:
            assert msg["type"] == "control_response"
            assert msg["response"]["response"]["behavior"] == "allow"
            received_ids.add(msg["response"]["request_id"])

        assert received_ids == {"r1", "r2", "r3"}

    @pytest.mark.asyncio
    async def test_queue_drains_to_zero(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """After approving all 3, the queue is empty."""
        await _init_session(mock_cli)

        for rid, tool, inp in [
            ("r1", "Bash", {"command": "ls"}),
            ("r2", "Edit", {"file_path": "/f.py", "old_string": "a", "new_string": "b"}),
            ("r3", "Write", {"file_path": "/g.py", "content": "x"}),
        ]:
            await mock_cli.send_control_request(
                request_id=rid, tool_name=tool, tool_input=inp
            )
        await asyncio.sleep(0.15)

        for rid in ("r1", "r2", "r3"):
            await api_client.post(
                f"/approval/{rid}",
                json={"pairingId": e2e_bridge.pairing_id, "approved": True},
            )

        # Drain CLI responses
        await mock_cli.recv_all(timeout=0.5)

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []


# ---------------------------------------------------------------------------
# D1.4: CLI disconnect during pending request
# ---------------------------------------------------------------------------

class TestD1_4_CLIDisconnect:
    """When the CLI disconnects, pending permissions are cancelled and
    the approval queue becomes empty (or returns 404 since the session
    is unregistered / cleaned up).
    """

    @pytest.mark.asyncio
    async def test_disconnect_clears_queue(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "sleep 10"},
        )
        await asyncio.sleep(0.1)

        # Verify it's in the queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 1

        # Disconnect the CLI
        await mock_cli.disconnect()
        # Give bridge time to process the disconnect callback
        await asyncio.sleep(0.2)

        # Queue should be empty (session still registered but permissions cancelled)
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []

    @pytest.mark.asyncio
    async def test_disconnect_with_multiple_pending(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """Multiple pending requests all get cancelled on disconnect."""
        await _init_session(mock_cli)

        for rid in ("r1", "r2", "r3"):
            await mock_cli.send_control_request(
                request_id=rid,
                tool_name="Bash",
                tool_input={"command": f"cmd-{rid}"},
            )
        await asyncio.sleep(0.15)

        # Verify all queued
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 3

        # Disconnect
        await mock_cli.disconnect()
        await asyncio.sleep(0.2)

        # All cancelled
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0


# ---------------------------------------------------------------------------
# D1.5: Latency check
# ---------------------------------------------------------------------------

class TestD1_5_LatencyCheck:
    """Measure the time from POST /approval to receiving the
    control_response on the WebSocket and assert < 200 ms.
    """

    @pytest.mark.asyncio
    async def test_approval_latency_under_200ms(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "echo fast"},
        )
        await asyncio.sleep(0.1)

        # Drain any stale messages
        await mock_cli.recv_all(timeout=0.05)

        # Time the approval round-trip
        t_start = time.monotonic()

        resp = await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": True,
            },
        )
        assert resp.status == 200

        msg = await mock_cli.recv(timeout=2.0)
        t_end = time.monotonic()

        assert msg is not None, "Expected control_response from bridge"
        assert msg["type"] == "control_response"
        assert msg["response"]["response"]["behavior"] == "allow"

        elapsed_ms = (t_end - t_start) * 1000
        assert elapsed_ms < 200, (
            f"Approval-to-response latency was {elapsed_ms:.1f} ms, "
            f"expected < 200 ms"
        )

    @pytest.mark.asyncio
    async def test_rejection_latency_under_200ms(
        self,
        e2e_bridge: E2EBridge,
        mock_cli: MockCLI,
        api_client,
    ) -> None:
        """Rejection path should also be fast."""
        await _init_session(mock_cli)

        await mock_cli.send_control_request(
            request_id="r1",
            tool_name="Bash",
            tool_input={"command": "echo fast"},
        )
        await asyncio.sleep(0.1)
        await mock_cli.recv_all(timeout=0.05)

        t_start = time.monotonic()

        resp = await api_client.post(
            "/approval/r1",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "approved": False,
            },
        )
        assert resp.status == 200

        msg = await mock_cli.recv(timeout=2.0)
        t_end = time.monotonic()

        assert msg is not None
        assert msg["type"] == "control_response"
        assert msg["response"]["response"]["behavior"] == "deny"

        elapsed_ms = (t_end - t_start) * 1000
        assert elapsed_ms < 200, (
            f"Rejection-to-response latency was {elapsed_ms:.1f} ms, "
            f"expected < 200 ms"
        )
