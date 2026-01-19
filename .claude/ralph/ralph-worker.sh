#!/bin/bash
#
# Ralph Worker Process - Executes tasks in isolated worktrees
#
# A worker process that runs as part of the parallel Ralph Loop.
# Each worker operates in its own git worktree to allow parallel execution.
#
# Usage: ./ralph-worker.sh <worker_id>
#
# Arguments:
#   worker_id    Unique identifier for this worker (e.g., 1, 2, 3)
#
# Exit Codes:
#   0   Worker shutdown cleanly
#   1   Worker error or failed initialization

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

WORKER_ID="${1:-}"

if [[ -z "$WORKER_ID" ]]; then
    echo "Usage: $0 <worker_id>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RALPH_DIR="$SCRIPT_DIR"
export PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PARALLEL_DIR="$RALPH_DIR/parallel"
export TASKS_FILE="$RALPH_DIR/tasks.yaml"

# Source utilities
source "$SCRIPT_DIR/parallel-utils.sh"

# Worker paths
WORKER_DIR="$PARALLEL_DIR/workers"
PID_FILE="$WORKER_DIR/worker-$WORKER_ID.pid"
STATUS_FILE="$WORKER_DIR/worker-$WORKER_ID.status"
LOG_FILE="$WORKER_DIR/worker-$WORKER_ID.log"
WORKTREE_BASE="$PROJECT_ROOT/.auto-claude/worktrees/ralph-parallel"

# Configuration
TASK_TIMEOUT="${TASK_TIMEOUT:-900}"  # 15 minutes per task
IDLE_WAIT="${IDLE_WAIT:-3}"          # Seconds to wait when idle

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════════

log_worker() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [worker-$WORKER_ID] $*" | tee -a "$LOG_FILE"
}

log_worker_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [worker-$WORKER_ID] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

set_status() {
    local status="$1"
    echo "$status" > "$STATUS_FILE"
}

