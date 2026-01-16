# Ralph Task Spaghetti - Cleanup Execution Plan

**Goal:** One task file, one PRD, one progress tracker
**Timeline:** 50 minutes total
**Status:** Ready to execute

---

## Phase 1: Emergency Fix (IMMEDIATE - 5 minutes)

**Problem:** Ralph can't see R1 and R2 tasks, will skip straight to C1

**Action:** Add R1 and R2 to tasks.yaml

**Changes:**

```yaml
# Insert at line 17 (before C1):

  # ═══════════════════════════════════════════════════════════════════════════
  # PHASE 0: RALPH SELF-IMPROVEMENT (Must complete first)
  # Parallel Group 0: Sequential execution required
  # ═══════════════════════════════════════════════════════════════════════════

  - id: "R1"
    title: "Fix Ralph session task tracking"
    description: |
      Ralph reports taskId: "unknown" in metrics.json instead of actual task ID.
      This breaks monitoring and progress visibility.

      Fix by extracting task ID before Claude session starts and passing it
      to the session context. Update metrics.json to show real task IDs.
    priority: critical
    parallel_group: 0
    completed: false
    verification: |
      # Verify next session reports real task ID
      grep -q '"taskId": "[A-Z][0-9]"' .claude/ralph/metrics.json
    acceptance_criteria:
      - "Metrics show real task ID (not 'unknown')"
      - "Session log mentions task by ID"
      - "Verification command passes"
    files:
      - ".claude/ralph/ralph.sh"
      - ".claude/ralph/PROMPT.md"
      - ".claude/ralph/metrics.json"
    tags:
      - ralph
      - monitoring
      - infrastructure
    commit_template: "fix(ralph): Track task IDs in session metrics"

  - id: "R2"
    title: "Prevent plan-only behavior"
    description: |
      Ralph session-001 created implementation plans but didn't modify code or commit.
      This breaks the autonomous execution guarantee.

      Fix by adding file modification validation to ralph.sh and strengthening
      PROMPT.md language to forbid planning-only sessions.
    priority: critical
    parallel_group: 0
    completed: false
    depends_on:
      - "R1"
    verification: |
      # This will be verified in the NEXT session after R2 is implemented
      # For now, check that validation code exists
      grep -q "git diff" .claude/ralph/ralph.sh
    acceptance_criteria:
      - "Ralph cannot complete session without modifying files"
      - "PROMPT.md explicitly forbids plan-only sessions"
      - "ralph.sh validates file changes before success"
    files:
      - ".claude/ralph/ralph.sh"
      - ".claude/ralph/PROMPT.md"
    tags:
      - ralph
      - execution
      - infrastructure
    commit_template: "fix(ralph): Require code changes, prevent plan-only mode"
```

**Test:**
```bash
# Verify Ralph can read new tasks
yq '.tasks[] | select(.id == "R1" or .id == "R2") | .id' .claude/ralph/tasks.yaml

# Should output:
# R1
# R2
```

**Commit:**
```bash
git add .claude/ralph/tasks.yaml
git commit -m "fix(ralph): Add R1 and R2 self-improvement tasks to queue"
```

**Result:** Ralph will now fix itself before working on app tasks

---

## Phase 2: Consolidation (30 minutes)

**Goal:** Enhance tasks.yaml, delete redundant files

### Step 1: Enhance tasks.yaml (20 min)

Add detailed fields to each task:

