"""
E2E contract regression tests for the Watch REST API (Task D6).

These tests verify that the REST API response schemas match the Cloudflare
Worker contract EXACTLY -- so the watch app needs zero changes when switching
from the cloud relay to the local bridge.

Uses the E2E fixtures from conftest.py:
  - e2e_bridge: Running Bridge with real NDJSON + HTTP servers
  - mock_cli:   WebSocket client pretending to be the Claude CLI
  - api_client: aiohttp.ClientSession pointed at the HTTP API

Test naming follows the D6 sub-task numbering:
  D6.1  Approval queue schema
  D6.2  Progress schema
  D6.3  Questions schema
  D6.4  Interrupt schema (GET + POST)
  D6.5  Health endpoint schema
  D6.6  Unknown pairing returns 404 with proper body
  D6.7  Tool type mapping is exhaustive
"""
from __future__ import annotations

import asyncio
import uuid

import pytest

from MCPServer.bridge.tests.conftest import E2EBridge, MockCLI


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _init_and_drain(mock_cli: MockCLI) -> None:
    """Send system/init and drain the initialize control_request that comes back.

    After the bridge receives system/init it sends an ``initialize``
    control_request back to the CLI.  We drain that message so it does
    not interfere with subsequent ``recv()`` calls.
    """
    await mock_cli.send_init()
    # Give the bridge time to process init and send the initialize message
    await mock_cli.recv_all(timeout=0.5)


async def _send_control_request_raw(
    mock_cli: MockCLI,
    request_id: str,
    tool_name: str,
    tool_input: dict,
) -> None:
    """Send a can_use_tool control_request with full control over tool_input."""
    await mock_cli.send({
        "type": "control_request",
        "request_id": request_id,
        "request": {
            "subtype": "can_use_tool",
            "tool_name": tool_name,
            "input": tool_input,
            "tool_use_id": f"tu-{request_id}",
        },
    })
    # Let the bridge process the message
    await asyncio.sleep(0.15)


async def _send_assistant_with_todo_write(
    mock_cli: MockCLI,
    todos: list[dict],
) -> None:
    """Send an assistant message containing a TodoWrite tool_use block.

    Uses the real wire format ``msg["message"]["content"]`` so that
    ``extract_todos_from_assistant`` in the bridge finds the TodoWrite block.
    The conftest ``send_assistant`` helper puts content at the wrong nesting
    level, so we send the raw message directly.
    """
    await mock_cli.send({
        "type": "assistant",
        "message": {
            "id": f"msg-{uuid.uuid4().hex[:8]}",
            "role": "assistant",
            "model": "claude-sonnet-4-5-20250929",
            "content": [
                {
                    "type": "tool_use",
                    "id": f"tu-todo-{uuid.uuid4().hex[:8]}",
                    "name": "TodoWrite",
                    "input": {"todos": todos},
                }
            ],
            "stop_reason": "tool_use",
        },
        "uuid": str(uuid.uuid4()),
    })
    # Let the bridge process
    await asyncio.sleep(0.15)


# ===========================================================================
# D6.1: Approval queue schema
# ===========================================================================

