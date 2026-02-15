# Claude Watch V3 Parallel Task List

> **Generated**: 2026-01-26
> **Design Lead Triage**: Systematic parallel execution plan
> **Total Tasks**: 12 parallelizable tasks across 4 phases

---

## Task Architecture

```
Phase 1: Design System (3 parallel tasks) ─────────────────┐
         ├── T1: Add V3 Colors                             │
         ├── T2: Add ClaudeState Cases                     │ No dependencies
         └── T3: Create AmbientGlow Component              │
                                                           ▼
Phase 2: Components (4 parallel tasks) ────────────────────┐
         ├── T4: Create ModeIndicator                      │
         ├── T5: Update Complications Colors               │ Depends on Phase 1
         ├── T6: Create ActionButtonRow                    │
         └── T7: Create TaskChecklist Component            │
                                                           ▼
Phase 3: Screens (3 parallel tasks) ───────────────────────┐
         ├── T8: Fresh Session Screen (A3)                 │
         ├── T9: Tier 3 Dangerous Screen (C3)              │ Depends on Phase 2
         └── T10: Working Screen Updates (B1)              │
                                                           ▼
Phase 4: Polish (2 parallel tasks) ────────────────────────┐
         ├── T11: Add Glow Effects to Approval Screens     │ Depends on Phase 3
         └── T12: Final Build Verification                 │
```

---

## Phase 1: Design System Foundation

### T1: Add V3 Colors to Claude.swift

**Task ID**: `v3-colors`
**Priority**: P0
**Parallelizable**: Yes (no dependencies)
**Estimated**: 15 min

**File**: `ClaudeWatch/DesignSystem/Claude.swift`

**Changes Required**:
```swift
// Add after line 34 (after `static let idle = Color.gray`)
/// Plan mode - Purple (#5E5CE6) - Planning state
static let plan = Color(red: 0.369, green: 0.361, blue: 0.902)  // #5E5CE6
/// Context warning - Yellow (#FFD60A) - Context usage alert
static let context = Color(red: 1.0, green: 0.839, blue: 0.039)  // #FFD60A
/// Question - Purple (#BF5AF2) - Needs input
static let question = Color(red: 0.749, green: 0.353, blue: 0.949)  // #BF5AF2
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-colors",
  "checks": [
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "static let plan" },
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "static let context" },
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "static let question" },
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "#5E5CE6" },
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "#FFD60A" },
    { "type": "contains", "file": "ClaudeWatch/DesignSystem/Claude.swift", "text": "#BF5AF2" },
    { "type": "build" }
  ]
}
```

---

### T2: Add ClaudeState Cases

**Task ID**: `v3-states`
**Priority**: P0
**Parallelizable**: Yes (no dependencies)
**Estimated**: 30 min

**File**: `ClaudeWatch/Models/ClaudeState.swift`

**Changes Required**:
1. Add 3 new cases to enum: `.plan`, `.context`, `.question`
2. Update `displayName` computed property
3. Update `icon` computed property
4. Update `color` computed property
5. Update `hexColor` computed property

**New Cases**:
```swift
/// Plan - Purple (#5E5CE6) - Planning mode active
case plan
/// Context - Yellow (#FFD60A) - Context usage warning
case context
/// Question - Purple (#BF5AF2) - Needs user input
case question
```

**Property Updates**:
```swift
// displayName
case .plan: return "Plan Mode"
case .context: return "Context Warning"
case .question: return "Question"

// icon
case .plan: return "pencil.and.outline"
case .context: return "exclamationmark.triangle.fill"
case .question: return "questionmark.circle.fill"

// color - use Claude.swift colors
case .plan: return Claude.plan
case .context: return Claude.context
case .question: return Claude.question

// hexColor
case .plan: return "#5E5CE6"
case .context: return "#FFD60A"
case .question: return "#BF5AF2"
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-states",
  "checks": [
    { "type": "contains", "file": "ClaudeWatch/Models/ClaudeState.swift", "text": "case plan" },
    { "type": "contains", "file": "ClaudeWatch/Models/ClaudeState.swift", "text": "case context" },
    { "type": "contains", "file": "ClaudeWatch/Models/ClaudeState.swift", "text": "case question" },
    { "type": "pattern_present", "pattern": "case \\.plan.*Plan Mode", "file": "ClaudeWatch/Models/ClaudeState.swift" },
    { "type": "build" }
  ]
}
```

---

