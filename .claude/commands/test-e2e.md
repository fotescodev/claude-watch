---
description: Comprehensive test suite for Claude Watch - hooks, integration, and E2E flows
allowed-tools: Bash, Read
---

# /test-e2e - Claude Watch Test Suite

Comprehensive test suite covering all Claude Watch V2 components: simulator tests, cloud integration, and end-to-end approval flows.

## Quick Start

```bash
# Run V2 simulator tests (fast, no cloud)
./scripts/test-v2-simulator.sh

# Run interactive cloud tests (waits for watch response at each step)
./scripts/test-v2-cloud.sh

# Run hook validation
python3 /Users/dfotesco/claude-watch/claude-watch/.claude/hooks/test-hooks.py
```

---

## Interactive Cloud Tests (NEW)

**Best for verifying real watch behavior.** Sends requests through cloud relay and waits for you to interact with your watch at each step.

```bash
./scripts/test-v2-cloud.sh
```

**What It Tests (with user confirmation at each step):**
| Test | What Happens | You Verify |
|------|--------------|------------|
| Tier 1 Approval | Creates Read request | Green card, approve/reject buttons |
| Tier 2 Approval | Creates npm install request | Orange card, approve/reject buttons |
| Tier 3 Approval | Creates rm -rf request | Red card, reject only, "requires Mac" hint |
| Question Flow | Creates binary question | 2 option buttons, no Mac escape |
| Context Warning | Posts 85% warning | Orange warning view |
| Progress Update | Posts task progress | Working view with task list |
| Approval Queue | Creates 3 pending requests | Queue view with tier colors |

**Requirements:**
- Active pairing (run `npx cc-watch` first)
- Watch connected (simulator or physical)
- Cloud server healthy

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
| F18 Question | QuestionResponseView | Shows question + binary option buttons (NO Mac escape) |
| F16 Context 75% | ContextWarningView | Yellow/info color, "OK" button |
| F16 Context 85% | ContextWarningView | Orange warning color |
| F16 Context 95% | ContextWarningView | Red critical color |
| Tier 1 Approval | TieredActionCard | Green card, Approve + Reject buttons, double tap approves |
| Tier 2 Approval | TieredActionCard | Orange card, Approve + Reject buttons, double tap approves |
| Tier 3 Approval | TieredActionCard | Red card, Reject + "Remind 5m" only, double tap REJECTS, "Approve requires Mac" hint |
| Swipe Gesture | SwipeActionCard | Tier 1-2: swipe enabled; Tier 3: swipe disabled |
| Emergency Stop | ActionButtonHandler | Long press shows confirmation, executes emergency stop |
| Breathing Animation | IdleView | 3s ease-in-out cycle (disabled with Reduce Motion) |

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

#### Happy Path: Tiered Approval Flow (V2)

**V2 Tier System:**
| Tier | Color | Double Tap | Buttons | Watch Approve? |
|------|-------|------------|---------|----------------|
| 1 (Low) | Green | Approve | Approve / Reject | Yes |
| 2 (Medium) | Orange | Approve | Approve / Reject | Yes |
| 3 (Dangerous) | Red | **Reject** | Reject / Remind 5m | **NO** |

##### Test: Tier 1 (Low Risk - Green)

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "=== E2E Test: Tier 1 Approval (Low Risk) ==="
echo "Step 1: Creating low-risk approval request (Read file)..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Read\",
    \"title\": \"Read config.json\",
    \"description\": \"Reading configuration file\"
  }")

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Request created: ${REQUEST_ID:0:8}..."
  echo ""
  echo "Step 2: Check your watch - should show:"
  echo "        → GREEN card background"
  echo "        → [Approve] + [Reject] buttons"
  echo "        → Double tap = Approve"
  echo "        → Swipe right = Approve, left = Reject"
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

##### Test: Tier 2 (Medium Risk - Orange)

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "=== E2E Test: Tier 2 Approval (Medium Risk) ==="
echo "Step 1: Creating medium-risk approval request (npm install)..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"npm install lodash\",
    \"title\": \"npm install lodash\",
    \"description\": \"Installing npm package\"
  }")

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Request created: ${REQUEST_ID:0:8}..."
  echo ""
  echo "Step 2: Check your watch - should show:"
  echo "        → ORANGE card background"
  echo "        → [Approve] + [Reject] buttons"
  echo "        → Double tap = Approve"
  echo "        → Swipe right = Approve, left = Reject"
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

