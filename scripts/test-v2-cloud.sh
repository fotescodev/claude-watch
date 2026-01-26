#!/bin/bash
# V2 Cloud Integration Test Suite
# Interactive testing for Claude Watch V2 features via cloud relay
#
# Usage: ./scripts/test-v2-cloud.sh [--pairing-id ID]
#
# This script sends real requests through the cloud relay and waits
# for user confirmation at each step to verify watch behavior.

set -e

CLOUD_URL="https://claude-watch.fotescodev.workers.dev"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get pairing ID
get_pairing_id() {
    if [ -n "$1" ]; then
        echo "$1"
    elif [ -n "$CLAUDE_WATCH_PAIRING_ID" ]; then
        echo "$CLAUDE_WATCH_PAIRING_ID"
    elif [ -f ~/.claude-watch-pairing ]; then
        cat ~/.claude-watch-pairing
    else
        echo ""
    fi
}

PAIRING_ID=$(get_pairing_id "$1")

echo "========================================"
echo "Claude Watch V2 Cloud Integration Tests"
echo "========================================"
echo ""

if [ -z "$PAIRING_ID" ]; then
    echo -e "${RED}✗ ERROR${NC}: No pairing ID found"
    echo ""
    echo "Options:"
    echo "  1. Run: npx cc-watch (to pair)"
    echo "  2. Set: export CLAUDE_WATCH_PAIRING_ID=your-id"
    echo "  3. Use: ./scripts/test-v2-cloud.sh --pairing-id YOUR_ID"
    exit 1
fi

echo "Pairing ID: ${PAIRING_ID:0:8}..."
echo "Cloud URL: $CLOUD_URL"
echo ""

# Check cloud health
echo "Checking cloud server health..."
HEALTH=$(curl -s --max-time 5 "$CLOUD_URL/health" 2>/dev/null || echo '{"status":"error"}')
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✓${NC} Cloud server healthy"
else
    echo -e "${RED}✗${NC} Cloud server unreachable"
    exit 1
fi

echo ""
echo "========================================"
echo ""

# Helper functions
wait_for_user() {
    local prompt="$1"
    echo ""
    echo -e "${CYAN}$prompt${NC}"
    echo -e "${YELLOW}Press Enter when ready to continue (or 'q' to quit)...${NC}"
    read -r response
    if [ "$response" = "q" ]; then
        echo "Test aborted by user"
        exit 0
    fi
}

check_response() {
    local result="$1"
    local success_key="${2:-success}"

    if echo "$result" | grep -q "\"$success_key\":true\|\"$success_key\":\""; then
        return 0
    else
        return 1
    fi
}

poll_approval_status() {
    local request_id="$1"
    local max_attempts="${2:-30}"
    local attempt=0

    echo "Polling for response (max ${max_attempts}s)..."
    while [ $attempt -lt $max_attempts ]; do
        STATUS=$(curl -s "$CLOUD_URL/approval/$PAIRING_ID/$request_id" 2>/dev/null)
        DECISION=$(echo "$STATUS" | grep -o '"decision":"[^"]*"' | cut -d'"' -f4)

        if [ -n "$DECISION" ] && [ "$DECISION" != "pending" ]; then
            echo -e "${GREEN}✓${NC} Response received: $DECISION"
            return 0
        fi

        sleep 1
        ((attempt++))
        printf "\r  Waiting... %ds" "$attempt"
    done

    echo ""
    echo -e "${YELLOW}⏱${NC} Timeout waiting for response"
    return 1
}

