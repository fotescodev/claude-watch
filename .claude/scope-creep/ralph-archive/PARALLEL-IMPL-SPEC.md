# Ralph Parallel Workflow Implementation Specification

> **Status**: Ready for implementation
> **Created**: 2026-01-17
> **Priority**: High - reduces task execution time by ~2x

## Overview

Transform ralph from FIFO sequential execution to parallel worker-based execution while respecting task dependencies and file conflicts.

---

## Current State

```
Sequential FIFO (Current)
─────────────────────────
Task A ──► Task B ──► Task C ──► Task D
  5min      5min       5min       5min
                                Total: 20min
```

## Target State

```
Parallel with Dependency Resolution (Target)
────────────────────────────────────────────
         ┌──► Task B ──┐
Task A ──┤             ├──► Task D
         └──► Task C ──┘
  5min        5min           5min
                        Total: 15min (25% faster)

With 3 independent tasks:
         ┌──► Task B ──┐
Task A ──┼──► Task C ──┼──► Task E
         └──► Task D ──┘
  5min        5min           5min
                        Total: 15min (40% faster)
```

---

## Architecture

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                         COORDINATOR                              │
│                        (ralph.sh --parallel)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Scheduler │  │ Lock Manager│  │   Validation Pipeline   │  │
│  │  (dep graph)│  │ (file locks)│  │ (syntax→merge→build)    │  │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘  │
└─────────┼────────────────┼─────────────────────┼────────────────┘
          │                │                     │
          ▼                ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                      WORK QUEUE (queue.yaml)                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Task UX3 │ │ Task UX4 │ │ Task UX5 │ │ Task UX6 │            │
│  │ pending  │ │ assigned │ │ assigned │ │ pending  │            │
│  │ worker:- │ │ worker:1 │ │ worker:2 │ │ blocked  │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────────────────────────────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Worker 1  │  │   Worker 2  │  │   Worker 3  │
│  (worktree) │  │  (worktree) │  │  (worktree) │
│             │  │             │  │             │
│ UX4: Action │  │ UX5: State  │  │   (idle)    │
│    Views    │  │    Views    │  │             │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Directory Structure

```
.claude/ralph/parallel/
├── queue.yaml              # Task queue with status
├── config.yaml             # Parallel execution settings
├── coordinator.pid         # Coordinator process ID
├── workers/
│   ├── worker-1.pid        # Worker 1 process ID
│   ├── worker-1.status     # "idle" | "running:TASK_ID"
│   ├── worker-1.log        # Worker output log
│   ├── worker-2.pid
│   ├── worker-2.status
│   └── worker-2.log
├── locks/
│   ├── MainView.swift.lock         # File lock (contains worker:task)
│   └── project.pbxproj.lock        # Xcode project lock
└── batches/
    ├── batch-001.yaml      # Completed batch record
    └── batch-002.yaml      # Current batch
```

---

## Implementation Tasks

### Phase 1: Foundation

#### 1.1 Create `parallel-utils.sh`
**File**: `.claude/ralph/parallel-utils.sh`