##### Test: Tier 3 (Dangerous - Red, NO Watch Approve)

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

echo "=== E2E Test: Tier 3 Approval (DANGEROUS) ==="
echo "Step 1: Creating dangerous approval request (rm -rf)..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"rm -rf ./build\",
    \"title\": \"rm -rf ./build\",
    \"description\": \"Deleting build directory\"
  }")

if echo "$RESULT" | grep -q '"success":true'; then
  echo "✓ Request created: ${REQUEST_ID:0:8}..."
  echo ""
  echo "Step 2: Check your watch - should show:"
  echo "        → RED card background"
  echo "        → [Reject] + [Remind 5m] buttons ONLY (no Approve!)"
  echo "        → Double tap = REJECT (safety default)"
  echo "        → Swipe DISABLED for Tier 3"
  echo "        → 'Approve requires Mac' hint text"
  echo ""
  echo "IMPORTANT: Cannot approve Tier 3 from watch - must use Mac!"
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

#### Happy Path: Question Flow (F18 - Binary Options)

**V2 Behavior:** Watch shows max 2 options as buttons. No "Handle on Mac" escape.

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
QUESTION_ID="q-e2e-$(date +%s)"

echo "=== E2E Test: Question Flow (F18 - V2 Binary) ==="
echo "Step 1: Creating question with 2 options..."

RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/question" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"questionId\": \"$QUESTION_ID\",
    \"question\": \"E2E Test: Which database should we use?\",
    \"header\": \"Database\",
    \"options\": [
      {\"label\": \"PostgreSQL\", \"description\": \"Recommended for production\"},
      {\"label\": \"SQLite\", \"description\": \"Simpler for development\"}
    ],
    \"multiSelect\": false
  }")

if echo "$RESULT" | grep -q '"questionId"'; then
  echo "✓ Question created: $QUESTION_ID"
  echo ""
  echo "Step 2: Check your watch for the question"
  echo "        → Shows 2 buttons: [PostgreSQL (Recommended)] [SQLite]"
  echo "        → Double tap selects recommended option"
  echo "        → NO 'Handle on Mac' button (removed in V2)"
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

#### Test: F18 Question Notification (V2 Binary)

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Claude: Question", "body": "Which database?"}, "sound": "default"},
  "type": "question",
  "questionId": "q-sim-test",
  "question": "Which database should we use?",
  "options": [
    {"label": "PostgreSQL", "description": "Recommended for production"},
    {"label": "SQLite", "description": "Simpler for development"}
  ],
  "recommendedAnswer": "PostgreSQL"
}
EOF

echo "✓ F18 Question notification sent"
echo "  → Watch should show QuestionResponseView with:"
echo "    • 2 option buttons (max shown on watch)"
echo "    • First option marked as (Recommended)"
echo "    • NO 'Handle on Mac' button (V2 removed)"
echo "    • Double tap selects recommended option"
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

#### Test: Tiered Approval Notifications

##### Tier 1 (Low Risk - Green)

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Read config.json"}, "sound": "default"},
  "type": "approval",
  "requestId": "test-tier1-001",
  "actionType": "Read",
  "title": "Read config.json",
  "description": "Reading configuration file"
}
EOF

echo "✓ Tier 1 (Low Risk) notification sent"
echo "  → Watch should show TieredActionCard with:"
echo "    • GREEN card background"
echo "    • [Approve] + [Reject] buttons"
echo "    • Double tap = Approve"
echo "    • Swipe gestures enabled"
```

##### Tier 2 (Medium Risk - Orange)

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "Claude: Approval", "body": "npm install lodash"}, "sound": "default"},
  "type": "approval",
  "requestId": "test-tier2-001",
  "actionType": "Bash",
  "command": "npm install lodash",
  "title": "npm install lodash",
  "description": "Installing npm package"
}
EOF

echo "✓ Tier 2 (Medium Risk) notification sent"
echo "  → Watch should show TieredActionCard with:"
echo "    • ORANGE card background"
echo "    • [Approve] + [Reject] buttons"
echo "    • Double tap = Approve"
echo "    • Swipe gestures enabled"
```

##### Tier 3 (Dangerous - Red, NO Approve)

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - <<'EOF'
{
  "aps": {"alert": {"title": "⚠️ DANGER", "body": "rm -rf ./build"}, "sound": "default"},
  "type": "approval",
  "requestId": "test-tier3-001",
  "actionType": "Bash",
  "command": "rm -rf ./build",
  "title": "rm -rf ./build",
  "description": "Delete build directory"
}
EOF