```yaml
- id: "C1"
  title: "Add accessibility labels to all interactive elements"
  description: |
    The watchOS app has 27+ interactive UI elements without accessibility labels.
    This blocks App Store submission and prevents VoiceOver users from navigating.

  # NEW: Implementation steps
  implementation_steps:
    - "Read MainView.swift and identify all interactive elements (buttons, fields)"
    - "Read PairingView.swift and identify interactive elements"
    - "Add .accessibilityLabel() to each Button"
    - "Add .accessibilityLabel() to each TextField"
    - "Run grep verification to count labels"
    - "Build project to ensure no errors introduced"
    - "Commit with provided template message"

  # NEW: Specific locations
  specific_locations:
    MainView.swift:
      - "Line 59-67: Settings button (gear icon)"
      - "Line 284-299: Pair with Code button"
      - "Line 301-310: Load Demo button"
      - "Line 352-364: Retry button"
      - "Line 367-374: Demo Mode button"
      - "Line 448-466: Approve All button"
      - "Line 518-546: Reject button"
      - "Line 549-577: Approve button"
      - "Lines 664-729: Command grid buttons (Go, Test, Fix, Stop)"
      - "Line 670-695: Voice Command button"
      - "Line 737-780: Mode selector"
      - "Line 819-825: Voice input TextField"
      - "Lines 829-844: Suggestion chips"
      - "Lines 869-901: Voice sheet buttons"
      - "Line 952-968: Exit Demo Mode button"
      - "Lines 987-1018: Unpair/Pair buttons"
      - "Lines 1040-1068: Settings save/cancel buttons"
      - "Line 1145-1157: Settings Done button"
    PairingView.swift:
      - "Line 30-48: Pairing code TextField"
      - "Line 58-68: Connect button"
      - "Line 71-76: Use Demo Mode button"

  # NEW: Code example
  code_example: |
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

  priority: critical
  parallel_group: 1
  completed: false

  verification: |
    count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l);
    [ "$count" -ge 10 ] && exit 0 || exit 1

  acceptance_criteria:
    - "Every Button has .accessibilityLabel()"
    - "Every TextField has .accessibilityLabel()"
    - "Grep count returns ≥10 matches"
    - "Build succeeds with no errors"
    - "VoiceOver announces all elements correctly"

  files:
    - "ClaudeWatch/Views/MainView.swift"
    - "ClaudeWatch/Views/PairingView.swift"

  tags:
    - accessibility
    - app-store
    - hig

  commit_template: "fix(a11y): Add accessibility labels to interactive elements"
```

**Apply to all 14 tasks** (C1-C3, H1-H4, M1-M3, LG1-LG2, T1)

### Step 2: Delete Redundant Files (1 min)

```bash
# Remove duplicated documentation
rm .claude/ralph/SHIPPING_ROADMAP.md     # 713 lines
rm .claude/ralph/TASK_BREAKDOWN.md      # 359 lines
rm .claude/ralph/SUMMARY.md             # Redundant with README

# Keep git history
git add -A
git commit -m "docs(ralph): Remove redundant task documentation, consolidate to tasks.yaml"
```

### Step 3: Update Documentation References (10 min)

**README.md:**
```markdown
# Remove references to deleted files
- ~~SHIPPING_ROADMAP.md~~
- ~~TASK_BREAKDOWN.md~~
- ~~SUMMARY.md~~

# Update task reference
For task details, see: `tasks.yaml`
```

**QUICK_START.md:**
```markdown
# Change:
"Ralph reads SHIPPING_ROADMAP.md..."

# To:
"Ralph reads tasks.yaml..."
```

**MONITORING_GUIDE.md:**
```markdown
# Change references from SHIPPING_ROADMAP to tasks.yaml
```

**Commit:**
```bash
git add .claude/ralph/*.md
git commit -m "docs(ralph): Update references to use tasks.yaml as single source"
```

---

## Phase 3: Create Proper Docs (15 minutes)

### Step 1: Create PRODUCT_SPEC.md (5 min)

**ONE PRD for the entire project:**

```markdown
# Claude Watch - Product Specification

**Version:** 1.0
**Platform:** watchOS 10.0+
**Language:** Swift 5.9+
**Last Updated:** 2026-01-16

## What We're Building

A watchOS app that brings Claude Code to your wrist.

## Why

Developers wear Apple Watches. Code approval shouldn't require returning to desk.
Enable approval/rejection of code changes directly from watch via:
- Push notifications
- Voice commands
- Watch complications

## Target Users

- **Primary:** Developers using Claude Code
- **Secondary:** Teams with AI-assisted development workflows

## Core Features

### MVP (Phase 1):
1. Receive push notifications for pending actions
2. Approve/reject with single tap
3. View action queue on watch face
4. Voice command support ("Approve all")

### Future (Phase 2):
5. Watch face complications showing pending count
6. Digital Crown scrolling through queue
7. Always-On Display optimization

## Success Criteria

### App Store Approval:
- ✅ All accessibility labels present
- ✅ App icons for all sizes
- ✅ AI data consent dialog
- ✅ Minimum 11pt fonts
- ✅ Recording indicator for voice

### User Experience:
- ✅ Notification → approval in <5 seconds
- ✅ VoiceOver fully functional
- ✅ Works in all lighting conditions

### Technical:
- ✅ Swift 5.9+
- ✅ SwiftUI native
- ✅ No deprecated APIs
- ✅ Build passes without errors

## Out of Scope (v1.0)

- iPhone companion app
- iPad support
- Code diff viewing on watch
- Editing code from watch

## Dependencies

- Claude Code CLI (server-side)
- APNs (push notifications)
- MCP server (WebSocket bridge)

## Timeline

- **Phase 0:** Ralph self-improvement (2 sessions)
- **Phase 1:** App Store blockers (3 sessions)
- **Phase 2:** Polish (4 sessions)
- **Phase 3:** Optional enhancements (6 sessions)

**Target:** Ready for TestFlight in ~9 Ralph sessions (~5 hours)

## Risks

- **APNs approval:** Requires Apple developer account
- **Battery drain:** Voice + notifications may impact battery
- **Screen size:** Limited UI real estate on watch
```

