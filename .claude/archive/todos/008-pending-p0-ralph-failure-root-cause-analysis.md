# Ralph Failure Root Cause Analysis: LG1, LG2, T1 Task Failures

**Status**: pending
**Priority**: P0 (Blocker)
**Category**: Root Cause Analysis
**Created**: 2026-01-16T19:45:00Z
**Supersedes**: 006-pending-p1-ralph-lg1-lg2-t1-failures.md (adds detailed evidence)

## Executive Summary

Ralph successfully completed 11 tasks but metrics reported failures for the last 3 attempts (LG1, LG2, T1). Investigation reveals **multiple overlapping issues** that create a cascade of failures.

## Evidence Collected

### 1. Git History Shows Successful Completion Through M3

```
0af3723 feat(a11y): Add Dynamic Type support          <- M3 COMMITTED
c11fe09 feat(display): Add Always-On Display support  <- M2 COMMITTED
ed829ab feat(input): Add Digital Crown support        <- M1 COMMITTED
3d41aa5 build: Update Swift version to 5.9            <- H4 COMMITTED
42680d5 feat(voice): Add recording indicator          <- H3 COMMITTED
```

All commits through M3 were successfully created with code changes.

### 2. Metrics File Shows Contradictory Failures

From `metrics.json`:
```json
{
  "tasksCompleted": 3,
  "tasksFailed": 9,
  "sessions": [
    {"timestamp": "2026-01-16T19:16:07Z", "taskId": "M3", "status": "failed"}
  ]
}
```

**Contradiction**: M3 was committed at commit `0af3723` but metrics say it "failed".

### 3. Session Logs Confirm "No code changes in ClaudeWatch/"

From `session-log.md`:
```
## Session session-003 - 2026-01-16 19:09 UTC
**Status:** FAILED
### Notes
No code changes in ClaudeWatch/
```

### 4. Specstory Shows Tasks Did Complete

From `2026-01-16_19-10-03Z-hash-ralph-task-execution.md`:
```
=== TASK COMPLETED ===
ID: M3
Title: Add Dynamic Type support
Commit: 0af3723
======================
```

## Root Causes Identified

### Root Cause 1: Validation Timing Bug (CRITICAL)

**Location**: `ralph.sh` lines 638-656

**The Bug**: `git_has_code_changes()` checks for uncommitted changes AFTER Claude commits:

```bash
# CHECK 1: Verify actual code changes
if ! git_has_code_changes; then
    log_error "CRITICAL: No Swift code changes detected in ClaudeWatch/"
    # ... marks as FAILED
```

**Timeline**:
1. Claude session makes code changes
2. Claude runs verification (passes)
3. Claude creates commit (per PROMPT.md Step 6)
4. Claude session ends
5. ralph.sh runs `git_has_code_changes()` - **finds NO uncommitted changes**
6. ralph.sh marks session as FAILED

**Evidence**: Every successful commit shows in git log, but metrics show "failed".

**Fix Required**:
```bash
git_has_code_changes() {
    cd "$PROJECT_ROOT"
    local code_paths="ClaudeWatch/ ClaudeWatch.xcodeproj/ MCPServer/"

    # Check uncommitted changes first
    for path in $code_paths; do
        if ! git diff --cached --quiet -- "$path" 2>/dev/null || \
           ! git diff --quiet -- "$path" 2>/dev/null; then
            return 0
        fi
    done

    # NEW: Also check if latest commit touched code files
    if git log -1 --name-only --pretty=format: | grep -q 'ClaudeWatch/'; then
        log_verbose "  Code changes detected in last commit"
        return 0
    fi

    return 1
}
```

### Root Cause 2: Impossible Task Definitions (LG1)

**Location**: `tasks.yaml` LG1 definition

**The Bug**: LG1 requires `.glassBackgroundEffect()` which does NOT exist:

```yaml
- id: "LG1"
  verification: |
    grep -q 'glassBackgroundEffect\|\.glass\|ultraThinMaterial' ClaudeWatch/Views/ -r
```

**Reality Check**:
- `.glassBackgroundEffect()` - **DOES NOT EXIST** in any watchOS SDK
- This was a rumored/hypothetical watchOS 26 API
- The task is literally impossible to complete

**Current Code Analysis**:
```bash
$ grep -r 'ultraThinMaterial\|thinMaterial\|regularMaterial' ClaudeWatch/Views/
No material effects found
```

**Fix Required**: Replace with achievable APIs:
```yaml
- id: "LG1"
  title: "Add material backgrounds for depth"
  description: |
    Use SwiftUI material effects (.ultraThinMaterial, .thinMaterial)
    to create depth and visual hierarchy.
  verification: |
    grep -q 'ultraThinMaterial\|thinMaterial\|regularMaterial' ClaudeWatch/Views/ -r
```

### Root Cause 3: Broken Verification Pattern (LG2)

**Location**: `tasks.yaml` LG2 definition

**The Bug**: Verification includes `.bouncy` which won't match actual usage:

```yaml
verification: |
  grep -q '\.spring\|interpolatingSpring\|\.bouncy' ClaudeWatch/Views/ -r
```

