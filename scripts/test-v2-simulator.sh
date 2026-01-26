#!/bin/bash
# V2 Simulator Test Suite
# Automated testing for Claude Watch V2 features
#
# Usage: ./scripts/test-v2-simulator.sh [--screenshots-dir DIR]

set -e

SIMULATOR="Apple Watch Series 11 (46mm)"
BUNDLE_ID="com.edgeoftrust.claudewatch"
SCREENSHOTS_DIR="${1:-/tmp/claude-watch-tests}"
DELAY=3

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

mkdir -p "$SCREENSHOTS_DIR"

echo "========================================"
echo "Claude Watch V2 Simulator Test Suite"
echo "========================================"
echo "Simulator: $SIMULATOR"
echo "Screenshots: $SCREENSHOTS_DIR"
echo ""

# Helper functions
take_screenshot() {
    local name="$1"
    local path="$SCREENSHOTS_DIR/${name}.png"
    xcrun simctl io "$SIMULATOR" screenshot "$path" 2>/dev/null
    echo "  📸 Saved: $path"
}

send_notification() {
    local payload="$1"
    echo "$payload" | xcrun simctl push "$SIMULATOR" "$BUNDLE_ID" - 2>/dev/null
}

wait_and_screenshot() {
    local name="$1"
    local wait="${2:-$DELAY}"
    sleep "$wait"
    take_screenshot "$name"
}

test_passed() {
    echo -e "${GREEN}✓ PASSED${NC}: $1"
}

test_info() {
    echo -e "${YELLOW}ℹ INFO${NC}: $1"
}

# Boot simulator if needed
echo "1. Checking simulator status..."
SIM_STATE=$(xcrun simctl list devices | grep "$SIMULATOR" | grep -o "(Booted)\|(Shutdown)" | head -1)
if [ "$SIM_STATE" != "(Booted)" ]; then
    echo "   Booting simulator..."
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    sleep 5
fi
test_passed "Simulator ready"

# Check if app is installed
echo ""
echo "2. Checking app installation..."
if xcrun simctl listapps "$SIMULATOR" 2>/dev/null | grep -q "$BUNDLE_ID"; then
    test_passed "App installed"
else
    echo -e "${RED}✗ FAILED${NC}: App not installed. Run 'xcodebuild' first."
    exit 1
fi

# Launch app
echo ""
echo "3. Launching app..."
xcrun simctl launch "$SIMULATOR" "$BUNDLE_ID" 2>/dev/null
sleep 2
take_screenshot "01-app-launched"
test_passed "App launched"

# Test: Basic notification delivery
echo ""
echo "4. Testing notification delivery..."
send_notification '{
  "aps": {"alert": {"title": "Test", "body": "Notification test"}, "sound": "default"}
}'
wait_and_screenshot "02-notification-test" 2
test_passed "Notification sent"

# Test: F18 Question Response (V2 - Binary options, NO Mac escape)
echo ""
echo "5. Testing F18: Question Response (V2 Binary)..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Question", "body": "Which database?"}, "sound": "default"},
  "questionId": "q-test-001",
  "type": "question",
  "question": "Which database should we use for the API?",
  "options": [
    {"label": "PostgreSQL", "description": "Recommended for production"},
    {"label": "SQLite", "description": "Simpler for development"}
  ],
  "recommendedAnswer": "PostgreSQL"
}'
wait_and_screenshot "03-f18-question-response"
test_info "Check: 2 option buttons (NO 'Handle on Mac' in V2), double tap hint"

# Test: F16 Context Warning (75%)
echo ""
echo "6. Testing F16: Context Warning 75%..."
send_notification '{
  "aps": {"alert": {"title": "Context Notice", "body": "75% context used"}, "sound": "default"},
  "type": "context_warning",
  "percentage": 75,
  "threshold": 75
}'
wait_and_screenshot "04-f16-context-75"
test_info "Check screenshot for ContextWarningView at 75%"

# Test: F16 Context Warning (85%)
echo ""
echo "7. Testing F16: Context Warning 85%..."
send_notification '{
  "aps": {"alert": {"title": "Context Warning", "body": "85% context used"}, "sound": "default"},
  "type": "context_warning",
  "percentage": 85,
  "threshold": 85
}'
wait_and_screenshot "05-f16-context-85"
test_info "Check screenshot for ContextWarningView at 85% (orange)"