```bash
#!/bin/bash
# Shared utilities for parallel execution

# ═══════════════════════════════════════════════════════════════
# FILE LOCKING
# ═══════════════════════════════════════════════════════════════

acquire_file_lock() {
    local file="$1"
    local worker_id="$2"
    local task_id="$3"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"

    if [[ -f "$lock_file" ]]; then
        return 1  # Already locked
    fi

    echo "$worker_id:$task_id" > "$lock_file"
    return 0
}

release_file_lock() {
    local file="$1"
    local worker_id="$2"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"

    if [[ -f "$lock_file" ]] && grep -q "^$worker_id:" "$lock_file"; then
        rm -f "$lock_file"
    fi
}

check_file_available() {
    local file="$1"
    local lock_file="$PARALLEL_DIR/locks/$(echo "$file" | tr '/' '_').lock"
    [[ ! -f "$lock_file" ]]
}

# ═══════════════════════════════════════════════════════════════
# QUEUE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

init_queue() {
    # Build queue from tasks.yaml
    yq '.tasks[] | select(.completed == false)' "$TASKS_FILE" | \
    yq -s '{tasks: .}' > "$PARALLEL_DIR/queue.yaml"

    # Add status fields
    yq -i '.tasks[].status = "pending"' "$PARALLEL_DIR/queue.yaml"
    yq -i '.tasks[].assigned_worker = null' "$PARALLEL_DIR/queue.yaml"
}

claim_task() {
    local worker_id="$1"

    (
        flock -x 200

        # Find next eligible task
        local task_id=$(get_next_eligible_task "$worker_id")

        if [[ -n "$task_id" ]]; then
            # Mark as assigned
            yq -i "(.tasks[] | select(.id == \"$task_id\")) .status = \"assigned\"" "$PARALLEL_DIR/queue.yaml"
            yq -i "(.tasks[] | select(.id == \"$task_id\")) .assigned_worker = \"$worker_id\"" "$PARALLEL_DIR/queue.yaml"

            # Acquire file locks
            acquire_task_locks "$task_id" "$worker_id"

            echo "$task_id"
        fi
    ) 200>"$PARALLEL_DIR/queue.lock"
}

# ═══════════════════════════════════════════════════════════════
# DEPENDENCY RESOLUTION
# ═══════════════════════════════════════════════════════════════

get_current_group() {
    yq '[.tasks[] | select(.status != "completed") | .parallel_group] | min' "$PARALLEL_DIR/queue.yaml"
}

task_dependencies_satisfied() {
    local task_id="$1"

    local deps=$(yq ".tasks[] | select(.id == \"$task_id\") | .depends_on[]" "$TASKS_FILE" 2>/dev/null)

    for dep in $deps; do
        local dep_status=$(yq ".tasks[] | select(.id == \"$dep\") | .completed" "$TASKS_FILE")
        if [[ "$dep_status" != "true" ]]; then
            return 1
        fi
    done

    return 0
}

get_next_eligible_task() {
    local worker_id="$1"
    local current_group=$(get_current_group)

    # Get pending tasks in current group
    local candidates=$(yq ".tasks[] | select(.parallel_group == $current_group and .status == \"pending\") | .id" "$PARALLEL_DIR/queue.yaml")

    for task_id in $candidates; do
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
    done

    return 1
}

task_has_file_conflicts() {
    local task_id="$1"

    local files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]" "$TASKS_FILE" 2>/dev/null)

    for file in $files; do
        if ! check_file_available "$file"; then
            return 0  # Has conflict
        fi
    done

    return 1  # No conflicts
}
```

#### 1.2 Create `ralph-worker.sh`
**File**: `.claude/ralph/ralph-worker.sh`

