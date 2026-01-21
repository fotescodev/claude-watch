---
description: Comprehensive test suite for Claude Watch - hooks, integration, and E2E flows
allowed-tools: Bash, Read
---

# /test-e2e - Claude Watch Test Suite

Comprehensive test suite covering all Claude Watch components: hook validation, unit tests, integration tests, and end-to-end approval flows.

## Quick Start

```bash
# Run ALL tests
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-hooks.py && \
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test_watch_approval.py && \
cd /Users/dfotesco/claude-watch/claude-watch/claude-watch-npm && npx tsx --test src/__tests__/stdin-proxy.test.ts
```

---

## Test Categories

### 1. Hook Validation Tests

Validates all Claude Watch hooks are properly configured before deploying.

```bash
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-hooks.py
```

**What It Checks:**
- Hook files exist (`watch-approval-cloud.py`, `progress-tracker.py`)
- Python syntax valid
- `settings.json` matchers include all tools (Bash, Write, Edit, MultiEdit, AskUserQuestion, TodoWrite)
- Hook handlers match declared tools
- Cloud endpoints responding (9 endpoints)
- E2E flows: question flow, progress flow

**Expected Output:**
```
============================================================
Claude Watch Hook Validation Tests
============================================================

1. Loading settings.json...
  ✓ PASS: settings.json exists

2. Checking hook files...
  ✓ PASS: watch-approval-cloud.py exists
  ...

6. Running end-to-end flow tests...
  ✓ PASS: Question flow (create → pending → answer → answered)
  ✓ PASS: Progress flow (post → retrieve)

============================================================
All tests passed! Ready to deploy.
============================================================
```

---

### 2. Watch Approval Hook Unit Tests

Tests the `watch-approval-cloud.py` hook logic.

```bash
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test_watch_approval.py
```

**Test Coverage:**
| Test Class | What It Tests |
|------------|---------------|
| `TestGetPairingId` | Env var priority, config file fallback, empty handling |
| `TestMapToolType` | Tool type mapping (Bash→bash, Edit→file_edit, etc.) |
| `TestBuildTitle` | Title generation for different tools |
| `TestBuildDescription` | Description generation |
| `TestToolsRequiringApproval` | Correct tools in approval set |
| `TestMainBehavior` | Skip non-approval tools, graceful exit when unconfigured |

---

### 3. Question Parsing Unit Tests (stdin-proxy)

Tests the question parsing logic that detects Claude's AskUserQuestion UI patterns.

```bash
cd /Users/dfotesco/claude-watch/claude-watch/claude-watch-npm && npx tsx --test src/__tests__/stdin-proxy.test.ts
```

**Test Coverage:**
- Problem question format (`❯ Problem` header)
- Auth method question format
- Simple `?` format
- Non-question output returns null
- Insufficient options returns null

---

### 4. Live E2E Approval Flow Test

Interactive test for the complete watch approval flow after pairing.

#### Prerequisites

```bash
# 1. Check session is active (must be running via cc-watch)
echo "=== Session Check ==="
if [ "$CLAUDE_WATCH_SESSION_ACTIVE" = "1" ]; then
  echo "✓ CLAUDE_WATCH_SESSION_ACTIVE=1 (cc-watch session)"
else
  echo "✗ CLAUDE_WATCH_SESSION_ACTIVE not set - are you running via cc-watch?"
fi

# 2. Check pairing ID exists
echo -e "\n=== Pairing Check ==="
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  echo "✓ Pairing ID: ${PAIRING_ID:0:8}..."
else
  echo "✗ No pairing ID found - run pairing flow first"
fi

# 3. Check hooks are enabled
echo -e "\n=== Hooks Check ==="
SETTINGS_FILE="/Users/dfotesco/claude-watch/claude-watch/.claude/settings.json"
if jq -e '.hooks.PreToolUse | length > 0' "$SETTINGS_FILE" >/dev/null 2>&1; then
  echo "✓ PreToolUse hooks enabled"
else
  echo "✗ PreToolUse hooks DISABLED - watch approvals won't work!"
fi

# 4. Check watch simulator
echo -e "\n=== Watch Check ==="
if xcrun simctl list devices 2>/dev/null | grep -qi "watch.*booted"; then
  echo "✓ Watch simulator running"
else
  echo "? No watch simulator detected (physical watch may be paired)"
fi

# 5. Check cloud server
echo -e "\n=== Cloud Server ==="
if curl -s --max-time 5 https://claude-watch.fotescodev.workers.dev/health | grep -q '"status":"ok"'; then
  echo "✓ Cloud server healthy"
else
  echo "✗ Cloud server unreachable"
fi
```

#### Send Test Approval Request

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "Sending test approval request to watch..."
# NOTE: Uses POST /approval (not /request) with 'id' field (not 'requestId')
RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"bash\",
    \"title\": \"E2E Test: echo hello\",
    \"description\": \"Test request from /test-e2e. Approve to verify the flow works.\"
  }")

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Request created: $REQUEST_ID"
  echo "  → Check your watch for the approval request"
  echo "$REQUEST_ID" > /tmp/e2e-test-request-id
  echo "$PAIRING_ID" > /tmp/e2e-test-pairing-id
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

#### Verify Response (After Watch Action)

