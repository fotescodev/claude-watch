#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  WATCH DEBUG MONITOR — Streaming Log View
#  Simple, compatible event stream for watch integration debugging
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.claude/logs/watch-debug"
SESSION_LOG="$LOG_DIR/session-$(date +%Y%m%d-%H%M%S).log"
LATEST_LOG="$LOG_DIR/latest.log"
CLOUD_URL="https://claude-watch.fotescodev.workers.dev"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

#───────────────────────────────────────────────────────────────────────────────
# COLORS (simple, widely supported)
#───────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

#───────────────────────────────────────────────────────────────────────────────
# STATE
#───────────────────────────────────────────────────────────────────────────────

PAIRING_ID=""
LAST_PENDING_COUNT=0
SESSION_START=$(date +%s)

#───────────────────────────────────────────────────────────────────────────────
# SETUP
#───────────────────────────────────────────────────────────────────────────────

setup() {
    PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null || echo "")

    # Link to latest
    ln -sf "$SESSION_LOG" "$LATEST_LOG"

    # Print header
    echo ""
    echo -e "${CYAN}======================================${NC}"
    echo -e "${WHITE}  ⌚ WATCH DEBUG MONITOR${NC}"
    echo -e "${CYAN}======================================${NC}"
    echo ""

    # Show status
    check_status

    echo ""
    echo -e "${CYAN}--------------------------------------${NC}"
    echo -e "${WHITE}  📡 LIVE EVENT STREAM${NC}"
    echo -e "${CYAN}--------------------------------------${NC}"
    echo ""

    log_event "🚀" "Monitor started" "session=$(basename "$SESSION_LOG")"
}

cleanup() {
    echo ""
    echo -e "${GRAY}--------------------------------------${NC}"
    echo -e "${GRAY}  Monitor stopped. Log: $(basename "$SESSION_LOG")${NC}"
    echo ""
    exit 0
}

trap cleanup INT TERM

#───────────────────────────────────────────────────────────────────────────────
# STATUS CHECK
#───────────────────────────────────────────────────────────────────────────────

