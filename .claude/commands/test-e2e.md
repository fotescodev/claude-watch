---
description: Comprehensive test suite for Claude Watch - hooks, integration, and E2E flows
allowed-tools: Bash, Read
---

# /test-e2e - Claude Watch Test Suite

Comprehensive test suite covering all Claude Watch V2 components: simulator tests, cloud integration, and end-to-end approval flows.

## Quick Start

```bash
# Run V2 simulator tests (recommended)
./scripts/test-v2-simulator.sh

# Run hook validation
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-hooks.py
```

---

## Happy Path Tests

### 1. Simulator UI Tests (V2 Features)

Tests all V2 views via simulator push notifications. No cloud connection required.

```bash
./scripts/test-v2-simulator.sh
```

**What It Tests:**
| Test | View | Expected Result |
|------|------|-----------------|
| F18 Question | QuestionResponseView | Shows question + "Accept"/"Mac" buttons |
| F16 Context 75% | ContextWarningView | Yellow/info color, "OK" button |
| F16 Context 85% | ContextWarningView | Orange warning color |
| F16 Context 95% | ContextWarningView | Red critical color |
| Single Approval | ActionQueue | Shows approve/reject buttons |
| Multiple Approvals | ApprovalQueueView | Shows queue count + list |

**Output:** Screenshots saved to `/tmp/claude-watch-tests/`

---

### 2. Cloud Integration Test

Tests the full cloud relay flow with a live pairing.

#### Prerequisites Check

```bash
echo "=== Claude Watch E2E Prerequisites ==="

# 1. Check pairing
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  echo "✓ Pairing ID: ${PAIRING_ID:0:8}..."
else
  echo "✗ No pairing - run: npx cc-watch"
  exit 1
fi

# 2. Check cloud server
if curl -s --max-time 5 https://claude-watch.fotescodev.workers.dev/health | grep -q '"status":"ok"'; then
  echo "✓ Cloud server healthy"
else
  echo "✗ Cloud server unreachable"
  exit 1
fi

# 3. Check simulator (optional)
if xcrun simctl list devices 2>/dev/null | grep -qi "watch.*booted"; then
  echo "✓ Watch simulator running"
else
  echo "? No simulator (physical watch may be paired)"
fi

echo ""
echo "Ready for E2E testing!"
```

#### Happy Path: Approval Flow

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "=== E2E Test: Approval Flow ==="
echo "Step 1: Creating approval request..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"bash\",
    \"title\": \"E2E Test: echo hello\",
    \"description\": \"Approve this to verify the flow works.\"
  }")

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Request created: ${REQUEST_ID:0:8}..."
  echo ""
  echo "Step 2: Check your watch for the approval request"
  echo "        → Approve or Reject it"
  echo ""
  echo "Step 3: Run this to verify response:"
  echo "        curl -s 'https://claude-watch.fotescodev.workers.dev/approval/$PAIRING_ID/$REQUEST_ID' | jq .status"
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

#### Happy Path: Question Flow (F18)

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
QUESTION_ID="q-e2e-$(date +%s)"

echo "=== E2E Test: Question Flow (F18) ==="
echo "Step 1: Creating question..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/question" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"questionId\": \"$QUESTION_ID\",
    \"question\": \"E2E Test: Which option should we use?\",
    \"header\": \"Test\",
    \"options\": [
      {\"label\": \"Option A\", \"description\": \"First choice\"},
      {\"label\": \"Option B\", \"description\": \"Second choice (Recommended)\"}
    ],
    \"multiSelect\": false
  }")

if echo "$RESULT" | grep -q '"questionId"'; then
  echo "✓ Question created: $QUESTION_ID"
  echo ""
  echo "Step 2: Check your watch for the question"
  echo "        → Tap 'Accept' to choose recommended, or 'Mac' to handle on desktop"
  echo ""
  echo "Step 3: Run this to verify response:"
  echo "        curl -s 'https://claude-watch.fotescodev.workers.dev/question/$QUESTION_ID/status?pairingId=$PAIRING_ID' | jq ."
else
  echo "✗ Failed to create question"
  echo "$RESULT"