```bash
#!/bin/bash
# Ralph worker process - executes tasks in isolated worktree

set -euo pipefail

WORKER_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/parallel-utils.sh"

WORKER_DIR="$PARALLEL_DIR/workers"
STATUS_FILE="$WORKER_DIR/worker-$WORKER_ID.status"
LOG_FILE="$WORKER_DIR/worker-$WORKER_ID.log"
WORKTREE_BASE="$PROJECT_ROOT/.auto-claude/worktrees/ralph-parallel"

log_worker() {
    echo "[worker-$WORKER_ID $(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

set_status() {
    echo "$1" > "$STATUS_FILE"
}

setup_worktree() {
    local task_id="$1"
    local worktree_path="$WORKTREE_BASE/$task_id"

    if [[ -d "$worktree_path" ]]; then
        log_worker "Reusing worktree: $worktree_path"
    else
        log_worker "Creating worktree for $task_id"
        git worktree add "$worktree_path" -b "ralph/$task_id" main 2>/dev/null || \
        git worktree add "$worktree_path" "ralph/$task_id" 2>/dev/null
    fi

    echo "$worktree_path"
}

execute_task() {
    local task_id="$1"
    local worktree="$2"

    log_worker "Executing task $task_id in $worktree"

    cd "$worktree"

    # Run Claude session
    if cat "$RALPH_DIR/PROMPT.md" | claude --print --verbose >> "$LOG_FILE" 2>&1; then
        log_worker "Task $task_id completed successfully"
        return 0
    else
        log_worker "Task $task_id failed"
        return 1
    fi
}

worker_loop() {
    log_worker "Starting worker loop"
    set_status "idle"

    while true; do
        # Check for shutdown signal
        if [[ -f "$PARALLEL_DIR/shutdown" ]]; then
            log_worker "Shutdown signal received"
            break
        fi

        # Check for pause signal
        if [[ -f "$PARALLEL_DIR/pause" ]]; then
            set_status "paused"
            sleep 2
            continue
        fi

        # Claim next task
        local task_id=$(claim_task "$WORKER_ID")

        if [[ -z "$task_id" ]]; then
            set_status "idle"
            sleep 3
            continue
        fi

        set_status "running:$task_id"

        # Setup worktree
        local worktree=$(setup_worktree "$task_id")

        # Execute task
        if execute_task "$task_id" "$worktree"; then
            signal_task_complete "$task_id" "$WORKER_ID"
        else
            signal_task_failed "$task_id" "$WORKER_ID"
        fi

        # Release locks
        release_worker_locks "$WORKER_ID"
        set_status "idle"
    done

    log_worker "Worker shutting down"
    set_status "stopped"
}

worker_loop
```

#### 1.3 Extend `ralph.sh` with parallel mode

Add to argument parsing:
```bash
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
```

Add parallel loop function:
```bash
run_parallel_loop() {
    log "Starting parallel execution mode..."
    log "Max workers: ${MAX_WORKERS:-3}"

    # Initialize parallel state
    init_parallel_state

    # Spawn workers
    spawn_workers "${MAX_WORKERS:-3}"

    # Coordinator loop
    while true; do
        local current_group=$(get_current_group)

        if [[ -z "$current_group" ]]; then
            log_success "All parallel groups completed!"
            break
        fi

        log "Processing parallel group $current_group..."

        # Wait for group to complete
        wait_for_group_completion "$current_group"

        # Run group validation
        if ! run_group_validation "$current_group"; then
            log_error "Group $current_group validation failed"
            handle_group_failure "$current_group"
            continue
        fi

        log_success "Group $current_group completed and validated"
    done

    # Shutdown workers
    shutdown_workers

    log_success "Parallel execution complete"
}
```

### Phase 2: Monitor Visualization

#### 2.1 Update `monitor-ralph.sh` for parallel display

**Add parallel thread visualization:**

