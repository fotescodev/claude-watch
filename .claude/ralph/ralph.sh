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
#   --parallel              Enable parallel worker execution mode
#   --max-workers N         Number of parallel workers (default: 3)
#   --parallel-group N      Only run tasks in specific parallel group
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
STATUS_MODE=false
BRANCH_PER_TASK=false
CREATE_PR=false
DRAFT_PR=false
BASE_BRANCH="main"
PARALLEL_MODE=false
MAX_WORKERS=3
PARALLEL_GROUP=""

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
  --status                Show task completion status
  --max-iterations N      Limit total loop iterations (default: unlimited)
  --max-retries N         Retries per failed task (default: 3)
  --retry-delay N         Seconds between retries (default: 5)
  --branch-per-task       Create feature branches per task
  --create-pr             Auto-create PRs on task completion
  --draft-pr              Create draft PRs instead
  --base-branch NAME      Base branch for PRs (default: main)
  --parallel              Enable parallel worker execution mode
  --max-workers N         Number of parallel workers (default: 3)
  --parallel-group N      Only run tasks in specific parallel group

Examples:
  ./ralph.sh                      # Run autonomous loop
  ./ralph.sh --init               # Initialize Ralph (first time)
  ./ralph.sh --single             # Run one session then exit
  ./ralph.sh --status             # Show task status
  ./ralph.sh --debug              # Run with verbose output
  ./ralph.sh --dry-run            # Preview without executing
  ./ralph.sh --branch-per-task    # Create feature branches
  ./ralph.sh --parallel           # Run with parallel workers
  ./ralph.sh --parallel --max-workers 5    # Run with 5 workers

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
# CODE CHANGE DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check for actual code changes (not just docs/logs)
# Returns 0 if ClaudeWatch/ has changes, 1 otherwise
git_has_code_changes() {
    cd "$PROJECT_ROOT"

    # Check for changes in code-related directories:
    # - ClaudeWatch/ (Swift source code)
    # - ClaudeWatch.xcodeproj/ (project settings, build configs)
    # - MCPServer/ (Python backend)
    # This excludes .claude/, .specstory/, docs, etc.
    local code_paths="ClaudeWatch/ ClaudeWatch.xcodeproj/ MCPServer/"

    # First check uncommitted changes (staged or unstaged)
    for path in $code_paths; do
        if ! git diff --cached --quiet -- "$path" 2>/dev/null || ! git diff --quiet -- "$path" 2>/dev/null; then
            log_verbose "  Code changes detected (uncommitted) in: $path"
            return 0  # Code changes detected
        fi
    done

    # Also check the LAST COMMIT - Claude commits before we validate!
    # This catches the case where Claude has already committed the changes
    local last_commit_files
    last_commit_files=$(git log -1 --name-only --pretty=format: HEAD 2>/dev/null)
    if echo "$last_commit_files" | grep -qE '^ClaudeWatch/|^ClaudeWatch\.xcodeproj/|^MCPServer/'; then
        log_verbose "  Code changes detected in last commit"
        return 0  # Code changes in last commit
    fi

    return 1  # No code changes
}

# Check if specific task files were modified
git_has_task_file_changes() {
    local task_id="$1"

    cd "$PROJECT_ROOT"

    # Get expected files from task definition
    local expected_files
    expected_files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]" "$TASKS_FILE" 2>/dev/null || echo "")

    if [[ -z "$expected_files" ]]; then
        # No specific files defined, fall back to general code check
        git_has_code_changes
        return $?
    fi

    # Check if at least one expected file was modified (uncommitted)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if ! git diff --quiet -- "$file" 2>/dev/null || ! git diff --cached --quiet -- "$file" 2>/dev/null; then
            log_verbose "  Modified (uncommitted): $file"
            return 0  # Found a change
        fi
    done <<< "$expected_files"

    # Also check the LAST COMMIT for expected files
    local last_commit_files
    last_commit_files=$(git log -1 --name-only --pretty=format: HEAD 2>/dev/null)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        # Remove quotes if present from YAML parsing
        file=$(echo "$file" | tr -d '"')
        if echo "$last_commit_files" | grep -qF "$file"; then
            log_verbose "  Modified (last commit): $file"
            return 0  # Found in last commit
        fi
    done <<< "$expected_files"

    return 1  # No expected files modified
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