fi
```

#### Happy Path: Progress Flow

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)

echo "=== E2E Test: Progress Flow ==="
echo "Posting progress update..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/progress/$PAIRING_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "currentTask": "E2E Test Task",
    "currentActivity": "Testing progress flow",
    "progress": 0.5,
    "completedCount": 1,
    "totalCount": 2,
    "tasks": [
      {"content": "First task", "status": "completed"},
      {"content": "Second task", "status": "in_progress"}
    ]
  }')

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Progress posted"
  echo ""
  echo "Check watch - should show:"
  echo "  • 'Testing progress flow' activity"
  echo "  • 50% progress bar"
  echo "  • 1/2 task count"
else
  echo "✗ Failed to post progress"
  echo "$RESULT"
fi
```

---

### 3. Simulator Push Notification Tests

Direct push notification tests for the watchOS simulator.

#### Boot Simulator & Launch App

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

# Boot if needed
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
sleep 2

# Install latest build
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClaudeWatch.app" -path "*watchsimulator*" -type d | head -1)
if [ -n "$APP_PATH" ]; then
  xcrun simctl install "$SIMULATOR" "$APP_PATH"
  echo "✓ App installed"
else
  echo "✗ No app found - run xcodebuild first"
fi

# Launch
xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID"
echo "✓ App launched"
```

#### Test: F18 Question Notification

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Claude: Question", "body": "Which approach?"}, "sound": "default"},
  "type": "question",
  "questionId": "q-sim-test",
  "question": "Which authentication approach should we use for the API?",
  "recommendedAnswer": "Use JWT with refresh tokens"
}
EOF

echo "✓ F18 Question notification sent"
echo "  → Watch should show QuestionResponseView"
```

#### Test: F16 Context Warning Notification

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Context Warning", "body": "85% used"}, "sound": "default"},
  "type": "context_warning",
  "percentage": 85,
  "threshold": 85
}
EOF

echo "✓ F16 Context Warning notification sent"
echo "  → Watch should show ContextWarningView with orange color"
```

#### Test: Approval Notification

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Edit main.swift"}, "sound": "default"},
  "type": "approval",
  "requestId": "test-sim-001",
  "title": "Edit main.swift",
  "description": "Add validation function"
}
EOF

echo "✓ Approval notification sent"
echo "  → Watch should show ActionQueue with approve/reject"
```

#### Test: Progress Notification

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"content-available": 1},
  "type": "progress",
  "currentTask": "Refactoring auth",
  "currentActivity": "Updating models",
  "progress": 0.6,
  "completedCount": 3,
  "totalCount": 5,
  "tasks": [
    {"content": "Create models", "status": "completed"},
    {"content": "Add validation", "status": "completed"},
    {"content": "Update tests", "status": "completed"},
    {"content": "Refactor service", "status": "in_progress"},
    {"content": "Update docs", "status": "pending"}
  ]
}
EOF

echo "✓ Progress notification sent"
echo "  → Watch should show WorkingView with task list"
```

---

### 4. Hook Validation Tests

Validates all hooks are properly configured.

```bash
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-hooks.py
```

**What It Checks:**
- Hook files exist and have valid Python syntax
- settings.json has correct matchers
- Cloud endpoints are responding
- E2E flows work (question flow, progress flow)

---

### 5. Watch Approval Hook Unit Tests

```bash
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test_watch_approval.py
```

**Test Coverage:**
| Test | Description |
|------|-------------|
| TestGetPairingId | Env var priority, config file fallback |
| TestMapToolType | Tool type mapping (Bash→bash, Edit→file_edit) |
| TestBuildTitle | Title generation for different tools |
| TestBuildDescription | Description generation |
| TestToolsRequiringApproval | Correct tools in approval set |

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| Notification not showing | App not in foreground | Tap notification banner or check app |
| View doesn't change | State not updating | Check if demo mode is enabled |
| Cloud request fails | No pairing | Run `npx cc-watch` to pair |
| Simulator push fails | App not installed | Run `xcodebuild` then install |
| "Session ended" | Watch ended session | Re-pair via watch app |

---

## Clean Up

```bash
# Clear test files
rm -f /tmp/e2e-test-* /tmp/claude-watch-* /tmp/test-notif.json

# Clear simulator screenshots
rm -rf /tmp/claude-watch-tests

echo "✓ Test state cleaned up"
```

---

## When to Run

| Scenario | What to Run |
|----------|-------------|
| Before TestFlight | `./scripts/test-v2-simulator.sh` + hook tests |
| After hook changes | `python3 .claude/hooks/test-hooks.py` |
| Verify cloud pairing | Cloud integration tests |
| Quick UI check | Simulator push notification tests |
| Part of /ship-check | Hook validation |
