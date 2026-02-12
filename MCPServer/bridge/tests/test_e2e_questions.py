"""
End-to-End integration tests for the AskUserQuestion flow (Task D2).

Tests the full path: CLI sends AskUserQuestion control_request via WebSocket
-> bridge queues it -> watch polls via HTTP API -> watch answers -> bridge
sends control_response back to CLI.

Uses the real Bridge with NDJSON WebSocket + HTTP API servers (no mocking).

Tests:
  D2.1: Happy path — accept recommended answer
  D2.2: Reject question
  D2.3: No recommended option — first option used as fallback
  D2.4: Questions don't appear in the approval queue
  D2.5: Handle on Mac — deferred to terminal
"""
from __future__ import annotations

import asyncio
import uuid

import pytest
import pytest_asyncio

from MCPServer.bridge.tests.conftest import E2EBridge, MockCLI


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _ask_user_question_input(
    header: str = "Database",
    question: str = "Which database?",
    options: list[dict] | None = None,
    multi_select: bool = False,
) -> dict:
    """Build a standard AskUserQuestion tool input payload."""
    if options is None:
        options = [
            {
                "label": "PostgreSQL (Recommended)",
                "description": "Best for complex queries and data integrity",
            },
            {
                "label": "MySQL",
                "description": "Good for simple read-heavy workloads",
            },
        ]
    return {
        "questions": [
            {
                "header": header,
                "question": question,
                "options": options,
                "multiSelect": multi_select,
            }
        ]
    }


async def _init_and_drain(mock_cli: MockCLI) -> None:
    """Send system/init and drain the bridge's initialize control_request."""
    await mock_cli.send_init()
    # The bridge sends an initialize control_request in response to init.
    init_msg = await mock_cli.recv(timeout=2.0)
    assert init_msg is not None, "Expected initialize control_request from bridge"
    assert init_msg.get("type") == "control_request"


