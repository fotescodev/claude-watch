#!/bin/bash
#
# verify-pairing-ids.sh - Verify pairing ID consistency across all storage locations
#
# Usage:
#   ./verify-pairing-ids.sh
#
# Checks:
#   1. Mac-side: ~/.claude-watch-pairing (legacy) vs ~/.claude-watch/config.json
#   2. Environment variable (if set)
#   3. Watch simulator (if running)
#   4. Cloud server recognition
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Claude Watch Pairing ID Verification"
echo "=========================================="

# 1. Mac-side pairing IDs
echo ""
echo -e "${CYAN}=== MAC SIDE ===${NC}"

# Legacy file
LEGACY_ID=$(cat ~/.claude-watch-pairing 2>/dev/null | tr -d '\n' || echo "")
if [ -n "$LEGACY_ID" ]; then
  echo -e "  ~/.claude-watch-pairing:     ${GREEN}${LEGACY_ID:0:12}...${NC}"
else
  echo -e "  ~/.claude-watch-pairing:     ${RED}NOT SET${NC}"
fi

# Config file
CONFIG_ID=""
if [ -f ~/.claude-watch/config.json ]; then
  CONFIG_ID=$(jq -r '.pairingId // empty' ~/.claude-watch/config.json 2>/dev/null || echo "")
fi

if [ -n "$CONFIG_ID" ]; then
  echo -e "  ~/.claude-watch/config.json: ${GREEN}${CONFIG_ID:0:12}...${NC}"
else
  echo -e "  ~/.claude-watch/config.json: ${RED}NOT SET${NC}"
fi

# Environment variable (runtime)
if [ -n "$CLAUDE_WATCH_PAIRING_ID" ]; then
  echo -e "  CLAUDE_WATCH_PAIRING_ID:     ${GREEN}${CLAUDE_WATCH_PAIRING_ID:0:12}...${NC}"
else
  echo -e "  CLAUDE_WATCH_PAIRING_ID:     ${YELLOW}not set (using file)${NC}"
fi

# 2. Check consistency
echo ""
echo -e "${CYAN}=== CONSISTENCY CHECK ===${NC}"

ISSUES_FOUND=0

if [ -n "$LEGACY_ID" ] && [ -n "$CONFIG_ID" ]; then
  if [ "$LEGACY_ID" = "$CONFIG_ID" ]; then
    echo -e "  ${GREEN}✓ Legacy and config files MATCH${NC}"
  else
    echo -e "  ${RED}✗ MISMATCH between legacy and config!${NC}"
    echo "    Legacy: $LEGACY_ID"
    echo "    Config: $CONFIG_ID"
    echo ""
    echo "    To fix, run:"
    echo "      jq -r '.pairingId' ~/.claude-watch/config.json > ~/.claude-watch-pairing"
    ISSUES_FOUND=1
  fi
elif [ -n "$LEGACY_ID" ] && [ -z "$CONFIG_ID" ]; then
  echo -e "  ${YELLOW}⚠ Legacy file exists but config.json missing pairingId${NC}"
  echo "    stdin-proxy may not work correctly"
elif [ -z "$LEGACY_ID" ] && [ -n "$CONFIG_ID" ]; then
  echo -e "  ${YELLOW}⚠ Config has pairingId but legacy file missing${NC}"
  echo "    Hooks may not find pairing ID"
  echo ""
  echo "    To fix, run:"
  echo "      jq -r '.pairingId' ~/.claude-watch/config.json > ~/.claude-watch-pairing"
else
  echo -e "  ${YELLOW}(No pairing IDs found - not paired yet)${NC}"
fi

# Check environment variable matches
if [ -n "$CLAUDE_WATCH_PAIRING_ID" ]; then
  EFFECTIVE_ID="${LEGACY_ID:-$CONFIG_ID}"
  if [ -n "$EFFECTIVE_ID" ] && [ "$CLAUDE_WATCH_PAIRING_ID" != "$EFFECTIVE_ID" ]; then
    echo -e "  ${RED}✗ Environment variable does not match file!${NC}"
    echo "    Env:  $CLAUDE_WATCH_PAIRING_ID"
    echo "    File: $EFFECTIVE_ID"
    ISSUES_FOUND=1
  fi
