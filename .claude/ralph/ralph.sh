#!/bin/bash
#
# watchOS Ralph Loop - Autonomous Coding for Apple Watch Apps
#
# An autonomous AI coding harness that runs Claude Code in a continuous loop,
# guided by structured prompts and task lists, specialized for watchOS development.
#
# Usage: ./ralph.sh [OPTIONS]
#
# Options:
#   -h, --help              Show this help message
#   -v, --verbose           Enable verbose output
#   -d, --debug             Enable verbose mode (shows all Claude output)
#   --dry-run               Show prompts without executing Claude
#   --init                  Run initializer instead of main loop
#   --single                Run single session then exit
#   --max-iterations N      Limit total loop iterations (default: unlimited)
#   --max-retries N         Retries per failed task (default: 3)
#   --retry-delay N         Seconds between retries (default: 5)
#   --branch-per-task       Create feature branches per task
#   --create-pr             Auto-create PRs on task completion
#   --draft-pr              Create draft PRs instead
#   --base-branch NAME      Base branch for PRs (default: main)
#
# Exit Codes:
#   0   All tasks completed successfully
#   1   Task failed after max retries
#   2   Build failure
#   3   Verification failure
#   130 User interrupt (Ctrl+C)
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RALPH_DIR="$SCRIPT_DIR"

# Files
PROMPT_FILE="$RALPH_DIR/PROMPT.md"
INITIALIZER_FILE="$RALPH_DIR/INITIALIZER.md"
TASKS_FILE="$RALPH_DIR/tasks.yaml"
SESSION_LOG="$RALPH_DIR/session-log.md"
METRICS_FILE="$RALPH_DIR/metrics.json"
VERIFY_SCRIPT="$RALPH_DIR/watchos-verify.sh"

# Defaults
MAX_ITERATIONS=0  # 0 = unlimited
MAX_RETRIES=3
RETRY_DELAY=5
VERBOSE=false
DEBUG=false
DRY_RUN=false
INIT_MODE=false
SINGLE_MODE=false
BRANCH_PER_TASK=false
CREATE_PR=false
DRAFT_PR=false
BASE_BRANCH="main"

# Colors (auto-detect terminal support)
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    echo -e "${CYAN}[ralph]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[ralph]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[ralph]${NC} $*"
}

log_error() {
    echo -e "${RED}[ralph]${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[ralph]${NC} $*"
    fi
}

