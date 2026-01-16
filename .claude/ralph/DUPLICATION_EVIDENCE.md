# Task Definition Duplication - Side by Side

This document shows **exact duplication** across the 3 task files.

---

## Example 1: Task C1 - Accessibility Labels

### In tasks.yaml (12 lines):

```yaml
- id: "C1"
  title: "Add accessibility labels to all interactive elements"
  description: |
    Add .accessibilityLabel() modifiers to all Button, NavigationLink,
    and interactive elements in MainView.swift and SettingsView.swift.
    This is required for App Store approval and VoiceOver support.
  priority: critical
  parallel_group: 1
  completed: false
  verification: |
    count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l);
    [ "$count" -ge 10 ] && exit 0 || exit 1
  acceptance_criteria:
    - "Every Button has .accessibilityLabel()"
    - "Every NavigationLink has .accessibilityLabel()"
    - "VoiceOver announces all elements correctly"
  files:
    - "ClaudeWatch/Views/MainView.swift"
    - "ClaudeWatch/Views/SettingsView.swift"
  tags:
    - accessibility
    - app-store
    - hig
  commit_template: "fix(a11y): Add accessibility labels to interactive elements"
```

### In SHIPPING_ROADMAP.md (120 lines):

```markdown
### C1: Add Accessibility Labels ⚠️

**Priority:** CRITICAL-1
**Status:** Not Started
**Effort:** 45 min
**Dependencies:** R1, R2
**App Store:** Required for approval

**Problem:** 27+ interactive elements lack accessibility labels

**Changes Required:**
Add `.accessibilityLabel()` to every:
- Button (24 instances across MainView.swift)
- TextField (2 instances)
- NavigationLink (if any)

**Specific Locations:**
- MainView.swift: Lines 59, 284, 301, 352, 367, 448, 518, 549, 664-729, 737, 819, 829, 869, 883, 952, 987, 1002, 1040, 1053, 1145
- PairingView.swift: Lines 30, 58, 71

**Files:**
- `ClaudeWatch/Views/MainView.swift`
- `ClaudeWatch/Views/PairingView.swift`
- `.claude/ralph/tasks.yaml` (mark complete)

**Verification:**
```bash
count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift | wc -l) && \
[ "$count" -ge 10 ] && \
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build | grep -q "BUILD SUCCEEDED"
```

**Definition of Done:**
- ✅ 27+ labels added
- ✅ Verification passes (grep ≥10, build succeeds)
- ✅ No deprecated APIs used
- ✅ tasks.yaml: `completed: true`
- ✅ Commit: `fix(a11y): Add accessibility labels to interactive elements`
```

### In TASK_BREAKDOWN.md (80 lines):

```markdown
### Task C1: Add Accessibility Labels to Interactive Elements

**ID:** `C1`
**Priority:** CRITICAL (App Store blocker)
**Status:** Not Started
**Depends On:** R1, R2
**Estimated Effort:** 30-45 minutes

#### Problem Statement
The watchOS app has 27+ interactive UI elements without accessibility labels:
- **MainView.swift**: 24+ buttons, links, navigation elements
- **PairingView.swift**: 3 interactive elements
- **Current state**: 0 accessibility labels exist (verified via grep)

This blocks:
- App Store submission (required for approval)
- VoiceOver users (cannot navigate the app)
- HIG compliance (Apple guideline violation)

#### Acceptance Criteria
- [ ] Every Button has `.accessibilityLabel()`
- [ ] Every TextField has `.accessibilityLabel()`
- [ ] Every NavigationLink has `.accessibilityLabel()`
- [ ] Grep count returns ≥10 matches
- [ ] Build succeeds with no errors
- [ ] VoiceOver announces all elements correctly (manual test)

#### Implementation Requirements

**Files to Modify:**
1. `ClaudeWatch/Views/MainView.swift` (24+ elements)
2. `ClaudeWatch/Views/PairingView.swift` (3 elements)

**Elements Requiring Labels (from codebase analysis):**

**MainView.swift:**
- Line 59-67: Settings button (gear icon)
- Line 183-189: Pending count badge
- Line 284-299: "Pair with Code" button
- Line 301-310: "Load Demo" button
[... 20 more lines of specific locations ...]

**Implementation Pattern:**
```swift
// Before:
Button("Approve") {
    service.approveAction(action.id)
}