```bash
REQUEST_ID=$(cat /tmp/e2e-test-request-id 2>/dev/null)
PAIRING_ID=$(cat /tmp/e2e-test-pairing-id 2>/dev/null)

if [ -z "$REQUEST_ID" ] || [ -z "$PAIRING_ID" ]; then
  echo "✗ No test request ID found. Run the send step first."
  exit 1
fi

echo "Checking response for request: $REQUEST_ID"
# NOTE: Uses GET /approval/:pairingId/:requestId (not /request/:id)
RESULT=$(curl -s "https://claude-watch.fotescodev.workers.dev/approval/$PAIRING_ID/$REQUEST_ID")

STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null)

echo ""
if [ "$STATUS" = "approved" ]; then
  echo "════════════════════════════════════════"
  echo "  ✓ E2E TEST PASSED - Approval received!"
  echo "════════════════════════════════════════"
elif [ "$STATUS" = "rejected" ]; then
  echo "════════════════════════════════════════"
  echo "  ✓ E2E TEST PASSED - Rejection received!"
  echo "════════════════════════════════════════"
elif [ "$STATUS" = "pending" ]; then
  echo "⏳ Request still pending - waiting for watch response"
  echo "   Approve or reject on your watch, then run this step again"
else
  echo "✗ Unexpected status: $STATUS"
  echo "$RESULT"
fi

rm -f /tmp/e2e-test-request-id /tmp/e2e-test-pairing-id
```

---

### 5. Interactive Question E2E Test (Recommended)

**Full round-trip test**: question → watch display → user selects option → answer returns to terminal.

```bash
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-question-e2e.py
```

**What It Does:**
1. Creates a test question with 3 options (A, B, C)
2. Sends it to your paired watch
3. Waits for you to select an option on the watch
4. Verifies the answer comes back correctly

**Options:**
- `--timeout 60` - How long to wait for watch response (default: 60s)

**Expected Output:**
```
============================================================
  Claude Watch Question Flow E2E Test
============================================================

[Step 1] Checking pairing configuration...
  ✓ Pairing ID: abc12345...

[Step 2] Creating test question...
  ✓ Question created: q_xyz789

[Step 3] Question sent to watch!
    On your Apple Watch, you should see:
    ┌─────────────────────────────────┐
    │  E2E Test                       │
    │  Which option do you want...    │
    │  ○ Option A                     │
    │  ○ Option B                     │
    │  ○ Option C                     │
    └─────────────────────────────────┘

[Step 4] Waiting for watch response (timeout: 60s)...
  ⏳ Polling.......
  ✓ Answer received!

    Selected option(s):
      → Option B

============================================================
  E2E TEST PASSED
============================================================
  ✓ Question created successfully
  ✓ Watch received and displayed question
  ✓ User selected: Option B
  ✓ Answer received back at terminal

  The full question→watch→terminal flow is working!
```

---

### 6. Basic Question Flow Test (API Only)

Quick API-level test without waiting for watch interaction.

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)

# Create a test question
RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/question" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"type\": \"question\",
    \"question\": \"E2E Test: Which option?\",
    \"header\": \"Test\",
    \"options\": [
      {\"label\": \"Option A\", \"description\": \"First choice\"},
      {\"label\": \"Option B\", \"description\": \"Second choice\"}
    ],
    \"multiSelect\": false
  }")

QUESTION_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('questionId',''))" 2>/dev/null)

if [ -n "$QUESTION_ID" ]; then
  echo "✓ Question created: $QUESTION_ID"
  echo "  → Check watch for question"
else
  echo "✗ Failed: $RESULT"
fi
```

---

### 7. Simulator Testing

For testing on watchOS simulator without a physical watch.

#### Boot Simulator

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
open -a Simulator
```

#### Install App

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClaudeWatch.app" -path "*watchsimulator*" | head -1)
xcrun simctl install "Apple Watch Series 11 (46mm)" "$APP_PATH"
```

#### Send Push Notification (Simulator)

```bash
cat > /tmp/test-notif.json << 'EOF'
{
  "aps": {
    "alert": {
      "title": "Claude: file edit",
      "body": "Edit example.swift",
      "subtitle": "Test notification"
    },
    "sound": "default",
    "category": "CLAUDE_ACTION"
  },
  "requestId": "test-001",
  "type": "file_edit"
}
EOF

xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/test-notif.json
```

#### Configure Cloud Mode (Required for Simulator)

```bash
DEVICE_ID=$(xcrun simctl list devices | grep "Apple Watch Series 11 (46mm)" | grep -oE "[0-9A-F-]{36}")
xcrun simctl spawn "$DEVICE_ID" defaults write com.edgeoftrust.claudewatch useCloudMode -bool true
```

---

### 8. Direct Hook Test

Test the PreToolUse hook directly:

```bash
echo '{"tool_name": "Bash", "tool_input": {"command": "echo test"}}' | \
  python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/watch-approval-cloud.py
```

**Expected on Approve:**
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
```

**Expected on Reject:** Exit code 2

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No notification on watch | Hooks disabled | Check `.claude/settings.json` PreToolUse array |
| Request created but watch shows nothing | APNs issue | Try `xcrun simctl push` directly |
| Approval not blocking Claude | Env var not set | Ensure running via `npx cc-watch` |
| "Session ended" message | Watch ended session | Re-pair or tap Resume on watch |
| Hook tests fail | Cloud server down | Check https://claude-watch.fotescodev.workers.dev/health |

---

## Clean Up Test State

```bash
rm -f /tmp/e2e-test-* /tmp/claude-watch-* /tmp/test-notif.json
echo "Test state cleaned up"
```

---

## When to Run

| Scenario | What to Run |
|----------|-------------|
| Before TestFlight/App Store | Full suite (all tests) |
| After modifying hook files | Hook validation + unit tests |
| After npm package changes | stdin-proxy tests |
| Verifying watch integration | Interactive Question E2E (`test-question-e2e.py`) |
| Testing question/answer flow | Interactive Question E2E (`test-question-e2e.py`) |
| Part of `/ship-check` | Hook validation |
