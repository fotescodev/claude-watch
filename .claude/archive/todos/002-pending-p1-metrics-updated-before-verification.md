---
status: pending
priority: p1
issue_id: 002
tags: [code-review, ralph, state-management, timing]
dependencies: [001]
---

# Metrics Updated Before Verification Completes

## Problem Statement

Ralph updates `metrics.json` BEFORE verifying that tasks actually completed, creating phantom completions where metrics show progress that doesn't exist in reality.

**Impact:** CRITICAL - Corrupts progress tracking, makes monitoring unreliable.

## Findings

### Evidence from Architecture Strategist

**Location:** `.claude/ralph/ralph.sh` lines 549-596

Current execution order (WRONG):

```bash
if run_claude_session "$PROMPT_FILE" "$session_id"; then
    # Check 1: Code changes?
    if git diff check passes; then
        log_success "Code changes detected - session valid"

        # Check 2: tasks.yaml updated?
        if [[ "$task_completed" != "true" ]]; then
            log_error "tasks.yaml NOT updated"
            log_session_end "$session_id" "FAILED" "..."
            update_metrics "$session_id" "failed" "$next_task_id"  # ⚠️ Line 586
            ((consecutive_failures++))
            continue
        fi

        # ⚠️ BUG: Updates metrics BEFORE verification runs
        log_success "Task $next_task_id marked complete"
        update_metrics "$session_id" "completed" "$next_task_id"  # Line 595
        consecutive_failures=0

        # Verification runs AFTER metrics updated
        if ! run_verification; then  # Line 607
            log_warning "Post-session verification had issues"
            # ⚠️ Too late - metrics already show completion
        fi
    fi
fi
```

**The Problem:** Line 595 updates metrics before line 607 runs verification.

### Impact Evidence

```json
// metrics.json shows 3 completions
{
  "tasksCompleted": 3,
  "sessions": [
    { "taskId": "C1", "status": "completed" },
    { "taskId": "C1", "status": "completed" },
    { "taskId": "C1", "status": "completed" }
  ]
}

// But verification would fail:
$ grep -r "accessibilityLabel" ClaudeWatch/Views/*.swift | wc -l
0
// Expected: >= 10 for C1 to pass verification
```

### Root Cause Analysis

**Temporal Coupling Anti-Pattern:**

The code assumes this order:
1. Session runs
2. Code changes detected
3. tasks.yaml updated
4. **Metrics updated** ← assumes success
5. Verification runs

But verification can fail AFTER metrics already recorded success.

**Why this happened:**
- Line 607 verification is marked "optional" (returns warning, not error)
- Original design may have assumed verification would never fail if code changed
- No atomic transaction across state updates

## Proposed Solutions

### Solution 1: Move Metrics Update After All Validation (RECOMMENDED)

**Effort:** Small (1 hour)
**Risk:** Low
**Pros:**
- Simplest fix
- Guarantees consistency
- No new dependencies

**Cons:**
- None significant

**Implementation:**

Modify `.claude/ralph/ralph.sh`:

```bash
if run_claude_session "$PROMPT_FILE" "$session_id"; then
    # Check 1: Code changes?
    if ! git_has_code_changes; then
        log_error "No code changes detected"
        log_session_end "$session_id" "FAILED" "No code changes"
        update_metrics "$session_id" "failed" "$next_task_id"
        continue
    fi

    # Check 2: tasks.yaml updated?
    if ! task_marked_complete "$next_task_id"; then
        log_error "tasks.yaml NOT updated"
        log_session_end "$session_id" "FAILED" "Task not marked complete"
        update_metrics "$session_id" "failed" "$next_task_id"
        continue
    fi

    # Check 3: Run verification (NOW REQUIRED)
    if ! run_verification; then
        log_error "Verification FAILED"
        log_session_end "$session_id" "FAILED" "Verification failed"
        update_metrics "$session_id" "failed" "$next_task_id"
        continue
    fi

    # ALL checks passed - NOW safe to update metrics
    log_success "All validation passed for task $next_task_id"
    update_metrics "$session_id" "completed" "$next_task_id"
    log_session_end "$session_id" "COMPLETED" "Task complete"
    consecutive_failures=0
fi
```

### Solution 2: Transactional State Updates

**Effort:** Medium (4 hours)
**Risk:** Medium
**Pros:**
- Most robust
- Can roll back on failure
- Better error handling

**Cons:**
- Requires temporary state files
- More complex

**Implementation:**

```bash
begin_transaction() {
    cp "$TASKS_FILE" "$TASKS_FILE.backup"
    cp "$METRICS_FILE" "$METRICS_FILE.backup"
}

commit_transaction() {
    rm -f "$TASKS_FILE.backup" "$METRICS_FILE.backup"
}

rollback_transaction() {
    mv "$TASKS_FILE.backup" "$TASKS_FILE"
    mv "$METRICS_FILE.backup" "$METRICS_FILE"
}

# In main loop:
begin_transaction
if all_validation_passes; then
    commit_transaction
else
    rollback_transaction
fi
```

### Solution 3: Make Verification Mandatory

**Effort:** Small (1 hour)
**Risk:** Low (complementary to Solution 1)
**Pros:**
- Forces proper validation
- Clear pass/fail semantics

**Cons:**
- May fail sessions that previously "passed"

**Implementation:**

Change line 607-609 from:

```bash
if ! run_verification; then
    log_warning "Post-session verification had issues"  # ⚠️ Just a warning
fi
```

To:

```bash
if ! run_verification; then
    log_error "Verification FAILED - blocking task completion"
    return 1  # ← Hard failure
fi
```

## Recommended Action

**Implement Solution 1 + Solution 3 together.**

**Why:**
- Solution 1: Fixes timing issue (metrics updated too early)
- Solution 3: Makes verification mandatory (prevents false positives)
- Combined: Guarantees metrics reflect reality

**Implementation order:**
1. Apply Solution 3 first (make verification mandatory)
2. Test that verification actually blocks bad sessions
3. Apply Solution 1 (reorder metrics update)
4. Test full cycle with single session

## Technical Details

**Affected Files:**
- `.claude/ralph/ralph.sh` (lines 549-609)

**Related Components:**
- `update_metrics()` function (lines 233-265)
- `run_verification()` function (lines 447-462)
- Task verification scripts in `tasks.yaml`

**State Changes:**
- `metrics.json` will only update after verification passes
- Failed verifications will increment `tasksFailed` counter
- Session history will show accurate completion status

## Acceptance Criteria

- [ ] Metrics update moved after verification
- [ ] Verification made mandatory (returns error, not warning)
- [ ] Test session with failing verification blocks metrics update
- [ ] Test session with passing verification updates metrics correctly
- [ ] `metrics.json` aligns with actual code state
- [ ] `tasksCompleted` counter matches reality

## Work Log

**2026-01-16 - Investigation**
- Architecture Strategist identified temporal coupling issue
- Confirmed metrics.json shows 3 completions despite 0 actual work
- Traced execution flow to find metrics update at line 595
- Identified verification as optional (line 607-609)

## Resources

- Ralph implementation: `.claude/ralph/ralph.sh`
- Architecture report: From architecture-strategist agent
- Verification logic: `run_verification()` function lines 447-462
