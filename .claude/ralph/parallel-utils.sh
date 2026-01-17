#!/bin/bash
#
# Parallel execution utilities for watchOS Ralph Loop
#
# This file provides shared utilities for parallel task execution:
# - File locking mechanisms
# - Queue management
# - Dependency resolution
# - Task coordination
#
# Usage: source this file from ralph.sh or ralph-worker.sh

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

PARALLEL_DIR="${PARALLEL_DIR:-$RALPH_DIR/parallel}"
TASKS_FILE="${TASKS_FILE:-$RALPH_DIR/tasks.yaml}"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$RALPH_DIR/../.." && pwd)}"

# Ensure parallel directory exists
ensure_parallel_dirs() {
    mkdir -p "$PARALLEL_DIR"
    mkdir -p "$PARALLEL_DIR/workers"
    mkdir -p "$PARALLEL_DIR/locks"
    mkdir -p "$PARALLEL_DIR/batches"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FILE LOCKING
# ═══════════════════════════════════════════════════════════════════════════════

# Acquire a file lock
# Args: file_path worker_id task_id
# Returns: 0 on success, 1 if already locked
acquire_file_lock() {
    local file="$1"
    local worker_id="$2"
    local task_id="$3"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"

    # Check if already locked
    if [[ -f "$lock_file" ]]; then
        return 1  # Already locked
    fi

    # Create lock atomically
    echo "$worker_id:$task_id:$(date +%s)" > "$lock_file"
    return 0
}

# Release a file lock
# Args: file_path worker_id
release_file_lock() {
    local file="$1"
    local worker_id="$2"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"

    # Only release if we own the lock
    if [[ -f "$lock_file" ]] && grep -q "^$worker_id:" "$lock_file" 2>/dev/null; then
        rm -f "$lock_file"
    fi
}

# Check if a file is available (not locked)
# Args: file_path
# Returns: 0 if available, 1 if locked
check_file_available() {
    local file="$1"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"
    [[ ! -f "$lock_file" ]]
}

# Release all locks held by a worker
# Args: worker_id
release_worker_locks() {
    local worker_id="$1"

    for lock_file in "$PARALLEL_DIR/locks/"*.lock 2>/dev/null; do
        [[ -f "$lock_file" ]] || continue
        if grep -q "^$worker_id:" "$lock_file" 2>/dev/null; then
            rm -f "$lock_file"
        fi
    done
}

# List all active locks
list_active_locks() {
    local count=0
    for lock_file in "$PARALLEL_DIR/locks/"*.lock 2>/dev/null; do
        [[ -f "$lock_file" ]] || continue
        local file
        file=$(basename "$lock_file" .lock | tr '_' '/')
        local holder
        holder=$(cat "$lock_file" 2>/dev/null)
        echo "  $file -> $holder"
        ((count++))
    done
    echo "Total: $count locks"
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUEUE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Initialize the parallel queue from tasks.yaml
init_queue() {
    ensure_parallel_dirs

    local queue_file="$PARALLEL_DIR/queue.yaml"

    # Build queue from incomplete tasks in tasks.yaml
    if command -v yq &> /dev/null; then
        # Extract incomplete tasks and add status fields
        yq '.tasks | map(select(.completed == false)) | {"tasks": ., "current_group": null}' "$TASKS_FILE" > "$queue_file"

        # Add status and assignment fields to each task
        yq -i '.tasks[].status = "pending"' "$queue_file"
        yq -i '.tasks[].assigned_worker = null' "$queue_file"
        yq -i '.tasks[].started_at = null' "$queue_file"

        # Set initial current group
        local min_group
        min_group=$(yq '[.tasks[].parallel_group] | min // 0' "$queue_file")
        yq -i ".current_group = $min_group" "$queue_file"

        echo "Queue initialized with $(yq '.tasks | length' "$queue_file") pending tasks"
    else
        echo "Error: yq not found, cannot initialize queue" >&2
        return 1
    fi
}

# Get the current parallel group being processed
get_current_group() {
    local queue_file="$PARALLEL_DIR/queue.yaml"

    if [[ ! -f "$queue_file" ]]; then
        echo "0"
        return
    fi

    # Find the minimum parallel_group among tasks that aren't completed
    yq '[.tasks[] | select(.status != "completed") | .parallel_group] | min // empty' "$queue_file" 2>/dev/null || echo ""
}

# Mark a task as assigned to a worker
# Args: task_id worker_id
assign_task() {
    local task_id="$1"
    local worker_id="$2"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    (
        flock -x 200

        yq -i "(.tasks[] | select(.id == \"$task_id\")).status = \"assigned\"" "$queue_file"
        yq -i "(.tasks[] | select(.id == \"$task_id\")).assigned_worker = \"$worker_id\"" "$queue_file"
        yq -i "(.tasks[] | select(.id == \"$task_id\")).started_at = \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"" "$queue_file"

    ) 200>"$PARALLEL_DIR/queue.lock"
}

# Mark a task as completed
# Args: task_id worker_id
mark_task_complete() {
    local task_id="$1"
    local worker_id="$2"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    (
        flock -x 200

        yq -i "(.tasks[] | select(.id == \"$task_id\")).status = \"completed\"" "$queue_file"

        # Also update the main tasks.yaml
        yq -i "(.tasks[] | select(.id == \"$task_id\")).completed = true" "$TASKS_FILE"

    ) 200>"$PARALLEL_DIR/queue.lock"
}

# Mark a task as failed
# Args: task_id worker_id reason
mark_task_failed() {
    local task_id="$1"
    local worker_id="$2"
    local reason="${3:-unknown}"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    (
        flock -x 200

        yq -i "(.tasks[] | select(.id == \"$task_id\")).status = \"failed\"" "$queue_file"
        yq -i "(.tasks[] | select(.id == \"$task_id\")).failure_reason = \"$reason\"" "$queue_file"

    ) 200>"$PARALLEL_DIR/queue.lock"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY RESOLUTION
# ═══════════════════════════════════════════════════════════════════════════════

# Check if a task's dependencies are satisfied
# Args: task_id
# Returns: 0 if satisfied, 1 if not
task_dependencies_satisfied() {
    local task_id="$1"

    # Get dependencies from tasks.yaml
    local deps
    deps=$(yq ".tasks[] | select(.id == \"$task_id\") | .depends_on[]?" "$TASKS_FILE" 2>/dev/null)

    # If no dependencies, return satisfied
    if [[ -z "$deps" ]]; then
        return 0
    fi

    # Check each dependency
    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        dep=$(echo "$dep" | tr -d '"')

        local dep_status
        dep_status=$(yq ".tasks[] | select(.id == \"$dep\") | .completed" "$TASKS_FILE" 2>/dev/null)

        if [[ "$dep_status" != "true" ]]; then
            return 1  # Dependency not satisfied
        fi
    done <<< "$deps"

    return 0
}

# Check if a task has file conflicts with running tasks
# Args: task_id
# Returns: 0 if has conflicts, 1 if no conflicts
task_has_file_conflicts() {
    local task_id="$1"

    # Get files this task will modify
    local files
    files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]?" "$TASKS_FILE" 2>/dev/null)

    if [[ -z "$files" ]]; then
        return 1  # No files specified, no conflicts
    fi

    # Check each file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file=$(echo "$file" | tr -d '"')

        if ! check_file_available "$file"; then
            return 0  # Has conflict
        fi
    done <<< "$files"

    return 1  # No conflicts
}

# Get the next eligible task for a worker
# Args: worker_id
# Returns: task_id or empty
get_next_eligible_task() {
    local worker_id="$1"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    local current_group
    current_group=$(get_current_group)

    if [[ -z "$current_group" ]]; then
        return 1  # No more tasks
    fi

    # Get pending tasks in current group
    local candidates
    candidates=$(yq ".tasks[] | select(.parallel_group == $current_group and .status == \"pending\") | .id" "$queue_file" 2>/dev/null)

    while IFS= read -r task_id; do
        [[ -z "$task_id" ]] && continue
        task_id=$(echo "$task_id" | tr -d '"')

        # Check dependencies
        if ! task_dependencies_satisfied "$task_id"; then
            continue
        fi

        # Check file conflicts
        if task_has_file_conflicts "$task_id"; then
            continue
        fi

        echo "$task_id"
        return 0
    done <<< "$candidates"

    return 1  # No eligible task found
}

# Claim a task for a worker (atomic operation)
# Args: worker_id
# Returns: task_id or empty
claim_task() {
    local worker_id="$1"

    (
        flock -x 200

        local task_id
        task_id=$(get_next_eligible_task "$worker_id")

        if [[ -n "$task_id" ]]; then
            # Mark as assigned
            assign_task "$task_id" "$worker_id"

            # Acquire file locks for this task
            acquire_task_locks "$task_id" "$worker_id"

            echo "$task_id"
        fi

    ) 200>"$PARALLEL_DIR/queue.lock"
}

# Acquire locks for all files a task will modify
# Args: task_id worker_id
acquire_task_locks() {
    local task_id="$1"
    local worker_id="$2"

    local files
    files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]?" "$TASKS_FILE" 2>/dev/null)

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        file=$(echo "$file" | tr -d '"')
        acquire_file_lock "$file" "$worker_id" "$task_id"
    done <<< "$files"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COORDINATION SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

# Signal that a task is complete
# Args: task_id worker_id
signal_task_complete() {
    local task_id="$1"
    local worker_id="$2"

    mark_task_complete "$task_id" "$worker_id"
    release_worker_locks "$worker_id"
}

# Signal that a task failed
# Args: task_id worker_id reason
signal_task_failed() {
    local task_id="$1"
    local worker_id="$2"
    local reason="${3:-unknown}"

    mark_task_failed "$task_id" "$worker_id" "$reason"
    release_worker_locks "$worker_id"
}

# Send shutdown signal to all workers
send_shutdown_signal() {
    touch "$PARALLEL_DIR/shutdown"
}

# Clear shutdown signal
clear_shutdown_signal() {
    rm -f "$PARALLEL_DIR/shutdown"
}

# Check for shutdown signal
check_shutdown_signal() {
    [[ -f "$PARALLEL_DIR/shutdown" ]]
}

# Send pause signal to all workers
send_pause_signal() {
    touch "$PARALLEL_DIR/pause"
}

# Clear pause signal
clear_pause_signal() {
    rm -f "$PARALLEL_DIR/pause"
}

# Check for pause signal
check_pause_signal() {
    [[ -f "$PARALLEL_DIR/pause" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# WORKER MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Get worker status
# Args: worker_id
get_worker_status() {
    local worker_id="$1"
    local status_file="$PARALLEL_DIR/workers/worker-$worker_id.status"

    if [[ -f "$status_file" ]]; then
        cat "$status_file"
    else
        echo "stopped"
    fi
}

# Set worker status
# Args: worker_id status
set_worker_status() {
    local worker_id="$1"
    local status="$2"

    echo "$status" > "$PARALLEL_DIR/workers/worker-$worker_id.status"
}

# Check if worker is alive
# Args: worker_id
worker_is_alive() {
    local worker_id="$1"
    local pid_file="$PARALLEL_DIR/workers/worker-$worker_id.pid"

    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        kill -0 "$pid" 2>/dev/null
        return $?
    fi
    return 1
}

# Get count of active workers
get_active_worker_count() {
    local count=0
    for status_file in "$PARALLEL_DIR/workers/"*.status 2>/dev/null; do
        [[ -f "$status_file" ]] || continue
        local status
        status=$(cat "$status_file")
        if [[ "$status" == "idle" || "$status" =~ ^running: ]]; then
            ((count++))
        fi
    done
    echo "$count"
}

# ═══════════════════════════════════════════════════════════════════════════════
# BATCH MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

# Create a new batch record
# Args: batch_id task_ids...
create_batch() {
    local batch_id="$1"
    shift
    local task_ids=("$@")

    local batch_file="$PARALLEL_DIR/batches/batch-$batch_id.yaml"

    cat > "$batch_file" << EOF
batch_id: $batch_id
created_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
status: running
tasks:
EOF

    for task_id in "${task_ids[@]}"; do
        echo "  - $task_id" >> "$batch_file"
    done
}

# Check if all tasks in current group are complete
group_is_complete() {
    local group="$1"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    local pending
    pending=$(yq "[.tasks[] | select(.parallel_group == $group and .status != \"completed\")] | length" "$queue_file" 2>/dev/null)

    [[ "$pending" == "0" ]]
}

# Wait for a parallel group to complete
# Args: group_number
wait_for_group_completion() {
    local group="$1"

    while ! group_is_complete "$group"; do
        sleep 2
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESS ESTIMATION
# ═══════════════════════════════════════════════════════════════════════════════

# Estimate task progress (0-100)
# Args: task_id
estimate_task_progress() {
    local task_id="$1"
    local queue_file="$PARALLEL_DIR/queue.yaml"

    local started_at
    started_at=$(yq ".tasks[] | select(.id == \"$task_id\") | .started_at" "$queue_file" 2>/dev/null)

    if [[ -z "$started_at" || "$started_at" == "null" ]]; then
        echo "0"
        return
    fi

    # Default task duration estimate: 5 minutes
    local estimated_duration=300

    local started_ts
    started_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" "+%s" 2>/dev/null || echo "0")
    local now_ts
    now_ts=$(date "+%s")

    local elapsed=$((now_ts - started_ts))
    local progress=$((elapsed * 100 / estimated_duration))

    # Cap at 95% (never show 100% until actually complete)
    if [[ $progress -gt 95 ]]; then
        progress=95
    fi

    echo "$progress"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

# Quick syntax check on a worktree
# Args: worktree_path
quick_syntax_check() {
    local worktree="$1"

    local swift_files
    swift_files=$(find "$worktree/ClaudeWatch" -name "*.swift" 2>/dev/null)

    if [[ -z "$swift_files" ]]; then
        return 0  # No files to check
    fi

    # Run swift syntax-only compilation
    swiftc -parse-as-library \
        -sdk "$(xcrun --sdk watchsimulator --show-sdk-path 2>/dev/null)" \
        -target arm64-apple-watchos10.0 \
        $swift_files 2>/dev/null
}

# Merge a worktree branch to main
# Args: task_id
merge_worktree_to_main() {
    local task_id="$1"
    local worktree_base="${WORKTREE_BASE:-$PROJECT_ROOT/.auto-claude/worktrees/ralph-parallel}"
    local worktree_path="$worktree_base/$task_id"

    if [[ ! -d "$worktree_path" ]]; then
        echo "Worktree not found: $worktree_path" >&2
        return 1
    fi

    cd "$PROJECT_ROOT"

    # Merge the ralph/$task_id branch into main
    if git merge --no-ff -m "Merge parallel task $task_id" "ralph/$task_id" 2>/dev/null; then
        return 0
    else
        echo "Merge conflict for task $task_id" >&2
        return 1
    fi
}