### Step 2: Create PROGRESS.md (5 min)

**ONE progress file that Ralph updates:**

```markdown
# Ralph Progress Tracker

**Last Updated:** 2026-01-16 11:17 UTC
**Current Session:** session-001

## Current Status

**Active Task:** R1 - Fix Ralph session task tracking
**Status:** In Progress
**Started:** 2026-01-16 11:17 UTC

## Progress Summary

**Total Tasks:** 15
**Completed:** 0
**In Progress:** 1 (R1)
**Pending:** 14

**Completion:** 0% (0/15)

## Task Breakdown

### Phase 0: Ralph Self-Improvement
- [ ] R1 - Fix task tracking (IN PROGRESS)
- [ ] R2 - Prevent plan-only behavior

### Phase 1: App Store Blockers
- [ ] C1 - Accessibility labels
- [ ] C2 - App icons
- [ ] C3 - Consent dialog

### Phase 2: HIG Compliance
- [ ] H1 - Fix font sizes
- [ ] H2 - App Groups
- [ ] H3 - Recording indicator
- [ ] H4 - Swift 5.9

### Phase 3: Enhancements
- [ ] M1 - Digital Crown
- [ ] M2 - Always-On Display
- [ ] M3 - Dynamic Type

### Phase 4: Polish
- [ ] LG1 - Liquid Glass
- [ ] LG2 - Spring animations

### Phase 5: Testing
- [ ] T1 - UI tests

## Recent Activity

**2026-01-16 11:17:** Started session-001, selected task R1
**2026-01-16 10:57:** Initialized Ralph, 2 sessions completed (init)

## Blockers

None currently

## Next Up

After R1 completes:
- R2 - Prevent plan-only behavior
- Then C1 - Accessibility labels

## Metrics

**Sessions Run:** 2 (init-1768578293, session-001)
**Tasks Completed:** 0
**Tasks Failed:** 0
**Build Failures:** 0
**Total Retries:** 0

## Notes

- Ralph is currently fixing its own task tracking system
- Monitoring dashboard waiting for progress log
- Will have full visibility after R1 and R2 complete
```

### Step 3: Auto-update Script (5 min)

Create a script Ralph calls to update PROGRESS.md:

```bash
#!/bin/bash
# .claude/ralph/update-progress.sh

TASKS_FILE=".claude/ralph/tasks.yaml"
PROGRESS_FILE=".claude/ralph/PROGRESS.md"
METRICS_FILE=".claude/ralph/metrics.json"

# Count tasks
total=$(yq '.tasks | length' "$TASKS_FILE")
completed=$(yq '.tasks[] | select(.completed == true)' "$TASKS_FILE" | yq 'length')
pending=$((total - completed))
percent=$((completed * 100 / total))

# Get current task from metrics
current_task=$(jq -r '.sessions[-1].taskId' "$METRICS_FILE" 2>/dev/null || echo "unknown")

# Update PROGRESS.md
cat > "$PROGRESS_FILE" << EOF
# Ralph Progress Tracker

**Last Updated:** $(date -u '+%Y-%m-%d %H:%M UTC')
**Current Session:** $(jq -r '.sessions[-1].id' "$METRICS_FILE" 2>/dev/null || echo "none")

## Current Status

**Active Task:** $current_task
**Status:** In Progress

## Progress Summary

**Total Tasks:** $total
**Completed:** $completed
**Pending:** $pending

**Completion:** $percent% ($completed/$total)

[... rest of template ...]
EOF
```

