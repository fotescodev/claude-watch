#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  RALPH TUI — Retro-Future Terminal Dashboard
#  An autonomous coding loop monitor with personality
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASKS_FILE="$SCRIPT_DIR/tasks.yaml"
PROGRESS_LOG="$SCRIPT_DIR/current-progress.log"
METRICS_FILE="$SCRIPT_DIR/metrics.json"

#───────────────────────────────────────────────────────────────────────────────
# COLOR PALETTE
#───────────────────────────────────────────────────────────────────────────────

CORAL='\033[38;5;209m'
CORAL_BRIGHT='\033[38;5;216m'
CORAL_DIM='\033[38;5;167m'
CORAL_DEEP='\033[38;5;166m'

WHITE='\033[97m'
GRAY='\033[90m'
DARK='\033[38;5;238m'

GREEN='\033[38;5;114m'
GREEN_DIM='\033[38;5;108m'
YELLOW='\033[38;5;221m'
CYAN='\033[38;5;116m'
RED='\033[38;5;203m'

BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

#───────────────────────────────────────────────────────────────────────────────
# ANIMATION
#───────────────────────────────────────────────────────────────────────────────

PULSE_FRAMES=("◉" "◎" "◉" "◎")
SPIN_FRAMES=("⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷")
FRAME_IDX=0

#───────────────────────────────────────────────────────────────────────────────
# VIEW STATE
#───────────────────────────────────────────────────────────────────────────────

CURRENT_VIEW="dashboard"

#───────────────────────────────────────────────────────────────────────────────
# TERMINAL SETUP
#───────────────────────────────────────────────────────────────────────────────

setup() {
    tput civis 2>/dev/null
    tput clear
    stty -echo 2>/dev/null
}

cleanup() {
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    echo ""
    echo -e "  ${CORAL}░▒▓${NC} ${WHITE}Ralph signing off${NC} ${CORAL}▓▒░${NC}"
    echo ""
    exit 0
}

read_key() {
    # Non-blocking read of a single keypress
    # Returns: the key pressed, or empty string if no key available
    local key=""
    if IFS= read -t 0.01 -r -s -n 1 key 2>/dev/null; then
        echo "$key"
    fi
}

handle_input() {
    # Process keypresses and switch views
    local key=$(read_key)

    case "$key" in
        d|D|1)
            CURRENT_VIEW="dashboard"
            ;;
        m|M|2)
            CURRENT_VIEW="metrics"
            ;;
        s|S|3)
            CURRENT_VIEW="sessions"
            ;;
        t|T|4)
            CURRENT_VIEW="tasks"
            ;;
        q|Q)
            cleanup
            ;;
    esac
}

trap cleanup INT TERM EXIT

#───────────────────────────────────────────────────────────────────────────────
# DATA FETCHERS
#───────────────────────────────────────────────────────────────────────────────

get_tasks() {
    yq -r '.tasks[] | [.id, .title, .completed, .priority] | @tsv' "$TASKS_FILE" 2>/dev/null
}

get_session() {
    local s=$(grep "Starting session" "$PROGRESS_LOG" 2>/dev/null | tail -1 | grep -oE 'session-[0-9]+')
    echo "${s:-initializing}"
}

