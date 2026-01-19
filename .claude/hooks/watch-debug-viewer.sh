#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  WATCH DEBUG VIEWER — Browse Saved Debug Sessions
#  Interactive log viewer with search and filtering
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.claude/logs/watch-debug"

#───────────────────────────────────────────────────────────────────────────────
# COLOR PALETTE
#───────────────────────────────────────────────────────────────────────────────

CORAL='\033[38;5;209m'
WHITE='\033[97m'
GRAY='\033[90m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;221m'
CYAN='\033[38;5;116m'
RED='\033[38;5;203m'
PURPLE='\033[38;5;183m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

#───────────────────────────────────────────────────────────────────────────────
# COMMANDS
#───────────────────────────────────────────────────────────────────────────────

show_help() {
    echo ""
    echo -e "  ${CORAL}${BOLD}WATCH DEBUG VIEWER${NC}"
    echo -e "  ${GRAY}Browse and analyze watch debug logs${NC}"
    echo ""
    echo -e "  ${WHITE}Usage:${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh${NC}              ${GRAY}# List recent sessions${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh latest${NC}       ${GRAY}# View latest session${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh tail${NC}         ${GRAY}# Follow latest log live${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh <filename>${NC}   ${GRAY}# View specific session${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh errors${NC}       ${GRAY}# Show only errors${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh stats${NC}        ${GRAY}# Show statistics${NC}"
    echo -e "    ${CYAN}./watch-debug-viewer.sh clean${NC}        ${GRAY}# Remove logs older than 7 days${NC}"
    echo ""
}

list_sessions() {
    echo ""
    echo -e "  ${CORAL}${BOLD}📋 RECENT DEBUG SESSIONS${NC}"
    echo ""

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "  ${GRAY}No debug sessions found${NC}"
        echo -e "  ${DIM}Run ./watch-debug-monitor.sh to start recording${NC}"
        return
    fi

    local count=0
    for log in $(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -10); do
        ((count++))
        local filename=$(basename "$log")
        local size=$(du -h "$log" | cut -f1)
        local events=$(grep -c '^\[' "$log" 2>/dev/null || echo "0")
        local errors=$(grep -c '\[ERROR\]\|\[FAIL\]' "$log" 2>/dev/null || echo "0")

        # Extract date from filename
        local date_part=$(echo "$filename" | grep -oE '[0-9]{8}-[0-9]{6}')

        # Color code based on errors
        local status_icon status_color
        if [[ "$errors" -gt 0 ]]; then
            status_icon="⚠️"
            status_color="$YELLOW"
        else
            status_icon="✅"
            status_color="$GREEN"
        fi

        printf "  ${WHITE}%2d.${NC} ${status_icon}  ${CYAN}%-30s${NC} ${GRAY}%5s${NC}  ${status_color}%4d events${NC}  ${RED}%d errors${NC}\n" \
            "$count" "$filename" "$size" "$events" "$errors"
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${GRAY}No session logs found${NC}"
    fi

    echo ""
    echo -e "  ${DIM}View with: ./watch-debug-viewer.sh <filename>${NC}"
    echo ""
}

view_log() {
    local logfile="$1"

    # Handle shortcuts
    if [[ "$logfile" == "latest" ]]; then
        logfile="$LOG_DIR/latest.log"
    elif [[ ! -f "$logfile" ]]; then
        # Try to find in log dir
        if [[ -f "$LOG_DIR/$logfile" ]]; then
            logfile="$LOG_DIR/$logfile"
        else
            echo -e "  ${RED}Log file not found: $logfile${NC}"
            return 1
        fi
    fi

    echo ""
    echo -e "  ${CORAL}${BOLD}📜 DEBUG LOG${NC}"
    echo -e "  ${GRAY}$(basename "$logfile")${NC}"
    echo ""
    echo -e "  ${DARK}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Colorize output
    while IFS= read -r line; do
        # Color based on log level
        if [[ "$line" =~ \[ERROR\]|\[FAIL\] ]]; then
            echo -e "  ${RED}${line}${NC}"
        elif [[ "$line" =~ \[WARN\] ]]; then
            echo -e "  ${YELLOW}${line}${NC}"
        elif [[ "$line" =~ \[SUCCESS\]|\[OK\]|\[APPROVE\] ]]; then
            echo -e "  ${GREEN}${line}${NC}"
        elif [[ "$line" =~ \[CLOUD\] ]]; then
            echo -e "  ${CYAN}${line}${NC}"
        elif [[ "$line" =~ \[WATCH\]|\[HOOK\] ]]; then
            echo -e "  ${CORAL}${line}${NC}"
        elif [[ "$line" =~ \[APNS\] ]]; then
            echo -e "  ${PURPLE}${line}${NC}"
        elif [[ "$line" =~ ^═ ]]; then
            echo -e "  ${CORAL}${line}${NC}"
        else
            echo -e "  ${GRAY}${line}${NC}"
        fi
    done < "$logfile"

    echo ""
}

