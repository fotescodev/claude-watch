---
status: pending
priority: p1
issue_id: 001
tags: [code-review, ralph, state-management, critical]
dependencies: []
---

# State Consistency Violation - tasks.yaml Never Updated

## Problem Statement

Ralph Loop has a critical state consistency violation where `tasks.yaml` is never updated by agent sessions despite 9 sessions running and `metrics.json` claiming 3 tasks are complete. This breaks the entire autonomous loop's ability to track progress.

**Impact:** CRITICAL - Blocks all Ralph functionality. Tasks run repeatedly without making progress.

## Findings

### Evidence from Review Agents

**From Pattern Recognition Specialist:**
- Task C1 ran 7 times but `tasks.yaml` still shows `completed: false`
- `metrics.json` claims 3 tasks completed
- Git history shows zero commits updating `tasks.yaml` after initial creation
- No accessibility labels exist in code despite C1 claiming to add them

**From Architecture Strategist:**
- Three-way state mismatch detected:
  - `tasks.yaml`: 0 tasks complete (source of truth)
  - `metrics.json`: 3 tasks complete (metrics layer)
  - Actual codebase: 0 tasks complete (ground truth)

### State Verification

```bash
# tasks.yaml - ALL tasks show incomplete
$ grep "completed:" .claude/ralph/tasks.yaml
    completed: false  # C1
    completed: false  # C2
    completed: false  # C3
    # ... all 13 tasks are false

# metrics.json - Claims completions
$ jq '.tasksCompleted' .claude/ralph/metrics.json
3

# Actual code - Zero work done
$ grep -r "accessibilityLabel" ClaudeWatch/Views/*.swift
# Returns: 0 matches
```

### Root Cause

**Location:** `.claude/ralph/ralph.sh` lines 571-591

The orchestrator validates that `tasks.yaml` was updated:

```bash
task_completed=$(yq ".tasks[] | select(.id == \"$next_task_id\") | .completed" "$TASKS_FILE")

if [[ "$task_completed" != "true" ]]; then
    log_error "CRITICAL: tasks.yaml NOT updated for task $next_task_id"
    log_session_end "$session_id" "FAILED" "Task not marked complete in tasks.yaml"
    # Session marked as FAILED ✓ Correct
fi
```

**However:** Claude agent sessions never update `tasks.yaml` because:
1. PROMPT.md instructs agents to edit YAML manually (error-prone)
2. No programmatic interface provided (no helper script)
3. Agents enter "plan mode" instead of "execution mode"
4. Validation happens AFTER session ends (no feedback loop)

## Proposed Solutions

### Solution 1: Create State Management Interface (RECOMMENDED)

**Effort:** Small (2 hours)
**Risk:** Low
**Pros:**
- Provides atomic, safe updates to tasks.yaml
- Can be called as a command from agent sessions
- Eliminates manual YAML editing errors
- Enables validation before update

**Cons:**
- Requires updating PROMPT.md to use new interface
- Adds another script to maintain

**Implementation:**

Create `.claude/ralph/state-manager.sh`:

```bash
#!/bin/bash
# State management interface for Ralph Loop

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_FILE="$RALPH_DIR/tasks.yaml"

mark_task_complete() {
  local task_id="$1"

  # Verify task exists
  if ! yq ".tasks[] | select(.id == \"$task_id\")" "$TASKS_FILE" &>/dev/null; then
    echo "ERROR: Task $task_id not found in tasks.yaml"
    return 1
  fi

  # Update atomically
  yq -i "(.tasks[] | select(.id == \"$task_id\") | .completed) = true" "$TASKS_FILE"

  # Verify update succeeded
  local status
  status=$(yq ".tasks[] | select(.id == \"$task_id\") | .completed" "$TASKS_FILE")

  if [[ "$status" == "true" ]]; then
    echo "✓ Task $task_id marked complete"
    return 0
  else
    echo "✗ Failed to update task $task_id"
    return 1
  fi
}

# Main command dispatcher
case "$1" in
  complete)
    mark_task_complete "$2"
    ;;
  *)
    echo "Usage: $0 complete <task_id>"
    exit 1
    ;;
esac
```

