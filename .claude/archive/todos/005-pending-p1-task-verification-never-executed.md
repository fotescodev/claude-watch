---
status: pending
priority: p1
issue_id: 005
tags: [code-review, ralph, verification, quality]
dependencies: [002]
---

# Task-Specific Verification Scripts Never Executed

## Problem Statement

Each task in `tasks.yaml` has a `verification` script to validate completion, but Ralph never executes these scripts. This means even if agents complete work, Ralph doesn't verify it actually meets requirements.

**Impact:** CRITICAL - No quality assurance, work may be incomplete or incorrect.

## Findings

### Evidence from Pattern Recognition Specialist

**Task C1 Verification:**

From `.claude/ralph/tasks.yaml` lines 33-34:

```yaml
- id: "C1"
  title: "Add accessibility labels to all interactive elements"
  verification: |
    count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l);
    [ "$count" -ge 10 ] && exit 0 || exit 1
  acceptance_criteria:
    - "Every Button has .accessibilityLabel()"
    - "Every NavigationLink has .accessibilityLabel()"
```

**Current Reality:**

```bash
$ grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift | wc -l
0

# Verification script would fail (0 < 10)
# But Ralph never runs this check
```

### Where Verification Should Run

**Location:** `.claude/ralph/ralph.sh` lines 607-609

```bash
# Run verification
if ! run_verification; then
    log_warning "Post-session verification had issues"  # ⚠️ Only warning
fi
```

**What `run_verification()` Actually Does:**

From lines 447-462:

```bash
run_verification() {
    log_verbose "Running watchOS verification checks"

    if [[ ! -x "$VERIFY_SCRIPT" ]]; then
        log_verbose "Verification script not found or not executable: $VERIFY_SCRIPT"
        return 0  # ⚠️ Passes if script doesn't exist
    fi

    if "$VERIFY_SCRIPT"; then
        log_success "Verification passed"
        return 0
    else
        log_warning "Verification checks found issues"
        return 1  # ⚠️ But this is ignored (see line 608)
    fi
}
```

**The Problem:**

1. `run_verification()` only runs `watchos-verify.sh` (general checks)
2. It does NOT extract and run the task-specific `verification` from `tasks.yaml`
3. Even if it did run and fail, the failure is ignored (line 608 shows "warning")

### Gap Analysis

**What exists in tasks.yaml:**

```yaml
# Each task has specific verification
- id: "C1"
  verification: |
    count=$(grep -r 'accessibilityLabel' ...); [ "$count" -ge 10 ]

- id: "H1"
  verification: |
    ! grep -E '\.font\(.*size:\s*([0-9]|10)\.' ClaudeWatch/ -r

- id: "H2"
  verification: |
    grep -q 'group.com' ClaudeWatch/*.entitlements || grep -q 'suiteName' ...
```

**What Ralph actually runs:**
- `watchos-verify.sh` (generic build/HIG checks)
- Nothing task-specific

**Result:** Ralph has no idea if task requirements were met.

## Proposed Solutions

### Solution 1: Run Task Verification After Code Changes (RECOMMENDED)

**Effort:** Small (1 hour)
**Risk:** Low
**Pros:**
- Uses existing verification scripts
- Task-specific validation
- Fails fast if incomplete

**Cons:**
- Requires yq/python for YAML parsing
- Verification scripts might have bugs

**Implementation:**

Add to `.claude/ralph/ralph.sh` after line 591:

```bash
# After git changes and tasks.yaml checks pass...

# Extract and run task-specific verification
log "Running task-specific verification for $next_task_id..."

task_verification=$(yq ".tasks[] | select(.id == \"$next_task_id\") | .verification" "$TASKS_FILE" 2>/dev/null)

if [[ -z "$task_verification" || "$task_verification" == "null" ]]; then
    log_verbose "No task-specific verification defined for $next_task_id"
else
    log_verbose "Verification script:"
    echo "$task_verification" | sed 's/^/    /'

    # Execute verification in subshell
    if (cd "$PROJECT_ROOT" && eval "$task_verification"); then
        log_success "Task verification PASSED"
    else
        log_error "Task verification FAILED"
        log_error "Task $next_task_id did not meet acceptance criteria"
        log_session_end "$session_id" "FAILED" "Verification failed"
        update_metrics "$session_id" "failed" "$next_task_id"
        ((consecutive_failures++))
        continue  # Retry task
    fi
fi

# Then run general verification (watchos-verify.sh)
if ! run_verification; then
    log_error "General verification FAILED"
    log_session_end "$session_id" "FAILED" "Build/HIG verification failed"
    update_metrics "$session_id" "failed" "$next_task_id"
    continue
fi

# All verifications passed - safe to proceed
log_success "All verification checks passed"
```