get_status() {
    if [[ -f "$STATUS_FILE" ]]; then
        cat "$STATUS_FILE"
    else
        echo "unknown"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# WORKTREE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Create or reuse a worktree for a task
# Args: task_id
# Returns: worktree path
setup_worktree() {
    local task_id="$1"
    local worktree_path="$WORKTREE_BASE/$task_id"
    local branch_name="ralph/$task_id"

    # Ensure base directory exists
    mkdir -p "$WORKTREE_BASE"

    if [[ -d "$worktree_path" ]]; then
        log_worker "Reusing existing worktree: $worktree_path"
        echo "$worktree_path"
        return 0
    fi

    log_worker "Creating worktree for $task_id at $worktree_path"

    cd "$PROJECT_ROOT"

    # Try to create worktree with new branch, or use existing branch
    if git worktree add "$worktree_path" -b "$branch_name" main 2>/dev/null; then
        log_worker "Created worktree with new branch $branch_name"
    elif git worktree add "$worktree_path" "$branch_name" 2>/dev/null; then
        log_worker "Created worktree using existing branch $branch_name"
    else
        log_worker_error "Failed to create worktree for $task_id"
        return 1
    fi

    echo "$worktree_path"
}

# Cleanup worktree for a task
# Args: task_id
cleanup_worktree() {
    local task_id="$1"
    local worktree_path="$WORKTREE_BASE/$task_id"

    if [[ -d "$worktree_path" ]]; then
        log_worker "Cleaning up worktree: $worktree_path"

        cd "$PROJECT_ROOT"
        git worktree remove "$worktree_path" --force 2>/dev/null || true
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# TASK EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Generate a task-specific prompt
# Args: task_id worktree
generate_task_prompt() {
    local task_id="$1"
    local worktree="$2"

    # Get task details
    local title
    title=$(yq ".tasks[] | select(.id == \"$task_id\") | .title" "$TASKS_FILE" 2>/dev/null | tr -d '"')

    local description
    description=$(yq ".tasks[] | select(.id == \"$task_id\") | .description" "$TASKS_FILE" 2>/dev/null)

    local files
    files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]?" "$TASKS_FILE" 2>/dev/null | tr -d '"')

    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE" 2>/dev/null)

    local acceptance
    acceptance=$(yq ".tasks[] | select(.id == \"$task_id\") | .acceptance_criteria[]?" "$TASKS_FILE" 2>/dev/null)

    # Generate prompt
    cat << EOF
# Ralph Worker Task: $task_id

Execute this single task in the worktree at: $worktree

## Task Details

**Title:** $title

**Description:**
$description

**Files to Modify:**
EOF

    if [[ -n "$files" ]]; then
        echo "$files" | while read -r file; do
            [[ -n "$file" ]] && echo "- $file"
        done
    else
        echo "- (no specific files listed)"
    fi

    cat << EOF

## Acceptance Criteria

EOF

    if [[ -n "$acceptance" && "$acceptance" != "null" ]]; then
        echo "$acceptance" | while read -r criterion; do
            [[ -n "$criterion" ]] && echo "- $criterion"
        done
    else
        echo "- Task completed as described"
    fi

    cat << EOF

## Verification

After completing the task, the following verification will be run:

\`\`\`bash
$verification
\`\`\`

## Instructions

1. Read the files listed above
2. Make the required changes following existing patterns
3. Ensure the verification passes
4. Commit your changes with message: "$(yq ".tasks[] | select(.id == \"$task_id\") | .commit_template" "$TASKS_FILE" 2>/dev/null | tr -d '"')"

IMPORTANT: Only modify files in this worktree. Do not touch the main repo.

Begin execution now.
EOF
}

# Execute a single task
# Args: task_id worktree
# Returns: 0 on success, non-zero on failure
execute_task() {
    local task_id="$1"
    local worktree="$2"

    log_worker "Executing task $task_id in $worktree"

    # Generate task-specific prompt
    local prompt_file="$worktree/.ralph-task-prompt.md"
    generate_task_prompt "$task_id" "$worktree" > "$prompt_file"

    # Change to worktree
    cd "$worktree"

    # Run Claude session with timeout
    local task_log="$WORKER_DIR/task-$task_id.log"

    log_worker "Starting Claude session for $task_id"

    # Use timeout to prevent runaway tasks
    if timeout "$TASK_TIMEOUT" bash -c "cat '$prompt_file' | claude --print --verbose --dangerously-skip-permissions" >> "$task_log" 2>&1; then
        log_worker "Task $task_id execution completed"
        return 0
    else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_worker_error "Task $task_id timed out after ${TASK_TIMEOUT}s"
        else
            log_worker_error "Task $task_id failed with exit code $exit_code"
        fi
        return $exit_code
    fi
}

# Run task verification
# Args: task_id
verify_task() {
    local task_id="$1"

    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE" 2>/dev/null)

    if [[ -z "$verification" || "$verification" == "null" ]]; then
        log_worker "No verification defined for $task_id, assuming success"
        return 0
    fi

    log_worker "Running verification for $task_id"

    cd "$PROJECT_ROOT"
    if eval "$verification"; then
        log_worker "Verification passed for $task_id"
        return 0
    else
        log_worker_error "Verification failed for $task_id"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN WORKER LOOP
# ═══════════════════════════════════════════════════════════════════════════════

worker_loop() {
    log_worker "Starting worker loop"
    set_status "idle"

    while true; do
        # Check for shutdown signal
        if check_shutdown_signal; then
            log_worker "Shutdown signal received"
            break
        fi

        # Check for pause signal
        if check_pause_signal; then
            set_status "paused"
            log_worker "Paused (validation in progress)"
            sleep 2
            continue
        fi

        # Try to claim a task
        local task_id
        task_id=$(claim_task "$WORKER_ID")

        if [[ -z "$task_id" ]]; then
            set_status "idle"
            sleep "$IDLE_WAIT"
            continue
        fi

        log_worker "Claimed task: $task_id"
        set_status "running:$task_id"

        # Setup worktree
        local worktree
        worktree=$(setup_worktree "$task_id")

        if [[ -z "$worktree" ]]; then
            log_worker_error "Failed to setup worktree for $task_id"
            signal_task_failed "$task_id" "$WORKER_ID" "worktree_setup_failed"
            continue
        fi

        # Execute task
        if execute_task "$task_id" "$worktree"; then
            # Run verification
            if verify_task "$task_id"; then
                log_worker "Task $task_id completed successfully"
                signal_task_complete "$task_id" "$WORKER_ID"
            else
                log_worker_error "Task $task_id verification failed"
                signal_task_failed "$task_id" "$WORKER_ID" "verification_failed"
            fi
        else
            log_worker_error "Task $task_id execution failed"
            signal_task_failed "$task_id" "$WORKER_ID" "execution_failed"
        fi

        # Release locks (done by signal_task_* functions)
        set_status "idle"

        # Brief pause before next task
        sleep 1
    done

    log_worker "Worker shutting down"
    set_status "stopped"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

init_worker() {
    log_worker "Initializing worker $WORKER_ID"

    # Ensure directories exist
    ensure_parallel_dirs
    mkdir -p "$WORKTREE_BASE"

    # Write PID file
    echo $$ > "$PID_FILE"

    # Initialize log
    echo "=== Worker $WORKER_ID started at $(date) ===" >> "$LOG_FILE"

    # Set initial status
    set_status "starting"

    log_worker "Worker initialized, PID: $$"
}

cleanup_worker() {
    log_worker "Cleaning up worker $WORKER_ID"

    # Remove PID file
    rm -f "$PID_FILE"

    # Set final status
    set_status "stopped"

    log_worker "Worker cleanup complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

handle_signal() {
    log_worker "Received signal, shutting down..."
    cleanup_worker
    exit 130
}

trap handle_signal INT TERM HUP

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    init_worker
    worker_loop
    cleanup_worker
}

main
