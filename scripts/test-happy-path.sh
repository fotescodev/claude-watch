#!/bin/bash
# Happy Path E2E Test - Connected Approval → Progress Flow
#
# Simulates a real Claude Code session where:
# 1. Claude requests approval for a task
# 2. User approves on watch
# 3. Claude shows progress working on that task
# 4. Task completes, next approval comes in
#
# Usage: ./scripts/test-happy-path.sh

set -e

CLOUD_URL="https://claude-watch.fotescodev.workers.dev"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Get pairing ID
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -z "$PAIRING_ID" ]; then
    echo -e "${RED}No pairing found. Run: npx cc-watch${NC}"
    exit 1
fi

clear
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Claude Watch - Happy Path E2E Test${NC}"
echo -e "${BOLD}   Connected Approval → Progress Flow${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Pairing: ${DIM}${PAIRING_ID:0:8}...${NC}"
echo ""
echo -e "${CYAN}This test simulates a real Claude Code session:${NC}"
echo "  1. Claude requests permission to do something"
echo "  2. You approve on your watch"
echo "  3. Claude works on it (progress shown)"
echo "  4. Next task begins"
echo ""
echo -e "${YELLOW}Press Enter to start the session simulation...${NC}"
read -r

# Clear any stale state
echo ""
echo -e "${DIM}Clearing stale state...${NC}"
curl -s -X DELETE "$CLOUD_URL/approval-queue/$PAIRING_ID" > /dev/null 2>&1 || true
curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\": \"$PAIRING_ID\", \"progress\": null}" > /dev/null 2>&1 || true
sleep 1

# ============================================================
# TASK 1: Read configuration
# ============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TASK 1/4: Read Configuration${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${DIM}Claude wants to read your project configuration...${NC}"
echo ""

REQUEST_ID="hp-task1-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Read\",
    \"title\": \"Read package.json\",
    \"description\": \"Reading project configuration to understand dependencies\"
  }" > /dev/null

echo -e "${GREEN}→ Approval request sent${NC}"
echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${GREEN}GREEN${NC} card (Tier 1 - Low risk)"
echo -e "    • Title: 'Read package.json'"
echo -e "    • [Approve] + [Reject] buttons"
echo ""
echo -e "${YELLOW}👆 APPROVE on your watch, then press Enter...${NC}"
read -r

# Poll for approval
echo -e "${DIM}Checking approval status...${NC}"
for i in {1..10}; do
    STATUS=$(curl -s "$CLOUD_URL/approval/$PAIRING_ID/$REQUEST_ID" 2>/dev/null)
    DECISION=$(echo "$STATUS" | grep -o '"decision":"[^"]*"' | cut -d'"' -f4)
    if [ "$DECISION" = "approved" ]; then
        echo -e "${GREEN}✓ Approved!${NC}"
        break
    elif [ "$DECISION" = "rejected" ]; then
        echo -e "${RED}✗ Rejected - continuing anyway for demo${NC}"
        break
    fi
    sleep 0.5
done

# Show progress for Task 1
echo ""
echo -e "${DIM}Claude is now reading the file...${NC}"
sleep 1

curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Reading package.json\",
    \"progress\": 0.25,
    \"completedCount\": 0,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"in_progress\"},
      {\"content\": \"Install dependencies\", \"status\": \"pending\"},
      {\"content\": \"Create config file\", \"status\": \"pending\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${CYAN}Working${NC} view"
echo -e "    • Activity: 'Reading package.json'"
echo -e "    • Progress: 25%"
echo -e "    • Task list with 1st item highlighted"
echo ""
sleep 2

# Complete Task 1
curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Read complete\",
    \"progress\": 0.25,
    \"completedCount\": 1,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"pending\"},
      {\"content\": \"Create config file\", \"status\": \"pending\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo -e "${GREEN}✓ Task 1 complete${NC} - package.json read successfully"
echo ""
echo -e "${YELLOW}Press Enter to continue to Task 2...${NC}"
read -r

# ============================================================
# TASK 2: Install dependencies (Tier 2)
# ============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TASK 2/4: Install Dependencies${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${DIM}Claude wants to install npm packages...${NC}"
echo ""

REQUEST_ID="hp-task2-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"npm install\",
    \"title\": \"npm install\",
    \"description\": \"Installing project dependencies from package.json\"
  }" > /dev/null

echo -e "${GREEN}→ Approval request sent${NC}"
echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${YELLOW}ORANGE${NC} card (Tier 2 - Medium risk)"
echo -e "    • Title: 'npm install'"
echo -e "    • [Approve] + [Reject] buttons"
echo ""
echo -e "${YELLOW}👆 APPROVE on your watch, then press Enter...${NC}"
read -r

# Poll for approval
echo -e "${DIM}Checking approval status...${NC}"
for i in {1..10}; do
    STATUS=$(curl -s "$CLOUD_URL/approval/$PAIRING_ID/$REQUEST_ID" 2>/dev/null)
    DECISION=$(echo "$STATUS" | grep -o '"decision":"[^"]*"' | cut -d'"' -f4)
    if [ "$DECISION" = "approved" ]; then
        echo -e "${GREEN}✓ Approved!${NC}"
        break
    elif [ "$DECISION" = "rejected" ]; then
        echo -e "${RED}✗ Rejected - continuing anyway for demo${NC}"
        break
    fi
    sleep 0.5
done

# Show progress for Task 2
echo ""
echo -e "${DIM}Claude is installing dependencies...${NC}"
sleep 1

curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Running npm install\",
    \"progress\": 0.50,
    \"completedCount\": 1,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"in_progress\"},
      {\"content\": \"Create config file\", \"status\": \"pending\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • Activity: 'Running npm install'"
echo -e "    • Progress: 50%"
echo -e "    • Task 1 ✓, Task 2 in progress"
echo ""
sleep 2

# Complete Task 2
curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Dependencies installed\",
    \"progress\": 0.50,
    \"completedCount\": 2,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"completed\"},
      {\"content\": \"Create config file\", \"status\": \"pending\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo -e "${GREEN}✓ Task 2 complete${NC} - dependencies installed"
echo ""
echo -e "${YELLOW}Press Enter to continue to Task 3...${NC}"
read -r

# ============================================================
# TASK 3: Create config file (Tier 1)
# ============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TASK 3/4: Create Configuration File${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${DIM}Claude wants to create a config file...${NC}"
echo ""

REQUEST_ID="hp-task3-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Write\",
    \"title\": \"Create .env.local\",
    \"description\": \"Creating environment configuration file\"
  }" > /dev/null

echo -e "${GREEN}→ Approval request sent${NC}"
echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${GREEN}GREEN${NC} card (Tier 1 - Low risk)"
echo -e "    • Title: 'Create .env.local'"
echo -e "    • [Approve] + [Reject] buttons"
echo ""
echo -e "${YELLOW}👆 APPROVE on your watch, then press Enter...${NC}"
read -r

# Poll for approval
echo -e "${DIM}Checking approval status...${NC}"
for i in {1..10}; do
    STATUS=$(curl -s "$CLOUD_URL/approval/$PAIRING_ID/$REQUEST_ID" 2>/dev/null)
    DECISION=$(echo "$STATUS" | grep -o '"decision":"[^"]*"' | cut -d'"' -f4)
    if [ "$DECISION" = "approved" ]; then
        echo -e "${GREEN}✓ Approved!${NC}"
        break
    elif [ "$DECISION" = "rejected" ]; then
        echo -e "${RED}✗ Rejected - continuing anyway for demo${NC}"
        break
    fi
    sleep 0.5
done

# Show progress for Task 3
echo ""
echo -e "${DIM}Claude is creating the config file...${NC}"
sleep 1

curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Writing .env.local\",
    \"progress\": 0.75,
    \"completedCount\": 2,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"completed\"},
      {\"content\": \"Create config file\", \"status\": \"in_progress\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • Activity: 'Writing .env.local'"
echo -e "    • Progress: 75%"
echo -e "    • Tasks 1-2 ✓, Task 3 in progress"
echo ""
sleep 2

# Complete Task 3
curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Config created\",
    \"progress\": 0.75,
    \"completedCount\": 3,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"completed\"},
      {\"content\": \"Create config file\", \"status\": \"completed\"},
      {\"content\": \"Run build\", \"status\": \"pending\"}
    ]
  }" > /dev/null

echo -e "${GREEN}✓ Task 3 complete${NC} - config file created"
echo ""
echo -e "${YELLOW}Press Enter to continue to Task 4 (final)...${NC}"
read -r

# ============================================================
# TASK 4: Run build (Tier 2)
# ============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}TASK 4/4: Run Build${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${DIM}Claude wants to run the build command...${NC}"
echo ""

REQUEST_ID="hp-task4-$(date +%s)"
curl -s -X POST "$CLOUD_URL/approval" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"id\": \"$REQUEST_ID\",
    \"type\": \"Bash\",
    \"command\": \"npm run build\",
    \"title\": \"npm run build\",
    \"description\": \"Building the project for production\"
  }" > /dev/null

echo -e "${GREEN}→ Approval request sent${NC}"
echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${YELLOW}ORANGE${NC} card (Tier 2 - Medium risk)"
echo -e "    • Title: 'npm run build'"
echo -e "    • [Approve] + [Reject] buttons"
echo ""
echo -e "${YELLOW}👆 APPROVE on your watch, then press Enter...${NC}"
read -r

# Poll for approval
echo -e "${DIM}Checking approval status...${NC}"
for i in {1..10}; do
    STATUS=$(curl -s "$CLOUD_URL/approval/$PAIRING_ID/$REQUEST_ID" 2>/dev/null)
    DECISION=$(echo "$STATUS" | grep -o '"decision":"[^"]*"' | cut -d'"' -f4)
    if [ "$DECISION" = "approved" ]; then
        echo -e "${GREEN}✓ Approved!${NC}"
        break
    elif [ "$DECISION" = "rejected" ]; then
        echo -e "${RED}✗ Rejected - continuing anyway for demo${NC}"
        break
    fi
    sleep 0.5
done

# Show progress for Task 4
echo ""
echo -e "${DIM}Claude is running the build...${NC}"
sleep 1

curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"Building project\",
    \"progress\": 0.90,
    \"completedCount\": 3,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"completed\"},
      {\"content\": \"Create config file\", \"status\": \"completed\"},
      {\"content\": \"Run build\", \"status\": \"in_progress\"}
    ]
  }" > /dev/null

echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • Activity: 'Building project'"
echo -e "    • Progress: 90%"
echo -e "    • Tasks 1-3 ✓, Task 4 in progress"
echo ""
sleep 3

# Complete all tasks
curl -s -X POST "$CLOUD_URL/session-progress" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"currentTask\": \"Setup Project\",
    \"currentActivity\": \"All tasks complete!\",
    \"progress\": 1.0,
    \"completedCount\": 4,
    \"totalCount\": 4,
    \"tasks\": [
      {\"content\": \"Read package.json\", \"status\": \"completed\"},
      {\"content\": \"Install dependencies\", \"status\": \"completed\"},
      {\"content\": \"Create config file\", \"status\": \"completed\"},
      {\"content\": \"Run build\", \"status\": \"completed\"}
    ]
  }" > /dev/null

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}   ✓ SESSION COMPLETE${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Watch should show:${NC}"
echo -e "    • ${GREEN}Complete${NC} state"
echo -e "    • Progress: 100%"
echo -e "    • All 4 tasks ✓"
echo ""
echo -e "${CYAN}This was the happy path:${NC}"
echo "  1. Approval → Approve → Progress update"
echo "  2. Repeat for each task"
echo "  3. All connected in logical flow"
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   Happy Path Test Complete!${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════════${NC}"
echo ""