Update PROMPT.md line 291-310 to replace manual edit with:

```markdown
### 1. Update Task Status

Run the state manager:
```bash
./.claude/ralph/state-manager.sh complete C1
```

Verify it succeeded (should print "✓ Task C1 marked complete").
```

### Solution 2: Auto-Update on Verification Pass

**Effort:** Medium (3 hours)
**Risk:** Medium
**Pros:**
- No agent action required
- Guaranteed consistency
- Single source of truth (ralph.sh owns state)

**Cons:**
- Removes agent autonomy
- ralph.sh becomes more complex
- Harder to debug when verification fails

**Implementation:**

Modify `.claude/ralph/ralph.sh` lines 593-596:

```bash
# AFTER all validation passes
if [[ "$task_completed" != "true" ]]; then
    # Auto-update instead of failing
    log "Auto-updating tasks.yaml for task $next_task_id"
    yq -i "(.tasks[] | select(.id == \"$next_task_id\") | .completed) = true" "$TASKS_FILE"

    # Verify it worked
    task_completed=$(yq ".tasks[] | select(.id == \"$next_task_id\") | .completed" "$TASKS_FILE")
    if [[ "$task_completed" != "true" ]]; then
        log_error "CRITICAL: Auto-update failed for task $next_task_id"
        return 1
    fi
fi
```

### Solution 3: Webhook-Style State Updates

**Effort:** Large (6 hours)
**Risk:** High
**Pros:**
- Most robust solution
- Can handle concurrent updates
- Enables audit trail

**Cons:**
- Requires HTTP server or IPC mechanism
- Over-engineered for current needs
- Additional dependencies

**Not recommended** for immediate fix.

## Recommended Action

**Implement Solution 1** (State Management Interface) immediately.

**Why:**
- Minimal code changes
- Low risk
- Solves the immediate problem
- Foundation for future improvements

**Next steps:**
1. Create `.claude/ralph/state-manager.sh` script
2. Make it executable: `chmod +x .claude/ralph/state-manager.sh`
3. Update PROMPT.md to use state-manager instead of manual edits
4. Test with single session: `./ralph.sh --single`
5. Verify tasks.yaml updates correctly

## Technical Details

**Affected Files:**
- `.claude/ralph/ralph.sh` (validation logic, lines 571-591)
- `.claude/ralph/PROMPT.md` (handoff protocol, lines 291-310)
- `.claude/ralph/tasks.yaml` (state file, never updated)
- `.claude/ralph/metrics.json` (inconsistent with tasks.yaml)

**Related Components:**
- Task selection logic (lines 539-546 in ralph.sh)
- Metrics tracking (lines 233-265 in ralph.sh)
- Session logging (lines 285-312 in ralph.sh)

**Database/State Changes:**
- New file: `.claude/ralph/state-manager.sh`
- Modified: `.claude/ralph/PROMPT.md` (handoff protocol section)
- Runtime state: `tasks.yaml` will finally be updated correctly

## Acceptance Criteria

- [ ] State manager script created and executable
- [ ] PROMPT.md updated to use state manager
- [ ] Test session successfully updates tasks.yaml
- [ ] Verification confirms `completed: true` in YAML
- [ ] Metrics.json aligns with tasks.yaml
- [ ] Task C1 completes without retrying
- [ ] Git history shows tasks.yaml being updated

## Work Log

**2026-01-16 - Investigation**
- Ran comprehensive review with pattern-recognition-specialist agent
- Ran architectural analysis with architecture-strategist agent
- Confirmed state consistency violation across all 3 layers
- Identified root cause: no programmatic update interface

## Resources

- Ralph implementation: `.claude/ralph/`
- Agent reports: This todo synthesizes findings from both agents
- Git history: `git log --oneline --all -- .claude/ralph/tasks.yaml`
- Verification: `grep -r "accessibilityLabel" ClaudeWatch/Views/*.swift`
