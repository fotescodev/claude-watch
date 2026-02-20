# E2E Testing Guide

How to test the full Remmy flow without running `remmy` CLI. Uses `curl` to simulate the hook → cloud → watch pipeline.

## Prerequisites

- Watch app running on simulator or device
- Paired: `~/.remmy/config.json` has `pairingId`
- Cloud worker healthy: `curl https://claude-watch.fotescodev.workers.dev/health`

## Variables

```bash
PAIRING="<your-pairing-id>"  # from ~/.remmy/config.json
CLOUD="https://claude-watch.fotescodev.workers.dev"
```

## Cloud API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/approval` | Create approval request |
| GET | `/approval/{pairingId}/{requestId}` | Poll request status |
| GET | `/approval-queue/{pairingId}` | List pending requests |
| POST | `/session-progress` | Send task progress |
| GET | `/session-progress/{pairingId}` | Read task progress |
| POST | `/question` | Create a question |
| GET | `/question-queue/{pairingId}` | List pending questions |
| GET | `/question/{pairingId}/{questionId}` | Check question answer |
| POST | `/session-interrupt` | Pause/resume session |
| GET | `/health` | Health check |

---

## 1. Single Approval (approve/reject)

```bash
ID=$(python3 -c "import uuid; print(uuid.uuid4())")

curl -s -X POST "$CLOUD/approval" \
  -H "Content-Type: application/json" \
  -H "User-Agent: remmy/1.0" \
  -d "{
    \"id\": \"$ID\",
    \"pairingId\": \"$PAIRING\",
    \"type\": \"file_create\",
    \"title\": \"Write: /tmp/test.txt\",
    \"description\": \"Create file with hello world\"
  }"

# Poll for result
curl -s "$CLOUD/approval/$PAIRING/$ID" -H "User-Agent: remmy/1.0"
# Returns: {"status": "approved"} or {"status": "rejected"}
```

**Type values**: `bash`, `file_create`, `file_edit`, `mobile_install`, `mobile_uninstall`, `tool_use`

## 2. Approval Queue (2+ requests)

Send multiple requests — watch shows queue view with "Approve All N" button:

```bash
ID_A=$(python3 -c "import uuid; print(uuid.uuid4())")
ID_B=$(python3 -c "import uuid; print(uuid.uuid4())")

curl -s -X POST "$CLOUD/approval" \
  -H "Content-Type: application/json" -H "User-Agent: remmy/1.0" \
  -d "{\"id\":\"$ID_A\",\"pairingId\":\"$PAIRING\",\"type\":\"file_edit\",\"title\":\"Edit: src/app.ts\",\"description\":\"Refactor module\"}"

curl -s -X POST "$CLOUD/approval" \
  -H "Content-Type: application/json" -H "User-Agent: remmy/1.0" \
  -d "{\"id\":\"$ID_B\",\"pairingId\":\"$PAIRING\",\"type\":\"bash\",\"title\":\"Run: npm test\",\"description\":\"Execute tests\"}"
```

## 3. Working View (session progress)

**Important**: Progress fields must be at the **top level** of the POST body (not nested under `progress`).

```bash
curl -s -X POST "$CLOUD/session-progress" \
  -H "Content-Type: application/json" \
  -H "User-Agent: remmy/1.0" \
  -d "{
    \"pairingId\": \"$PAIRING\",
    \"currentTask\": \"Refactoring auth module\",
    \"currentActivity\": \"Editing src/auth.ts\",
    \"progress\": 0.4,
    \"completedCount\": 2,
    \"totalCount\": 5,
    \"elapsedSeconds\": 45,
    \"tasks\": [
      {\"content\": \"Update imports\", \"status\": \"completed\"},
      {\"content\": \"Refactor login flow\", \"status\": \"completed\"},
      {\"content\": \"Edit auth middleware\", \"status\": \"in_progress\", \"activeForm\": \"Editing auth middleware\"},
      {\"content\": \"Update tests\", \"status\": \"pending\"},
      {\"content\": \"Run test suite\", \"status\": \"pending\"}
    ]
  }"
```