### T3: Create AmbientGlow Component

**Task ID**: `v3-glow`
**Priority**: P2
**Parallelizable**: Yes (no dependencies)
**Estimated**: 30 min

**New File**: `ClaudeWatch/Components/AmbientGlow.swift`

**Component Spec**:
```swift
import SwiftUI

/// Ambient glow effect for state emphasis
/// Specs: 100×80 ellipse, 35px blur, 18% opacity
struct AmbientGlow: View {
    let color: Color

    init(color: Color) {
        self.color = color
    }

    init(state: ClaudeState) {
        self.color = state.color
    }

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.18))
            .frame(width: 100, height: 80)
            .blur(radius: 35)
    }
}

// Convenience extension
extension AmbientGlow {
    static func success() -> AmbientGlow { AmbientGlow(color: Claude.success) }
    static func warning() -> AmbientGlow { AmbientGlow(color: Claude.warning) }
    static func danger() -> AmbientGlow { AmbientGlow(color: Claude.danger) }
    static func working() -> AmbientGlow { AmbientGlow(color: Claude.info) }
    static func plan() -> AmbientGlow { AmbientGlow(color: Claude.plan) }
    static func context() -> AmbientGlow { AmbientGlow(color: Claude.context) }
    static func question() -> AmbientGlow { AmbientGlow(color: Claude.question) }
}
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-glow",
  "checks": [
    { "type": "file_exists", "file": "ClaudeWatch/Components/AmbientGlow.swift" },
    { "type": "contains", "file": "ClaudeWatch/Components/AmbientGlow.swift", "text": "struct AmbientGlow" },
    { "type": "contains", "file": "ClaudeWatch/Components/AmbientGlow.swift", "text": "opacity(0.18)" },
    { "type": "contains", "file": "ClaudeWatch/Components/AmbientGlow.swift", "text": "blur(radius: 35)" },
    { "type": "build" }
  ]
}
```

---

## Phase 2: Components

### T4: Create ModeIndicator Component

**Task ID**: `v3-mode-indicator`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: T1 (colors)
**Estimated**: 1 hour

**New File**: `ClaudeWatch/Components/ModeIndicator.swift`

**Component Spec**:
```swift
import SwiftUI

/// Agent operating mode
enum AgentMode: String, CaseIterable {
    case normal   // Green circle + "N"
    case plan     // Purple rounded square + "P"
    case auto     // Orange pill + "A"

    var color: Color {
        switch self {
        case .normal: return Claude.success
        case .plan: return Claude.plan
        case .auto: return Claude.warning
        }
    }

    var letter: String {
        switch self {
        case .normal: return "N"
        case .plan: return "P"
        case .auto: return "A"
        }
    }
}

/// Mode indicator badge for status bar
struct ModeIndicator: View {
    let mode: AgentMode

    var body: some View {
        ZStack {
            shape
                .fill(mode.color)
                .frame(width: 18, height: 18)

            Text(mode.letter)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
        }
    }

    @ViewBuilder
    private var shape: some Shape {
        switch mode {
        case .normal:
            Circle()
        case .plan:
            RoundedRectangle(cornerRadius: 4)
        case .auto:
            Capsule()
        }
    }
}
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-mode-indicator",
  "checks": [
    { "type": "file_exists", "file": "ClaudeWatch/Components/ModeIndicator.swift" },
    { "type": "contains", "file": "ClaudeWatch/Components/ModeIndicator.swift", "text": "enum AgentMode" },
    { "type": "contains", "file": "ClaudeWatch/Components/ModeIndicator.swift", "text": "struct ModeIndicator" },
    { "type": "contains", "file": "ClaudeWatch/Components/ModeIndicator.swift", "text": "case normal" },
    { "type": "contains", "file": "ClaudeWatch/Components/ModeIndicator.swift", "text": "case plan" },
    { "type": "contains", "file": "ClaudeWatch/Components/ModeIndicator.swift", "text": "case auto" },
    { "type": "build" }
  ]
}
```

---

### T5: Update Complications Colors

**Task ID**: `v3-complications`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: T1 (colors)
**Estimated**: 30 min

**File**: `ClaudeWatch/Complications/ComplicationViews.swift`

**Changes Required**:
Replace generic SwiftUI colors with Claude design system colors:
- `Color.green` → `Claude.success`
- `Color.orange` → `Claude.warning`
- `Color.blue` → `Claude.info`
- `Color.gray` → `Claude.idle`
- `Color.red` → `Claude.danger`

