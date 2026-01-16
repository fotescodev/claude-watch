---
status: pending
priority: p1
issue_id: 004
tags: [code-review, ralph, validation, git]
dependencies: []
---

# Git Diff Check Counts Documentation as Code Changes

## Problem Statement

Ralph's validation accepts ANY file changes as "code changes," including documentation files. This allows sessions to pass the git diff check without actually implementing the task, contributing to the infinite loop on task C1.

**Impact:** CRITICAL - Sessions appear successful despite no actual code work.

## Findings

### Evidence from Architecture Strategist

**Location:** `.claude/ralph/ralph.sh` lines 551-568

```bash
if run_claude_session "$PROMPT_FILE" "$session_id"; then
    # CRITICAL: Verify files were actually modified
    if git diff --cached --quiet && git diff --quiet; then
        log_error "CRITICAL: No code changes detected after session"
        log_session_end "$session_id" "FAILED" "..."
    else
        log_success "Code changes detected - session valid"  # ⚠️ ANY changes
    fi
fi
```

**The Problem:** This check passes if:
- Documentation added (`.md` files)
- Session logs updated (`.claude/ralph/session-log.md`)
- Metrics updated (`.claude/ralph/metrics.json`)
- Task tracking updated (`.claude/ralph/TASKS.md`)

But **NOT** if actual Swift code in `ClaudeWatch/` was modified.

### Why This Matters

**Task C1 ran 7 times:**

Each session likely:
1. Read PROMPT.md (plan mode triggered)
2. Created session notes or documentation
3. Git detected changes to `.md` files
4. Passed git diff check ✓
5. Failed tasks.yaml check (not updated) ✗
6. Marked as "valid session with changes" but failed for other reasons
7. Metrics counted it as an attempt

**Result:** Loop never realizes no actual code work is happening.

### Verification

```bash
# Check what files actually changed in recent sessions
$ git log --name-only --oneline -10

c695bd4 fix(ralph): Add graceful shutdown and task completion verification
.claude/ralph/ralph.sh           # ← Infrastructure, not task work
.claude/ralph/PROMPT.md

8e1f944 fix(ralph): Improve visibility with verbose commentary
.claude/ralph/ralph.sh           # ← Infrastructure, not task work

4bfbbfb chore(ralph): Track session-001 completion
.claude/ralph/session-log.md    # ← Logs, not task work
.claude/ralph/metrics.json

# No changes to ClaudeWatch/*.swift despite 7 attempts at C1
```

## Proposed Solutions

### Solution 1: Check Specific Code Directories (RECOMMENDED)

**Effort:** Small (30 minutes)
**Risk:** Low
**Pros:**
- Simple boolean logic change
- Clearly defines "code" vs "docs"
- Prevents false positives

**Cons:**
- Hardcodes directory structure
- Need to update if structure changes

**Implementation:**

Replace `.claude/ralph/ralph.sh` lines 551-568:

```bash
# Helper function: Check for code changes only
git_has_code_changes() {
    # Check ClaudeWatch/ directory (actual code)
    # Exclude .claude/, .specstory/, and root-level markdown

    if git diff --cached --quiet -- ClaudeWatch/ && \
       git diff --quiet -- ClaudeWatch/; then
        return 1  # No code changes
    else
        return 0  # Code changes detected
    fi
}

# In main validation:
if ! git_has_code_changes; then
    log_error "CRITICAL: No Swift code changes detected after session"
    log_error "Changes to docs/logs don't count - must modify ClaudeWatch/"
    log_session_end "$session_id" "FAILED" "No code changes"
    update_metrics "$session_id" "failed" "$next_task_id"
    continue
fi

log_success "Swift code changes detected - session valid"
```

### Solution 2: Check File Extensions

**Effort:** Small (30 minutes)
**Risk:** Low
**Pros:**
- Language-agnostic
- Easy to extend (add .json, .plist, etc.)
- Clear validation

**Cons:**
- Might miss edge cases (e.g., no-extension files)
- More complex regex

**Implementation:**

```bash
git_has_code_changes() {
    # Get list of changed files
    local changed_files
    changed_files=$(git diff --name-only && git diff --cached --name-only)

    # Check if any are Swift/code files
    if echo "$changed_files" | grep -qE '\.(swift|h|m|xib|storyboard)$'; then
        return 0  # Code changes found
    else
        return 1  # Only docs/config changed
    fi
}
```

### Solution 3: Require Task-Specific File Changes

**Effort:** Medium (2 hours)
**Risk:** Medium
**Pros:**
- Most precise validation
- Enforces task contract
- Catches partial implementations

**Cons:**
- Requires parsing tasks.yaml
- More complex logic
- Might be too strict

**Implementation:**

```bash
verify_task_files_modified() {
    local task_id="$1"

    # Get list of files the task should modify
    local expected_files
    expected_files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]" "$TASKS_FILE")

    # Check if at least one expected file was modified
    local found_changes=false
    while IFS= read -r file; do
        if ! git diff --quiet -- "$file" || ! git diff --cached --quiet -- "$file"; then
            log "  ✓ Modified: $file"
            found_changes=true
        fi
    done <<< "$expected_files"

    if [[ "$found_changes" == "false" ]]; then
        log_error "None of the expected files were modified:"
        echo "$expected_files" | sed 's/^/    - /'
        return 1
    fi

    return 0
}

# In main validation:
if ! verify_task_files_modified "$next_task_id"; then
    log_error "Task $next_task_id didn't modify expected files"
    log_session_end "$session_id" "FAILED" "Wrong files modified"
    continue
fi
```

## Recommended Action

**Implement Solution 1 + Solution 3 together.**

**Why:**
- Solution 1: Quick fix, prevents obvious false positives
- Solution 3: Stronger validation, enforces task contract
- Combined: Both breadth (any code) and precision (right files)

**Implementation order:**
1. Apply Solution 1 first (check ClaudeWatch/ directory)
2. Test with single session
3. Apply Solution 3 (check task-specific files)
4. Test with single session again

## Technical Details

**Affected Files:**
- `.claude/ralph/ralph.sh` (validation logic, lines 551-568)

**Git Commands Used:**
- `git diff --quiet -- <path>` - Check for unstaged changes in path
- `git diff --cached --quiet -- <path>` - Check for staged changes
- `git diff --name-only` - List changed files

**Validation Flow:**

```
Session completes
  ├─ Check 1: Any changes? (current - too broad)
  ├─ Check 1 NEW: ClaudeWatch/ changes? (Solution 1)
  ├─ Check 2 NEW: Expected task files changed? (Solution 3)
  ├─ Check 3: tasks.yaml updated?
  └─ Check 4: Verification passed?
```

## Acceptance Criteria

- [ ] Git diff check scoped to ClaudeWatch/ directory
- [ ] Documentation changes don't count as "code changes"
- [ ] Task-specific file validation implemented
- [ ] Test session modifying only docs fails validation
- [ ] Test session modifying Swift code passes validation
- [ ] Task C1 requires changes to MainView.swift/SettingsView.swift

## Work Log

**2026-01-16 - Investigation**
- Architecture Strategist identified overly broad git check
- Verified task C1 ran 7 times with no Swift code changes
- Analyzed git log to confirm only infrastructure files changed
- Identified solution: scope git diff to code directories

## Resources

- Validation logic: `.claude/ralph/ralph.sh` lines 551-568
- Git history: `git log --name-only --oneline -10`
- Task file definitions: `.claude/ralph/tasks.yaml` (files: property)