check_status() {
    local pairing_status cloud_status hook_status
    local has_issues=false

    # Check pairing
    if [[ -z "$PAIRING_ID" ]]; then
        pairing_status="${RED}✗ not paired${NC}"
        has_issues=true
    else
        local cli_pairing=$(cat ~/.claude-watch-pairing 2>/dev/null)
        local config_pairing=$(jq -r '.pairingId // ""' ~/.claude-watch/config.json 2>/dev/null)
        if [[ "$cli_pairing" != "$config_pairing" ]]; then
            pairing_status="${YELLOW}⚠ mismatch${NC}"
            # Log to trigger bug detection
            "$SCRIPT_DIR/watch-debug-log.sh" "WARN" "Pairing ID mismatch detected" "cli=$cli_pairing config=$config_pairing"
            has_issues=true
        else
            pairing_status="${GREEN}✓ ${PAIRING_ID:0:8}...${NC}"
        fi
    fi

    # Check cloud
    local health=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUD_URL/health" --max-time 3 2>/dev/null)
    if [[ "$health" == "200" ]]; then
        cloud_status="${GREEN}✓ connected${NC}"
    else
        cloud_status="${RED}✗ unreachable${NC}"
        # Log to trigger bug detection
        "$SCRIPT_DIR/watch-debug-log.sh" "ERROR" "Cloud server unreachable" "status=$health"
        has_issues=true
    fi

    # Check hooks
    local hook=$(jq '.hooks.PreToolUse | length' "$PROJECT_ROOT/.claude/settings.json" 2>/dev/null || echo "0")
    if [[ "$hook" == "0" ]] || [[ "$hook" == "null" ]]; then
        hook_status="${RED}✗ disabled${NC}"
        has_issues=true
    else
        hook_status="${GREEN}✓ enabled${NC}"
    fi

    echo -e "  ${GRAY}Pairing:${NC} $pairing_status"
    echo -e "  ${GRAY}Cloud:${NC}   $cloud_status"
    echo -e "  ${GRAY}Hooks:${NC}   $hook_status"

    if [[ "$has_issues" == "true" ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠ Issues detected - check Ralph tasks${NC}"
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# LOGGING
#───────────────────────────────────────────────────────────────────────────────

log_event() {
    local emoji="$1"
    local message="$2"
    local details="${3:-}"
    local timestamp=$(date '+%H:%M:%S')

    # Print to terminal
    if [[ -n "$details" ]]; then
        echo -e "  ${GRAY}${timestamp}${NC}  ${emoji}  ${WHITE}${message}${NC}"
        echo -e "           ${GRAY}└─ ${details}${NC}"
    else
        echo -e "  ${GRAY}${timestamp}${NC}  ${emoji}  ${WHITE}${message}${NC}"
    fi

    # Use the smart logger (includes bug detection!)
    "$SCRIPT_DIR/watch-debug-log.sh" "INFO" "$emoji $message" "$details"
}

# Log with specific level (for bug detection)
log_error() {
    local message="$1"
    local details="${2:-}"
    local timestamp=$(date '+%H:%M:%S')

    echo -e "  ${GRAY}${timestamp}${NC}  ❌  ${RED}${message}${NC}"
    [[ -n "$details" ]] && echo -e "           ${GRAY}└─ ${details}${NC}"

    # Smart logger will detect patterns and create Ralph tasks
    "$SCRIPT_DIR/watch-debug-log.sh" "ERROR" "$message" "$details"
}

#───────────────────────────────────────────────────────────────────────────────
# CLOUD POLLING
#───────────────────────────────────────────────────────────────────────────────

check_cloud() {
    if [[ -z "$PAIRING_ID" ]]; then
        return
    fi

    local pending_json=$(curl -s "$CLOUD_URL/requests/$PAIRING_ID" --max-time 3 2>/dev/null)
    local curl_exit=$?

    # Check for curl failure
    if [[ $curl_exit -ne 0 ]]; then
        log_error "Cloud server unreachable" "curl_exit=$curl_exit"
        return
    fi

    local pending_count=$(echo "$pending_json" | jq '.requests | length' 2>/dev/null || echo "0")

    if [[ "$pending_count" != "$LAST_PENDING_COUNT" ]]; then
        if [[ "$pending_count" -gt "$LAST_PENDING_COUNT" ]]; then
            local diff=$((pending_count - LAST_PENDING_COUNT))
            log_event "📨" "+${diff} new request(s)" "total=${pending_count}"

            # Show pending requests
            echo "$pending_json" | jq -r '.requests[]? | "           \(.id[0:8])  \(.title // "Untitled")[0:40]"' 2>/dev/null | while read -r line; do
                echo -e "  ${YELLOW}${line}${NC}"
            done
        elif [[ "$pending_count" -lt "$LAST_PENDING_COUNT" ]]; then
            local diff=$((LAST_PENDING_COUNT - pending_count))
            log_event "📬" "${diff} request(s) resolved" "remaining=${pending_count}"
        fi
        LAST_PENDING_COUNT=$pending_count
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# EXTERNAL LOG WATCHER
#───────────────────────────────────────────────────────────────────────────────

watch_external_logs() {
    # Watch the all-events.log for entries from hooks
    local all_events="$LOG_DIR/all-events.log"

    if [[ -f "$all_events" ]]; then
        local last_line=$(wc -l < "$all_events" 2>/dev/null || echo "0")

        while true; do
            sleep 0.5

            if [[ -f "$all_events" ]]; then
                local current_lines=$(wc -l < "$all_events" 2>/dev/null || echo "0")

                if [[ $current_lines -gt $last_line ]]; then
                    # New lines added - print them
                    tail -n $((current_lines - last_line)) "$all_events" | while IFS= read -r line; do
                        # Skip if it's from our own session
                        if [[ ! "$line" =~ "Monitor started" ]] && [[ ! "$line" =~ "Monitor stopped" ]]; then
                            # Extract and colorize
                            local ts=$(echo "$line" | grep -oE '^\[[0-9-]+ [0-9:]+\]' | tr -d '[]')
                            local rest=$(echo "$line" | sed 's/^\[[0-9-]* [0-9:]*\] //')
                            local time_only=$(echo "$ts" | awk '{print $2}')

                            # Color based on content
                            if [[ "$line" =~ ERROR|FAIL ]]; then
                                echo -e "  ${GRAY}${time_only}${NC}  ${RED}${rest}${NC}"
                            elif [[ "$line" =~ APPROVE|SUCCESS|OK ]]; then
                                echo -e "  ${GRAY}${time_only}${NC}  ${GREEN}${rest}${NC}"
                            elif [[ "$line" =~ WARN|REJECT ]]; then
                                echo -e "  ${GRAY}${time_only}${NC}  ${YELLOW}${rest}${NC}"
                            elif [[ "$line" =~ HOOK ]]; then
                                echo -e "  ${GRAY}${time_only}${NC}  ${PURPLE}${rest}${NC}"
                            elif [[ "$line" =~ CLOUD ]]; then
                                echo -e "  ${GRAY}${time_only}${NC}  ${CYAN}${rest}${NC}"
                            else
                                echo -e "  ${GRAY}${time_only}${NC}  ${WHITE}${rest}${NC}"
                            fi
                        fi
                    done
                    last_line=$current_lines
                fi
            fi
        done
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# MAIN
#───────────────────────────────────────────────────────────────────────────────

main() {
    setup

    # Start external log watcher in background
    watch_external_logs &
    WATCHER_PID=$!
    trap "kill $WATCHER_PID 2>/dev/null; cleanup" INT TERM

    # Main loop - poll cloud periodically
    while true; do
        check_cloud
        sleep 2
    done
}

main "$@"