**Acceptance Criteria**:
```json
{
  "task_id": "v3-complications",
  "checks": [
    { "type": "not_contains", "file": "ClaudeWatch/Complications/ComplicationViews.swift", "text": "Color.green" },
    { "type": "not_contains", "file": "ClaudeWatch/Complications/ComplicationViews.swift", "text": "Color.orange" },
    { "type": "contains", "file": "ClaudeWatch/Complications/ComplicationViews.swift", "text": "Claude.success" },
    { "type": "contains", "file": "ClaudeWatch/Complications/ComplicationViews.swift", "text": "Claude.warning" },
    { "type": "build" }
  ]
}
```

---

### T6: Create ActionButtonRow Component

**Task ID**: `v3-action-row`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: T1 (colors)
**Estimated**: 45 min

**New File**: `ClaudeWatch/Components/ActionButtonRow.swift`

**Component Spec**:
- Yes/No button pair for binary choices
- Used in QuestionResponseView
- Specs from V3_DESIGN_SYSTEM.md node `s1LF1`

```swift
import SwiftUI

/// Yes/No action button row for binary decisions
struct ActionButtonRow: View {
    let yesAction: () -> Void
    let noAction: () -> Void
    var yesLabel: String = "Yes"
    var noLabel: String = "No"

    var body: some View {
        HStack(spacing: 12) {
            Button(action: yesAction) {
                Text(yesLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Claude.success)

            Button(action: noAction) {
                Text(noLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
}
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-action-row",
  "checks": [
    { "type": "file_exists", "file": "ClaudeWatch/Components/ActionButtonRow.swift" },
    { "type": "contains", "file": "ClaudeWatch/Components/ActionButtonRow.swift", "text": "struct ActionButtonRow" },
    { "type": "contains", "file": "ClaudeWatch/Components/ActionButtonRow.swift", "text": "yesAction" },
    { "type": "contains", "file": "ClaudeWatch/Components/ActionButtonRow.swift", "text": "noAction" },
    { "type": "build" }
  ]
}
```

---

### T7: Create TaskChecklist Component

**Task ID**: `v3-checklist`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: T1 (colors)
**Estimated**: 45 min

**New File**: `ClaudeWatch/Components/TaskChecklist.swift`

**Component Spec**:
- Task check items: Done (✓ green), Active (● blue), Pending (○ gray)
- Used in WorkingView and PausedView
- Specs from V3_DESIGN_SYSTEM.md nodes `Ywufr`, `zVQDv`, `OEFWF`

```swift
import SwiftUI

/// Task check status
enum TaskCheckStatus {
    case done      // ✓ green
    case active    // ● blue
    case pending   // ○ gray

    var icon: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .active: return "circle.inset.filled"
        case .pending: return "circle"
        }
    }

    var color: Color {
        switch self {
        case .done: return Claude.success
        case .active: return Claude.info
        case .pending: return Color(hex: "#6E6E73")
        }
    }
}

/// Single task check item
struct TaskCheckItem: View {
    let status: TaskCheckStatus
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
                .foregroundColor(status.color)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(status == .pending ? Color(hex: "#6E6E73") : .white)
                .lineLimit(1)
        }
    }
}

/// Task checklist for progress display
struct TaskChecklist: View {
    let items: [(status: TaskCheckStatus, text: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                TaskCheckItem(status: items[index].status, text: items[index].text)
            }
        }
    }
}
```

**Acceptance Criteria**:
```json
{
  "task_id": "v3-checklist",
  "checks": [
    { "type": "file_exists", "file": "ClaudeWatch/Components/TaskChecklist.swift" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "enum TaskCheckStatus" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "struct TaskCheckItem" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "struct TaskChecklist" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "case done" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "case active" },
    { "type": "contains", "file": "ClaudeWatch/Components/TaskChecklist.swift", "text": "case pending" },
    { "type": "build" }
  ]
}
```

---

## Phase 3: Screens

### T8: Fresh Session Screen (A3)

**Task ID**: `v3-fresh-session`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: Phase 2 complete
**Estimated**: 1 hour

**File**: Update `ClaudeWatch/Views/StateViews.swift` or create new view

**Screen Spec** (from V3_SCREEN_SPECS.md A3):
- Status: Green dot, "Connected"
- Claude icon (32×32)
- "Waiting for Claude..." (15pt 600)
- "No activity yet" (11pt secondary)
- Footer nav (History, Settings)