fi

# 3. Cloud validation
echo ""
echo -e "${CYAN}=== CLOUD VALIDATION ===${NC}"

PAIRING_ID="${LEGACY_ID:-$CONFIG_ID}"
if [ -n "$PAIRING_ID" ]; then
  # Check if cloud server is reachable
  if curl -s --max-time 5 "https://claude-watch.fotescodev.workers.dev/health" | grep -q '"status":"ok"'; then
    echo -e "  ${GREEN}✓ Cloud server healthy${NC}"

    # Check if pairing ID is recognized
    QUEUE_RESULT=$(curl -s --max-time 5 "https://claude-watch.fotescodev.workers.dev/approval-queue/$PAIRING_ID" 2>/dev/null || echo '{}')
    if echo "$QUEUE_RESULT" | grep -q '"requests"'; then
      echo -e "  ${GREEN}✓ Pairing ID recognized by cloud${NC}"
    else
      echo -e "  ${YELLOW}⚠ Pairing ID not found in cloud (may be new or expired)${NC}"
    fi
  else
    echo -e "  ${RED}✗ Cloud server unreachable${NC}"
  fi
else
  echo -e "  ${YELLOW}(Skipping - no pairing ID to check)${NC}"
fi

# 4. Watch side (simulator only)
echo ""
echo -e "${CYAN}=== WATCH SIMULATOR ===${NC}"

WATCH_SIM="Apple Watch Series 11 (46mm)"
if xcrun simctl list devices 2>/dev/null | grep -q "$WATCH_SIM.*Booted"; then
  # Read from simulator defaults
  DEVICE_ID=$(xcrun simctl list devices | grep "$WATCH_SIM" | grep -oE "[0-9A-F-]{36}" | head -1)

  if [ -n "$DEVICE_ID" ]; then
    WATCH_PAIRING=$(xcrun simctl spawn "$DEVICE_ID" defaults read com.edgeoftrust.claudewatch pairingId 2>/dev/null || echo "")

    if [ -n "$WATCH_PAIRING" ]; then
      echo -e "  Simulator pairingId: ${GREEN}${WATCH_PAIRING:0:12}...${NC}"

      if [ -n "$PAIRING_ID" ] && [ "$WATCH_PAIRING" = "$PAIRING_ID" ]; then
        echo -e "  ${GREEN}✓ Watch simulator MATCHES Mac${NC}"
      elif [ -n "$PAIRING_ID" ]; then
        echo -e "  ${RED}✗ Watch simulator has DIFFERENT pairing ID!${NC}"
        echo "    Watch:  $WATCH_PAIRING"
        echo "    Mac:    $PAIRING_ID"
        echo ""
        echo "    To fix on simulator:"
        echo "      xcrun simctl spawn \"$DEVICE_ID\" defaults delete com.edgeoftrust.claudewatch pairingId"
        echo "    Then re-pair in the app"
        ISSUES_FOUND=1
      fi
    else
      echo -e "  Simulator pairingId: ${YELLOW}not set (not paired on simulator)${NC}"
    fi
  fi
else
  echo -e "  ${YELLOW}Watch simulator not running${NC}"
  echo "  To start: xcrun simctl boot \"$WATCH_SIM\" && open -a Simulator"
fi

# 5. Physical watch note
echo ""
echo -e "${CYAN}=== PHYSICAL WATCH ===${NC}"
echo "  Cannot read pairing ID from physical watch via script."
echo "  Check watch app Settings > Pairing ID"
echo "  Or: Tap 'Unpair' then re-pair to sync IDs"

# Summary
echo ""
echo "=========================================="
if [ $ISSUES_FOUND -eq 0 ]; then
  echo -e "  ${GREEN}All pairing IDs are consistent${NC}"
else
  echo -e "  ${RED}Issues detected - see fixes above${NC}"
fi
echo "=========================================="

exit $ISSUES_FOUND