**Reality**:
- `.bouncy` is NOT a method - it's a parameter: `.animation(.bouncy)`
- The grep pattern `\.bouncy` won't match `animation(.bouncy)`

**Fix Required**:
```yaml
verification: |
  grep -qE '\.spring\(|interpolatingSpring|\.animation\(\.bouncy' ClaudeWatch/Views/ -r
```

### Root Cause 4: Wrong File Path for UI Tests (T1)

**Location**: `tasks.yaml` T1 definition

**The Bug**: Specifies non-existent directory:

```yaml
files:
  - "ClaudeWatch/Tests/UITests/"  # This directory does NOT exist
verification: |
  ls ClaudeWatch/Tests/UI*.swift 2>/dev/null | wc -l | grep -q '[1-9]'
```

**Actual Directory Structure**:
```
ClaudeWatch/Tests/
  - ConnectionStatusTests.swift
  - QueuedMessageTests.swift
  - ReconnectionConfigTests.swift
  - WatchServiceTests.swift
  - WebSocketErrorTests.swift
```

No UITests/ subdirectory exists. XCUITest for watchOS requires:
1. A separate UI test target in the Xcode project
2. Files in a different location entirely

**Fix Required**: Either:
- Create the UITests directory structure, OR
- Update the task to match actual project structure:
```yaml
files:
  - "ClaudeWatch/Tests/"
verification: |
  ls ClaudeWatch/Tests/*UITest*.swift 2>/dev/null | wc -l | grep -q '[1-9]'
```

### Root Cause 5: Session ID Counter Reset

**Location**: `ralph.sh` run_loop() function

**The Bug**: Multiple `session-001` entries in metrics:
- session-001 at 15:52
- session-001 at 16:16
- session-001 at 17:13
- session-001 at 18:22
- etc.

This indicates Ralph is being restarted between runs rather than running continuously, causing the iteration counter to reset.

**Impact**: Makes debugging difficult and may cause task selection confusion.

## Files Requiring Modification

| File | Changes Required |
|------|-----------------|
| `.claude/ralph/ralph.sh` | Fix `git_has_code_changes()` to check last commit |
| `.claude/ralph/tasks.yaml` | Fix LG1, LG2, T1 definitions |
| `.claude/ralph/PROMPT.md` | Clarify commit timing expectations |

## Immediate Actions

### 1. Fix Validation Logic (P0)

Update `git_has_code_changes()` in `ralph.sh`:

```bash
# After the current diff checks, add:
# Also check if latest commit touched code files
if git log -1 --name-only --pretty=format: HEAD 2>/dev/null | grep -qE '^ClaudeWatch/|^ClaudeWatch\.xcodeproj/|^MCPServer/'; then
    log_verbose "  Code changes detected in last commit"
    return 0
fi
```

### 2. Fix LG1 Task Definition

Replace `.glassBackgroundEffect()` with real APIs:

```yaml
- id: "LG1"
  title: "Add material backgrounds for depth"
  description: |
    Use SwiftUI material effects (.ultraThinMaterial, .thinMaterial)
    to create depth and visual hierarchy in the UI.
    These materials provide translucency that adapts to light/dark mode.
  verification: |
    grep -q 'ultraThinMaterial\|thinMaterial\|regularMaterial\|thickMaterial' ClaudeWatch/Views/ -r
```

### 3. Fix LG2 Verification Pattern

```yaml
verification: |
  grep -qE '\.spring\(|interpolatingSpring|animation\(\.bouncy|animation\(\.snappy' ClaudeWatch/Views/ -r
```

### 4. Fix T1 File Path

```yaml
files:
  - "ClaudeWatch/Tests/"
# Or create the UITests directory first
```

## Verification Steps

After fixes, verify:

```bash
# 1. Test validation logic
cd /Users/dfotesco/claude-watch/claude-watch
git log -1 --name-only --pretty=format: | grep -q 'ClaudeWatch/' && echo "PASS" || echo "FAIL"

# 2. Test LG1 verification is achievable
grep -q 'ultraThinMaterial\|thinMaterial' ClaudeWatch/Views/ -r || echo "Ready to implement"

# 3. Test LG2 verification pattern
echo '.animation(.spring(response: 0.5))' | grep -qE '\.spring\(' && echo "PASS"

# 4. Test T1 path exists
ls -la ClaudeWatch/Tests/
```

## Related Issues

- `005-pending-p1-task-verification-never-executed.md`
- `004-pending-p1-git-diff-counts-docs-as-code.md`
- `002-pending-p1-metrics-updated-before-verification.md`

## Conclusion

The "failures" for LG1, LG2, T1 are a **composite issue**:

1. **Validation timing bug** causes successful completions to be marked as failures
2. **Impossible task definitions** (LG1) prevent any progress
3. **Broken verification patterns** (LG2) can't match real code
4. **Wrong file paths** (T1) point to non-existent directories

All four issues must be fixed for Ralph to proceed past M3.

---
**Assignee**: Unassigned
**Labels**: ralph, blocker, validation, task-definition, root-cause