**Acceptance Criteria**:
```json
{
  "task_id": "v3-fresh-session",
  "checks": [
    { "type": "contains", "text": "Waiting for Claude" },
    { "type": "contains", "text": "No activity yet" },
    { "type": "build" },
    { "type": "screenshot_verify" }
  ]
}
```

---

### T9: Tier 3 Dangerous Screen (C3)

**Task ID**: `v3-tier3-dangerous`
**Priority**: P0
**Parallelizable**: Yes (within phase)
**Depends On**: Phase 2 complete
**Estimated**: 1.5 hours

**File**: Update `ClaudeWatch/Views/ActionViews.swift`

**Screen Spec** (from V3_SCREEN_SPECS.md C3):
- Status: Red dot, "DANGEROUS"
- DELETE badge (red, white text)
- Command + description
- Red ambient glow
- Primary escape: "Review on Mac" button
- Secondary: "Reject" and "Remind" buttons

**Key Difference from Tier 1/2**:
- NO approve button on watch
- Forces review on Mac for dangerous operations
- Red glow emphasis

**Acceptance Criteria**:
```json
{
  "task_id": "v3-tier3-dangerous",
  "checks": [
    { "type": "contains", "file": "ClaudeWatch/Views/ActionViews.swift", "text": "Review on Mac" },
    { "type": "contains", "file": "ClaudeWatch/Views/ActionViews.swift", "text": "DANGEROUS" },
    { "type": "contains", "file": "ClaudeWatch/Views/ActionViews.swift", "text": "Remind" },
    { "type": "not_contains", "file": "ClaudeWatch/Views/ActionViews.swift", "text": "tier == .high.*Approve" },
    { "type": "build" }
  ]
}
```

---

### T10: Working Screen Updates (B1)

**Task ID**: `v3-working-screen`
**Priority**: P1
**Parallelizable**: Yes (within phase)
**Depends On**: T7 (TaskChecklist)
**Estimated**: 1 hour

**File**: `ClaudeWatch/Views/WorkingView.swift`

**Screen Spec** (from V3_SCREEN_SPECS.md B1):
- Status: Blue dot, "Working"
- Task title
- TaskChecklist (done, active, pending items)
- ProgressBar with percentage
- Blue ambient glow
- Pause button
- Hint: "Double tap to pause"

**Acceptance Criteria**:
```json
{
  "task_id": "v3-working-screen",
  "checks": [
    { "type": "contains", "file": "ClaudeWatch/Views/WorkingView.swift", "text": "TaskChecklist" },
    { "type": "contains", "file": "ClaudeWatch/Views/WorkingView.swift", "text": "ProgressBar" },
    { "type": "contains", "file": "ClaudeWatch/Views/WorkingView.swift", "text": "Double tap" },
    { "type": "build" }
  ]
}
```

---

## Phase 4: Polish

### T11: Add Glow Effects to Approval Screens

**Task ID**: `v3-approval-glows`
**Priority**: P2
**Parallelizable**: Yes (within phase)
**Depends On**: T3 (AmbientGlow), Phase 3 complete
**Estimated**: 45 min

**Files**:
- `ClaudeWatch/Views/ActionViews.swift`

**Changes Required**:
- Add `AmbientGlow` behind TaskCard in approval views
- Green glow for Tier 1 (Edit)
- Orange glow for Tier 2 (Run)
- Red glow for Tier 3 (Delete)

**Acceptance Criteria**:
```json
{
  "task_id": "v3-approval-glows",
  "checks": [
    { "type": "contains", "file": "ClaudeWatch/Views/ActionViews.swift", "text": "AmbientGlow" },
    { "type": "build" },
    { "type": "screenshot_verify" }
  ]
}
```

---

### T12: Final Build Verification

**Task ID**: `v3-final-verify`
**Priority**: P0
**Parallelizable**: No (final gate)
**Depends On**: All previous tasks
**Estimated**: 30 min

**Verification Checklist**:
1. Clean build succeeds
2. All new colors render correctly
3. All new states work
4. Complications update with correct colors
5. No SwiftUI previews crash
6. No force unwrapping in new code

**Acceptance Criteria**:
```json
{
  "task_id": "v3-final-verify",
  "checks": [
    { "type": "build_clean" },
    { "type": "no_force_unwrap", "files": ["ClaudeWatch/Components/*.swift", "ClaudeWatch/Models/ClaudeState.swift"] },
    { "type": "screenshot_verify", "screens": ["idle", "working", "approval", "plan", "context", "question"] }
  ]
}
```

