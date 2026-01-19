# Ralph Task Failures: LG1, LG2, T1 Analysis

**Status**: pending
**Priority**: P1 (Critical)
**Category**: Bug Investigation
**Created**: 2026-01-16T19:30:00Z

## Summary

Ralph successfully completed 11 tasks (TEST1, C1, C2, C3, H1, H2, H3, H4, M1, M2, M3) but then failed 3 consecutive times on LG1 (Liquid Glass materials), LG2 (spring animations), and T1 (UI tests). All failures report "No Swift code changes detected in ClaudeWatch/".

## Critical Finding: Tasks Already Marked Complete

Looking at the metrics.json session history:
- M3 was marked as failed at 19:16:07 but the git log shows:
  - `0af3723 feat(a11y): Add Dynamic Type support` (M3) was committed
  - `c11fe09 feat(display): Add Always-On Display support` (M2)
  - `ed829ab feat(input): Add Digital Crown support` (M1)

**The tasks.yaml shows LG1, LG2, T1 are still `completed: false`**, but the metrics are showing M1, M2, M3 as the failing tasks (IDs mismatch).

## Root Cause Analysis

### Issue 1: All Previous Tasks Already Completed

The git history and code inspection reveal:
- All tasks through M3 have been completed and committed
- The code already contains:
  - `isLuminanceReduced` (Always-On Display - M2)
  - `dynamicTypeSize` and `@ScaledMetric` (Dynamic Type - M3)
  - `digitalCrownRotation` (Digital Crown - M1)

**But tasks.yaml still shows LG1 as the next incomplete task.**

### Issue 2: Task Definition Problems for LG1, LG2, T1

**LG1 (Liquid Glass materials)**:
```yaml
verification: |
  grep -q 'glassBackgroundEffect\|\.glass\|ultraThinMaterial' ClaudeWatch/Views/ -r
```
- **Problem**: `.glassBackgroundEffect()` is NOT a real SwiftUI API
- watchOS does NOT have a Liquid Glass API - this was hypothetical/future API
- The task is impossible to complete with current watchOS SDK
- Available alternatives: `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`

**LG2 (Spring animations)**:
```yaml
verification: |
  grep -q '\.spring\|interpolatingSpring\|\.bouncy' ClaudeWatch/Views/ -r
```
- **Problem**: `.bouncy` is NOT a real SwiftUI animation API
- Real APIs: `.spring()`, `.interpolatingSpring()`, `.spring(response:dampingFraction:)`
- The task is achievable but the verification includes a non-existent API

**T1 (UI tests)**:
```yaml
verification: |
  ls ClaudeWatch/Tests/UI*.swift 2>/dev/null | wc -l | grep -q '[1-9]'
files:
  - "ClaudeWatch/Tests/UITests/"
```
- **Problem 1**: The `files` path specifies `ClaudeWatch/Tests/UITests/` but this directory doesn't exist
- **Problem 2**: The verification looks for `ClaudeWatch/Tests/UI*.swift` (files in Tests/) not `ClaudeWatch/Tests/UITests/*.swift`
- **Problem 3**: XCUITest for watchOS requires a separate target in the Xcode project, not just Swift files
- The Tests/ directory exists but only contains unit tests, not UI tests

### Issue 3: Validation Logic Race Condition

Looking at ralph.sh lines 638-656:
```bash
# CHECK 1: Verify actual code changes (not just docs/logs)
log "Checking for Swift code changes in ClaudeWatch/..."
if ! git_has_code_changes; then
    log_error "CRITICAL: No Swift code changes detected in ClaudeWatch/"
```

The `git_has_code_changes` function checks:
```bash
if ! git diff --cached --quiet -- "$path" 2>/dev/null || ! git diff --quiet -- "$path" 2>/dev/null; then
```

**Problem**: If the Claude session commits its work (Step 6 in PROMPT.md says "Create a git commit"), then the changes are no longer in the working tree or staging area. The validation will fail because `git diff` returns nothing for committed changes!

This is a **timing issue**:
1. Claude makes changes
2. Claude runs verification (passes)
3. Claude commits the changes
4. ralph.sh checks for uncommitted changes (none found - fails!)

### Issue 4: Session ID Reset Problem

The metrics show multiple `session-001` entries at different times:
- session-001 at 15:52, 16:16, 17:13, 17:20, 17:25, 18:17, 18:22, 18:55, 19:02

**The session counter is being reset between runs**, which indicates Ralph is being restarted rather than running continuously. Each restart picks the "next incomplete task" which may already have been worked on.

## Evidence Summary

| Task | Status in YAML | Verification Pattern | Real API? | Can Complete? |
|------|---------------|---------------------|-----------|---------------|
| LG1 | `false` | `glassBackgroundEffect` | NO | NO |
| LG2 | `false` | `.bouncy` | NO | PARTIAL |
| T1 | `false` | `UI*.swift` in Tests/ | YES | NEEDS SETUP |

## Recommendations

### Immediate Fix: Update tasks.yaml

1. **LG1**: Replace with achievable alternative:
```yaml
- id: "LG1"
  title: "Add material effects for depth"
  description: |
    Use SwiftUI material backgrounds (.ultraThinMaterial, .thinMaterial)
    to create depth and hierarchy in the UI.
  verification: |
    grep -q 'ultraThinMaterial\|thinMaterial\|regularMaterial' ClaudeWatch/Views/ -r
```

2. **LG2**: Remove `.bouncy` from verification:
```yaml
verification: |
  grep -q '\.spring(\|interpolatingSpring' ClaudeWatch/Views/ -r
```

3. **T1**: Fix the directory path and add proper setup:
```yaml
files:
  - "ClaudeWatch/Tests/"  # Not UITests/ since it doesn't exist
verification: |
  ls ClaudeWatch/Tests/*UITest*.swift 2>/dev/null | wc -l | grep -q '[1-9]' || \
  ls ClaudeWatchUITests/*.swift 2>/dev/null | wc -l | grep -q '[1-9]'
```

### Fix: Validation Logic

Update `ralph.sh` to check for changes since the last known commit, not just uncommitted changes:
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

    # Also check if latest commit touched code files
    if git log -1 --name-only --pretty=format: | grep -q 'ClaudeWatch/'; then
        return 0
    fi

    return 1
}
```

### Fix: Prevent Premature Commits

Update PROMPT.md to NOT commit, let ralph.sh handle commits:
```markdown
## Step 6: DO NOT COMMIT

Ralph will handle the commit after verification passes.
Just ensure your changes are staged with `git add`.
```

## Files to Modify

1. `/Users/dfotesco/claude-watch/claude-watch/.claude/ralph/tasks.yaml` - Fix task definitions
2. `/Users/dfotesco/claude-watch/claude-watch/.claude/ralph/ralph.sh` - Fix validation logic
3. `/Users/dfotesco/claude-watch/claude-watch/.claude/ralph/PROMPT.md` - Clarify commit behavior

## Verification

After fixes:
```bash
# Test LG1 verification manually
grep -q 'ultraThinMaterial\|thinMaterial' ClaudeWatch/Views/ -r && echo "PASS" || echo "FAIL"

# Test validation logic
./.claude/ralph/ralph.sh --dry-run
```

## Related Issues

- See `005-pending-p1-task-verification-never-executed.md` for related verification problems
- See `004-pending-p1-git-diff-counts-docs-as-code.md` for git diff issues

---
**Assignee**: Unassigned
**Labels**: ralph, bug, validation, task-definition