```bash
show_parallel_threads() {
    clear

    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║              RALPH PARALLEL EXECUTION MONITOR                         ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Current parallel group
    local current_group=$(yq '.current_group // 0' "$PARALLEL_DIR/queue.yaml" 2>/dev/null || echo "0")
    echo -e "${CYAN}Current Parallel Group:${NC} $current_group"
    echo ""

    # Worker status with thread visualization
    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│  WORKER THREADS                                                      │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────┤${NC}"

    for i in 1 2 3; do
        local status_file="$PARALLEL_DIR/workers/worker-$i.status"
        local status="stopped"
        local task_id=""
        local task_title=""

        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
        fi

        if [[ "$status" =~ ^running: ]]; then
            task_id="${status#running:}"
            task_title=$(yq ".tasks[] | select(.id == \"$task_id\") | .title" "$TASKS_FILE" 2>/dev/null | head -c 40)

            echo -e "${BOLD}│${NC}  ${GREEN}▶ Thread $i${NC} ─── ${CYAN}$task_id${NC}: $task_title"

            # Show progress bar
            local progress=$(estimate_task_progress "$task_id")
            local bar=$(printf '█%.0s' $(seq 1 $((progress / 5))))
            local empty=$(printf '░%.0s' $(seq 1 $((20 - progress / 5))))
            echo -e "${BOLD}│${NC}              [${GREEN}$bar${NC}${empty}] ${progress}%"

        elif [[ "$status" == "idle" ]]; then
            echo -e "${BOLD}│${NC}  ${YELLOW}○ Thread $i${NC} ─── ${DIM}waiting for task...${NC}"

        elif [[ "$status" == "paused" ]]; then
            echo -e "${BOLD}│${NC}  ${BLUE}⏸ Thread $i${NC} ─── ${DIM}paused (validation)${NC}"

        else
            echo -e "${BOLD}│${NC}  ${RED}✗ Thread $i${NC} ─── ${DIM}stopped${NC}"
        fi
        echo -e "${BOLD}│${NC}"
    done

    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Task queue visualization
    show_task_queue_visualization

    # File locks
    show_active_locks
}

show_task_queue_visualization() {
    echo -e "${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}│  TASK QUEUE BY PARALLEL GROUP                                        │${NC}"
    echo -e "${BOLD}├─────────────────────────────────────────────────────────────────────┤${NC}"

    # Group tasks by parallel_group
    local groups=$(yq '[.tasks[].parallel_group] | unique | sort | .[]' "$TASKS_FILE" 2>/dev/null)

    for group in $groups; do
        local group_tasks=$(yq ".tasks[] | select(.parallel_group == $group)" "$TASKS_FILE")
        local completed=$(yq "[.tasks[] | select(.parallel_group == $group and .completed == true)] | length" "$TASKS_FILE")
        local total=$(yq "[.tasks[] | select(.parallel_group == $group)] | length" "$TASKS_FILE")

        if [[ $completed -eq $total ]]; then
            echo -e "${BOLD}│${NC}  ${GREEN}✓ Group $group${NC} [$completed/$total] ────────────────────────────────────"
        else
            echo -e "${BOLD}│${NC}  ${CYAN}► Group $group${NC} [$completed/$total] ────────────────────────────────────"
        fi

        # Show tasks in group (horizontal layout for parallelism visualization)
        local task_line="│    "
        local tasks_in_group=$(yq ".tasks[] | select(.parallel_group == $group) | .id" "$TASKS_FILE")

        for task_id in $tasks_in_group; do
            local completed=$(yq ".tasks[] | select(.id == \"$task_id\") | .completed" "$TASKS_FILE")
            local status=$(yq ".tasks[] | select(.id == \"$task_id\") | .status // \"pending\"" "$PARALLEL_DIR/queue.yaml" 2>/dev/null || echo "pending")

            if [[ "$completed" == "true" ]]; then
                task_line+="${GREEN}[$task_id]${NC} "
            elif [[ "$status" == "assigned" ]]; then
                task_line+="${YELLOW}[$task_id]${NC} "
            else
                task_line+="${DIM}[$task_id]${NC} "
            fi
        done

        echo -e "${BOLD}$task_line${NC}"

        # Show parallel execution indicator
        if [[ $total -gt 1 ]] && [[ $completed -lt $total ]]; then
            echo -e "${BOLD}│${NC}    ${DIM}└── Can run in parallel (no file conflicts)${NC}"
        fi

        echo -e "${BOLD}│${NC}"
    done

    echo -e "${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
}

show_active_locks() {
    local lock_count=$(ls "$PARALLEL_DIR/locks/"*.lock 2>/dev/null | wc -l)

    if [[ $lock_count -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}Active File Locks:${NC}"

        for lock_file in "$PARALLEL_DIR/locks/"*.lock; do
            [[ -f "$lock_file" ]] || continue
            local file=$(basename "$lock_file" .lock | tr '_' '/')
            local holder=$(cat "$lock_file")
            echo -e "  ${YELLOW}⚿${NC} $file ${DIM}(held by $holder)${NC}"
        done
    fi
}
```

