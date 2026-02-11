"""Tests for the NDJSON WebSocket server (spec task A1).

Tests A1.1–A1.8 validate connection handling, NDJSON parsing,
error resilience, and lifecycle callbacks.
"""

from __future__ import annotations

import asyncio
import json
import socket
from typing import Any

import pytest
import pytest_asyncio

from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosedError, InvalidStatus

from MCPServer.bridge.ndjson_server import NDJSONServer


def _free_port() -> int:
    """Return an available TCP port on localhost."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


@pytest_asyncio.fixture
async def server_and_port():
    """Start an NDJSONServer on a random free port, yield (server, port),
    then shut it down."""
    port = _free_port()
    srv = NDJSONServer(host="localhost", port=port)
    ws_server = await srv.start()
    yield srv, port
    ws_server.close()
    await ws_server.wait_closed()


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def _ws_url(port: int, session_id: str = "test-session") -> str:
    return f"ws://localhost:{port}/ws/cli/{session_id}"


# ------------------------------------------------------------------
# TEST A1.1 — Connection acceptance
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_1_connection_acceptance(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Connect to /ws/cli/test-session-123 and verify the session is registered."""
    srv, port = server_and_port
    session_id = "test-session-123"

    async with connect(_ws_url(port, session_id)):
        # Allow the server handler to run
        await asyncio.sleep(0.05)
        assert srv.is_cli_connected(session_id), (
            f"Expected session {session_id!r} to be registered"
        )