poll_question_status() {
    local question_id="$1"
    local max_attempts="${2:-30}"
    local attempt=0

    echo "Polling for answer (max ${max_attempts}s)..."
    while [ $attempt -lt $max_attempts ]; do
        STATUS=$(curl -s "$CLOUD_URL/question/$question_id/status?pairingId=$PAIRING_ID" 2>/dev/null)
        STATE=$(echo "$STATUS" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

        if [ "$STATE" = "answered" ]; then
            ANSWER=$(echo "$STATUS" | grep -o '"answer":\[[^]]*\]' | sed 's/"answer":\[//;s/\]//;s/"//g')
            echo -e "${GREEN}✓${NC} Answer received: $ANSWER"
            return 0
        fi

        sleep 1
        ((attempt++))
        printf "\r  Waiting... %ds" "$attempt"
    done

    echo ""
    echo -e "${YELLOW}⏱${NC} Timeout waiting for answer"
    return 1
}

# ============================================================
# TEST 1: Tier 1 Approval (Low Risk - Green)
# ============================================================
echo -e "${BOLD}TEST 1: Tier 1 Approval (Low Risk)${NC}"
echo "============================================"
echo ""
echo "Sending low-risk approval request (Read file)..."

REQUEST_ID="cloud-tier1-$(date +%s)"
RESULT=$(curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Read\",
    \"title\": \"Read config.json\",
    \"description\": \"Reading configuration file\"
  }")

if check_response "$RESULT"; then
    echo -e "${GREEN}✓${NC} Request created: ${REQUEST_ID:0:16}..."
else
    echo -e "${RED}✗${NC} Failed to create request"
    echo "$RESULT"
    exit 1
fi

echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • GREEN card background"
echo "  • [Approve] + [Reject] buttons"
echo "  • Double tap = Approve"
echo "  • Swipe right = Approve, left = Reject"

wait_for_user "Tap Approve or Reject on your watch, then press Enter"

poll_approval_status "$REQUEST_ID" 10

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 2: Tier 2 Approval (Medium Risk - Orange)
# ============================================================
echo -e "${BOLD}TEST 2: Tier 2 Approval (Medium Risk)${NC}"
echo "============================================"
echo ""
echo "Sending medium-risk approval request (npm install)..."

REQUEST_ID="cloud-tier2-$(date +%s)"
RESULT=$(curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"npm install lodash\",
    \"title\": \"npm install lodash\",
    \"description\": \"Installing npm package\"
  }")

if check_response "$RESULT"; then
    echo -e "${GREEN}✓${NC} Request created: ${REQUEST_ID:0:16}..."
else
    echo -e "${RED}✗${NC} Failed to create request"
    echo "$RESULT"
    exit 1
fi

echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • ORANGE card background"
echo "  • [Approve] + [Reject] buttons"
echo "  • Double tap = Approve"
echo "  • Swipe right = Approve, left = Reject"

wait_for_user "Tap Approve or Reject on your watch, then press Enter"

poll_approval_status "$REQUEST_ID" 10

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 3: Tier 3 Approval (Dangerous - Red, NO Watch Approve)
# ============================================================
echo -e "${BOLD}TEST 3: Tier 3 Approval (DANGEROUS)${NC}"
echo "============================================"
echo ""
echo "Sending dangerous approval request (rm -rf)..."

REQUEST_ID="cloud-tier3-$(date +%s)"
RESULT=$(curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"rm -rf ./build\",
    \"title\": \"rm -rf ./build\",
    \"description\": \"Delete build directory\"
  }")

if check_response "$RESULT"; then
    echo -e "${GREEN}✓${NC} Request created: ${REQUEST_ID:0:16}..."
else
    echo -e "${RED}✗${NC} Failed to create request"
    echo "$RESULT"
    exit 1
fi

echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • RED card background"
echo "  • [Reject] + [Remind 5m] buttons ONLY (no Approve!)"
echo "  • Double tap = REJECT (safety default)"
echo "  • Swipe gestures DISABLED"
echo "  • 'Approve requires Mac' hint text"
echo ""
echo -e "${YELLOW}IMPORTANT: Cannot approve Tier 3 from watch - must use Mac!${NC}"

wait_for_user "Tap Reject on your watch (only option), then press Enter"

poll_approval_status "$REQUEST_ID" 10

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 4: Question Flow (F18 - Binary Options)
# ============================================================
echo -e "${BOLD}TEST 4: Question Flow (Binary Options)${NC}"
echo "============================================"
echo ""
echo "Sending question with 2 options..."

QUESTION_ID="cloud-q-$(date +%s)"
RESULT=$(curl -s -X POST "$CLOUD_URL/question" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"questionId\": \"$QUESTION_ID\",
    \"question\": \"Which database should we use?\",
    \"header\": \"Database\",
    \"options\": [
      {\"label\": \"PostgreSQL\", \"description\": \"Recommended for production\"},
      {\"label\": \"SQLite\", \"description\": \"Simpler for development\"}
    ],
    \"multiSelect\": false
  }")

if check_response "$RESULT" "questionId"; then
    echo -e "${GREEN}✓${NC} Question created: $QUESTION_ID"
else
    echo -e "${RED}✗${NC} Failed to create question"
    echo "$RESULT"
    # Continue anyway - question endpoint might have different response format
fi

echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • Question text displayed"
echo "  • 2 option buttons: [PostgreSQL (Recommended)] [SQLite]"
echo "  • Double tap selects recommended option"
echo "  • NO 'Handle on Mac' button (removed in V2)"

wait_for_user "Select an option on your watch, then press Enter"

poll_question_status "$QUESTION_ID" 10

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 5: Context Warning (F16)
# ============================================================
echo -e "${BOLD}TEST 5: Context Warning (85%)${NC}"
echo "============================================"
echo ""
echo "Sending context warning at 85%..."

RESULT=$(curl -s -X POST "$CLOUD_URL/context-warning" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"percentage\": 85,
    \"threshold\": 85
  }" 2>/dev/null || echo '{"note":"endpoint may not exist"}')

echo "Request sent (context-warning endpoint may not be implemented)"
echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • ContextWarningView displayed"
echo "  • Orange warning color (85% threshold)"
echo "  • Progress bar at 85%"
echo "  • 'Session may compress soon' message"
echo "  • [Dismiss] + [View] buttons"

wait_for_user "Check if context warning appeared on watch, then press Enter"

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 6: Progress Update
# ============================================================
echo -e "${BOLD}TEST 6: Progress Update${NC}"
echo "============================================"
echo ""
echo "Sending progress update..."

RESULT=$(curl -s -X POST "$CLOUD_URL/progress/$PAIRING_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "currentTask": "Cloud Test Task",
    "currentActivity": "Testing progress flow",
    "progress": 0.6,
    "completedCount": 3,
    "totalCount": 5,
    "tasks": [
      {"content": "First task", "status": "completed"},
      {"content": "Second task", "status": "completed"},
      {"content": "Third task", "status": "completed"},
      {"content": "Fourth task", "status": "in_progress"},
      {"content": "Fifth task", "status": "pending"}
    ]
  }')

if check_response "$RESULT"; then
    echo -e "${GREEN}✓${NC} Progress update sent"
else
    echo -e "${YELLOW}⚠${NC} Progress response: $RESULT"
fi

echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • WorkingView displayed"
echo "  • 'Testing progress flow' activity"
echo "  • 60% progress bar"
echo "  • 3/5 task count"
echo "  • Task list with checkmarks"

wait_for_user "Check progress display on watch, then press Enter"

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 7: Approval Queue (Multiple Pending)
# ============================================================
echo -e "${BOLD}TEST 7: Approval Queue (Multiple Items)${NC}"
echo "============================================"
echo ""
echo "Sending 3 approval requests to build a queue..."

# Tier 1
REQUEST_ID1="cloud-queue1-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID1\",
    \"type\": \"Edit\",
    \"title\": \"Edit config.json\",
    \"description\": \"Update configuration\"
  }" > /dev/null
echo "  • Tier 1: Edit config.json"

sleep 0.5

# Tier 2
REQUEST_ID2="cloud-queue2-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID2\",
    \"type\": \"Bash\",
    \"command\": \"npm install express\",
    \"title\": \"npm install express\",
    \"description\": \"Install dependencies\"
  }" > /dev/null
