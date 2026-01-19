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
PARALLEL_DIR="$RALPH_DIR/parallel"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

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

# ═══════════════════════════════════════════════════════════════════════════
# WORKER THREADS - Parallel Execution Status
# ═══════════════════════════════════════════════════════════════════════════

# Estimate task progress based on elapsed time (assumes ~5min per task)
estimate_task_progress() {
    local task_id="$1"
    local status_file="$PARALLEL_DIR/workers/worker-*.status"

    # Check if we have a start time recorded
    local start_file="$PARALLEL_DIR/workers/task-$task_id.start"
    if [[ -f "$start_file" ]]; then
        local start_time=$(cat "$start_file")
        local now=$(date +%s)
        local elapsed=$((now - start_time))
        local estimated_total=300  # 5 minutes default
        local progress=$((elapsed * 100 / estimated_total))

        # Cap at 95% until actually complete
        if [[ $progress -gt 95 ]]; then
            progress=95
        fi
        echo "$progress"
    else
        # If no start time, show indeterminate progress
        echo "50"
    fi
}

# Display parallel worker thread status
show_parallel_threads() {
    echo -e "${BOLD}${MAGENTA}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${MAGENTA}│  WORKER THREADS                                                      │${NC}"
    echo -e "${BOLD}${MAGENTA}├─────────────────────────────────────────────────────────────────────┤${NC}"

    local workers_dir="$PARALLEL_DIR/workers"
    local any_worker_active=false

    for i in 1 2 3; do
        local status_file="$workers_dir/worker-$i.status"
        local status="stopped"
        local task_id=""
        local task_title=""

        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
            any_worker_active=true
        fi

        if [[ "$status" =~ ^running: ]]; then
            task_id="${status#running:}"
            task_title=$(yq ".tasks[] | select(.id == \"$task_id\") | .title" "$TASKS_FILE" 2>/dev/null | head -c 40)

            echo -e "${BOLD}${MAGENTA}│${NC}  ${GREEN}▶ Thread $i${NC} ─── ${CYAN}$task_id${NC}: $task_title"

            # Show progress bar
            local progress=$(estimate_task_progress "$task_id")
            local filled=$((progress / 5))
            local empty=$((20 - filled))
            local bar=""
            for ((j=0; j<filled; j++)); do bar+="█"; done
            for ((j=0; j<empty; j++)); do bar+="░"; done
            echo -e "${BOLD}${MAGENTA}│${NC}              [${GREEN}$bar${NC}] ${progress}%"

        elif [[ "$status" == "idle" ]]; then
            echo -e "${BOLD}${MAGENTA}│${NC}  ${YELLOW}○ Thread $i${NC} ─── ${DIM}waiting for task...${NC}"

        elif [[ "$status" == "paused" ]]; then
            echo -e "${BOLD}${MAGENTA}│${NC}  ${BLUE}⏸ Thread $i${NC} ─── ${DIM}paused (validation)${NC}"

        else
            echo -e "${BOLD}${MAGENTA}│${NC}  ${RED}✗ Thread $i${NC} ─── ${DIM}stopped${NC}"
        fi
        echo -e "${BOLD}${MAGENTA}│${NC}"
    done

    echo -e "${BOLD}${MAGENTA}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    return 0
}

