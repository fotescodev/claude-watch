"""
Shared E2E fixtures for integration tests (Workstream D).

Provides:
  - ``e2e_bridge``: A running Bridge with real NDJSON + HTTP servers on ephemeral ports
  - ``mock_cli``: A WebSocket client that speaks NDJSON to the bridge
  - ``api_client``: An aiohttp.ClientSession pointed at the HTTP API

Usage in tests::

    async def test_something(e2e_bridge, mock_cli, api_client):
        # Send a message from "Claude CLI"
        await mock_cli.send_init()

        # Poll the HTTP API (as the watch would)
        resp = await api_client.get(f"/approval-queue/{e2e_bridge.pairing_id}")
        data = await resp.json()
"""
from __future__ import annotations

import asyncio
import json
import uuid
from typing import Any

import pytest
import pytest_asyncio
import aiohttp
from websockets.asyncio.client import connect as ws_connect

from MCPServer.bridge.main import Bridge


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# We pick a high port range and rely on sequential allocation.
# Each test gets a unique pair of ports via _next_port().
_PORT_BASE = 18700
_port_counter = 0


def _next_port() -> int:
    """Return the next available port pair base (WS=base, HTTP=base+1)."""
    global _port_counter
    port = _PORT_BASE + (_port_counter * 2)
    _port_counter += 1
    return port


# ---------------------------------------------------------------------------
# Mock CLI client
# ---------------------------------------------------------------------------


class MockCLI:
    """WebSocket client that pretends to be a Claude CLI session.

    Sends and receives NDJSON messages through the bridge's WebSocket server.
    """

    def __init__(self, ws_url: str, session_id: str) -> None:
        self.ws_url = ws_url
        self.session_id = session_id
        self._ws: Any = None
        self._received: list[dict] = []
        self._recv_task: asyncio.Task | None = None

    async def connect(self) -> None:
        """Open WebSocket connection to the bridge."""
        self._ws = await ws_connect(self.ws_url)
        # Background task to accumulate received messages
        self._recv_task = asyncio.create_task(self._read_loop())

    async def _read_loop(self) -> None:
        """Read messages from bridge in background."""
        try:
            async for raw in self._ws:
                data = raw if isinstance(raw, str) else raw.decode("utf-8")
                for line in data.split("\n"):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        self._received.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
        except Exception:
            pass  # Connection closed

    async def disconnect(self) -> None:
        """Close the WebSocket connection."""
        if self._recv_task:
            self._recv_task.cancel()
            try:
                await self._recv_task
            except (asyncio.CancelledError, Exception):
                pass
        if self._ws:
            await self._ws.close()

    async def send(self, msg: dict) -> None:
        """Send an NDJSON message to the bridge."""
        payload = json.dumps(msg) + "\n"
        await self._ws.send(payload)

    async def send_init(
        self,
        model: str = "claude-sonnet-4-5-20250929",
        cwd: str = "/home/user/project",
        tools: list[str] | None = None,
        permission_mode: str = "default",
    ) -> None:
        """Send a system/init message."""
        await self.send({
            "type": "system",
            "subtype": "init",
            "session_id": self.session_id,
            "model": model,
            "cwd": cwd,
            "tools": tools or ["Bash", "Edit", "Read", "Write"],
            "permissionMode": permission_mode,
            "claude_code_version": "2.1.37",
            "mcp_servers": [],
            "slash_commands": [],
            "uuid": str(uuid.uuid4()),
        })

    async def send_control_request(
        self,
        request_id: str,
        tool_name: str = "Bash",
        tool_input: dict | None = None,
        tool_use_id: str | None = None,
    ) -> None:
        """Send a can_use_tool control_request."""
        await self.send({
            "type": "control_request",
            "request_id": request_id,
            "request": {
                "subtype": "can_use_tool",
                "tool_name": tool_name,
                "input": tool_input or {"command": "ls -la"},
                "tool_use_id": tool_use_id or f"tu-{request_id}",
            },
        })

    async def send_assistant(self, content: list[dict]) -> None:
        """Send an assistant message with given content blocks."""
        await self.send({
            "type": "assistant",
            "content": content,
            "uuid": str(uuid.uuid4()),
        })

    async def send_tool_progress(
        self,
        tool_use_id: str,
        tool_name: str = "Bash",
        elapsed: float = 5.0,
    ) -> None:
        """Send a tool_progress heartbeat."""
        await self.send({
            "type": "tool_progress",
            "tool_use_id": tool_use_id,
            "tool_name": tool_name,
            "elapsed_time_seconds": elapsed,
        })

    async def send_result(
        self,
        subtype: str = "success",
        num_turns: int = 5,
        total_cost_usd: float = 0.12,
    ) -> None:
        """Send a result message (query completion)."""
        await self.send({
            "type": "result",
            "subtype": subtype,
            "is_error": subtype != "success",
            "num_turns": num_turns,
            "total_cost_usd": total_cost_usd,
            "modelUsage": {
                "claude-sonnet-4-5-20250929": {
                    "inputTokens": 5000,
                    "outputTokens": 1000,
                    "cacheReadInputTokens": 2000,
                    "cacheCreationInputTokens": 500,
                }
            },
            "stop_reason": "end_turn",
            "uuid": str(uuid.uuid4()),
        })

    async def recv(self, timeout: float = 2.0) -> dict | None:
        """Wait for the next received message from bridge, with timeout."""
        deadline = asyncio.get_event_loop().time() + timeout
        while asyncio.get_event_loop().time() < deadline:
            if self._received:
                return self._received.pop(0)
            await asyncio.sleep(0.01)
        return None

    async def recv_all(self, timeout: float = 0.5) -> list[dict]:
        """Drain all received messages after a short wait."""
        await asyncio.sleep(timeout)
        msgs = list(self._received)
        self._received.clear()
        return msgs

    @property
    def received(self) -> list[dict]:
        """Direct access to received message buffer."""
        return self._received


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


class E2EBridge:
    """Wrapper around a running Bridge with port info."""

    def __init__(self, bridge: Bridge, ws_port: int, http_port: int) -> None:
        self.bridge = bridge
        self.ws_port = ws_port
        self.http_port = http_port
        self.pairing_id = bridge.pairing_id

    @property
    def ws_base(self) -> str:
        return f"ws://localhost:{self.ws_port}"

    @property
    def http_base(self) -> str:
        return f"http://localhost:{self.http_port}"


@pytest_asyncio.fixture
async def e2e_bridge():
    """Start a real Bridge with NDJSON + HTTP servers."""
    port = _next_port()
    pairing_id = f"e2e-pair-{uuid.uuid4().hex[:8]}"
    bridge = Bridge(port=port, pairing_id=pairing_id)
    await bridge.start()

    wrapper = E2EBridge(bridge, ws_port=port, http_port=port + 1)
    yield wrapper

    await bridge.stop()


@pytest_asyncio.fixture
async def mock_cli(e2e_bridge: E2EBridge):
    """Connect a mock CLI to the running bridge."""
    session_id = f"cli-sess-{uuid.uuid4().hex[:8]}"
    url = f"{e2e_bridge.ws_base}/ws/cli/{session_id}"
    cli = MockCLI(url, session_id)
    await cli.connect()
    # Small delay for connect callback to fire
    await asyncio.sleep(0.05)

    yield cli

    await cli.disconnect()


@pytest_asyncio.fixture
async def api_client(e2e_bridge: E2EBridge):
    """Provide an aiohttp.ClientSession for the bridge's HTTP API."""
    session = aiohttp.ClientSession(base_url=e2e_bridge.http_base)
    yield session
    await session.close()
