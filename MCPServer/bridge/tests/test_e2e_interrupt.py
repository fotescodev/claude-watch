"""
End-to-end integration tests for the interrupt flow (Task D4).

Tests the full path: HTTP API -> Bridge -> WebSocket -> CLI, verifying that
interrupt commands issued via REST reach the mock CLI as NDJSON messages and
that the interrupt state is tracked correctly.

D4.1: Stop sends interrupt control_request to CLI
D4.2: GET interrupt state reflects stop
D4.3: Resume clears interrupt state
D4.4: Default interrupt state is not interrupted
"""
from __future__ import annotations

import asyncio

import pytest


# ---------------------------------------------------------------------------
# D4.1: POST /session-interrupt with action="stop" sends interrupt to CLI
# ---------------------------------------------------------------------------


class TestD4_1_StopSendsInterruptToCLI:
    """POST /session-interrupt action=stop delivers an interrupt control_request
    to the connected CLI over the WebSocket."""

    @pytest.mark.asyncio
    async def test_stop_response_success(self, e2e_bridge, mock_cli, api_client):
        """POST returns {"success": true}."""
        await mock_cli.send_init()
        # Drain the initialize control_request the bridge sends after init
        init_msg = await mock_cli.recv(timeout=2.0)
        assert init_msg is not None, "Expected initialize message after send_init"

        resp = await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

    @pytest.mark.asyncio
    async def test_stop_delivers_interrupt_control_request(
        self, e2e_bridge, mock_cli, api_client
    ):
        """CLI receives a control_request with request.subtype="interrupt"."""
        await mock_cli.send_init()
        # Drain initialize
        await mock_cli.recv(timeout=2.0)

        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )

        msg = await mock_cli.recv(timeout=2.0)
        assert msg is not None, "Expected interrupt control_request from bridge"
        assert msg["type"] == "control_request"
        assert msg["request"]["subtype"] == "interrupt"
        assert "request_id" in msg


# ---------------------------------------------------------------------------
# D4.2: GET /session-interrupt reflects stop state
# ---------------------------------------------------------------------------


class TestD4_2_GetInterruptStateAfterStop:
    """After a stop, GET /session-interrupt/{pairing_id} returns
    interrupted=true, action="stop"."""

    @pytest.mark.asyncio
    async def test_interrupt_state_after_stop(
        self, e2e_bridge, mock_cli, api_client
    ):
        """GET returns {"interrupted": true, "action": "stop"} after a stop."""
        await mock_cli.send_init()
        await mock_cli.recv(timeout=2.0)  # drain initialize

        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )

        # Small delay for state update
        await asyncio.sleep(0.1)

        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()
        assert data["interrupted"] is True
        assert data["action"] == "stop"


# ---------------------------------------------------------------------------
# D4.3: Resume clears interrupt state
# ---------------------------------------------------------------------------


class TestD4_3_ResumeClearsInterruptState:
    """After stop then resume, interrupt state is cleared."""

    @pytest.mark.asyncio
    async def test_resume_response_success(
        self, e2e_bridge, mock_cli, api_client
    ):
        """POST resume returns {"success": true}."""
        await mock_cli.send_init()
        await mock_cli.recv(timeout=2.0)  # drain initialize

        # Stop first
        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )
        await asyncio.sleep(0.1)

        # Resume
        resp = await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "resume"},
        )
        assert resp.status == 200
        data = await resp.json()
        assert data == {"success": True}

    @pytest.mark.asyncio
    async def test_interrupt_state_cleared_after_resume(
        self, e2e_bridge, mock_cli, api_client
    ):
        """GET returns interrupted=false after resume."""
        await mock_cli.send_init()
        await mock_cli.recv(timeout=2.0)  # drain initialize

        # Stop
        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )
        await asyncio.sleep(0.1)

        # Resume
        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "resume"},
        )
        await asyncio.sleep(0.1)

        # Verify state
        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()
        assert data["interrupted"] is False
        assert data["action"] is None


# ---------------------------------------------------------------------------
# D4.4: Default interrupt state is not interrupted
# ---------------------------------------------------------------------------


class TestD4_4_DefaultInterruptState:
    """Without any interrupt action, the default state is not interrupted."""

    @pytest.mark.asyncio
    async def test_default_state_not_interrupted(
        self, e2e_bridge, mock_cli, api_client
    ):
        """GET returns interrupted=false when no interrupt has been issued."""
        await mock_cli.send_init()
        await mock_cli.recv(timeout=2.0)  # drain initialize

        # Small delay for session registration to propagate
        await asyncio.sleep(0.1)

        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()
        assert data["interrupted"] is False
        # action should be None (serialized as null in JSON)
        assert data.get("action") is None