### Phase 3: Validation Pipeline

```bash
validate_parallel_batch() {
    local batch_tasks="$1"

    log "Validating parallel batch..."

    # Phase 1: Parallel syntax check per worktree
    local syntax_pids=()
    for task_id in $batch_tasks; do
        local worktree="$WORKTREE_BASE/$task_id"
        quick_syntax_check "$worktree" &
        syntax_pids+=($!)
    done

    # Wait for all syntax checks
    for pid in "${syntax_pids[@]}"; do
        wait "$pid" || return 1
    done

    log_success "Syntax checks passed"

    # Phase 2: Sequential merge to main
    for task_id in $batch_tasks; do
        if ! merge_worktree_to_main "$task_id"; then
            log_error "Merge failed for $task_id"
            return 1
        fi
    done

    log_success "All worktrees merged"

    # Phase 3: Single build
    if ! run_build_check; then
        log_error "Build failed after merge"
        return 2
    fi

    log_success "Build passed"

    # Phase 4: Task verifications
    for task_id in $batch_tasks; do
        if ! run_task_verification "$task_id"; then
            log_error "Verification failed for $task_id"
            return 3
        fi
    done

    log_success "All task verifications passed"
    return 0
}

quick_syntax_check() {
    local worktree="$1"

    # Fast syntax-only check
    local swift_files=$(find "$worktree/ClaudeWatch" -name "*.swift" 2>/dev/null)

    swiftc -parse-as-library \
        -sdk "$(xcrun --sdk watchsimulator --show-sdk-path)" \
        -target arm64-apple-watchos10.0 \
        $swift_files 2>/dev/null
}
```

---

## Configuration

### `parallel/config.yaml`

```yaml
parallel_execution:
  enabled: true
  max_workers: 3
  worker_timeout: 900  # seconds per task

scheduling:
  respect_parallel_groups: true
  respect_depends_on: true
  auto_detect_conflicts: true

validation:
  syntax_check_parallel: true
  single_build_after_batch: true
  run_task_verification: true

failure_handling:
  build_failure: halt_all
  verification_failure: retry_3x_then_skip
  worker_crash: respawn_and_retry

git:
  branch_per_task: false
  create_pr: false
  squash_batch_commits: false
```

---

## Command Reference

```bash
# Enable parallel mode
./ralph.sh --parallel

# Parallel with custom workers
./ralph.sh --parallel --max-workers 5

# Run specific parallel group only
./ralph.sh --parallel --parallel-group 3

# Dry run to see execution plan
./ralph.sh --parallel --dry-run

# Monitor parallel execution
./monitor-ralph.sh --parallel
```

---

## Testing Checklist

- [ ] Create test tasks.yaml with known dependencies
- [ ] Verify topological sort produces correct order
- [ ] Verify file conflict detection works
- [ ] Test worker spawn/shutdown
- [ ] Test task claiming with flock
- [ ] Test file locking
- [ ] Test worktree creation/cleanup
- [ ] Test merge to main
- [ ] Test build after parallel batch
- [ ] Test failure handling (worker crash)
- [ ] Test monitor visualization
- [ ] Stress test with max-workers=5

---

## Estimated Effort

| Phase | Description | Complexity |
|-------|-------------|------------|
| 1.1 | parallel-utils.sh | Medium |
| 1.2 | ralph-worker.sh | Medium |
| 1.3 | ralph.sh parallel mode | Medium |
| 2.1 | monitor visualization | Low |
| 3 | validation pipeline | Medium |
| Testing | Full test suite | Medium |

---

## Future Enhancements

1. **Smart task restructuring**: Analyze tasks and suggest splits to maximize parallelism
2. **Dynamic worker scaling**: Add/remove workers based on queue depth
3. **Remote workers**: Distribute across multiple machines
4. **Predictive scheduling**: Use historical data to optimize batch composition