// After:
Button("Approve") {
    service.approveAction(action.id)
}
.accessibilityLabel("Approve code change")
.accessibilityHint("Allows Claude to proceed with this action")
```

#### Verification Steps
```bash
# 1. Count accessibility labels added
label_count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l)
[ "$label_count" -ge 10 ] || exit 1

# 2. Verify both files modified
git diff --name-only | grep -q "MainView.swift" || exit 1
git diff --name-only | grep -q "PairingView.swift" || exit 1

# 3. Build for watchOS Simulator
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build \
  | grep -q "BUILD SUCCEEDED" || exit 1

# Exit code 0 = success
```

#### Definition of Done
- ✅ 27+ accessibility labels added across both files
- ✅ Grep count ≥10 (verification passes)
- ✅ Build succeeds with no errors
- ✅ No deprecated APIs used
- ✅ tasks.yaml shows `completed: true` for C1
- ✅ Committed with message: `fix(a11y): Add accessibility labels to interactive elements`
- ✅ Session log updated with completion notes
```

---

## Duplication Summary for C1

| Content | tasks.yaml | SHIPPING_ROADMAP.md | TASK_BREAKDOWN.md | Total Occurrences |
|---------|-----------|---------------------|-------------------|-------------------|
| Task ID "C1" | ✅ | ✅ | ✅ | 3 |
| Title "Add accessibility labels" | ✅ | ✅ | ✅ | 3 |
| Priority "critical" | ✅ | ✅ | ✅ | 3 |
| Description of problem | ✅ | ✅ | ✅ | 3 |
| Verification command | ✅ | ✅ | ✅ | 3 |
| File list (MainView, PairingView) | ✅ | ✅ | ✅ | 3 |
| Acceptance criteria | ✅ | ✅ | ✅ | 3 |
| Commit message template | ✅ | ✅ | ✅ | 3 |
| Grep count ≥10 requirement | ✅ | ✅ | ✅ | 3 |
| Build verification | ❌ | ✅ | ✅ | 2 |
| Line number locations | ❌ | ✅ | ✅ | 2 |
| Code examples (before/after) | ❌ | ❌ | ✅ | 1 |

**Total Duplicate Lines:** ~200 lines across 3 files defining the same task

---

## Example 2: Missing Tasks (R1, R2)

### In tasks.yaml:

```
❌ NOT DEFINED
```

### In SHIPPING_ROADMAP.md:

```markdown
### R1: Fix Ralph Session Task Tracking ⚠️

**Priority:** CRITICAL-0 (blocks everything)
**Status:** Not Started
**Effort:** 15 min
**Dependencies:** None

**Problem:** Ralph session-001 reported `taskId: "unknown"` instead of "C1"

**Changes Required:**
1. Extract task ID before Claude session starts
2. Pass task ID to Claude via environment or prompt header
3. Verify task ID appears in metrics.json after session

**Files:**
- `.claude/ralph/ralph.sh` (lines 350-375)
- `.claude/ralph/PROMPT.md` (add task ID requirement)

**Verification:**
```bash
./ralph.sh && \
grep -q '"taskId": "C[1-9]"' .claude/ralph/metrics.json && \
grep -q "Task: C[1-9]" .claude/ralph/session-log.md
```

**Definition of Done:**
- ✅ Metrics show real task ID (not "unknown")
- ✅ Session log mentions task by ID
- ✅ Verification passes
- ✅ Commit: `fix(ralph): Track task IDs in session metrics`
```

### In TASK_BREAKDOWN.md:

```markdown
### Task R1: Fix Ralph Session Task Tracking

**ID:** `R1`
**Priority:** CRITICAL-0 (blocks everything)
**Status:** Not Started
**Estimated Effort:** 15-30 minutes

#### Problem Statement
Ralph session-001 completed but reported `taskId: "unknown"` in metrics.json instead of "C1". This causes:
- No task marked complete in tasks.yaml
- Poor handoff documentation
- Inability to track progress

[... 60 more lines of detailed breakdown ...]
```

---

## Contradiction: Which File is Authoritative?

### What Ralph Reads:

```bash
# ralph.sh line 45:
TASKS_FILE="$RALPH_DIR/tasks.yaml"

# PROMPT.md line 50:
"1. `.claude/ralph/tasks.yaml` - Task list with completion status"
```

**Ralph reads:** tasks.yaml **ONLY**

### What Tasks Exist:

| Task | tasks.yaml | SHIPPING_ROADMAP.md | TASK_BREAKDOWN.md |
|------|-----------|---------------------|-------------------|
| R1 | ❌ | ✅ | ✅ |
| R2 | ❌ | ✅ | ✅ |
| C1 | ✅ | ✅ | ✅ |
| C2 | ✅ | ✅ | ❌ |
| C3 | ✅ | ✅ | ❌ |
| H1-H4 | ✅ | ✅ | ❌ |
| M1-M3 | ✅ | ✅ | ❌ |
| LG1-LG2 | ✅ | ✅ | ❌ |
| T1 | ✅ | ✅ | ❌ |

**Problem:** R1 and R2 exist in documentation but Ralph will never execute them!

---

## Impact Analysis

### Current State:

```
Ralph starts → Reads tasks.yaml → Selects C1 (first task) → Executes C1
```

**Result:**
- Task tracking broken (R1 not run)
- Might plan instead of execute (R2 not run)
- Monitoring shows "unknown" task IDs
- Progress visibility broken

### After Fix:

```
Ralph starts → Reads tasks.yaml → Selects R1 (first task) → Executes R1 → R2 → C1...
```

**Result:**
- Task tracking works (R1 fixes it)
- Guaranteed execution (R2 prevents planning)
- Monitoring shows real task IDs
- Progress visibility works

---

## Wasted Storage

| File | Lines | Duplicated Content | Waste |
|------|-------|-------------------|-------|
| tasks.yaml | 357 | Baseline | 0% |
| SHIPPING_ROADMAP.md | 713 | ~60% duplicate | ~430 lines |
| TASK_BREAKDOWN.md | 359 | ~80% duplicate | ~287 lines |
| **Total** | **1,429** | | **~717 lines wasted** |

**50% of content is duplication**

---

## Confusion Examples

### Example A: Which Verification Command?

**tasks.yaml says:**
```bash
count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l);
[ "$count" -ge 10 ] && exit 0 || exit 1
```

**SHIPPING_ROADMAP.md says:**
```bash
count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift | wc -l) && \
[ "$count" -ge 10 ] && \
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build | grep -q "BUILD SUCCEEDED"
```

**Which one is correct?**
- tasks.yaml: Just grep
- SHIPPING_ROADMAP: Grep + build

**Ralph uses:** tasks.yaml (just grep)

**Problem:** SHIPPING_ROADMAP is more thorough but Ralph doesn't use it!

---

### Example B: Which Files to Modify?

**tasks.yaml says:**
```yaml
files:
  - "ClaudeWatch/Views/MainView.swift"
  - "ClaudeWatch/Views/SettingsView.swift"
```

**SHIPPING_ROADMAP.md says:**
```markdown
**Files:**
- `ClaudeWatch/Views/MainView.swift`
- `ClaudeWatch/Views/PairingView.swift`
- `.claude/ralph/tasks.yaml` (mark complete)
```

**Which one is correct?**
- tasks.yaml: MainView + **SettingsView**
- SHIPPING_ROADMAP: MainView + **PairingView** + tasks.yaml

**Reality Check:**
```bash
$ ls ClaudeWatch/Views/
MainView.swift  PairingView.swift
```

**SettingsView.swift doesn't exist!** It's SettingsSheet inside MainView.swift.

**Problem:** tasks.yaml has wrong filename, SHIPPING_ROADMAP is correct!

---

## Summary of Duplication

**3 Files Define Tasks:**
1. tasks.yaml (12 tasks)
2. SHIPPING_ROADMAP.md (15 tasks)
3. TASK_BREAKDOWN.md (3 tasks)

**Duplication:**
- C1 defined 3 times (~200 duplicate lines)
- C2, C3 defined 2 times each
- H1-H4, M1-M3, LG1-LG2, T1 defined 2 times each
- **Total: ~717 lines of duplication (50% waste)**

**Contradictions:**
- R1, R2 exist in 2 files but Ralph can't see them
- Verification commands differ between files
- File lists have errors (SettingsView doesn't exist)
- SHIPPING_ROADMAP more thorough but ignored

**Root Cause:**
- Ralph only reads tasks.yaml (hardcoded)
- Other files created for humans but not integrated
- No sync mechanism
- Result: Spaghetti

**Solution:**
- Add R1, R2 to tasks.yaml (immediate)
- Delete SHIPPING_ROADMAP.md and TASK_BREAKDOWN.md
- Consolidate to tasks.yaml as single source
- Create proper PRD and progress tracking

**This will eliminate:**
- 717 lines of duplication
- 2 redundant files
- All contradictions
- All confusion
