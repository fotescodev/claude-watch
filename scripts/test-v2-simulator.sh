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

# Test: F18 Question Response
echo ""
echo "5. Testing F18: Question Response..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Question", "body": "Which auth approach?"}, "sound": "default"},
  "questionId": "q-test-001",
  "type": "question",
  "question": "Which authentication approach should we use for the API?",
  "recommendedAnswer": "Use JWT with refresh tokens"
}'
wait_and_screenshot "03-f18-question-response"
test_info "Check screenshot for QuestionResponseView with Accept/Mac buttons"

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

# Test: Approval notification
echo ""
echo "9. Testing Approval Request..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Edit main.swift"}, "sound": "default"},
  "requestId": "test-approval-001",
  "type": "approval",
  "title": "Edit main.swift",
  "description": "Add validation function"
}'
wait_and_screenshot "07-approval-request"
test_info "Check screenshot for approval view"

# Test: Multiple approvals (queue)
echo ""
echo "10. Testing Approval Queue (2+ pending)..."
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Create AuthService.ts"}, "sound": "default"},
  "requestId": "test-approval-002",
  "type": "approval",
  "title": "Create AuthService.ts",
  "description": "New authentication service"
}'
sleep 1
send_notification '{
  "aps": {"alert": {"title": "Claude: Approval", "body": "Run npm install"}, "sound": "default"},
  "requestId": "test-approval-003",
  "type": "approval",
  "title": "Run npm install",
  "description": "Install dependencies"
}'
wait_and_screenshot "08-approval-queue"
test_info "Check screenshot for ApprovalQueueView with multiple items"

# Summary
echo ""
echo "========================================"
echo "Test Suite Complete"
echo "========================================"
echo ""
echo "Screenshots saved to: $SCREENSHOTS_DIR"
echo ""
echo "Manual verification needed:"
echo "  - 03-f18-question-response.png: Shows Accept/Mac buttons"
echo "  - 04-f16-context-75.png: Shows 75% with info color"
echo "  - 05-f16-context-85.png: Shows 85% with orange color"
echo "  - 06-f16-context-95.png: Shows 95% with red color"
echo "  - 07-approval-request.png: Shows approval view"
echo "  - 08-approval-queue.png: Shows queue with 3+ items"
echo ""
echo "Open screenshots:"
echo "  open $SCREENSHOTS_DIR"