**Task statuses**: `completed`, `in_progress`, `pending`

The watch shows a 3-task window centered on the current `in_progress` task (1 completed before, current, 1 pending after).

## 4. Success / Complete View

Send progress with `progress: 1.0` and all tasks completed. Shows briefly then archives to "Session Ended" history card.

```bash
curl -s -X POST "$CLOUD/session-progress" \
  -H "Content-Type: application/json" \
  -H "User-Agent: remmy/1.0" \
  -d "{
    \"pairingId\": \"$PAIRING\",
    \"currentTask\": \"All tasks complete\",
    \"currentActivity\": \"Done\",
    \"progress\": 1.0,
    \"completedCount\": 5,
    \"totalCount\": 5,
    \"elapsedSeconds\": 120,
    \"outcome\": \"Auth module refactored with full test coverage\",
    \"tasks\": [
      {\"content\": \"Update imports\", \"status\": \"completed\"},
      {\"content\": \"Refactor login flow\", \"status\": \"completed\"},
      {\"content\": \"Edit auth middleware\", \"status\": \"completed\"},
      {\"content\": \"Update tests\", \"status\": \"completed\"},
      {\"content\": \"Run test suite\", \"status\": \"completed\"}
    ]
  }"
```

**Completion trigger**: `progress >= 1.0` OR `completedCount == totalCount`

## 5. Question View

Options must be **objects** with `label` (and optional `description`), not strings.

```bash
Q_ID=$(python3 -c "import uuid; print(uuid.uuid4())")

curl -s -X POST "$CLOUD/question" \
  -H "Content-Type: application/json" \
  -H "User-Agent: remmy/1.0" \
  -d "{
    \"pairingId\": \"$PAIRING\",
    \"questionId\": \"$Q_ID\",
    \"question\": \"Which database should we use?\",
    \"options\": [
      {\"label\": \"PostgreSQL\", \"description\": \"Relational, ACID compliant\"},
      {\"label\": \"MongoDB\", \"description\": \"Document store\"},
      {\"label\": \"SQLite\", \"description\": \"Embedded, zero config\"}
    ]
  }"

# Check answer
curl -s "$CLOUD/question/$PAIRING/$Q_ID" -H "User-Agent: remmy/1.0"
```

**Gotcha**: If you include `recommendedAnswer`, the watch may auto-answer with it. Omit for interactive testing.

## 6. Pause (watch-initiated)

Pause is triggered by tapping "Pause" on the watch — it's a watch → cloud action, not cloud → watch.

The watch sends: `POST /session-interrupt` with `{"pairingId": "...", "action": "stop"}`

To resume: double-tap on watch, or the watch sends `{"action": "resume"}`.

The hook checks pause status via: `GET /session-interrupt?pairingId=...`

## 7. Session Isolation

Hook only activates when `CLAUDE_WATCH_SESSION_ACTIVE=1` is set AND `~/.remmy/config.json` exists:

```bash
# Should exit 0 immediately (passthrough)
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/t.txt"}}' | \
  env -u CLAUDE_WATCH_SESSION_ACTIVE python3 ~/.claude/hooks/watch-approval-cloud.py
```

---

## Polling Intervals

- **Idle**: 15 seconds (no pending actions or progress)
- **Active**: 5 seconds (pending actions, questions, or active progress)
- Screenshots may need 15-18s delay to capture state changes

## Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Watch stays on Idle | Progress fields nested under `progress` key | Flatten — fields at top level of POST body |
| Question not showing | Options are strings, not objects | Use `[{"label": "..."}]` format |
| Question auto-answered | `recommendedAnswer` field present | Omit for interactive testing |
| Success view too brief | Archives after ~5s to history card | Screenshot within 8s of sending completion |
| Pause not triggered from curl | Pause is watch-initiated only | Tap Pause button on watch |