show_help() {
    cat << 'EOF'
watchOS Ralph Loop - Autonomous Coding for Apple Watch Apps

Usage: ./ralph.sh [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output
  -d, --debug             Enable verbose mode (shows all Claude output)
  --dry-run               Show prompts without executing Claude
  --init                  Run initializer instead of main loop
  --single                Run single session then exit
  --max-iterations N      Limit total loop iterations (default: unlimited)
  --max-retries N         Retries per failed task (default: 3)
  --retry-delay N         Seconds between retries (default: 5)
  --branch-per-task       Create feature branches per task
  --create-pr             Auto-create PRs on task completion
  --draft-pr              Create draft PRs instead
  --base-branch NAME      Base branch for PRs (default: main)

Examples:
  ./ralph.sh                      # Run autonomous loop
  ./ralph.sh --init               # Initialize Ralph (first time)
  ./ralph.sh --single             # Run one session then exit
  ./ralph.sh --debug              # Run with verbose output
  ./ralph.sh --dry-run            # Preview without executing
  ./ralph.sh --branch-per-task    # Create feature branches

Exit Codes:
  0   All tasks completed / session ended normally
  1   Task failed after max retries
  2   Build failure
  130 User interrupt (Ctrl+C)
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

preflight_check() {
    log "Running preflight checks..."

    local errors=0

    # Check we're in the project root
    if [[ ! -f "$PROJECT_ROOT/ClaudeWatch.xcodeproj/project.pbxproj" ]]; then
        log_error "Not in claude-watch project root"
        ((errors++))
    fi

    # Check Claude CLI is available
    if ! command -v claude &> /dev/null; then
        log_error "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        ((errors++))
    fi

    # Check required files exist
    if [[ "$INIT_MODE" == "false" ]]; then
        if [[ ! -f "$PROMPT_FILE" ]]; then
            log_error "PROMPT.md not found. Run with --init first."
            ((errors++))
        fi
        if [[ ! -f "$TASKS_FILE" ]]; then
            log_error "tasks.yaml not found. Run with --init first."
            ((errors++))
        fi
    else
        if [[ ! -f "$INITIALIZER_FILE" ]]; then
            log_error "INITIALIZER.md not found."
            ((errors++))
        fi
    fi

    # Check git status
    if [[ -n "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null)" ]]; then
        log_warning "Git working directory has uncommitted changes"
    fi

    # Check watchOS simulator available
    if ! xcrun simctl list devices 2>/dev/null | grep -q "Apple Watch"; then
        log_warning "No watchOS simulators found. Build verification may fail."
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Preflight check failed with $errors error(s)"
        return 1
    fi

    log_success "Preflight checks passed"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# METRICS TRACKING
# ═══════════════════════════════════════════════════════════════════════════════

init_metrics() {
    if [[ ! -f "$METRICS_FILE" ]]; then
        cat > "$METRICS_FILE" << 'EOF'
{
  "version": "1.0",
  "project": "ClaudeWatch",
  "platform": "watchOS",
  "initialized": "",
  "lastSession": "",
  "totalSessions": 0,
  "totalTokens": {
    "input": 0,
    "output": 0
  },
  "estimatedCost": 0.00,
  "tasksCompleted": 0,
  "tasksFailed": 0,
  "totalRetries": 0,
  "buildFailures": 0,
  "sessions": []
}
EOF
        # Set initialized timestamp
        local now
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        if command -v jq &> /dev/null; then
            jq --arg ts "$now" '.initialized = $ts' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
        fi
    fi
}

update_metrics() {
    local session_id="$1"
    local status="$2"
    local task_id="${3:-unknown}"

    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, skipping metrics update"
        return
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update metrics
    jq --arg ts "$now" \
       --arg sid "$session_id" \
       --arg status "$status" \
       --arg tid "$task_id" \
       '.lastSession = $ts |
        .totalSessions += 1 |
        .sessions += [{
          "id": $sid,
          "timestamp": $ts,
          "taskId": $tid,
          "status": $status
        }]' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"

    if [[ "$status" == "completed" ]]; then
        jq '.tasksCompleted += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
    elif [[ "$status" == "failed" ]]; then
        jq '.tasksFailed += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# SESSION LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

init_session_log() {
    if [[ ! -f "$SESSION_LOG" ]]; then
        cat > "$SESSION_LOG" << 'EOF'
# watchOS Ralph Loop - Session Log

This file tracks session handoffs for the autonomous coding loop.
Each session documents what was accomplished and provides context for the next iteration.

---

EOF
    fi
}

log_session_start() {
    local session_id="$1"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M UTC")

    cat >> "$SESSION_LOG" << EOF

## Session $session_id - $timestamp

**Status:** STARTED

EOF
}

log_session_end() {
    local session_id="$1"
    local status="$2"
    local notes="${3:-}"

    cat >> "$SESSION_LOG" << EOF
**Status:** $status

### Notes
$notes

---
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# TASK MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

get_incomplete_task_count() {
    if ! command -v yq &> /dev/null && ! command -v python3 &> /dev/null; then
        log_warning "Neither yq nor python3 found, cannot count tasks"
        echo "0"
        return
    fi

    if command -v yq &> /dev/null; then
        yq '.tasks | map(select(.completed == false)) | length' "$TASKS_FILE" 2>/dev/null || echo "0"
    else
        python3 -c "
import yaml
with open('$TASKS_FILE') as f:
    data = yaml.safe_load(f)
    incomplete = [t for t in data.get('tasks', []) if not t.get('completed', False)]
    print(len(incomplete))
" 2>/dev/null || echo "0"
    fi
}

all_tasks_complete() {
    local count
    count=$(get_incomplete_task_count)
    [[ "$count" == "0" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

run_claude_session() {
    local prompt_file="$1"
    local session_id="$2"

    log "Starting Claude session: $session_id"
    log_verbose "Using prompt: $prompt_file"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "=== DRY RUN - Prompt Content ==="
        echo ""
        cat "$prompt_file"
        echo ""
        log "=== END DRY RUN ==="
        return 0
    fi

    # Change to project root
    cd "$PROJECT_ROOT"

    # Create progress log for monitoring
    local progress_log="$RALPH_DIR/current-progress.log"
    echo "→ Starting session $session_id at $(date '+%H:%M:%S')" > "$progress_log"

    # Run Claude with the prompt
    # Using --print to output results, piping the prompt via stdin
    # Tee output to both console and progress log
    # Note: Thinking blocks are not available in --print mode (automation)
    if [[ "$DEBUG" == "true" ]]; then
        log "Verbose mode: showing all output including TodoWrite progress"
    fi

    if cat "$prompt_file" | claude --print 2>&1 | tee -a "$progress_log"; then
        echo "✓ Session $session_id completed at $(date '+%H:%M:%S')" >> "$progress_log"
        log_success "Session $session_id completed"
        return 0
    else
        local exit_code=$?
        echo "✗ Session $session_id failed at $(date '+%H:%M:%S')" >> "$progress_log"
        log_error "Session $session_id failed with exit code $exit_code"
        return $exit_code
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# BRANCH MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

create_task_branch() {
    local task_slug="$1"
    local branch_name="ralph/watchos-$task_slug"

    log "Creating branch: $branch_name"

    cd "$PROJECT_ROOT"

    # Fetch latest
    git fetch origin "$BASE_BRANCH" 2>/dev/null || true

    # Create and checkout branch
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git checkout "$branch_name"
    else
        git checkout -b "$branch_name" "origin/$BASE_BRANCH" 2>/dev/null || \
        git checkout -b "$branch_name" "$BASE_BRANCH"
    fi

    echo "$branch_name"
}

create_pull_request() {
    local branch_name="$1"
    local task_title="$2"

    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not found, skipping PR creation"
        return
    fi

    log "Creating pull request for: $branch_name"

    cd "$PROJECT_ROOT"

    # Push branch
    git push -u origin "$branch_name"

    # Create PR
    local pr_args=("--title" "[Ralph] $task_title" "--body" "Automated PR from watchOS Ralph Loop")

    if [[ "$DRAFT_PR" == "true" ]]; then
        pr_args+=("--draft")
    fi

    gh pr create "${pr_args[@]}" || log_warning "PR creation failed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

run_verification() {
    if [[ ! -x "$VERIFY_SCRIPT" ]]; then
        log_warning "Verification script not executable or not found"
        return 0
    fi

    log "Running verification harness..."

    if "$VERIFY_SCRIPT"; then
        log_success "Verification passed"
        return 0
    else
        log_error "Verification failed"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════════════

run_init() {
    log "Initializing watchOS Ralph Loop..."

    init_metrics
    init_session_log

    local session_id="init-$(date +%s)"
    log_session_start "$session_id"

    run_claude_session "$INITIALIZER_FILE" "$session_id"
    local result=$?

    if [[ $result -eq 0 ]]; then
        log_session_end "$session_id" "COMPLETED" "Initialization successful"
        update_metrics "$session_id" "completed" "init"

        # Generate initial TASKS.md
        log "Generating initial TASKS.md..."
        if python3 "$RALPH_DIR/generate-tasks-md.py" 2>&1 | grep -q "successfully"; then
            log_success "TASKS.md generated"
        else
            log_warning "Failed to generate TASKS.md"
        fi

        log_success "Initialization complete. Run ./ralph.sh to start the loop."
    else
        log_session_end "$session_id" "FAILED" "Initialization failed"
        update_metrics "$session_id" "failed" "init"
        log_error "Initialization failed"
    fi

    return $result
}

run_loop() {
    log "Starting watchOS Ralph Loop..."
    log "Press Ctrl+C to stop"
    echo ""

    init_metrics
    init_session_log

    local iteration=0
    local consecutive_failures=0

    while true; do
        ((iteration++))

        # Check iteration limit
        if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $iteration -gt $MAX_ITERATIONS ]]; then
            log "Reached maximum iterations ($MAX_ITERATIONS)"
            break
        fi

        # Check if all tasks complete
        if all_tasks_complete; then
            log_success "All tasks completed!"
            break
        fi

        local session_id="session-$(printf '%03d' $iteration)"

        echo ""
        log "═══════════════════════════════════════════════════════════════"
        log "  Iteration $iteration"
        log "═══════════════════════════════════════════════════════════════"
        echo ""

        log_session_start "$session_id"

        # Select next task from tasks.yaml
        local next_task_id
        next_task_id=$(yq '.tasks[] | select(.completed == false) | .id' "$TASKS_FILE" 2>/dev/null | head -1)
        if [[ -z "$next_task_id" ]]; then
            log_error "No incomplete tasks found in tasks.yaml"
            break
        fi

        log "Selected task: $next_task_id"

        # Run Claude session
        if run_claude_session "$PROMPT_FILE" "$session_id"; then
            # CRITICAL: Verify files were actually modified (prevent plan-only behavior)
            if git diff --cached --quiet && git diff --quiet; then
                log_error "CRITICAL: No code changes detected after session"
                log_error "Ralph must IMPLEMENT changes, not just plan"
                log_error "This session will be marked as FAILED"
                log_session_end "$session_id" "FAILED" "No code changes made"
                update_metrics "$session_id" "failed" "$next_task_id"
                ((consecutive_failures++))

                if [[ $consecutive_failures -ge $MAX_RETRIES ]]; then
                    log_error "Too many consecutive failures ($consecutive_failures). Stopping."
                    return 1
                fi

                log "Waiting ${RETRY_DELAY}s before retry..."
                sleep "$RETRY_DELAY"
                continue
            fi

            log_success "Code changes detected - session valid"
            log_session_end "$session_id" "COMPLETED" "Session completed successfully"
            update_metrics "$session_id" "completed" "$next_task_id"
            consecutive_failures=0

            # Regenerate TASKS.md from tasks.yaml
            log "Updating TASKS.md from tasks.yaml..."
            if python3 "$RALPH_DIR/generate-tasks-md.py" 2>&1 | grep -q "successfully"; then
                log_success "TASKS.md updated"
            else
                log_warning "Failed to update TASKS.md"
            fi

            # Run verification
            if ! run_verification; then
                log_warning "Post-session verification had issues"
            fi
        else
            log_session_end "$session_id" "FAILED" "Session failed"
            update_metrics "$session_id" "failed" "$next_task_id"
            ((consecutive_failures++))

            if [[ $consecutive_failures -ge $MAX_RETRIES ]]; then
                log_error "Too many consecutive failures ($consecutive_failures). Stopping."
                return 1
            fi

            log "Waiting ${RETRY_DELAY}s before retry..."
            sleep "$RETRY_DELAY"
        fi

        # Single mode - exit after one session
        if [[ "$SINGLE_MODE" == "true" ]]; then
            log "Single session mode - exiting"
            break
        fi

        # Brief pause between iterations
        log "Waiting 3s before next iteration..."
        sleep 3
    done

    log_success "Ralph Loop completed"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

cleanup() {
    echo ""
    log "Received interrupt signal, cleaning up..."

    # Any cleanup needed here

    log "Goodbye!"
    exit 130
}

trap cleanup INT TERM HUP

# ═══════════════════════════════════════════════════════════════════════════════
# ARGUMENT PARSING
# ═══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --init)
            INIT_MODE=true
            shift
            ;;
        --single)
            SINGLE_MODE=true
            shift
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --max-retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --retry-delay)
            RETRY_DELAY="$2"
            shift 2
            ;;
        --branch-per-task)
            BRANCH_PER_TASK=true
            shift
            ;;
        --create-pr)
            CREATE_PR=true
            shift
            ;;
        --draft-pr)
            DRAFT_PR=true
            CREATE_PR=true
            shift
            ;;
        --base-branch)
            BASE_BRANCH="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║         watchOS Ralph Loop - Autonomous Coding Agent          ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Preflight checks
    if ! preflight_check; then
        exit 1
    fi

    # Run appropriate mode
    if [[ "$INIT_MODE" == "true" ]]; then
        run_init
    else
        run_loop
    fi
}

main
