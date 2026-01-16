#!/bin/bash
#
# Ralph Progress Monitor
# Real-time view of what Ralph is doing
#
# Usage: ./monitor-ralph.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RALPH_DIR="$PROJECT_ROOT/.claude/ralph"
PROGRESS_FILE="$RALPH_DIR/current-progress.log"
SESSION_LOG="$RALPH_DIR/session-log.md"
TASKS_FILE="$RALPH_DIR/tasks.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

clear

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                   Ralph Progress Monitor                        ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show current task from tasks.yaml
show_current_task() {
    echo -e "${BOLD}${BLUE}📋 Task Status:${NC}"
    echo ""

    # Count completed vs total
    total=$(yq '.tasks | length' "$TASKS_FILE" 2>/dev/null || echo "0")
    completed=$(yq '.tasks[] | select(.completed == true) | .id' "$TASKS_FILE" 2>/dev/null | wc -l | tr -d ' ')

    echo -e "  ${GREEN}✓ Completed:${NC} $completed / $total tasks"
    echo ""

    # Show next incomplete task
    next_task=$(yq '.tasks[] | select(.completed == false) | .id' "$TASKS_FILE" 2>/dev/null | head -1)
    if [ -n "$next_task" ]; then
        next_title=$(yq ".tasks[] | select(.id == \"$next_task\") | .title" "$TASKS_FILE" 2>/dev/null)
        next_priority=$(yq ".tasks[] | select(.id == \"$next_task\") | .priority" "$TASKS_FILE" 2>/dev/null)

        echo -e "  ${YELLOW}▶ Next Task:${NC} ${BOLD}$next_task${NC}"
        echo -e "    ${CYAN}$next_title${NC}"
        echo -e "    Priority: $next_priority"
    else
        echo -e "  ${GREEN}${BOLD}🎉 ALL TASKS COMPLETE!${NC}"
    fi
    echo ""
}

# Show recent commits
show_recent_commits() {
    echo -e "${BOLD}${MAGENTA}📝 Recent Commits:${NC}"
    echo ""

    if git log --oneline -5 &>/dev/null; then
        git log --oneline --color=always -5 | sed 's/^/  /'
    else
        echo -e "  ${RED}No commits yet${NC}"
    fi
    echo ""
}

# Show live progress if Ralph is running
show_live_progress() {
    echo -e "${BOLD}${YELLOW}⚡ Live Progress:${NC}"
    echo ""

    if [ -f "$PROGRESS_FILE" ]; then
        # Show last 15 lines of progress
        tail -15 "$PROGRESS_FILE" | while IFS= read -r line; do
            # Colorize based on content
            if [[ "$line" =~ "✓"|"COMPLETED"|"SUCCESS" ]]; then
                echo -e "  ${GREEN}$line${NC}"
            elif [[ "$line" =~ "✗"|"ERROR"|"FAILED" ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" =~ "→"|"STARTING"|"Working on" ]]; then
                echo -e "  ${CYAN}$line${NC}"
            elif [[ "$line" =~ "⚠"|"WARNING" ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            else
                echo -e "  $line"
            fi
        done
    else
        echo -e "  ${YELLOW}Waiting for Ralph to start...${NC}"
        echo -e "  ${CYAN}Run: ./.claude/ralph/ralph.sh${NC}"
    fi
    echo ""
}

# Show session summary
show_session_summary() {
    echo -e "${BOLD}${BLUE}📊 Session Summary:${NC}"
    echo ""

    if [ -f "$RALPH_DIR/metrics.json" ]; then
        total_sessions=$(jq -r '.totalSessions' "$RALPH_DIR/metrics.json" 2>/dev/null || echo "0")
        tasks_completed=$(jq -r '.tasksCompleted' "$RALPH_DIR/metrics.json" 2>/dev/null || echo "0")
        tasks_failed=$(jq -r '.tasksFailed' "$RALPH_DIR/metrics.json" 2>/dev/null || echo "0")

        echo -e "  Sessions run:     ${BOLD}$total_sessions${NC}"
        echo -e "  Tasks completed:  ${GREEN}$tasks_completed${NC}"
        echo -e "  Tasks failed:     ${RED}$tasks_failed${NC}"
    else
        echo -e "  ${YELLOW}No metrics yet${NC}"
    fi
    echo ""
}

# Main display
show_current_task
show_recent_commits
show_session_summary
show_live_progress

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}Monitoring Options:${NC}"
echo ""
echo -e "  ${CYAN}Watch live progress:${NC}    tail -f $PROGRESS_FILE"
echo -e "  ${CYAN}View session log:${NC}       cat $SESSION_LOG"
echo -e "  ${CYAN}Check task status:${NC}      cat $TASKS_FILE | grep completed"
echo -e "  ${CYAN}See git changes:${NC}        git status"
echo ""
echo -e "${BOLD}${YELLOW}Press Ctrl+C to exit, or run with --watch for live updates${NC}"

# If --watch flag, continuously update
if [ "${1:-}" = "--watch" ]; then
    echo ""
    echo -e "${GREEN}Watching for changes... (Ctrl+C to stop)${NC}"
    echo ""

    while true; do
        sleep 5
        clear

        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║              Ralph Progress Monitor (Live)                       ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        show_current_task
        show_recent_commits
        show_session_summary
        show_live_progress

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "Last updated: $(date '+%H:%M:%S') | Refreshing every 5 seconds..."
    done
fi