# ------------------------------------------------------------------
# TEST A1.2 — NDJSON parsing
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_2_ndjson_parsing(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Send a system/init JSON message and verify the handler receives the parsed dict."""
    srv, port = server_and_port

    received: list[tuple[str, dict[str, Any]]] = []

    async def system_handler(session_id: str, msg: dict[str, Any]) -> None:
        received.append((session_id, msg))

    srv.on_message("system", system_handler)

    init_msg = {
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

    async with connect(_ws_url(port)) as ws:
        await ws.send(json.dumps(init_msg) + "\n")
        await asyncio.sleep(0.1)

    assert len(received) == 1
    sid, msg = received[0]
    assert sid == "test-session"
    assert msg["type"] == "system"
    assert msg["subtype"] == "init"
    assert msg["model"] == "sonnet"
    assert msg["tools"] == ["Bash"]


# ------------------------------------------------------------------
# TEST A1.3 — Multi-line message
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_3_multi_line_message(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Send two JSON objects in one WebSocket frame; both must be dispatched."""
    srv, port = server_and_port

    received: list[dict[str, Any]] = []

    async def handler(session_id: str, msg: dict[str, Any]) -> None:
        received.append(msg)

    srv.on_message("system", handler)
    srv.on_message("assistant", handler)

    msg1 = json.dumps({"type": "system", "subtype": "init", "session_id": "s1"})
    msg2 = json.dumps({"type": "assistant", "message": {"content": []}, "uuid": "u2"})
    combined = msg1 + "\n" + msg2 + "\n"

    async with connect(_ws_url(port)) as ws:
        await ws.send(combined)
        await asyncio.sleep(0.1)

    assert len(received) == 2
    assert received[0]["type"] == "system"
    assert received[1]["type"] == "assistant"


# ------------------------------------------------------------------
# TEST A1.4 — Malformed line
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_4_malformed_line(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Malformed JSON is skipped; valid JSON in the same frame is still dispatched."""
    srv, port = server_and_port

    received: list[dict[str, Any]] = []

    async def handler(session_id: str, msg: dict[str, Any]) -> None:
        received.append(msg)

    srv.on_message("assistant", handler)

    # First line is garbage, second line is valid JSON
    frame = 'not valid json\n{"type":"assistant","uuid":"u3"}\n'

    async with connect(_ws_url(port)) as ws:
        await ws.send(frame)
        await asyncio.sleep(0.1)

    # Only the valid line should have been dispatched
    assert len(received) == 1
    assert received[0]["type"] == "assistant"


# ------------------------------------------------------------------
# TEST A1.5 — Disconnect cleanup
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_5_disconnect_cleanup(server_and_port: tuple[NDJSONServer, int]) -> None:
    """After CLI disconnects, the disconnect callback fires and the session is removed."""
    srv, port = server_and_port
    session_id = "disconnect-test"

    disconnected_sessions: list[str] = []

    async def on_disconnect(sid: str) -> None:
        disconnected_sessions.append(sid)

    srv.on_disconnect(on_disconnect)

    ws = await connect(_ws_url(port, session_id))
    await asyncio.sleep(0.05)
    assert srv.is_cli_connected(session_id)

    await ws.close()
    # Give the server time to process the disconnect
    await asyncio.sleep(0.15)

    assert not srv.is_cli_connected(session_id), (
        "Session should be removed after disconnect"
    )
    assert session_id in disconnected_sessions, (
        "Disconnect callback should have been called"
    )


# ------------------------------------------------------------------
# TEST A1.6 — send_to_cli round-trip
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_6_send_to_cli_roundtrip(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Server sends a message via send_to_cli; client receives valid NDJSON."""
    srv, port = server_and_port
    session_id = "roundtrip-test"

    outgoing = {
        "type": "control_response",
        "response": {
            "subtype": "success",
            "request_id": "r1",
            "response": {"behavior": "allow", "updatedInput": {"command": "ls"}},
        },
    }

    async with connect(_ws_url(port, session_id)) as ws:
        await asyncio.sleep(0.05)

        sent = await srv.send_to_cli(session_id, outgoing)
        assert sent is True

        raw = await asyncio.wait_for(ws.recv(), timeout=2)

        # The server appends "\n" — strip it before parsing
        assert raw.endswith("\n")
        parsed = json.loads(raw.strip())

        assert parsed["type"] == "control_response"
        assert parsed["response"]["request_id"] == "r1"
        assert parsed["response"]["response"]["behavior"] == "allow"


# ------------------------------------------------------------------
# TEST A1.7 — keep_alive silently consumed
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_7_keep_alive_consumed(server_and_port: tuple[NDJSONServer, int]) -> None:
    """keep_alive messages must NOT trigger any handler."""
    srv, port = server_and_port

    keep_alive_received = False

    async def keep_alive_handler(session_id: str, msg: dict[str, Any]) -> None:
        nonlocal keep_alive_received
        keep_alive_received = True

    # Register a handler that should NEVER be called
    srv.on_message("keep_alive", keep_alive_handler)

    # Also register a "system" handler to verify other messages still work
    system_received: list[dict[str, Any]] = []

    async def system_handler(session_id: str, msg: dict[str, Any]) -> None:
        system_received.append(msg)

    srv.on_message("system", system_handler)

    async with connect(_ws_url(port)) as ws:
        # Send keep_alive followed by a real message
        frame = (
            json.dumps({"type": "keep_alive"})
            + "\n"
            + json.dumps({"type": "system", "subtype": "status"})
            + "\n"
        )
        await ws.send(frame)
        await asyncio.sleep(0.1)

    assert not keep_alive_received, "keep_alive handler should never be called"
    assert len(system_received) == 1, "system handler should still fire"


# ------------------------------------------------------------------
# TEST A1.8 — Invalid path rejected
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_a1_8_invalid_path_rejected(server_and_port: tuple[NDJSONServer, int]) -> None:
    """Connecting to a non /ws/cli/{id} path results in close code 4000."""
    _, port = server_and_port

    ws = await connect(f"ws://localhost:{port}/ws/invalid/path")
    try:
        await asyncio.wait_for(ws.recv(), timeout=2)
        pytest.fail("Expected ConnectionClosedError")
    except ConnectionClosedError as exc:
        assert exc.rcvd is not None
        assert exc.rcvd.code == 4000, f"Expected close code 4000, got {exc.rcvd.code}"
    finally:
        # Ensure we don't leak the connection
        await ws.close() if ws else None


# ------------------------------------------------------------------
# Additional edge-case tests
# ------------------------------------------------------------------

@pytest.mark.asyncio
async def test_send_to_cli_no_session(server_and_port: tuple[NDJSONServer, int]) -> None:
    """send_to_cli returns False when there is no active socket."""
    srv, _ = server_and_port

    result = await srv.send_to_cli("nonexistent", {"type": "test"})
    assert result is False


@pytest.mark.asyncio
async def test_on_connect_callback(server_and_port: tuple[NDJSONServer, int]) -> None:
    """The on_connect callback fires with the session_id and websocket."""
    srv, port = server_and_port
    session_id = "connect-callback-test"

    connected: list[str] = []

    async def on_connect(sid: str, ws: Any) -> None:
        connected.append(sid)

    srv.on_connect(on_connect)

    async with connect(_ws_url(port, session_id)):
        await asyncio.sleep(0.05)

    assert session_id in connected


@pytest.mark.asyncio
async def test_handler_exception_does_not_crash(server_and_port: tuple[NDJSONServer, int]) -> None:
    """A handler that raises an exception should not crash the server."""
    srv, port = server_and_port

    call_count = 0

    async def bad_handler(session_id: str, msg: dict[str, Any]) -> None:
        nonlocal call_count
        call_count += 1
        raise RuntimeError("handler exploded")

    srv.on_message("system", bad_handler)

    async with connect(_ws_url(port)) as ws:
        # Send a message that triggers the bad handler
        await ws.send(json.dumps({"type": "system", "subtype": "test"}) + "\n")
        await asyncio.sleep(0.1)

        # Server should still be alive — send another message
        await ws.send(json.dumps({"type": "system", "subtype": "test2"}) + "\n")
        await asyncio.sleep(0.1)

    assert call_count == 2, "Handler should have been called twice despite first exception"