# Parse token usage from Claude output and update metrics
parse_and_update_tokens() {
    local output_file="$1"

    [[ ! -f "$output_file" ]] && return

    # Claude outputs various formats, try to capture them
    # Format 1: "Total cost: $X.XX"
    # Format 2: "XXX input tokens, XXX output tokens"
    # Format 3: "↓ XXX ↑ XXX" (input/output)

    local input_tokens=0
    local output_tokens=0
    local cost=0

    # Try to parse tokens (various formats Claude might use)
    if grep -qE '[0-9]+ input' "$output_file" 2>/dev/null; then
        input_tokens=$(grep -oE '[0-9]+ input' "$output_file" | tail -1 | grep -oE '[0-9]+' || echo 0)
    fi
    if grep -qE '[0-9]+ output' "$output_file" 2>/dev/null; then
        output_tokens=$(grep -oE '[0-9]+ output' "$output_file" | tail -1 | grep -oE '[0-9]+' || echo 0)
    fi

    # Try arrow format: "↓ XXX ↑ XXX"
    if grep -qE '↓ [0-9]+' "$output_file" 2>/dev/null; then
        input_tokens=$(grep -oE '↓ [0-9]+' "$output_file" | tail -1 | grep -oE '[0-9]+' || echo 0)
    fi
    if grep -qE '↑ [0-9]+' "$output_file" 2>/dev/null; then
        output_tokens=$(grep -oE '↑ [0-9]+' "$output_file" | tail -1 | grep -oE '[0-9]+' || echo 0)
    fi

    # Try to parse cost
    if grep -qE '\$[0-9]+\.[0-9]+' "$output_file" 2>/dev/null; then
        cost=$(grep -oE '\$[0-9]+\.[0-9]+' "$output_file" | tail -1 | tr -d '$' || echo 0)
    fi

    # Update metrics if we found any token data
    if [[ $input_tokens -gt 0 ]] || [[ $output_tokens -gt 0 ]] || [[ "$cost" != "0" ]]; then
        log_verbose "Tokens: $input_tokens input, $output_tokens output, cost: \$$cost"

        jq --argjson inp "$input_tokens" \
           --argjson out "$output_tokens" \
           --argjson c "${cost:-0}" \
           '.totalTokens.input += $inp |
            .totalTokens.output += $out |
            .estimatedCost = ((.estimatedCost // 0) + $c | . * 100 | floor / 100)' \
           "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
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

    # Capture output to temp file for token parsing
    local output_file="/tmp/ralph-claude-output-$$.log"

    if cat "$prompt_file" | claude --print --verbose 2>&1 | tee -a "$progress_log" "$output_file"; then
        echo "✓ Session $session_id completed at $(date '+%H:%M:%S')" >> "$progress_log"
        log_success "Session $session_id completed"

        # Parse and update token metrics from Claude output
        parse_and_update_tokens "$output_file"

        rm -f "$output_file"
        return 0
    else
        local exit_code=$?
        echo "✗ Session $session_id failed at $(date '+%H:%M:%S')" >> "$progress_log"
        log_error "Session $session_id failed with exit code $exit_code"

        # Still try to capture tokens even on failure
        parse_and_update_tokens "$output_file"

        rm -f "$output_file"
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

# Get available watchOS simulator dynamically
get_watch_simulator() {
    local sim_name
    sim_name=$(xcrun simctl list devices available 2>/dev/null | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*//')

    if [[ -z "$sim_name" ]]; then
        echo "Apple Watch Series 11 (42mm)"  # Fallback
    else
        echo "$sim_name"
    fi
}

# Check all Swift files are in Xcode project
run_project_sync_check() {
    log "Checking Xcode project sync..."

    cd "$PROJECT_ROOT"

    local project_file="ClaudeWatch.xcodeproj/project.pbxproj"
    local missing=0

    while IFS= read -r -d '' swift_file; do
        local filename
        filename=$(basename "$swift_file")

        if ! grep -q "$filename" "$project_file" 2>/dev/null; then
            log_error "MISSING from Xcode project: $swift_file"
            ((missing++))
        fi
    done < <(find ClaudeWatch -name "*.swift" ! -path "*/Tests/*" -print0 2>/dev/null)

    if [[ $missing -gt 0 ]]; then
        log_error "Found $missing Swift files not in Xcode project!"
        log_error "Files exist on disk but won't compile - add them to project.pbxproj"
        return 1
    fi

    log_success "All Swift files are in Xcode project"
    return 0
}

# Run xcodebuild to verify the project compiles
run_build_check() {
    log "Running mandatory build verification..."

    cd "$PROJECT_ROOT"

    # Check if xcodebuild is available
    if ! command -v xcodebuild &> /dev/null; then
        log_warning "xcodebuild not available, skipping build check"
        return 0
    fi

    # Get available simulator
    local simulator
    simulator=$(get_watch_simulator)
    log_verbose "Using simulator: $simulator"

    # Run build
    local build_output
    build_output=$(mktemp)

    if xcodebuild -project ClaudeWatch.xcodeproj \
        -scheme ClaudeWatch \
        -destination "platform=watchOS Simulator,name=$simulator" \
        -quiet \
        build 2>&1 | tee "$build_output" | tail -10; then

        if grep -qE "BUILD SUCCEEDED|Build Succeeded" "$build_output"; then
            log_success "Build succeeded"
            rm -f "$build_output"
            return 0
        fi
    fi

    log_error "Build FAILED"
    log_error "Last 20 lines of build output:"
    tail -20 "$build_output"
    rm -f "$build_output"
    return 2
}

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

# Run task-specific verification from tasks.yaml
run_task_verification() {
    local task_id="$1"

    if ! command -v yq &> /dev/null; then
        log_warning "yq not found, skipping task verification"
        return 0
    fi

    # Get verification script from tasks.yaml
    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE" 2>/dev/null || echo "")

    if [[ -z "$verification" || "$verification" == "null" ]]; then
        log_verbose "No task-specific verification defined for $task_id"
        return 0
    fi

    log "Running task-specific verification for $task_id..."
    log_verbose "Verification script:"
    echo "$verification" | sed 's/^/    /' | head -5

    # Execute verification in project root
    cd "$PROJECT_ROOT"
    if eval "$verification"; then
        log_success "Task verification PASSED"
        return 0
    else
        log_error "Task verification FAILED"
        log_error "Task $task_id did not meet acceptance criteria"
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

        log_success "Initialization complete. Run ./ralph.sh to start the loop."
        log "View task status with: ./ralph.sh --status"
    else
        log_session_end "$session_id" "FAILED" "Initialization failed"
        update_metrics "$session_id" "failed" "init"
        log_error "Initialization failed"
    fi

    return $result
}

# ═══════════════════════════════════════════════════════════════════════════════
# PARALLEL EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Source parallel utilities if in parallel mode
init_parallel_state() {
    log "Initializing parallel execution state..."

    # Source parallel utilities
    source "$RALPH_DIR/parallel-utils.sh"

    # Ensure directories exist
    ensure_parallel_dirs

    # Initialize the queue
    init_queue

    # Clear any stale signals
    clear_shutdown_signal
    clear_pause_signal

    log_success "Parallel state initialized"
}

# Spawn worker processes
# Args: num_workers
spawn_workers() {
    local num_workers="$1"

    log "Spawning $num_workers worker processes..."

    for i in $(seq 1 "$num_workers"); do
        log_verbose "Starting worker $i"

        # Run worker in background
        "$RALPH_DIR/ralph-worker.sh" "$i" &

        local pid=$!
        echo "$pid" > "$RALPH_DIR/parallel/workers/worker-$i.pid"

        log_verbose "Worker $i started with PID $pid"
    done

    # Wait a moment for workers to initialize
    sleep 2

    log_success "All $num_workers workers spawned"
}

# Shutdown all workers gracefully
shutdown_workers() {
    log "Shutting down workers..."

    # Send shutdown signal
    send_shutdown_signal

    # Wait for workers to exit (up to 30 seconds)
    local timeout=30
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        local active
        active=$(get_active_worker_count)

        if [[ "$active" == "0" ]]; then
            break
        fi

        log_verbose "Waiting for $active workers to exit..."
        sleep 2
        ((elapsed+=2))
    done

    # Force kill any remaining workers
    for pid_file in "$RALPH_DIR/parallel/workers/"*.pid; do
        [[ -f "$pid_file" ]] || continue
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Force killing worker $pid"
            kill -9 "$pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    done

    clear_shutdown_signal
    log_success "All workers shutdown"
}

# Handle parallel group failure
# Args: group_number
handle_group_failure() {
    local group="$1"

    log_error "Handling failure for parallel group $group"

    # Pause workers
    send_pause_signal

    # Get failed tasks in this group
    local failed_tasks
    failed_tasks=$(yq ".tasks[] | select(.parallel_group == $group and .status == \"failed\") | .id" "$RALPH_DIR/parallel/queue.yaml" 2>/dev/null)

    if [[ -n "$failed_tasks" ]]; then
        log_error "Failed tasks in group $group:"
        echo "$failed_tasks" | while read -r task_id; do
            [[ -n "$task_id" ]] && log_error "  - $task_id"
        done
    fi

    # Reset failed tasks to pending for retry
    yq -i "(.tasks[] | select(.parallel_group == $group and .status == \"failed\")).status = \"pending\"" "$RALPH_DIR/parallel/queue.yaml"

    # Resume workers
    clear_pause_signal
}

# Run validation for a parallel group
# Args: group_number
run_group_validation() {
    local group="$1"

    log "Running validation for parallel group $group..."

    # Pause workers during validation
    send_pause_signal

    # Get completed tasks in this group
    local completed_tasks
    completed_tasks=$(yq ".tasks[] | select(.parallel_group == $group and .status == \"completed\") | .id" "$RALPH_DIR/parallel/queue.yaml" 2>/dev/null | tr '\n' ' ')

    # Run Xcode project sync check
    if ! run_project_sync_check; then
        log_error "Project sync check failed for group $group"
        clear_pause_signal
        return 1
    fi

    # Run build check
    if ! run_build_check; then
        log_error "Build check failed for group $group"
        clear_pause_signal
        return 2
    fi

    # Run verification for each completed task
    for task_id in $completed_tasks; do
        [[ -z "$task_id" ]] && continue
        task_id=$(echo "$task_id" | tr -d '"')

        if ! run_task_verification "$task_id"; then
            log_error "Task verification failed for $task_id"
            clear_pause_signal
            return 3
        fi
    done

    clear_pause_signal
    log_success "Group $group validation passed"
    return 0
}

# Main parallel execution loop
run_parallel_loop() {
    log "Starting parallel execution mode..."
    log "Max workers: $MAX_WORKERS"
    log "Press Ctrl+C to stop"
    echo ""

    init_metrics
    init_session_log
    init_parallel_state

    # Spawn workers
    spawn_workers "$MAX_WORKERS"

    # Coordinator loop
    local last_group=""

    while true; do
        # Check if all tasks complete
        if all_tasks_complete; then
            log_success "All tasks completed!"
            break
        fi

        # Get current parallel group
        local current_group
        current_group=$(get_current_group)

        if [[ -z "$current_group" ]]; then
            log_success "No more tasks to process"
            break
        fi

        # Filter by specific group if requested
        if [[ -n "$PARALLEL_GROUP" ]] && [[ "$current_group" != "$PARALLEL_GROUP" ]]; then
            log "Skipping group $current_group (waiting for group $PARALLEL_GROUP)"
            # Fast-forward: mark all tasks in other groups as completed in queue
            yq -i "(.tasks[] | select(.parallel_group == $current_group)).status = \"completed\"" "$RALPH_DIR/parallel/queue.yaml"
            continue
        fi

        # Log group transition
        if [[ "$current_group" != "$last_group" ]]; then
            echo ""
            log "═══════════════════════════════════════════════════════════════"
            log "  Processing Parallel Group $current_group"
            log "═══════════════════════════════════════════════════════════════"
            echo ""
            last_group="$current_group"
        fi

        # Wait for group to complete
        log_verbose "Waiting for group $current_group to complete..."

        while ! group_is_complete "$current_group"; do
            # Show progress
            local active
            active=$(get_active_worker_count)
            local pending
            pending=$(yq "[.tasks[] | select(.parallel_group == $current_group and .status == \"pending\")] | length" "$RALPH_DIR/parallel/queue.yaml" 2>/dev/null)
            local assigned
            assigned=$(yq "[.tasks[] | select(.parallel_group == $current_group and .status == \"assigned\")] | length" "$RALPH_DIR/parallel/queue.yaml" 2>/dev/null)

            log_verbose "Group $current_group: $pending pending, $assigned in progress, $active workers active"

            # Check for stuck workers (no progress for too long)
            sleep 5
        done

        log_success "Group $current_group execution complete, running validation..."

        # Run group validation
        if ! run_group_validation "$current_group"; then
            log_error "Group $current_group validation failed"
            handle_group_failure "$current_group"

            # Count retries
            ((consecutive_failures++)) || true

            if [[ ${consecutive_failures:-0} -ge $MAX_RETRIES ]]; then
                log_error "Too many consecutive failures. Stopping."
                break
            fi

            continue
        fi

        log_success "Group $current_group completed and validated"
        consecutive_failures=0

        # Mark group tasks as complete in main tasks.yaml
        local completed_tasks
        completed_tasks=$(yq ".tasks[] | select(.parallel_group == $current_group and .status == \"completed\") | .id" "$RALPH_DIR/parallel/queue.yaml" 2>/dev/null)

        for task_id in $completed_tasks; do
            [[ -z "$task_id" ]] && continue
            task_id=$(echo "$task_id" | tr -d '"')
            update_metrics "parallel-$current_group" "completed" "$task_id"
        done

        # Brief pause before next group
        sleep 2
    done

    # Shutdown workers
    shutdown_workers

    log_success "Parallel execution complete"
    return 0
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
            # ═══════════════════════════════════════════════════════════════
            # VALIDATION PHASE - All checks must pass before metrics update
            # ═══════════════════════════════════════════════════════════════

            # CHECK 0: Project sync - all Swift files must be in Xcode project
            if ! run_project_sync_check; then
                log_error "CRITICAL: Swift files missing from Xcode project!"
                log_error "Files exist on disk but won't compile"
                log_session_end "$session_id" "FAILED" "Project sync failed - missing files"
                update_metrics "$session_id" "failed" "$next_task_id"
                jq '.buildFailures += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
                ((consecutive_failures++))

                if [[ $consecutive_failures -ge $MAX_RETRIES ]]; then
                    log_error "Too many consecutive failures ($consecutive_failures). Stopping."
                    return 1
                fi

                log "Waiting ${RETRY_DELAY}s before retry..."
                sleep "$RETRY_DELAY"
                continue
            fi

            # CHECK 0.5: Mandatory build verification
            if ! run_build_check; then
                log_error "CRITICAL: Build failed!"
                log_session_end "$session_id" "FAILED" "Build verification failed"
                update_metrics "$session_id" "failed" "$next_task_id"
                jq '.buildFailures += 1' "$METRICS_FILE" > "$METRICS_FILE.tmp" && mv "$METRICS_FILE.tmp" "$METRICS_FILE"
                ((consecutive_failures++))

                if [[ $consecutive_failures -ge $MAX_RETRIES ]]; then
                    log_error "Too many consecutive failures ($consecutive_failures). Stopping."
                    return 1
                fi

                log "Waiting ${RETRY_DELAY}s before retry..."
                sleep "$RETRY_DELAY"
                continue
            fi

            # CHECK 1: Verify actual code changes (not just docs/logs)
            log "Checking for Swift code changes in ClaudeWatch/..."
            if ! git_has_code_changes; then
                log_error "CRITICAL: No Swift code changes detected in ClaudeWatch/"
                log_error "Documentation changes don't count - must modify actual code"
                log_error "This session will be marked as FAILED"
                log_session_end "$session_id" "FAILED" "No code changes in ClaudeWatch/"
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
            log_success "Swift code changes detected in ClaudeWatch/"

            # CHECK 2: Verify task-specific files were modified
            log "Checking if expected task files were modified..."
            if ! git_has_task_file_changes "$next_task_id"; then
                log_warning "Expected task files not modified, but ClaudeWatch/ has changes"
                # Continue anyway - they may have modified different but related files
            else
                log_success "Task-specific files modified"
            fi

            # CHECK 3: Run task-specific verification
            if ! run_task_verification "$next_task_id"; then
                log_error "Task verification FAILED - work may be incomplete"
                log_session_end "$session_id" "FAILED" "Task verification failed"
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

            # CHECK 4: Verify tasks.yaml was updated (via state-manager or manually)
            local task_completed
            task_completed=$(yq ".tasks[] | select(.id == \"$next_task_id\") | .completed" "$TASKS_FILE" 2>/dev/null || echo "false")

            if [[ "$task_completed" != "true" ]]; then
                log_warning "tasks.yaml not updated by agent, auto-updating..."
                # Auto-update using state-manager
                if "$RALPH_DIR/state-manager.sh" complete "$next_task_id"; then
                    log_success "Task $next_task_id auto-marked complete"
                else
                    log_error "Failed to auto-update task status"
                    log_session_end "$session_id" "FAILED" "Could not mark task complete"
                    update_metrics "$session_id" "failed" "$next_task_id"
                    ((consecutive_failures++))
                    continue
                fi
            else
                log_success "Task $next_task_id marked complete in tasks.yaml"
            fi

            # CHECK 5: Run general verification harness
            if ! run_verification; then
                log_warning "General verification had issues (non-blocking)"
            fi

            # ═══════════════════════════════════════════════════════════════
            # ALL CHECKS PASSED - Now safe to update metrics
            # ═══════════════════════════════════════════════════════════════
            log_success "All validation checks passed for task $next_task_id"
            log_session_end "$session_id" "COMPLETED" "Session completed successfully"
            update_metrics "$session_id" "completed" "$next_task_id"
            consecutive_failures=0

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
    log "Received interrupt signal (Ctrl+C), shutting down gracefully..."
    echo ""

    # Shutdown workers if in parallel mode
    if [[ "$PARALLEL_MODE" == "true" ]]; then
        log "Shutting down parallel workers..."
        # Source parallel utils if not already sourced
        if [[ -f "$RALPH_DIR/parallel-utils.sh" ]]; then
            source "$RALPH_DIR/parallel-utils.sh" 2>/dev/null || true
            send_shutdown_signal 2>/dev/null || true

            # Give workers time to shutdown
            sleep 2

            # Force kill any remaining
            for pid_file in "$RALPH_DIR/parallel/workers/"*.pid; do
                [[ -f "$pid_file" ]] || continue
                local pid
                pid=$(cat "$pid_file" 2>/dev/null)
                if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                    kill -9 "$pid" 2>/dev/null || true
                fi
                rm -f "$pid_file"
            done
        fi
    fi

    # Show current progress
    if [[ -f "$METRICS_FILE" ]] && command -v jq &> /dev/null; then
        local sessions
        local completed
        sessions=$(jq '.totalSessions' "$METRICS_FILE" 2>/dev/null || echo "0")
        completed=$(jq '.tasksCompleted' "$METRICS_FILE" 2>/dev/null || echo "0")
        log "Session Summary:"
        log "  - Total sessions run: $sessions"
        log "  - Tasks completed: $completed"
    fi

    # Show incomplete task count
    if [[ -f "$TASKS_FILE" ]]; then
        local incomplete
        incomplete=$(get_incomplete_task_count)
        log "  - Tasks remaining: $incomplete"
    fi

    echo ""
    log "Progress saved. Resume anytime with: ./ralph.sh"
    log "View progress: ./ralph.sh --status"
    echo ""
    log_success "Shutdown complete"
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
        --status)
            STATUS_MODE=true
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
        --parallel)
            PARALLEL_MODE=true
            shift
            ;;
        --max-workers)
            MAX_WORKERS="$2"
            shift 2
            ;;
        --parallel-group)
            PARALLEL_GROUP="$2"
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
    if [[ "$STATUS_MODE" == "true" ]]; then
        "$RALPH_DIR/state-manager.sh" list
    elif [[ "$INIT_MODE" == "true" ]]; then
        run_init
    elif [[ "$PARALLEL_MODE" == "true" ]]; then
        run_parallel_loop
    else
        run_loop
    fi
}

main