class TestD6_1_ApprovalQueueSchema:
    """Verify GET /approval-queue/{pairing_id} returns the exact contract schema.

    Contract::

        {
            "requests": [
                {
                    "id": str,
                    "type": str,          # "bash" | "file_edit" | "file_create"
                    "title": str,
                    "description": str,
                    "filePath": str|null,
                    "command": str|null
                }
            ],
            "totalCount": int
        }
    """

    @pytest.mark.asyncio
    async def test_top_level_keys_strict(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Top-level response has exactly {requests, totalCount} -- no extra keys."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"requests", "totalCount"}
        assert isinstance(data["requests"], list)
        assert isinstance(data["totalCount"], int)

    @pytest.mark.asyncio
    async def test_bash_request_exact_keys_and_types(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Bash request has exact field set with correct types and values."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "req-bash-1", "Bash", {"command": "npm test"}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert data["totalCount"] == 1
        req = data["requests"][0]

        # Strict key check -- exactly these keys, no more, no less
        assert set(req.keys()) == {
            "id", "type", "title", "description", "filePath", "command",
        }

        # Type and value checks
        assert isinstance(req["id"], str)
        assert req["id"] == "req-bash-1"
        assert isinstance(req["type"], str)
        assert req["type"] == "bash"
        assert isinstance(req["title"], str)
        assert isinstance(req["description"], str)
        assert req["description"] == "npm test"
        assert req["filePath"] is None
        assert isinstance(req["command"], str)
        assert req["command"] == "npm test"

    @pytest.mark.asyncio
    async def test_edit_request_exact_keys_and_types(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Edit request has filePath set and command null."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "req-edit-1", "Edit",
            {"file_path": "/src/app.py", "old_string": "foo", "new_string": "bar"},
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]

        assert set(req.keys()) == {
            "id", "type", "title", "description", "filePath", "command",
        }
        assert req["type"] == "file_edit"
        assert isinstance(req["filePath"], str)
        assert req["filePath"] == "/src/app.py"
        assert req["command"] is None
        assert req["title"] == "app.py"
        assert req["description"] == "Edit /src/app.py"

    @pytest.mark.asyncio
    async def test_write_request_exact_keys_and_types(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Write request has type 'file_create' with filePath set."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "req-write-1", "Write",
            {"file_path": "/src/new_module.py", "content": "# new file"},
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]

        assert set(req.keys()) == {
            "id", "type", "title", "description", "filePath", "command",
        }
        assert req["type"] == "file_create"
        assert isinstance(req["filePath"], str)
        assert req["filePath"] == "/src/new_module.py"
        assert req["command"] is None
        assert req["title"] == "new_module.py"
        assert req["description"] == "Create /src/new_module.py"

    @pytest.mark.asyncio
    async def test_multiple_requests_all_have_correct_schema(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Multiple pending requests: every item has exact keys, totalCount matches."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "r1", "Bash", {"command": "ls"}
        )
        await _send_control_request_raw(
            mock_cli, "r2", "Edit", {"file_path": "/a.py"}
        )
        await _send_control_request_raw(
            mock_cli, "r3", "Write", {"file_path": "/b.py", "content": ""}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert data["totalCount"] == 3
        assert len(data["requests"]) == 3

        ids = {r["id"] for r in data["requests"]}
        assert ids == {"r1", "r2", "r3"}

        # Every single item must have the exact key set
        for req in data["requests"]:
            assert set(req.keys()) == {
                "id", "type", "title", "description", "filePath", "command",
            }

    @pytest.mark.asyncio
    async def test_empty_queue_exact_response(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Empty queue returns exactly {requests: [], totalCount: 0}."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert data == {"requests": [], "totalCount": 0}


# ===========================================================================
# D6.2: Progress schema
# ===========================================================================

class TestD6_2_ProgressSchema:
    """Verify GET /session-progress/{pairing_id} returns the exact contract schema.

    Contract::

        {
            "progress": {
                "currentTask": str|null,
                "currentActivity": str|null,
                "progress": float,
                "completedCount": int,
                "totalCount": int,
                "elapsedSeconds": float,
                "tasks": [
                    {"content": str, "status": str, "activeForm": str}
                ]
            }
        }
    """

    @pytest.mark.asyncio
    async def test_top_level_has_only_progress_key(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Response wraps everything under a single 'progress' key."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/session-progress/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"progress"}

    @pytest.mark.asyncio
    async def test_progress_inner_keys_strict(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Progress object has exactly the contract keys -- no extras."""
        await _init_and_drain(mock_cli)

        await _send_assistant_with_todo_write(mock_cli, [
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        resp = await api_client.get(
            f"/session-progress/{e2e_bridge.pairing_id}"
        )
        p = (await resp.json())["progress"]

        assert set(p.keys()) == {
            "currentTask",
            "currentActivity",
            "progress",
            "completedCount",
            "totalCount",
            "elapsedSeconds",
            "tasks",
        }

    @pytest.mark.asyncio
    async def test_progress_field_types_and_values(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Each field in the progress object has the correct type and value."""
        await _init_and_drain(mock_cli)

        await _send_assistant_with_todo_write(mock_cli, [
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
        ])

        resp = await api_client.get(
            f"/session-progress/{e2e_bridge.pairing_id}"
        )
        p = (await resp.json())["progress"]

        # currentTask is the content of the in_progress task (str or null)
        assert isinstance(p["currentTask"], str)
        assert p["currentTask"] == "Write tests"

        # currentActivity is str or null
        assert isinstance(p["currentActivity"], str) or p["currentActivity"] is None

        # progress is a float (completed / total)
        assert isinstance(p["progress"], (int, float))
        assert abs(p["progress"] - 0.5) < 0.01  # 1 of 2 completed

        # completedCount and totalCount are ints
        assert isinstance(p["completedCount"], int)
        assert p["completedCount"] == 1
        assert isinstance(p["totalCount"], int)
        assert p["totalCount"] == 2

        # elapsedSeconds is numeric (int or float)
        assert isinstance(p["elapsedSeconds"], (int, float))
        assert p["elapsedSeconds"] >= 0

        # tasks is a list
        assert isinstance(p["tasks"], list)
        assert len(p["tasks"]) == 2

    @pytest.mark.asyncio
    async def test_task_item_exact_keys(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Each task in tasks[] has exactly {content, status, activeForm}."""
        await _init_and_drain(mock_cli)

        await _send_assistant_with_todo_write(mock_cli, [
            {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
            {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
            {"content": "Deploy", "status": "pending", "activeForm": "Deploying"},
        ])

        resp = await api_client.get(
            f"/session-progress/{e2e_bridge.pairing_id}"
        )
        tasks = (await resp.json())["progress"]["tasks"]

        assert len(tasks) == 3
        for task in tasks:
            assert set(task.keys()) == {"content", "status", "activeForm"}
            assert isinstance(task["content"], str)
            assert isinstance(task["status"], str)
            assert task["status"] in ("pending", "in_progress", "completed")
            # activeForm can be str or None
            assert isinstance(task["activeForm"], str) or task["activeForm"] is None

        # Verify order and values match
        assert tasks[0]["content"] == "Fix bug"
        assert tasks[0]["status"] == "completed"
        assert tasks[0]["activeForm"] == "Fixing bug"
        assert tasks[1]["content"] == "Write tests"
        assert tasks[1]["status"] == "in_progress"
        assert tasks[1]["activeForm"] == "Writing tests"
        assert tasks[2]["content"] == "Deploy"
        assert tasks[2]["status"] == "pending"
        assert tasks[2]["activeForm"] == "Deploying"

    @pytest.mark.asyncio
    async def test_progress_empty_todos(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """When no todos, progress returns null currentTask and empty tasks[]."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/session-progress/{e2e_bridge.pairing_id}"
        )
        p = (await resp.json())["progress"]

        assert p["currentTask"] is None
        assert p["tasks"] == []
        assert p["completedCount"] == 0
        assert p["totalCount"] == 0
        assert p["progress"] == 0.0


# ===========================================================================
# D6.3: Questions schema
# ===========================================================================

class TestD6_3_QuestionsSchema:
    """Verify GET /questions/{pairing_id} returns the exact contract schema.

    Contract (actual implementation)::

        {
            "questions": [
                {
                    "questionId": str,
                    "question": str,
                    "recommendedAnswer": str,
                    "optionCount": int,
                    "allOptions": [str],
                    "header": str
                }
            ]
        }
    """

    @pytest.mark.asyncio
    async def test_top_level_key_strict(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Response has exactly {questions}."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/questions/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"questions"}
        assert isinstance(data["questions"], list)

    @pytest.mark.asyncio
    async def test_question_item_exact_keys_and_types(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Each question has the exact field set with correct types and values."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "q-1", "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "Database",
                        "question": "Which database should we use?",
                        "options": [
                            {"label": "PostgreSQL (Recommended)", "description": "Most popular"},
                            {"label": "MySQL", "description": "Alternative"},
                        ],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await api_client.get(
            f"/questions/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert len(data["questions"]) == 1
        q = data["questions"][0]

        # Strict key check -- exactly these keys
        assert set(q.keys()) == {
            "questionId", "question", "recommendedAnswer",
            "optionCount", "allOptions", "header",
        }

        # Type checks
        assert isinstance(q["questionId"], str)
        assert q["questionId"] == "q-1"
        assert isinstance(q["question"], str)
        assert q["question"] == "Which database should we use?"
        assert isinstance(q["recommendedAnswer"], str)
        assert q["recommendedAnswer"] == "PostgreSQL"
        assert isinstance(q["optionCount"], int)
        assert q["optionCount"] == 2
        assert isinstance(q["allOptions"], list)
        assert all(isinstance(opt, str) for opt in q["allOptions"])
        assert q["allOptions"] == ["PostgreSQL (Recommended)", "MySQL"]
        assert isinstance(q["header"], str)
        assert q["header"] == "Database"

    @pytest.mark.asyncio
    async def test_question_excluded_from_approval_queue(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """AskUserQuestion items must NOT appear in /approval-queue."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "q-excl", "AskUserQuestion",
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

        # Not in approval queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0
        assert data["requests"] == []

        # Present in questions endpoint
        resp = await api_client.get(
            f"/questions/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert len(data["questions"]) == 1

    @pytest.mark.asyncio
    async def test_question_answer_response_exact_schema(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """POST /question/{id}/answer returns exactly {success: true}."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "q-ans", "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "DB",
                        "question": "Which?",
                        "options": [{"label": "PG (Recommended)", "description": ""}],
                        "multiSelect": False,
                    }
                ]
            },
        )

        resp = await api_client.post(
            "/question/q-ans/answer",
            json={
                "pairingId": e2e_bridge.pairing_id,
                "accepted": True,
                "handleOnMac": False,
            },
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"success"}
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_empty_questions_response(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """When no AskUserQuestion pending, returns empty questions list."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/questions/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert data == {"questions": []}


# ===========================================================================
# D6.4: Interrupt schema
# ===========================================================================

class TestD6_4_InterruptSchema:
    """Verify POST /session-interrupt and GET /session-interrupt/{pairing_id}.

    POST contract:  ``{"success": true}``
    GET contract:   ``{"interrupted": bool, "action": str|null}``
    """

    @pytest.mark.asyncio
    async def test_post_stop_response_exact_schema(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """POST /session-interrupt with action=stop returns exactly {success: true}."""
        await _init_and_drain(mock_cli)

        resp = await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"success"}
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_post_resume_response_exact_schema(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """POST /session-interrupt with action=resume returns exactly {success: true}."""
        await _init_and_drain(mock_cli)

        resp = await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "resume"},
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"success"}
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_get_default_interrupt_exact_keys(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """GET /session-interrupt returns exactly {interrupted, action} with correct types."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"interrupted", "action"}
        assert isinstance(data["interrupted"], bool)
        assert data["interrupted"] is False
        assert data["action"] is None

    @pytest.mark.asyncio
    async def test_get_interrupt_after_stop(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """After stop, GET returns interrupted=true, action='stop'."""
        await _init_and_drain(mock_cli)

        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )

        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert set(data.keys()) == {"interrupted", "action"}
        assert data["interrupted"] is True
        assert isinstance(data["action"], str)
        assert data["action"] == "stop"

    @pytest.mark.asyncio
    async def test_get_interrupt_after_stop_then_resume(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """After stop then resume, interrupted=false and action=null."""
        await _init_and_drain(mock_cli)

        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "stop"},
        )
        await api_client.post(
            "/session-interrupt",
            json={"pairingId": e2e_bridge.pairing_id, "action": "resume"},
        )

        resp = await api_client.get(
            f"/session-interrupt/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert set(data.keys()) == {"interrupted", "action"}
        assert data["interrupted"] is False
        assert data["action"] is None


# ===========================================================================
# D6.5: Health endpoint schema
# ===========================================================================

class TestD6_5_HealthSchema:
    """Verify GET /health returns the exact contract.

    Contract: ``{"status": "ok"}``
    """

    @pytest.mark.asyncio
    async def test_health_exact_response(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """Health endpoint returns exactly {"status": "ok"} with no extras."""
        resp = await api_client.get("/health")
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"status"}
        assert data["status"] == "ok"

    @pytest.mark.asyncio
    async def test_health_no_session_required(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """Health check works without any CLI connected or session registered."""
        resp = await api_client.get("/health")
        assert resp.status == 200
        data = await resp.json()
        assert data == {"status": "ok"}


# ===========================================================================
# D6.6: Unknown pairing returns 404 with proper body
# ===========================================================================

class TestD6_6_UnknownPairing404:
    """Verify all pairing-based endpoints return 404 for unknown pairing_id.

    GET 404 body contract: ``{"error": str, "pairingId": str}``
    """

    @pytest.mark.asyncio
    async def test_approval_queue_404_exact_body(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """GET /approval-queue with unknown pairing returns 404 with exact body shape."""
        resp = await api_client.get("/approval-queue/nonexistent-pair")
        assert resp.status == 404
        data = await resp.json()

        assert set(data.keys()) == {"error", "pairingId"}
        assert isinstance(data["error"], str)
        assert isinstance(data["pairingId"], str)
        assert data["pairingId"] == "nonexistent-pair"

    @pytest.mark.asyncio
    async def test_progress_404_exact_body(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """GET /session-progress with unknown pairing returns 404."""
        resp = await api_client.get("/session-progress/nonexistent-pair")
        assert resp.status == 404
        data = await resp.json()

        assert set(data.keys()) == {"error", "pairingId"}
        assert data["pairingId"] == "nonexistent-pair"

    @pytest.mark.asyncio
    async def test_questions_404_exact_body(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """GET /questions with unknown pairing returns 404."""
        resp = await api_client.get("/questions/nonexistent-pair")
        assert resp.status == 404
        data = await resp.json()

        assert set(data.keys()) == {"error", "pairingId"}
        assert data["pairingId"] == "nonexistent-pair"

    @pytest.mark.asyncio
    async def test_interrupt_get_404_exact_body(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """GET /session-interrupt with unknown pairing returns 404."""
        resp = await api_client.get("/session-interrupt/nonexistent-pair")
        assert resp.status == 404
        data = await resp.json()

        assert set(data.keys()) == {"error", "pairingId"}
        assert data["pairingId"] == "nonexistent-pair"

    @pytest.mark.asyncio
    async def test_approval_post_unknown_pairing_404(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """POST /approval with unknown pairingId in body returns 404."""
        resp = await api_client.post(
            "/approval/some-req-id",
            json={"pairingId": "nonexistent-pair", "approved": True},
        )
        assert resp.status == 404
        data = await resp.json()
        assert "error" in data

    @pytest.mark.asyncio
    async def test_interrupt_post_unknown_pairing_404(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """POST /session-interrupt with unknown pairingId returns 404."""
        resp = await api_client.post(
            "/session-interrupt",
            json={"pairingId": "nonexistent-pair", "action": "stop"},
        )
        assert resp.status == 404
        data = await resp.json()
        assert "error" in data

    @pytest.mark.asyncio
    async def test_question_answer_unknown_pairing_404(
        self, e2e_bridge: E2EBridge, api_client
    ) -> None:
        """POST /question/{id}/answer with unknown pairingId returns 404."""
        resp = await api_client.post(
            "/question/some-q-id/answer",
            json={
                "pairingId": "nonexistent-pair",
                "accepted": True,
                "handleOnMac": False,
            },
        )
        assert resp.status == 404
        data = await resp.json()
        assert "error" in data


# ===========================================================================
# D6.7: Tool type mapping is exhaustive
# ===========================================================================

class TestD6_7_ToolTypeMapping:
    """Verify tool_name -> type mapping for all known tool types via live API.

    Mapping:
      Bash         -> "bash"
      Edit         -> "file_edit"
      MultiEdit    -> "file_edit"
      NotebookEdit -> "file_edit"
      Write        -> "file_create"
    """

    @pytest.mark.asyncio
    async def test_bash_maps_to_bash(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Bash -> 'bash'."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-bash", "Bash", {"command": "echo hi"}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]
        assert req["type"] == "bash"

    @pytest.mark.asyncio
    async def test_edit_maps_to_file_edit(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Edit -> 'file_edit'."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-edit", "Edit", {"file_path": "/a.py"}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]
        assert req["type"] == "file_edit"

    @pytest.mark.asyncio
    async def test_multi_edit_maps_to_file_edit(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """MultiEdit -> 'file_edit'."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-medit", "MultiEdit", {"file_path": "/b.py"}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]
        assert req["type"] == "file_edit"

    @pytest.mark.asyncio
    async def test_notebook_edit_maps_to_file_edit(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """NotebookEdit -> 'file_edit'."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-nbedit", "NotebookEdit", {"file_path": "/c.ipynb"}
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]
        assert req["type"] == "file_edit"

    @pytest.mark.asyncio
    async def test_write_maps_to_file_create(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """Write -> 'file_create'."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-write", "Write",
            {"file_path": "/d.py", "content": ""},
        )

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        req = (await resp.json())["requests"][0]
        assert req["type"] == "file_create"

    @pytest.mark.asyncio
    async def test_ask_user_question_routes_to_questions_not_approvals(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """AskUserQuestion does not appear in /approval-queue; only in /questions."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "map-auq", "AskUserQuestion",
            {
                "questions": [
                    {
                        "header": "Test",
                        "question": "Test?",
                        "options": [{"label": "Yes", "description": "Confirm"}],
                        "multiSelect": False,
                    }
                ]
            },
        )

        # Not in approval queue
        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert data["totalCount"] == 0

        # Present in questions endpoint
        resp = await api_client.get(
            f"/questions/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()
        assert len(data["questions"]) == 1

    @pytest.mark.asyncio
    async def test_all_tool_types_in_single_queue(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """All non-question tool types appear correctly in one approval queue."""
        await _init_and_drain(mock_cli)

        tools = [
            ("all-bash", "Bash", {"command": "ls"}),
            ("all-edit", "Edit", {"file_path": "/a.py"}),
            ("all-medit", "MultiEdit", {"file_path": "/b.py"}),
            ("all-nbedit", "NotebookEdit", {"file_path": "/c.ipynb"}),
            ("all-write", "Write", {"file_path": "/d.py", "content": ""}),
        ]
        for req_id, tool_name, tool_input in tools:
            await _send_control_request_raw(mock_cli, req_id, tool_name, tool_input)

        resp = await api_client.get(
            f"/approval-queue/{e2e_bridge.pairing_id}"
        )
        data = await resp.json()

        assert data["totalCount"] == 5

        by_id = {r["id"]: r["type"] for r in data["requests"]}
        assert by_id == {
            "all-bash": "bash",
            "all-edit": "file_edit",
            "all-medit": "file_edit",
            "all-nbedit": "file_edit",
            "all-write": "file_create",
        }


# ===========================================================================
# Additional contract tests: POST /approval + GET /state
# ===========================================================================

class TestApprovalPostResponseSchema:
    """Verify POST /approval/{request_id} response format.

    Contract: ``{"success": true}``
    """

    @pytest.mark.asyncio
    async def test_approval_approve_exact_response(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """POST /approval with approved=true returns exactly {success: true}."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "appr-1", "Bash", {"command": "ls"}
        )

        resp = await api_client.post(
            "/approval/appr-1",
            json={"pairingId": e2e_bridge.pairing_id, "approved": True},
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"success"}
        assert data["success"] is True

    @pytest.mark.asyncio
    async def test_approval_deny_exact_response(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """POST /approval with approved=false returns exactly {success: true}."""
        await _init_and_drain(mock_cli)

        await _send_control_request_raw(
            mock_cli, "deny-1", "Bash", {"command": "rm -rf /"}
        )

        resp = await api_client.post(
            "/approval/deny-1",
            json={"pairingId": e2e_bridge.pairing_id, "approved": False},
        )
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"success"}
        assert data["success"] is True


class TestStateDebugEndpointSchema:
    """Verify GET /state debug endpoint schema.

    Contract: ``{"pairingMap": dict, "sessions": dict, "interruptState": dict}``
    """

    @pytest.mark.asyncio
    async def test_state_exact_keys(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """GET /state returns exactly {pairingMap, sessions, interruptState}."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get("/state")
        assert resp.status == 200
        data = await resp.json()

        assert set(data.keys()) == {"pairingMap", "sessions", "interruptState"}
        assert isinstance(data["pairingMap"], dict)
        assert isinstance(data["sessions"], dict)
        assert isinstance(data["interruptState"], dict)

    @pytest.mark.asyncio
    async def test_state_contains_registered_pairing(
        self, e2e_bridge: E2EBridge, mock_cli: MockCLI, api_client
    ) -> None:
        """After init, the pairing and session appear in /state."""
        await _init_and_drain(mock_cli)

        resp = await api_client.get("/state")
        data = await resp.json()

        # Pairing map should contain our pairing_id
        assert e2e_bridge.pairing_id in data["pairingMap"]
        session_id = data["pairingMap"][e2e_bridge.pairing_id]
        assert session_id in data["sessions"]