# Display task queue grouped by parallel_group
show_task_queue_visualization() {
    echo -e "${BOLD}${BLUE}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${BLUE}│  TASK QUEUE BY PARALLEL GROUP                                        │${NC}"
    echo -e "${BOLD}${BLUE}├─────────────────────────────────────────────────────────────────────┤${NC}"

    # Get unique parallel groups (sorted)
    local groups=$(yq '[.tasks[].parallel_group] | unique | sort | .[]' "$TASKS_FILE" 2>/dev/null)

    for group in $groups; do
        # Count completed vs total for this group
        local completed=$(yq "[.tasks[] | select(.parallel_group == $group and .completed == true)] | length" "$TASKS_FILE" 2>/dev/null || echo "0")
        local total=$(yq "[.tasks[] | select(.parallel_group == $group)] | length" "$TASKS_FILE" 2>/dev/null || echo "0")

        # Group header with completion status
        if [[ "$completed" -eq "$total" ]]; then
            echo -e "${BOLD}${BLUE}│${NC}  ${GREEN}✓ Group $group${NC} [$completed/$total] ────────────────────────────────────"
        else
            echo -e "${BOLD}${BLUE}│${NC}  ${CYAN}► Group $group${NC} [$completed/$total] ────────────────────────────────────"
        fi

        # Show tasks in group (horizontal layout for parallelism visualization)
        local task_line="${BOLD}${BLUE}│${NC}    "
        local tasks_in_group=$(yq ".tasks[] | select(.parallel_group == $group) | .id" "$TASKS_FILE" 2>/dev/null)

        for task_id in $tasks_in_group; do
            local task_completed=$(yq ".tasks[] | select(.id == \"$task_id\") | .completed" "$TASKS_FILE" 2>/dev/null)

            # Check if task is currently assigned (running)
            local is_running=false
            if [[ -d "$PARALLEL_DIR/workers" ]]; then
                if grep -l "running:$task_id" "$PARALLEL_DIR/workers/"*.status 2>/dev/null >/dev/null; then
                    is_running=true
                fi
            fi

            if [[ "$task_completed" == "true" ]]; then
                task_line+="${GREEN}[$task_id]${NC} "
            elif [[ "$is_running" == "true" ]]; then
                task_line+="${YELLOW}[$task_id]${NC} "
            else
                task_line+="${DIM}[$task_id]${NC} "
            fi
        done

        echo -e "$task_line"

        # Show parallel execution indicator
        if [[ "$total" -gt 1 ]] && [[ "$completed" -lt "$total" ]]; then
            echo -e "${BOLD}${BLUE}│${NC}    ${DIM}└── Can run in parallel (no file conflicts)${NC}"
        fi

        echo -e "${BOLD}${BLUE}│${NC}"
    done

    echo -e "${BOLD}${BLUE}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Display active file locks held by workers
show_active_locks() {
    local locks_dir="$PARALLEL_DIR/locks"

    if [[ ! -d "$locks_dir" ]]; then
        return 0
    fi

    local lock_files=("$locks_dir"/*.lock 2>/dev/null)
    local lock_count=0

    for lock_file in "${lock_files[@]}"; do
        [[ -f "$lock_file" ]] && ((lock_count++)) || true
    done

    if [[ $lock_count -gt 0 ]]; then
        echo -e "${BOLD}${YELLOW}⚿ Active File Locks:${NC}"
        echo ""

        for lock_file in "$locks_dir"/*.lock; do
            [[ -f "$lock_file" ]] || continue
            local file=$(basename "$lock_file" .lock | tr '_' '/')
            local holder=$(cat "$lock_file")
            echo -e "  ${YELLOW}⚿${NC} $file ${DIM}(held by $holder)${NC}"
        done
        echo ""
    fi
}

# Check if parallel mode is active
is_parallel_mode_active() {
    [[ -d "$PARALLEL_DIR" ]] && [[ -d "$PARALLEL_DIR/workers" ]]
}

# Parse command line arguments
SHOW_PARALLEL=false
WATCH_MODE=false
for arg in "$@"; do
    case "$arg" in
        --parallel)
            SHOW_PARALLEL=true
            ;;
        --watch)
            WATCH_MODE=true
            ;;
    esac
done

# Main display function
display_main() {
    show_current_task

    # Show parallel visualization if enabled or if parallel mode is active
    if [[ "$SHOW_PARALLEL" == "true" ]] || is_parallel_mode_active 2>/dev/null; then
        show_parallel_threads
        show_task_queue_visualization
        show_active_locks
    fi

    show_recent_commits
    show_session_summary
    show_live_progress
}

# Main display
display_main

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BOLD}Monitoring Options:${NC}"
echo ""
echo -e "  ${CYAN}Watch live progress:${NC}    tail -f $PROGRESS_FILE"
echo -e "  ${CYAN}View session log:${NC}       cat $SESSION_LOG"
echo -e "  ${CYAN}Check task status:${NC}      cat $TASKS_FILE | grep completed"
echo -e "  ${CYAN}See git changes:${NC}        git status"
echo -e "  ${CYAN}Parallel view:${NC}          $0 --parallel"
echo ""
echo -e "${BOLD}${YELLOW}Press Ctrl+C to exit, or run with --watch for live updates${NC}"
echo -e "${BOLD}${YELLOW}Add --parallel to show worker threads and task queue${NC}"

# If --watch flag, continuously update
if [[ "$WATCH_MODE" == "true" ]]; then
    echo ""
    echo -e "${GREEN}Watching for changes... (Ctrl+C to stop)${NC}"
    echo ""

    while true; do
        sleep 5
        clear

        if [[ "$SHOW_PARALLEL" == "true" ]] || is_parallel_mode_active 2>/dev/null; then
            echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║              RALPH PARALLEL EXECUTION MONITOR (Live)                  ║${NC}"
            echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
        else
            echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║              Ralph Progress Monitor (Live)                       ║${NC}"
            echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        fi
        echo ""

        display_main

        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "Last updated: $(date '+%H:%M:%S') | Refreshing every 5 seconds..."
    done
fi