---

## Execution Plan

### Parallel Execution Groups

**Group 1** (Phase 1 - No dependencies):
```
┌─────────────────────────────────────────────────────────┐
│  PARALLEL: T1, T2, T3                                   │
│  ├── Agent 1: v3-colors (Claude.swift)                  │
│  ├── Agent 2: v3-states (ClaudeState.swift)             │
│  └── Agent 3: v3-glow (AmbientGlow.swift)               │
└─────────────────────────────────────────────────────────┘
```

**Group 2** (Phase 2 - After Group 1):
```
┌─────────────────────────────────────────────────────────┐
│  PARALLEL: T4, T5, T6, T7                               │
│  ├── Agent 1: v3-mode-indicator (ModeIndicator.swift)   │
│  ├── Agent 2: v3-complications (ComplicationViews.swift)│
│  ├── Agent 3: v3-action-row (ActionButtonRow.swift)     │
│  └── Agent 4: v3-checklist (TaskChecklist.swift)        │
└─────────────────────────────────────────────────────────┘
```

**Group 3** (Phase 3 - After Group 2):
```
┌─────────────────────────────────────────────────────────┐
│  PARALLEL: T8, T9, T10                                  │
│  ├── Agent 1: v3-fresh-session (StateViews.swift)       │
│  ├── Agent 2: v3-tier3-dangerous (ActionViews.swift)    │
│  └── Agent 3: v3-working-screen (WorkingView.swift)     │
└─────────────────────────────────────────────────────────┘
```

**Group 4** (Phase 4 - After Group 3):
```
┌─────────────────────────────────────────────────────────┐
│  PARALLEL: T11, then SEQUENTIAL: T12                    │
│  ├── Agent 1: v3-approval-glows (ActionViews.swift)     │
│  └── Final: v3-final-verify (orchestrator)              │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Reference

| Task ID | Priority | Depends On | File(s) |
|---------|----------|------------|---------|
| v3-colors | P0 | None | Claude.swift |
| v3-states | P0 | None | ClaudeState.swift |
| v3-glow | P2 | None | AmbientGlow.swift (new) |
| v3-mode-indicator | P1 | T1 | ModeIndicator.swift (new) |
| v3-complications | P1 | T1 | ComplicationViews.swift |
| v3-action-row | P1 | T1 | ActionButtonRow.swift (new) |
| v3-checklist | P1 | T1 | TaskChecklist.swift (new) |
| v3-fresh-session | P1 | Phase 2 | StateViews.swift |
| v3-tier3-dangerous | P0 | Phase 2 | ActionViews.swift |
| v3-working-screen | P1 | T7 | WorkingView.swift |
| v3-approval-glows | P2 | T3, Phase 3 | ActionViews.swift |
| v3-final-verify | P0 | All | (verification only) |

---

## Subagent Spawn Commands

Ready-to-use Task tool invocations for the orchestrator:

### Phase 1 (spawn all 3 in parallel):
```
Task(subagent_type="general-purpose", description="T1: Add V3 colors", prompt="...")
Task(subagent_type="general-purpose", description="T2: Add ClaudeState cases", prompt="...")
Task(subagent_type="general-purpose", description="T3: Create AmbientGlow", prompt="...")
```

### Phase 2 (spawn all 4 in parallel after Phase 1):
```
Task(subagent_type="general-purpose", description="T4: Create ModeIndicator", prompt="...")
Task(subagent_type="general-purpose", description="T5: Update Complications", prompt="...")
Task(subagent_type="general-purpose", description="T6: Create ActionButtonRow", prompt="...")
Task(subagent_type="general-purpose", description="T7: Create TaskChecklist", prompt="...")
```

### Phase 3 (spawn all 3 in parallel after Phase 2):
```
Task(subagent_type="general-purpose", description="T8: Fresh Session screen", prompt="...")
Task(subagent_type="general-purpose", description="T9: Tier 3 Dangerous screen", prompt="...")
Task(subagent_type="general-purpose", description="T10: Working screen updates", prompt="...")
```

### Phase 4 (spawn T11, then T12 sequentially):
```
Task(subagent_type="general-purpose", description="T11: Add approval glows", prompt="...")
Task(subagent_type="swift-reviewer", description="T12: Final verification", prompt="...")
```