# Test: F16 Context Warning (95%)
echo ""
echo "8. Testing F16: Context Warning 95%..."
send_notification '{
  "aps": {"alert": {"title": "Context Critical", "body": "95% context used"}, "sound": "default"},
  "type": "context_warning",
  "percentage": 95,
  "threshold": 95
}'
wait_and_screenshot "06-f16-context-95"
test_info "Check screenshot for ContextWarningView at 95% (red)"

# Test: Tier 1 Approval (Low Risk - Green)
echo ""
echo "9. Testing V2 Tier 1 Approval (Low Risk)..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Read config.json"}, "sound": "default"},
  "requestId": "test-tier1-001",
  "type": "approval",
  "actionType": "Read",
  "title": "Read config.json",
  "description": "Reading configuration file"
}'
wait_and_screenshot "07-tier1-approval"
test_info "Check: GREEN card, [Approve]+[Reject] buttons, double tap approves"

# Test: Tier 2 Approval (Medium Risk - Orange)
echo ""
echo "10. Testing V2 Tier 2 Approval (Medium Risk)..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "npm install lodash"}, "sound": "default"},
  "requestId": "test-tier2-001",
  "type": "approval",
  "actionType": "Bash",
  "command": "npm install lodash",
  "title": "npm install lodash",
  "description": "Installing npm package"
}'
wait_and_screenshot "08-tier2-approval"
test_info "Check: ORANGE card, [Approve]+[Reject] buttons, double tap approves"

# Test: Tier 3 Approval (Dangerous - Red, NO Approve)
echo ""
echo "11. Testing V2 Tier 3 Approval (DANGEROUS)..."
send_notification '{
  "aps": {"alert": {"title": "⚠️ DANGER", "body": "rm -rf ./build"}, "sound": "default"},
  "requestId": "test-tier3-001",
  "type": "approval",
  "actionType": "Bash",
  "command": "rm -rf ./build",
  "title": "rm -rf ./build",
  "description": "Delete build directory"
}'
wait_and_screenshot "09-tier3-approval"
test_info "Check: RED card, [Reject]+[Remind 5m] ONLY, NO approve, 'Approve requires Mac' hint"

# Test: Multiple approvals (queue with mixed tiers)
echo ""
echo "12. Testing Approval Queue (mixed tiers)..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Edit AuthService.ts"}, "sound": "default"},
  "requestId": "test-queue-001",
  "type": "approval",
  "actionType": "Edit",
  "title": "Edit AuthService.ts",
  "description": "Update authentication"
}'
sleep 1
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "npm install"}, "sound": "default"},
  "requestId": "test-queue-002",
  "type": "approval",
  "actionType": "Bash",
  "command": "npm install express",
  "title": "npm install express",
  "description": "Install dependencies"
}'
wait_and_screenshot "10-approval-queue"
test_info "Check: ApprovalQueueView with tier indicators"

# Summary
echo ""
echo "========================================"
echo "V2 Test Suite Complete"
echo "========================================"
echo ""
echo "Screenshots saved to: $SCREENSHOTS_DIR"
echo ""
echo "Manual verification needed:"
echo ""
echo "F18 Question (V2):"
echo "  - 03-f18-question-response.png: 2 option buttons, NO 'Handle on Mac'"
echo ""
echo "F16 Context Warnings:"
echo "  - 04-f16-context-75.png: 75% with info color"
echo "  - 05-f16-context-85.png: 85% with orange color"
echo "  - 06-f16-context-95.png: 95% with red color"
echo ""
echo "V2 Tiered Approvals:"
echo "  - 07-tier1-approval.png: GREEN card, Approve+Reject, swipe enabled"
echo "  - 08-tier2-approval.png: ORANGE card, Approve+Reject, swipe enabled"
echo "  - 09-tier3-approval.png: RED card, Reject+Remind ONLY, 'Approve requires Mac'"
echo "  - 10-approval-queue.png: Queue with tier indicators"
echo ""
echo "V2 Key Behaviors to Verify:"
echo "  • Tier 1-2: Double tap = Approve, swipe gestures enabled"
echo "  • Tier 3: Double tap = REJECT, swipe DISABLED, no approve button"
echo "  • F18: Binary choice only (no Mac escape in V2)"
echo "  • Idle: Breathing animation (if visible)"
echo ""
echo "Open screenshots:"
echo "  open $SCREENSHOTS_DIR"