---

## Phase 4: Validate (5 minutes)

### Test 1: Ralph Reads tasks.yaml

```bash
# Verify Ralph can see R1, R2
yq '.tasks[] | select(.parallel_group == 0) | .id' .claude/ralph/tasks.yaml

# Expected output:
# R1
# R2
```

### Test 2: No References to Deleted Files

```bash
# Should return empty (no references)
grep -r "SHIPPING_ROADMAP\|TASK_BREAKDOWN" .claude/ralph/*.md 2>/dev/null | grep -v "CLEANUP_PLAN\|DUPLICATION_EVIDENCE\|TASK_SPAGHETTI"
```

### Test 3: Ralph Dry Run

```bash
# Test Ralph's task selection logic
cd .claude/ralph
./ralph.sh --dry-run

# Should show: "Would select task: R1"
```

### Test 4: Documentation Links Work

```bash
# Check all markdown files for broken links
find .claude/ralph -name "*.md" -exec markdown-link-check {} \;
```

---

## Final State

After cleanup:

```
.claude/ralph/
├── README.md              ← Index (updated)
├── QUICK_START.md         ← Getting started (updated)
├── MONITORING_GUIDE.md    ← Monitoring (updated)
│
├── tasks.yaml             ← ✅ SINGLE TASK SOURCE (enhanced)
├── PRODUCT_SPEC.md        ← ✅ ONE PRD (new)
├── PROGRESS.md            ← ✅ ONE progress file (new)
│
├── PROMPT.md              ← Ralph's instructions
├── ralph.sh               ← Execution harness
├── monitor-ralph.sh       ← Live monitoring
├── update-progress.sh     ← Progress updater (new)
│
├── session-log.md         ← Session history
├── metrics.json           ← Statistics
├── current-progress.log   ← Live log
│
└── SPEC.md                ← Technical architecture
    TESTING.md             ← Testing checklist
    INITIALIZER.md         ← Setup guide

DELETED:
- ❌ SHIPPING_ROADMAP.md (713 lines)
- ❌ TASK_BREAKDOWN.md (359 lines)
- ❌ SUMMARY.md (redundant)

ANALYSIS DOCS (keep for reference):
- TASK_SPAGHETTI_ANALYSIS.md
- DUPLICATION_EVIDENCE.md
- CLEANUP_PLAN.md (this file)
```

---

## Rollback Plan

If something breaks:

```bash
# Restore deleted files
git checkout HEAD~1 -- .claude/ralph/SHIPPING_ROADMAP.md
git checkout HEAD~1 -- .claude/ralph/TASK_BREAKDOWN.md
git checkout HEAD~1 -- .claude/ralph/SUMMARY.md

# Revert tasks.yaml changes
git checkout HEAD~1 -- .claude/ralph/tasks.yaml

# Ralph will work again (with old structure)
```

---

## Success Metrics

**Before:**
- 3 task files (tasks.yaml, SHIPPING_ROADMAP, TASK_BREAKDOWN)
- 1,429 total lines
- 717 lines of duplication (50%)
- Ralph missing R1, R2 tasks
- Unknown task IDs in metrics
- Monitoring broken

**After:**
- 1 task file (tasks.yaml)
- ~500 lines (enhanced with details)
- 0 lines of duplication
- Ralph has all 15 tasks
- Real task IDs in metrics
- Monitoring working

**Improvement:**
- ✅ 929 fewer lines (65% reduction)
- ✅ 100% less duplication
- ✅ One source of truth
- ✅ Ralph fully functional
- ✅ Clear ownership

---

## Approval Checkboxes

- [ ] **Phase 1 (IMMEDIATE):** Add R1, R2 to tasks.yaml - APPROVE?
- [ ] **Phase 2:** Consolidate to enhanced tasks.yaml - APPROVE?
- [ ] **Phase 3:** Create PRODUCT_SPEC and PROGRESS.md - APPROVE?
- [ ] **Phase 4:** Validate everything works - APPROVE?

**Or:**
- [ ] **Alternative approach:** Suggest different plan

---

## Ready to Execute

Once approved, I'll execute all phases in sequence with git commits at each step.

**Estimated time:** 50 minutes total
**Risk:** Low (git history preserves everything)
**Benefit:** Clean, maintainable, working Ralph system

**Approve to proceed?**