get_session_start_time() {
    local line=$(grep "Starting session" "$PROGRESS_LOG" 2>/dev/null | tail -1)
    if [[ "$line" =~ at\ ([0-9:]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

get_last_commit() {
    cd "$PROJECT_ROOT"
    git log --oneline -1 2>/dev/null | cut -c9-60
}

get_last_commit_time() {
    cd "$PROJECT_ROOT"
    git log -1 --format="%ar" 2>/dev/null
}

get_total_sessions() {
    jq -r '.totalSessions // 0' "$METRICS_FILE" 2>/dev/null || echo "0"
}

get_tokens() {
    local input=$(jq -r '.totalTokens.input // 0' "$METRICS_FILE" 2>/dev/null || echo "0")
    local output=$(jq -r '.totalTokens.output // 0' "$METRICS_FILE" 2>/dev/null || echo "0")
    echo "$((input + output))"
}

get_cost() {
    jq -r '.estimatedCost // 0' "$METRICS_FILE" 2>/dev/null || echo "0"
}

get_activity() {
    local last=$(tail -1 "$PROGRESS_LOG" 2>/dev/null)
    # Clean up the line for display
    echo "$last" | sed 's/^→ //' | cut -c1-45
}

is_ralph_running() {
    # Check for the actual ralph.sh process (not TUI or subprocesses)
    # Use ps + grep to filter precisely
    ps aux 2>/dev/null | grep -E "bash.*ralph\.sh" | grep -v "ralph-tui" | grep -qv grep && echo "1" || echo "0"
}

get_workers() {
    # Get all Ralph-related worker processes with their status
    # Format: TYPE|PID|STATUS|DETAIL
    local workers=()

    # Main ralph.sh orchestrator
    local ralph_pid=$(ps aux 2>/dev/null | grep -E "bash.*ralph\.sh$" | grep -v "ralph-tui" | grep -v grep | awk '{print $2}' | head -1)
    if [[ -n "$ralph_pid" ]]; then
        local current_task=$(grep "Selected task:" "$PROGRESS_LOG" 2>/dev/null | tail -1 | sed 's/.*Selected task: //')
        workers+=("orchestrator|$ralph_pid|active|${current_task:-initializing}")
    fi

    # Claude subagents spawned by Ralph
    local claude_procs=$(ps aux 2>/dev/null | grep -E "claude.*--print|claude --output-format" | grep -v grep | grep -v "Portfolio")
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pid=$(echo "$line" | awk '{print $2}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local elapsed=$(echo "$line" | awk '{print $10}')
        # Try to get what it's working on from the session
        local task_hint=$(grep -E "Starting session|Working on" "$PROGRESS_LOG" 2>/dev/null | tail -1 | cut -c1-30)
        workers+=("claude|$pid|${cpu}% cpu|${task_hint:-processing}")
    done <<< "$claude_procs"

    # Verification scripts
    local verify_pid=$(ps aux 2>/dev/null | grep -E "verify\.sh|watchos-verify" | grep -v grep | awk '{print $2}' | head -1)
    if [[ -n "$verify_pid" ]]; then
        workers+=("verify|$verify_pid|running|build check")
    fi

    # Build processes (xcodebuild)
    local build_pid=$(ps aux 2>/dev/null | grep -E "xcodebuild.*ClaudeWatch" | grep -v grep | awk '{print $2}' | head -1)
    if [[ -n "$build_pid" ]]; then
        workers+=("xcode|$build_pid|building|ClaudeWatch")
    fi

    printf '%s\n' "${workers[@]}"
}

#───────────────────────────────────────────────────────────────────────────────
# RENDER ENGINE
#───────────────────────────────────────────────────────────────────────────────

render() {
    local W=$(tput cols 2>/dev/null || echo 80)
    local H=$(tput lines 2>/dev/null || echo 24)
    local pad="  "

    tput cup 0 0

    # Advance animation frame
    FRAME_IDX=$(( (FRAME_IDX + 1) % 8 ))
    local spin="${SPIN_FRAMES[$FRAME_IDX]}"
    local pulse="${PULSE_FRAMES[$((FRAME_IDX % 4))]}"

    #═══════════════════════════════════════════════════════════════════════════
    # HEADER — The Ralph Logo
    #═══════════════════════════════════════════════════════════════════════════

    echo ""
    echo -e "${pad}${CORAL}    ╭──────────╮${NC}"
    echo -e "${pad}${CORAL}    │${NC}          ${CORAL}├${CORAL_DIM}╤╮${NC}"
    echo -e "${pad}${CORAL}    │${NC}  ${WHITE}◠${NC}    ${WHITE}■${NC}  ${CORAL}│${CORAL_DIM}││${NC}"
    echo -e "${pad}${CORAL}    │${NC}          ${CORAL}├${CORAL_DIM}╧╯${NC}"
    echo -e "${pad}${CORAL}    │${NC}  ${WHITE}╰────╯${NC}  ${CORAL}│${NC}"
    echo -e "${pad}${CORAL}    │${NC}          ${CORAL}│${NC}"
    echo -e "${pad}${CORAL}    ╰──────────╯${NC}"
    echo ""

    #═══════════════════════════════════════════════════════════════════════════
    # TITLE + STATUS BAR
    #═══════════════════════════════════════════════════════════════════════════

    local session=$(get_session)
    local running=$(is_ralph_running)
    local status_icon status_text time_display

    if [[ "$running" == "1" ]]; then
        status_icon="${GREEN}●${NC}"
        status_text="${GREEN}running${NC}"
        time_display="${DIM}$(date '+%H:%M:%S')${NC}"
    else
        status_icon="${GRAY}○${NC}"
        status_text="${GRAY}idle${NC}"
        # Show last session time from metrics instead of live clock
        local last_session=$(jq -r '.lastSession // ""' "$METRICS_FILE" 2>/dev/null)
        if [[ -n "$last_session" && "$last_session" != "null" ]]; then
            time_display="${DIM}stopped${NC}"
        else
            time_display="${DIM}--:--:--${NC}"
        fi
    fi

    echo -e "${pad}${CORAL}${BOLD}    R  A  L  P  H${NC}"
    echo -e "${pad}${GRAY}    autonomous coding loop${NC}"
    echo ""
    echo -e "${pad}${DARK}    ┌───────────────────────────────────────────────────┐${NC}"
    echo -e "${pad}${DARK}    │${NC} ${status_icon} ${status_text}  ${GRAY}│${NC}  ${CORAL}${spin}${NC} ${WHITE}${session}${NC}  ${GRAY}│${NC}  ${time_display}             ${DARK}│${NC}"
    echo -e "${pad}${DARK}    └───────────────────────────────────────────────────┘${NC}"
    echo ""

    #═══════════════════════════════════════════════════════════════════════════
    # TASK DATA
    #═══════════════════════════════════════════════════════════════════════════

    local completed=0 total=0
    declare -a done_tasks todo_tasks

    while IFS=$'\t' read -r id title comp prio; do
        [[ -z "$id" ]] && continue
        ((total++))
        if [[ "$comp" == "true" ]]; then
            ((completed++))
            done_tasks+=("$id|$title")
        else
            todo_tasks+=("$id|$title|$prio")
        fi
    done < <(get_tasks)

    local remaining=$((total - completed))
    local pct=0
    [[ $total -gt 0 ]] && pct=$((completed * 100 / total))

    #═══════════════════════════════════════════════════════════════════════════
    # PROGRESS — The Hero Metric
    #═══════════════════════════════════════════════════════════════════════════

    # Big percentage display - width proportional to progress
    local pct_bar_w=$((pct * 40 / 100))
    [[ $pct_bar_w -lt 2 ]] && pct_bar_w=2

    printf "${pad}    "
    for ((i=0; i<pct_bar_w; i++)); do printf "${CORAL_BRIGHT}${BOLD}█${NC}"; done
    echo ""
    printf "${pad}    "
    for ((i=0; i<pct_bar_w; i++)); do printf "${CORAL_BRIGHT}${BOLD}█${NC}"; done
    printf "  ${WHITE}${BOLD}%d%%${NC}\n" "$pct"
    printf "${pad}    "
    for ((i=0; i<pct_bar_w; i++)); do printf "${CORAL_BRIGHT}${BOLD}█${NC}"; done
    echo ""
    echo ""

    # Progress bar with gradient
    local bar_w=40
    local filled=$((pct * bar_w / 100))

    printf "${pad}    "
    for ((i=0; i<bar_w; i++)); do
        if ((i < filled)); then
            if ((i < filled/3)); then
                printf "${CORAL_DEEP}█${NC}"
            elif ((i < 2*filled/3)); then
                printf "${CORAL}█${NC}"
            else
                printf "${CORAL_BRIGHT}█${NC}"
            fi
        else
            printf "${DARK}░${NC}"
        fi
    done
    echo ""
    echo ""

    echo -e "${pad}    ${GREEN}●${NC} ${WHITE}${completed}${NC} ${GRAY}done${NC}    ${CORAL}○${NC} ${WHITE}${remaining}${NC} ${GRAY}todo${NC}    ${GRAY}of ${total}${NC}"
    echo ""

    #═══════════════════════════════════════════════════════════════════════════
    # LAST COMMIT — Proof of Work
    #═══════════════════════════════════════════════════════════════════════════

    local last_commit=$(get_last_commit)
    local commit_time=$(get_last_commit_time)

    if [[ -n "$last_commit" ]]; then
        printf "${pad}${CORAL}    "
        for ((i=0; i<52; i++)); do printf "─"; done
        printf "${NC}\n"
        echo ""
        echo -e "${pad}    ${CYAN}⎋${NC}  ${DIM}last commit${NC}  ${GRAY}${commit_time}${NC}"
        echo -e "${pad}       ${WHITE}${last_commit}${NC}"
        echo ""
    fi

    #═══════════════════════════════════════════════════════════════════════════
    # ACTIVITY — What's happening now
    #═══════════════════════════════════════════════════════════════════════════

    local activity=$(get_activity)
    if [[ -n "$activity" && "$running" == "1" ]]; then
        echo -e "${pad}    ${CORAL}${pulse}${NC}  ${DIM}activity${NC}"
        echo -e "${pad}       ${GRAY}${activity}${NC}"
        echo ""
    fi

    #═══════════════════════════════════════════════════════════════════════════
    # WORKERS — Active threads/processes
    #═══════════════════════════════════════════════════════════════════════════

    if [[ "$running" == "1" ]]; then
        echo -e "${pad}    ${CYAN}${BOLD}⚡ WORKERS${NC}"
        echo ""

        local worker_count=0
        while IFS='|' read -r wtype wpid wstatus wdetail; do
            [[ -z "$wtype" ]] && continue
            ((worker_count++))

            local wicon wcolor
            case "$wtype" in
                orchestrator) wicon="◉"; wcolor="$CORAL" ;;
                claude)       wicon="◈"; wcolor="$CYAN" ;;
                verify)       wicon="◇"; wcolor="$YELLOW" ;;
                xcode)        wicon="◆"; wcolor="$GREEN" ;;
                *)            wicon="○"; wcolor="$GRAY" ;;
            esac

            printf "${pad}    ${wcolor}${wicon}${NC}  ${WHITE}%-12s${NC} ${DIM}pid:%-6s${NC} ${GRAY}%s${NC}\n" \
                "$wtype" "$wpid" "${wdetail:0:28}"
        done < <(get_workers)

        if [[ $worker_count -eq 0 ]]; then
            echo -e "${pad}    ${GRAY}○  no active workers${NC}"
        fi
        echo ""
    fi

    #═══════════════════════════════════════════════════════════════════════════
    # TASK LISTS
    #═══════════════════════════════════════════════════════════════════════════

    printf "${pad}${CORAL}    "
    for ((i=0; i<52; i++)); do printf "─"; done
    printf "${NC}\n"
    echo ""

    # Remaining tasks
    if [[ ${#todo_tasks[@]} -gt 0 ]]; then
        echo -e "${pad}    ${CORAL}${BOLD}◯ TODO${NC} ${GRAY}(${remaining})${NC}"
        echo ""

        local show_todo=4
        [[ $H -gt 40 ]] && show_todo=6

        for ((i=0; i<show_todo && i<${#todo_tasks[@]}; i++)); do
            IFS='|' read -r id title prio <<< "${todo_tasks[$i]}"
            title="${title:0:40}"

            local pcolor="$GRAY"
            local marker="○"
            case "$prio" in
                critical) pcolor="$RED"; marker="◆" ;;
                high)     pcolor="$YELLOW"; marker="◇" ;;
                medium)   pcolor="$CORAL"; marker="○" ;;
                *)        pcolor="$GRAY"; marker="○" ;;
            esac

            printf "${pad}    ${pcolor}${marker}${NC}  ${WHITE}%-6s${NC}  ${GRAY}%s${NC}\n" "[$id]" "$title"
        done

        [[ ${#todo_tasks[@]} -gt $show_todo ]] && echo -e "${pad}       ${DIM}+$((${#todo_tasks[@]} - show_todo)) more${NC}"
        echo ""
    fi

    # Completed tasks
    if [[ ${#done_tasks[@]} -gt 0 ]]; then
        echo -e "${pad}    ${GREEN_DIM}${BOLD}✓ DONE${NC} ${GRAY}(${completed})${NC}"
        echo ""

        local show_done=3
        [[ $H -gt 45 ]] && show_done=5

        for ((i=0; i<show_done && i<${#done_tasks[@]}; i++)); do
            IFS='|' read -r id title <<< "${done_tasks[$i]}"
            title="${title:0:40}"
            printf "${pad}    ${GREEN}✓${NC}  ${DIM}%-6s${NC}  ${DIM}%s${NC}\n" "[$id]" "$title"
        done

        [[ ${#done_tasks[@]} -gt $show_done ]] && echo -e "${pad}       ${DIM}+$((${#done_tasks[@]} - show_done)) more${NC}"
    fi

    echo ""

    #═══════════════════════════════════════════════════════════════════════════
    # FOOTER — Stats
    #═══════════════════════════════════════════════════════════════════════════

    local total_sessions=$(get_total_sessions)
    local tokens=$(get_tokens)
    local cost=$(get_cost)

    # Format tokens (K for thousands, M for millions)
    local tokens_fmt="$tokens"
    if [[ $tokens -ge 1000000 ]]; then
        tokens_fmt="$(echo "scale=1; $tokens/1000000" | bc)M"
    elif [[ $tokens -ge 1000 ]]; then
        tokens_fmt="$(echo "scale=1; $tokens/1000" | bc)K"
    fi

    printf "${pad}${CORAL}    "
    for ((i=0; i<52; i++)); do printf "─"; done
    printf "${NC}\n"
    echo ""
    echo -e "${pad}    ${DARK}${total_sessions} sessions${NC}  ${DARK}│${NC}  ${CYAN}${tokens_fmt} tokens${NC}  ${DARK}│${NC}  ${GREEN}\$${cost}${NC}  ${DARK}│${NC}  ${DIM}Ctrl+C${NC}"

    tput ed 2>/dev/null
}

#───────────────────────────────────────────────────────────────────────────────
# MAIN LOOP
#───────────────────────────────────────────────────────────────────────────────

main() {
    setup

    while true; do
        handle_input
        render
        sleep 0.4
    done
}

main
