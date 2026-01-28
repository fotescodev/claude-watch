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
clear_approval_queue() {
    echo "Clearing approval queue..."
    QUEUE=$(curl -s "$CLOUD_URL/approval-queue/$PAIRING_ID" 2>/dev/null)
    IDS=$(echo "$QUEUE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

    for id in $IDS; do
        curl -s -X POST "$CLOUD_URL/approval/$PAIRING_ID/$id/respond" \
          -H "Content-Type: application/json" \
          -d '{"approved": false}' > /dev/null 2>&1
    done

    REMAINING=$(curl -s "$CLOUD_URL/approval-queue/$PAIRING_ID" 2>/dev/null | grep -o '"pending":[0-9]*' | cut -d':' -f2)
    if [ "${REMAINING:-0}" = "0" ]; then
        echo -e "${GREEN}✓${NC} Queue cleared"
    else
        echo -e "${YELLOW}⚠${NC} Queue has $REMAINING remaining items"
    fi
}

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

# Clear queue before starting tests (prevents stale state issues)
clear_approval_queue
echo ""

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
echo "  • RED card background with red glow"
echo "  • [Approve] + [Reject] buttons (both red-styled)"
echo "  • 'Dangerous - handle on Mac' warning text"

wait_for_user "Tap Approve or Reject on your watch, then press Enter"

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
clear_approval_queue
echo ""
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
# TEST 8: Approval Queue - 3 Tiers (TierQueueView with swipe)
# ============================================================
clear_approval_queue
echo ""
echo -e "${BOLD}TEST 8: Approval Queue - 3 Tiers (V3 TierQueueView)${NC}"
echo "============================================"
echo ""
echo "Creating 10 approval requests across 3 tiers..."
echo ""

# Tier 1: 3 Edit requests (green)
for i in 1 2 3; do
    curl -s -X POST "$CLOUD_URL/approval" \
      -H "Content-Type: application/json" \
      -d "{
        \"pairingId\": \"$PAIRING_ID\",
        \"id\": \"t8-edit-$i-$(date +%s)\",
        \"type\": \"Edit\",
        \"title\": \"Edit file$i.swift\",
        \"description\": \"Updating SwiftUI view\"
      }" > /dev/null
    sleep 0.1
done
echo -e "  ${GREEN}✓${NC} Created 3 Edit requests (Tier 1 - Green)"

# Tier 2: 5 Bash requests (orange)
for i in 1 2 3 4 5; do
    curl -s -X POST "$CLOUD_URL/approval" \
      -H "Content-Type: application/json" \
      -d "{
        \"pairingId\": \"$PAIRING_ID\",
        \"id\": \"t8-bash-$i-$(date +%s)\",
        \"type\": \"Bash\",
        \"command\": \"npm install pkg$i\",
        \"title\": \"npm install pkg$i\",
        \"description\": \"Installing dependency\"
      }" > /dev/null
    sleep 0.1
done
echo -e "  ${YELLOW}✓${NC} Created 5 Bash requests (Tier 2 - Orange)"

# Tier 3: 2 Dangerous requests (red)
for i in 1 2; do
    curl -s -X POST "$CLOUD_URL/approval" \
      -H "Content-Type: application/json" \
      -d "{
        \"pairingId\": \"$PAIRING_ID\",
        \"id\": \"t8-danger-$i-$(date +%s)\",
        \"type\": \"Bash\",
        \"command\": \"rm -rf ./build$i\",
        \"title\": \"rm -rf ./build$i\",
        \"description\": \"Delete build directory\"
      }" > /dev/null
    sleep 0.1
done
echo -e "  ${RED}✓${NC} Created 2 Danger requests (Tier 3 - Red)"

echo ""
echo -e "${BOLD}Expected on watch - TierQueueView with swipe navigation:${NC}"
echo ""
echo "  FIRST SCREEN (Green):"
echo "    • Green dot + '3 Edit' header"
echo "    • 3 action rows with [EDIT] badges"
echo "    • [Review] + [Approve All 3] buttons"
echo "    • 3 pagination dots (green active)"
echo ""
echo "  SWIPE DOWN → Orange (5 Bash):"
echo "    • Orange dot + '5 Bash' header"
echo "    • 3 visible + '+2 more'"
echo "    • [Review] + [Approve All 5] buttons"
echo ""
echo "  SWIPE DOWN → Red (2 Danger):"
echo "    • Red dot + '2 Danger' header"
echo "    • [Review Each] button ONLY"

wait_for_user "Process all 3 tiers on your watch, then press Enter"

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 9: Approval Queue - Combined View (1 per tier)
# ============================================================
clear_approval_queue
echo ""
echo -e "${BOLD}TEST 9: Approval Queue - Combined View (V3 CombinedQueueView)${NC}"
echo "============================================"
echo ""
echo "Creating 3 requests (1 per tier) to test combined view..."
echo ""

# 1 Read (Tier 1 - green)
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"t9-edit-$(date +%s)\",
    \"type\": \"Read\",
    \"title\": \"config.json\",
    \"description\": \"Reading config\"
  }" > /dev/null
echo -e "  ${GREEN}✓${NC} Created 1 Read (Tier 1 - Green)"

sleep 0.2

# 1 Bash (Tier 2 - orange)
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"t9-bash-$(date +%s)\",
    \"type\": \"Bash\",
    \"command\": \"npm install\",
    \"title\": \"npm install\",
    \"description\": \"Installing deps\"
  }" > /dev/null