### Solution 2: Pre-Flight Verification (Before Session)

**Effort:** Medium (2 hours)
**Risk:** Medium
**Pros:**
- Catches already-completed tasks
- Prevents wasted work
- Validates task list accuracy

**Cons:**
- Slows down loop startup
- May have false negatives

**Implementation:**

```bash
# In task selection logic (before line 539)
verify_task_not_already_complete() {
    local task_id="$1"

    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE")

    if [[ -n "$verification" ]]; then
        if (cd "$PROJECT_ROOT" && eval "$verification" &>/dev/null); then
            log "Task $task_id already passes verification - skipping"
            # Auto-mark as complete
            yq -i "(.tasks[] | select(.id == \"$task_id\") | .completed) = true" "$TASKS_FILE"
            return 0  # Skip this task
        fi
    fi

    return 1  # Task not complete
}

# Use in selection:
if verify_task_not_already_complete "$next_task_id"; then
    log "Skipping already-complete task $next_task_id"
    continue  # Select next task
fi
```

### Solution 3: Verification Report

**Effort:** Small (1 hour)
**Risk:** Low (complementary to Solution 1)
**Pros:**
- Clear pass/fail report
- Easy debugging
- Good documentation

**Cons:**
- Just reporting, doesn't block bad sessions

**Implementation:**

```bash
generate_verification_report() {
    local task_id="$1"
    local report_file="$RALPH_DIR/verification-report-$task_id.log"

    echo "Verification Report for Task $task_id" > "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "" >> "$report_file"

    # Run verification and capture output
    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE")

    echo "Verification Script:" >> "$report_file"
    echo "$verification" >> "$report_file"
    echo "" >> "$report_file"

    echo "Results:" >> "$report_file"
    if (cd "$PROJECT_ROOT" && eval "$verification" >> "$report_file" 2>&1); then
        echo "STATUS: PASSED ✓" >> "$report_file"
    else
        echo "STATUS: FAILED ✗" >> "$report_file"
    fi

    cat "$report_file"
}
```

## Recommended Action

**Implement Solution 1 + Solution 3 together.**

**Why:**
- Solution 1: Blocks sessions that don't meet criteria (enforcement)
- Solution 3: Provides clear reports for debugging (visibility)
- Combined: Both validation and transparency

**Implementation order:**
1. Apply Solution 1 (run verification, block on failure)
2. Test with task C1 - should fail (0 labels < 10 required)
3. Apply Solution 3 (generate reports)
4. Test again - should see clear failure reason

## Technical Details

**Affected Files:**
- `.claude/ralph/ralph.sh` (add verification execution after line 591)
- `.claude/ralph/tasks.yaml` (contains verification scripts)

**Verification Script Format:**

All verification scripts in tasks.yaml follow this pattern:

```yaml
verification: |
  # Bash script that exits 0 on success, 1 on failure
  some_check && exit 0 || exit 1
```

**Execution Context:**
- Scripts run from `$PROJECT_ROOT` (repository root)
- Have access to all project files
- Should be idempotent (safe to run multiple times)

**Validation Chain:**

```
Session completes
  ├─ Git changes check ✓
  ├─ tasks.yaml update check ✓
  ├─ Task-specific verification ← NEW (Solution 1)
  │  ├─ Extract from tasks.yaml
  │  ├─ Execute in subshell
  │  └─ Exit 0 = pass, Exit 1 = fail
  ├─ General verification (watchos-verify.sh)
  └─ Update metrics (only if all pass)
```

## Acceptance Criteria

- [ ] Task verification extracted from tasks.yaml
- [ ] Verification executed after code changes validated
- [ ] Failed verification blocks task completion
- [ ] Verification failure increments failure counter
- [ ] Test C1 verification fails correctly (0 labels < 10)
- [ ] Test C1 only marked complete when verification passes
- [ ] Verification reports generated for debugging

## Work Log

**2026-01-16 - Investigation**
- Pattern Recognition Specialist identified missing verification execution
- Found task C1 has verification script requiring >= 10 labels
- Confirmed 0 labels exist, verification would fail if run
- Analyzed run_verification() - only runs generic watchos-verify.sh
- Identified gap: task-specific verification never executed

## Resources

- Verification logic: `.claude/ralph/ralph.sh` lines 447-462 (run_verification)
- Task definitions: `.claude/ralph/tasks.yaml` (verification: property)
- Verification check point: `.claude/ralph/ralph.sh` lines 607-609
- Example verification: Task C1 (lines 33-34 in tasks.yaml)