echo "✓ Tier 3 (DANGEROUS) notification sent"
echo "  → Watch should show TieredActionCard with:"
echo "    • RED card background"
echo "    • [Reject] + [Remind 5m] buttons ONLY (no Approve!)"
echo "    • Double tap = REJECT (safety default)"
echo "    • Swipe gestures DISABLED"
echo "    • 'Approve requires Mac' hint text"
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

#### Test: Idle State - Breathing Animation (V2)

```bash
SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"

# Just launch the app in idle state
xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID"

echo "✓ App launched in idle state"
echo "  → Watch should show V2 idle design with:"
echo "    • BreathingLogo - 3s ease-in-out animation cycle"
echo "    • 'Ready' text"
echo "    • 'Waiting for activity' subtitle"
echo "    • Pairing ID at bottom"
echo ""
echo "  To test Reduce Motion:"
echo "    Settings > Accessibility > Reduce Motion = ON"
echo "    • Animation should be static (no breathing)"
```

#### Test: Emergency Stop (Long Press)

**Prerequisites**: Have an active session with pending actions

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)

echo "=== E2E Test: Emergency Stop ==="
echo ""
echo "Step 1: Create some pending actions first..."

# Create a Tier 1 action
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"estop-test-1\",
    \"type\": \"Read\",
    \"title\": \"Read file.txt\",
    \"description\": \"Test action 1\"
  }" > /dev/null

# Create a Tier 2 action
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"estop-test-2\",
    \"type\": \"Bash\",
    \"command\": \"npm install\",
    \"title\": \"npm install\",
    \"description\": \"Test action 2\"
  }" > /dev/null

echo "✓ Created 2 pending actions"
echo ""
echo "Step 2: On the watch, perform LONG PRESS (Action Button)"
echo "        → Should show EmergencyStopAlert confirmation"
echo ""
echo "Step 3: Tap 'Stop' to confirm emergency stop"
echo "        → All pending requests rejected"
echo "        → Session ended"
echo "        → Failure haptic"
echo "        → Returns to unpaired state"
echo ""
echo "Expected behavior:"
echo "  • Long press shows confirmation dialog"
echo "  • 'Cancel' dismisses dialog"
echo "  • 'Stop' executes emergency stop"
echo "  • Haptic feedback on stop"
```

#### Test: Swipe Gestures (V2)

**Test swipe-to-approve/reject functionality:**

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)

echo "=== E2E Test: Swipe Gestures ==="
echo ""
echo "Step 1: Create Tier 1 action (swipe ENABLED)..."

curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"swipe-test-1\",
    \"type\": \"Edit\",
    \"title\": \"Edit config.json\",
    \"description\": \"Swipe test - Tier 1\"
  }" > /dev/null

echo "✓ Tier 1 action created"
echo "  → Test: Swipe RIGHT → GREEN fill → Approve"
echo "  → Test: Swipe LEFT → RED fill → Reject"
echo "  → Test: 50% threshold triggers haptic"
echo "  → Test: Release before threshold cancels"
echo ""
echo "Step 2: Create Tier 3 action (swipe DISABLED)..."

curl -s -X POST "https://claude-watch.fotescodev.workers.dev/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"swipe-test-3\",
    \"type\": \"Bash\",
    \"command\": \"rm -rf ./build\",
    \"title\": \"rm -rf ./build\",
    \"description\": \"Swipe test - Tier 3 (DISABLED)\"
  }" > /dev/null

echo "✓ Tier 3 action created"
echo "  → Test: Swipe gestures should be DISABLED"
echo "  → Card should NOT move on swipe"
echo "  → Must use buttons: [Reject] or [Remind 5m]"
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
| Breathing animation not showing | Old build | Rebuild and reinstall app |
| Swipe not working | Tier 3 action | Swipe disabled for Tier 3 (safety) |
| Can't approve Tier 3 | Expected behavior | Tier 3 requires Mac approval |
| Double tap rejects | Tier 3 action | Tier 3 double tap = reject (safety) |
| Only 2 question options shown | Expected V2 behavior | Watch shows max 2 options |
| No "Handle on Mac" button | Expected V2 behavior | Removed in V2 - binary choice only |

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