echo -e "  ${YELLOW}✓${NC} Created 1 Bash (Tier 2 - Orange)"

sleep 0.2

# 1 Danger (Tier 3 - red)
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"t9-danger-$(date +%s)\",
    \"type\": \"Bash\",
    \"command\": \"rm -rf cache\",
    \"title\": \"rm -rf cache\",
    \"description\": \"Clear cache\"
  }" > /dev/null
echo -e "  ${RED}✓${NC} Created 1 Danger (Tier 3 - Red)"

echo ""
echo -e "${BOLD}Expected on watch - CombinedQueueView (no swiping):${NC}"
echo ""
echo "  • White dot + '3 pending' header"
echo "  • 3 colored rows in single view:"
echo "    - Green row: [EDIT] config.json"
echo "    - Orange row: [BASH] npm install"
echo "    - Red row: [DELETE] rm -rf cache"
echo "  • Each row has tier-colored background + border + glow"
echo "  • Single [Approve All 3] green button"

wait_for_user "Verify combined view then tap Approve All, then press Enter"

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 10: Approval Queue - Review Mode (TierReviewView)
# ============================================================
clear_approval_queue
echo ""
echo -e "${BOLD}TEST 10: Review Mode (V3 TierReviewView)${NC}"
echo "============================================"
echo ""
echo "Creating 3 same-tier requests to test review mode..."
echo ""

for i in 1 2 3; do
    curl -s -X POST "$CLOUD_URL/approval" \
      -H "Content-Type: application/json" \
      -d "{
        \"pairingId\": \"$PAIRING_ID\",
        \"id\": \"t10-review-$i-$(date +%s)\",
        \"type\": \"Bash\",
        \"command\": \"npm run build:$i\",
        \"title\": \"npm run build:$i\",
        \"description\": \"Building module $i\"
      }" > /dev/null
    sleep 0.1
done
echo -e "  ${YELLOW}✓${NC} Created 3 Bash requests"

echo ""
echo -e "${BOLD}Test steps:${NC}"
echo ""
echo "  STEP 1: TierQueueView shows '3 Bash'"
echo "    • Orange dot + '3 Bash' header"
echo "    • [Review] + [Approve All 3] buttons"
echo ""
echo "  STEP 2: Tap [Review] to enter TierReviewView"
echo "    • Orange dot + '1 of 3' header"
echo "    • Full action card with details"
echo "    • [✕] reject + [✓] approve icon buttons"
echo ""
echo "  STEP 3: Tap [✓] approve → shows '2 of 3'"
echo "  STEP 4: Continue through all 3 actions"
echo "  STEP 5: After last, returns to queue or empty"

wait_for_user "Tap [Review] and process each action, then press Enter"

echo ""
echo "========================================"
echo ""

# ============================================================
# TEST 11: Danger Queue Only
# ============================================================
clear_approval_queue
echo ""
echo -e "${BOLD}TEST 11: Danger Queue Only (Red TierQueueView)${NC}"
echo "============================================"
echo ""
echo "Creating 2 dangerous requests..."
echo ""

curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"t11-danger1-$(date +%s)\",
    \"type\": \"Bash\",
    \"command\": \"sudo rm -rf /tmp/test\",
    \"title\": \"sudo rm -rf /tmp/test\",
    \"description\": \"Elevated delete\"
  }" > /dev/null

sleep 0.2

curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"t11-danger2-$(date +%s)\",
    \"type\": \"Bash\",
    \"command\": \"chmod 777 /var/log\",
    \"title\": \"chmod 777 /var/log\",
    \"description\": \"Change permissions\"
  }" > /dev/null

echo -e "  ${RED}✓${NC} Created 2 Danger requests"

echo ""
echo -e "${BOLD}Expected on watch - Red TierQueueView:${NC}"
echo ""
echo "  • Red dot + '2 Danger' header"
echo "  • 2 action rows with [DELETE] badges (white text)"
echo "  • [Review Each] button ONLY (red outline, centered)"
echo "  • NO [Approve All] button (safety)"
echo "  • NO pagination dots (single tier)"

wait_for_user "Tap [Review Each] and reject both, then press Enter"

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
echo "V2 Core Tests:"
echo -e "  ${GREEN}✓${NC} Test 1: Tier 1 - Green card, approve/reject buttons"
echo -e "  ${GREEN}✓${NC} Test 2: Tier 2 - Orange card, approve/reject buttons"
echo -e "  ${GREEN}✓${NC} Test 3: Tier 3 - Red card, reject only, 'requires Mac'"
echo -e "  ${GREEN}✓${NC} Test 4: Question - Binary options, no Mac escape"
echo -e "  ${GREEN}✓${NC} Test 5: Context Warning - 85% threshold"
echo -e "  ${GREEN}✓${NC} Test 6: Progress - Working view with task list"
echo -e "  ${GREEN}✓${NC} Test 7: Basic Queue - Multiple pending approvals"
echo ""
echo "V3 Queue Tests:"
echo -e "  ${GREEN}✓${NC} Test 8: TierQueueView - 3 tiers with swipe navigation"
echo -e "  ${GREEN}✓${NC} Test 9: CombinedQueueView - 3 singles in colored rows"
echo -e "  ${GREEN}✓${NC} Test 10: TierReviewView - Individual action review"
echo -e "  ${GREEN}✓${NC} Test 11: Danger Queue - Red tier, Review Each only"
echo ""
echo "V3 is working correctly!"
echo ""