# ---------------------------------------------------------------------------
# D2.1: Happy path question answer
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d2_1_happy_path_question_answer(
    e2e_bridge: E2EBridge,
    mock_cli: MockCLI,
    api_client,
):
    """Accept a question with the recommended answer.

    Flow:
    1. CLI sends init + AskUserQuestion control_request
    2. Watch polls GET /questions/{pairing_id} — sees the question
    3. Watch POSTs accepted=true
    4. CLI receives control_response with updatedInput.answers
    """
    await _init_and_drain(mock_cli)

    # Send AskUserQuestion control_request
    request_id = f"q-{uuid.uuid4().hex[:8]}"
    tool_input = _ask_user_question_input()
    await mock_cli.send_control_request(
        request_id=request_id,
        tool_name="AskUserQuestion",
        tool_input=tool_input,
    )

    # Wait for bridge to process the message
    await asyncio.sleep(0.15)

    # Poll GET /questions/{pairing_id}
    resp = await api_client.get(f"/questions/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()

    questions = data["questions"]
    assert len(questions) == 1

    q = questions[0]
    assert q["questionId"] == request_id
    assert q["question"] == "Which database?"
    assert q["recommendedAnswer"] == "PostgreSQL"
    assert q["header"] == "Database"

    # Accept the question
    answer_resp = await api_client.post(
        f"/question/{request_id}/answer",
        json={
            "pairingId": e2e_bridge.pairing_id,
            "accepted": True,
            "handleOnMac": False,
        },
    )
    assert answer_resp.status == 200
    answer_data = await answer_resp.json()
    assert answer_data["success"] is True

    # CLI should receive a control_response with updatedInput
    cli_msg = await mock_cli.recv(timeout=2.0)
    assert cli_msg is not None, "Expected control_response from bridge"
    assert cli_msg["type"] == "control_response"

    response = cli_msg["response"]
    assert response["request_id"] == request_id
    inner = response["response"]
    assert inner["behavior"] == "allow"
    assert "updatedInput" in inner

    updated_input = inner["updatedInput"]
    assert "answers" in updated_input
    assert updated_input["answers"] == {"Database": "PostgreSQL"}

    # Question should be gone from the queue now
    resp2 = await api_client.get(f"/questions/{e2e_bridge.pairing_id}")
    data2 = await resp2.json()
    assert len(data2["questions"]) == 0


# ---------------------------------------------------------------------------
# D2.2: Reject question
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d2_2_reject_question(
    e2e_bridge: E2EBridge,
    mock_cli: MockCLI,
    api_client,
):
    """Reject a question — CLI receives behavior='deny'."""
    await _init_and_drain(mock_cli)

    request_id = f"q-{uuid.uuid4().hex[:8]}"
    tool_input = _ask_user_question_input()
    await mock_cli.send_control_request(
        request_id=request_id,
        tool_name="AskUserQuestion",
        tool_input=tool_input,
    )
    await asyncio.sleep(0.15)

    # Reject the question
    answer_resp = await api_client.post(
        f"/question/{request_id}/answer",
        json={
            "pairingId": e2e_bridge.pairing_id,
            "accepted": False,
            "handleOnMac": False,
        },
    )
    assert answer_resp.status == 200

    # CLI receives deny response
    cli_msg = await mock_cli.recv(timeout=2.0)
    assert cli_msg is not None, "Expected control_response from bridge"
    assert cli_msg["type"] == "control_response"

    response = cli_msg["response"]
    assert response["request_id"] == request_id
    inner = response["response"]
    assert inner["behavior"] == "deny"
    assert "message" in inner


# ---------------------------------------------------------------------------
# D2.3: No recommended option — first option used as fallback
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d2_3_no_recommended_option_uses_first(
    e2e_bridge: E2EBridge,
    mock_cli: MockCLI,
    api_client,
):
    """When no option has '(Recommended)' suffix, the first option is used."""
    await _init_and_drain(mock_cli)

    request_id = f"q-{uuid.uuid4().hex[:8]}"
    tool_input = _ask_user_question_input(
        header="Framework",
        question="Which framework?",
        options=[
            {"label": "React", "description": "Popular UI library"},
            {"label": "Vue", "description": "Progressive framework"},
            {"label": "Svelte", "description": "Compiler-based framework"},
        ],
    )
    await mock_cli.send_control_request(
        request_id=request_id,
        tool_name="AskUserQuestion",
        tool_input=tool_input,
    )
    await asyncio.sleep(0.15)

    # Poll questions — recommendedAnswer should be the first option
    resp = await api_client.get(f"/questions/{e2e_bridge.pairing_id}")
    assert resp.status == 200
    data = await resp.json()

    questions = data["questions"]
    assert len(questions) == 1

    q = questions[0]
    assert q["recommendedAnswer"] == "React"

    # Accept — should use the first option as the answer
    answer_resp = await api_client.post(
        f"/question/{request_id}/answer",
        json={
            "pairingId": e2e_bridge.pairing_id,
            "accepted": True,
            "handleOnMac": False,
        },
    )
    assert answer_resp.status == 200

    cli_msg = await mock_cli.recv(timeout=2.0)
    assert cli_msg is not None, "Expected control_response from bridge"
    assert cli_msg["type"] == "control_response"

    inner = cli_msg["response"]["response"]
    assert inner["behavior"] == "allow"
    assert inner["updatedInput"]["answers"] == {"Framework": "React"}


# ---------------------------------------------------------------------------
# D2.4: Questions don't appear in approval queue
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d2_4_questions_not_in_approval_queue(
    e2e_bridge: E2EBridge,
    mock_cli: MockCLI,
    api_client,
):
    """AskUserQuestion items appear only in /questions, not /approval-queue."""
    await _init_and_drain(mock_cli)

    request_id = f"q-{uuid.uuid4().hex[:8]}"
    tool_input = _ask_user_question_input()
    await mock_cli.send_control_request(
        request_id=request_id,
        tool_name="AskUserQuestion",
        tool_input=tool_input,
    )
    await asyncio.sleep(0.15)

    # Approval queue should be empty
    approval_resp = await api_client.get(
        f"/approval-queue/{e2e_bridge.pairing_id}"
    )
    assert approval_resp.status == 200
    approval_data = await approval_resp.json()
    assert approval_data["totalCount"] == 0
    assert len(approval_data["requests"]) == 0

    # Questions endpoint should have 1 question
    questions_resp = await api_client.get(
        f"/questions/{e2e_bridge.pairing_id}"
    )
    assert questions_resp.status == 200
    questions_data = await questions_resp.json()
    assert len(questions_data["questions"]) == 1
    assert questions_data["questions"][0]["questionId"] == request_id


# ---------------------------------------------------------------------------
# D2.5: Handle on Mac
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_d2_5_handle_on_mac(
    e2e_bridge: E2EBridge,
    mock_cli: MockCLI,
    api_client,
):
    """handleOnMac=true defers the question to the terminal (deny + message)."""
    await _init_and_drain(mock_cli)

    request_id = f"q-{uuid.uuid4().hex[:8]}"
    tool_input = _ask_user_question_input()
    await mock_cli.send_control_request(
        request_id=request_id,
        tool_name="AskUserQuestion",
        tool_input=tool_input,
    )
    await asyncio.sleep(0.15)

    # Answer with handleOnMac=true
    answer_resp = await api_client.post(
        f"/question/{request_id}/answer",
        json={
            "pairingId": e2e_bridge.pairing_id,
            "accepted": True,  # accepted is irrelevant when handleOnMac is true
            "handleOnMac": True,
        },
    )
    assert answer_resp.status == 200

    # CLI receives deny with "Deferred" message
    cli_msg = await mock_cli.recv(timeout=2.0)
    assert cli_msg is not None, "Expected control_response from bridge"
    assert cli_msg["type"] == "control_response"

    response = cli_msg["response"]
    assert response["request_id"] == request_id
    inner = response["response"]
    assert inner["behavior"] == "deny"
    assert "Deferred" in inner["message"]
