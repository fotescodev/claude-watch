"""
End-to-end tests for the progress flow (Task D3).

Verifies that progress data flows correctly from CLI -> Bridge -> HTTP API:
  - D3.1: TodoWrite updates progress (via assistant message)
  - D3.2: Tool progress updates activity (via tool_progress message)
  - D3.3: Result updates session (via result message)
  - D3.4: Empty session has default progress (no TodoWrite)

Uses the E2E fixtures from conftest.py:
  - ``e2e_bridge``: Running Bridge with real NDJSON + HTTP servers
  - ``mock_cli``: WebSocket client pretending to be Claude CLI
  - ``api_client``: aiohttp.ClientSession for the HTTP REST API
"""
from __future__ import annotations

import asyncio
import uuid

import pytest
import pytest_asyncio


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# The actual Claude CLI NDJSON protocol wraps assistant content inside a
# "message" object ({"type": "assistant", "message": {"content": [...]}}).
# The mock_cli.send_assistant() convenience puts content at the top level,
# which does NOT match the format expected by extract_todos_from_assistant().
# We build the correct wire-format messages directly via mock_cli.send().

def _make_wire_assistant_msg(content_blocks: list[dict]) -> dict:
    """Build an assistant message in the actual NDJSON wire format."""
    return {
        "type": "assistant",
        "message": {
            "id": f"msg_{uuid.uuid4().hex[:8]}",
            "role": "assistant",
            "model": "claude-sonnet-4-5-20250929",
            "content": content_blocks,
            "stop_reason": "end_turn",
            "usage": {"input_tokens": 200, "output_tokens": 100},
        },
        "parent_tool_use_id": None,
        "uuid": str(uuid.uuid4()),
    }


THREE_TODOS = [
    {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
    {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
    {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
]


def _todowrite_assistant_msg(todos: list[dict] | None = None) -> dict:
    """Build an assistant message containing a TodoWrite tool_use block."""
    return _make_wire_assistant_msg([
        {"type": "text", "text": "Let me create a plan for this work."},
        {
            "type": "tool_use",
            "id": "tu-todo-1",
            "name": "TodoWrite",
            "input": {
                "todos": todos if todos is not None else THREE_TODOS,
            },
        },
    ])


# ---------------------------------------------------------------------------
# D3.1 — TodoWrite updates progress
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d3_1_todowrite_updates_progress(e2e_bridge, mock_cli, api_client):
    """D3.1: Sending an assistant message with TodoWrite updates the progress
    endpoint to reflect the correct task list, counts, and progress fraction.
    """
    # 1. Initialize session and drain the initialize control_request
    await mock_cli.send_init()
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None, "Expected initialize control_request from bridge"

    # 2. Send assistant message with TodoWrite (1 completed, 1 in_progress, 1 pending)
    await mock_cli.send(_todowrite_assistant_msg())
    await asyncio.sleep(0.15)

    # 3. Poll the progress endpoint
    resp = await api_client.get(f"/session-progress/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()

    assert "progress" in data
    progress = data["progress"]

    # Verify currentTask is the in_progress task
    assert progress["currentTask"] == "Write tests"

    # Verify progress fraction: 1 completed / 3 total = 0.3333
    assert progress["progress"] == pytest.approx(1 / 3, abs=0.01)

    # Verify counts
    assert progress["completedCount"] == 1
    assert progress["totalCount"] == 3

    # Verify tasks list
    assert len(progress["tasks"]) == 3
    assert progress["tasks"][0] == {
        "content": "Fix bug",
        "status": "completed",
        "activeForm": "Fixing bug",
    }
    assert progress["tasks"][1] == {
        "content": "Write tests",
        "status": "in_progress",
        "activeForm": "Writing tests",
    }
    assert progress["tasks"][2] == {
        "content": "Deploy",
        "status": "pending",
        "activeForm": "Deploying",
    }

    # Verify currentActivity reflects the in_progress task's activeForm
    assert progress["currentActivity"] == "Writing tests"

    # Verify elapsedSeconds is a non-negative integer
    assert isinstance(progress["elapsedSeconds"], int)
    assert progress["elapsedSeconds"] >= 0


# ---------------------------------------------------------------------------
# D3.2 — Tool progress updates activity
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d3_2_tool_progress_updates_activity(e2e_bridge, mock_cli, api_client):
    """D3.2: Sending a tool_progress message updates currentActivity in the
    progress endpoint to reflect the currently running tool.
    """
    # 1. Initialize and drain
    await mock_cli.send_init()
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None

    # 2. Send TodoWrite first so we have a baseline
    await mock_cli.send(_todowrite_assistant_msg())
    await asyncio.sleep(0.1)

    # 3. Send tool_progress for Bash tool
    await mock_cli.send_tool_progress(
        tool_use_id="tu-bash-1",
        tool_name="Bash",
        elapsed=5.0,
    )
    await asyncio.sleep(0.15)

    # 4. Poll progress
    resp = await api_client.get(f"/session-progress/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()
    progress = data["progress"]

    # currentActivity should now reflect the Bash tool activity
    # format_tool_activity("Bash", 5.0) -> "Running command (5s)"
    assert progress["currentActivity"] is not None
    assert "Running command" in progress["currentActivity"]

    # The todo tasks should still be intact
    assert progress["totalCount"] == 3


# ---------------------------------------------------------------------------
# D3.3 — Result updates session
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d3_3_result_updates_session(e2e_bridge, mock_cli, api_client):
    """D3.3: Sending a result message with subtype='success' updates the session
    and the progress endpoint returns valid JSON with the progress field.
    """
    # 1. Initialize and drain
    await mock_cli.send_init()
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None

    # 2. Send a TodoWrite so there is some progress state
    await mock_cli.send(_todowrite_assistant_msg())
    await asyncio.sleep(0.1)

    # 3. Send result with subtype="success"
    await mock_cli.send_result(
        subtype="success",
        num_turns=5,
        total_cost_usd=0.12,
    )
    await asyncio.sleep(0.15)

    # 4. Poll progress — should still return valid JSON with progress field
    resp = await api_client.get(f"/session-progress/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()

    assert "progress" in data
    progress = data["progress"]

    # The progress payload should have all expected fields
    assert "currentTask" in progress
    assert "currentActivity" in progress
    assert "progress" in progress
    assert "completedCount" in progress
    assert "totalCount" in progress
    assert "elapsedSeconds" in progress
    assert "tasks" in progress

    # Tasks should still be present (result doesn't clear them)
    assert progress["totalCount"] == 3


# ---------------------------------------------------------------------------
# D3.4 — Empty session has default progress
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d3_4_empty_session_default_progress(e2e_bridge, mock_cli, api_client):
    """D3.4: After send_init with no TodoWrite, the progress endpoint returns
    sensible defaults: progress=0, empty tasks list.
    """
    # 1. Initialize and drain
    await mock_cli.send_init()
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None

    # Small delay to ensure session is fully registered
    await asyncio.sleep(0.1)

    # 2. Poll progress without any TodoWrite
    resp = await api_client.get(f"/session-progress/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()

    assert "progress" in data
    progress = data["progress"]

    # Default values for an empty session
    assert progress["currentTask"] is None
    assert progress["progress"] == 0.0
    assert progress["completedCount"] == 0
    assert progress["totalCount"] == 0
    assert progress["tasks"] == []
    assert isinstance(progress["elapsedSeconds"], int)
    assert progress["elapsedSeconds"] >= 0