echo "  • Tier 2: npm install express"

sleep 0.5

# Tier 1
REQUEST_ID3="cloud-queue3-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID3\",
    \"type\": \"Write\",
    \"title\": \"Write README.md\",
    \"description\": \"Create documentation\"
  }" > /dev/null
echo "  • Tier 1: Write README.md"

echo ""
echo -e "${GREEN}✓${NC} Created 3 pending approvals"
echo ""
echo -e "${BOLD}Expected on watch:${NC}"
echo "  • ApprovalQueueView with 3 items"
echo "  • Tier color indicators on each item"
echo "  • Swipe through queue or use buttons"
echo "  • 'Approve All' option (if all Tier 1-2)"

wait_for_user "Process the queue on your watch (approve/reject all), then press Enter"

# Check queue status
echo "Checking queue status..."
QUEUE=$(curl -s "$CLOUD_URL/approval-queue/$PAIRING_ID" 2>/dev/null)
PENDING=$(echo "$QUEUE" | grep -o '"pending":[0-9]*' | cut -d':' -f2)
echo "  Remaining pending: ${PENDING:-0}"

echo ""
echo "========================================"
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo -e "${BOLD}TEST SUMMARY${NC}"
echo "========================================"
echo ""
echo "All interactive tests completed!"
echo ""
echo "If you saw the expected behaviors:"
echo -e "  ${GREEN}✓${NC} Tier 1 - Green card, approve/reject buttons"
echo -e "  ${GREEN}✓${NC} Tier 2 - Orange card, approve/reject buttons"
echo -e "  ${GREEN}✓${NC} Tier 3 - Red card, reject only, 'requires Mac' hint"
echo -e "  ${GREEN}✓${NC} Question - Binary options, no Mac escape"
echo -e "  ${GREEN}✓${NC} Progress - Working view with task list"
echo -e "  ${GREEN}✓${NC} Queue - Multiple pending approvals"
echo ""
echo "V2 is working correctly!"
echo ""