tail_log() {
    local logfile="$LOG_DIR/latest.log"

    if [[ ! -f "$logfile" ]]; then
        echo -e "  ${YELLOW}No active session. Start the monitor first.${NC}"
        return 1
    fi

    echo ""
    echo -e "  ${CORAL}${BOLD}📡 LIVE DEBUG STREAM${NC}"
    echo -e "  ${GRAY}Following: $(basename "$(readlink "$logfile" 2>/dev/null || echo "$logfile")")${NC}"
    echo -e "  ${DIM}Press Ctrl+C to stop${NC}"
    echo ""

    # Follow with colorization
    tail -f "$logfile" | while IFS= read -r line; do
        if [[ "$line" =~ \[ERROR\]|\[FAIL\] ]]; then
            echo -e "  ${RED}${line}${NC}"
        elif [[ "$line" =~ \[WARN\] ]]; then
            echo -e "  ${YELLOW}${line}${NC}"
        elif [[ "$line" =~ \[SUCCESS\]|\[OK\]|\[APPROVE\] ]]; then
            echo -e "  ${GREEN}${line}${NC}"
        elif [[ "$line" =~ \[CLOUD\] ]]; then
            echo -e "  ${CYAN}${line}${NC}"
        elif [[ "$line" =~ \[WATCH\]|\[HOOK\] ]]; then
            echo -e "  ${CORAL}${line}${NC}"
        else
            echo -e "  ${WHITE}${line}${NC}"
        fi
    done
}

show_errors() {
    echo ""
    echo -e "  ${RED}${BOLD}❌ ERROR SUMMARY${NC}"
    echo ""

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "  ${GRAY}No logs found${NC}"
        return
    fi

    local total_errors=0

    for log in $(ls -t "$LOG_DIR"/session-*.log 2>/dev/null | head -20); do
        local filename=$(basename "$log")
        local errors=$(grep '\[ERROR\]\|\[FAIL\]' "$log" 2>/dev/null)

        if [[ -n "$errors" ]]; then
            echo -e "  ${YELLOW}📁 ${filename}${NC}"
            echo "$errors" | while IFS= read -r line; do
                ((total_errors++))
                echo -e "     ${RED}${line}${NC}"
            done
            echo ""
        fi
    done

    if [[ $total_errors -eq 0 ]]; then
        echo -e "  ${GREEN}✅ No errors found in recent logs${NC}"
    fi

    echo ""
}

show_stats() {
    echo ""
    echo -e "  ${CORAL}${BOLD}📊 DEBUG STATISTICS${NC}"
    echo ""

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "  ${GRAY}No logs found${NC}"
        return
    fi

    local total_sessions=$(ls "$LOG_DIR"/session-*.log 2>/dev/null | wc -l | tr -d ' ')
    local total_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
    local total_events=0
    local total_errors=0
    local total_approvals=0
    local total_rejections=0

    for log in "$LOG_DIR"/session-*.log; do
        [[ -f "$log" ]] || continue
        total_events=$((total_events + $(grep -c '^\[' "$log" 2>/dev/null || echo 0)))
        total_errors=$((total_errors + $(grep -c '\[ERROR\]\|\[FAIL\]' "$log" 2>/dev/null || echo 0)))
        total_approvals=$((total_approvals + $(grep -c '\[APPROVE\]' "$log" 2>/dev/null || echo 0)))
        total_rejections=$((total_rejections + $(grep -c '\[REJECT\]' "$log" 2>/dev/null || echo 0)))
    done

    echo -e "  ${WHITE}Sessions:${NC}     ${CYAN}${total_sessions}${NC}"
    echo -e "  ${WHITE}Total Size:${NC}   ${CYAN}${total_size}${NC}"
    echo -e "  ${WHITE}Total Events:${NC} ${CYAN}${total_events}${NC}"
    echo ""
    echo -e "  ${GREEN}✅ Approvals:${NC}  ${GREEN}${total_approvals}${NC}"
    echo -e "  ${RED}❌ Rejections:${NC} ${RED}${total_rejections}${NC}"
    echo -e "  ${YELLOW}⚠️  Errors:${NC}     ${YELLOW}${total_errors}${NC}"
    echo ""

    # Approval rate
    local total_decisions=$((total_approvals + total_rejections))
    if [[ $total_decisions -gt 0 ]]; then
        local approval_rate=$((total_approvals * 100 / total_decisions))
        echo -e "  ${WHITE}Approval Rate:${NC} ${GREEN}${approval_rate}%${NC}"
    fi

    echo ""
}

clean_logs() {
    echo ""
    echo -e "  ${YELLOW}${BOLD}🧹 CLEANING OLD LOGS${NC}"
    echo ""

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "  ${GRAY}No logs to clean${NC}"
        return
    fi

    # Find logs older than 7 days
    local old_logs=$(find "$LOG_DIR" -name "session-*.log" -mtime +7 2>/dev/null)
    local count=$(echo "$old_logs" | grep -c . 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]] || [[ -z "$old_logs" ]]; then
        echo -e "  ${GREEN}No logs older than 7 days${NC}"
        return
    fi

    echo -e "  Found ${YELLOW}${count}${NC} logs older than 7 days"
    echo ""

    # List them
    echo "$old_logs" | while IFS= read -r log; do
        [[ -z "$log" ]] && continue
        echo -e "  ${DIM}$(basename "$log")${NC}"
    done

    echo ""
    read -p "  Delete these logs? [y/N] " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "$old_logs" | xargs rm -f 2>/dev/null
        echo -e "  ${GREEN}✅ Cleaned ${count} old logs${NC}"
    else
        echo -e "  ${GRAY}Cancelled${NC}"
    fi

    echo ""
}

#───────────────────────────────────────────────────────────────────────────────
# MAIN
#───────────────────────────────────────────────────────────────────────────────

case "${1:-list}" in
    help|--help|-h)
        show_help
        ;;
    list|ls)
        list_sessions
        ;;
    latest)
        view_log "latest"
        ;;
    tail|follow|-f)
        tail_log
        ;;
    errors|error)
        show_errors
        ;;
    stats|statistics)
        show_stats
        ;;
    clean|cleanup)
        clean_logs
        ;;
    *)
        view_log "$1"
        ;;
esac
