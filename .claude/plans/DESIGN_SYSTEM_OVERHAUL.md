# Design System Overhaul Plan

> **Status**: Draft
> **Created**: 2026-01-20
> **Target**: Align SwiftUI implementation with React prototype + Anthropic brand

---

## Executive Summary

This plan bridges the gap between:
- **React prototype** (`ClaudeWatchComplete`) - comprehensive design vision
- **Swift implementation** (`Claude.swift` + Views) - current production code

The overhaul ensures visual consistency with Anthropic brand guidelines while maintaining watchOS 10+ compatibility and Liquid Glass readiness for watchOS 26.

---

## Gap Analysis

### Color Token Misalignment

| Token | React Prototype | Current Swift | Action |
|-------|-----------------|---------------|--------|
| `dark` | `#141413` | `#000000` | Update |
| `light` | `#faf9f5` | N/A | Add |
| `orange` | `#d97757` | `#FF9500` (Apple) | **Keep Apple for watchOS** |
| `blue` | `#6a9bcc` | `#007AFF` (Apple) | Keep |
| `green` | `#788c5d` | `#34C759` (Apple) | Keep |
| `danger` | `#c4675a` | `#FF3B30` (Apple) | Keep |
| `surface` | `#1c1b1a` | `#1C1C1E` | Close enough |
| `dangerBg` | `rgba(196,103,90,0.15)` | Missing | **Add** |

**Decision**: Keep Apple system colors for watchOS HIG compliance. Add missing semantic tokens.

### Missing Screens (by Persona)

| Screen | Persona | Current Status | Priority |
|--------|---------|----------------|----------|
| Danger Action (red border) | Sam | Missing | P1 |
| Progress + ETA | Jordan | Partial (no ETA) | P2 |
| Expanded Detail | Sam | Missing | P2 |
| Selective Queue | Sam | Missing | P3 |
| Session History | Sam | Missing | P3 |
| iOS Companion | Riley | Out of scope | Deferred |

### Missing Components

| Component | Description | Priority |
|-----------|-------------|----------|
| `DangerIndicator` | Red border + warning for destructive ops | P1 |
| `ETADisplay` | Time remaining estimation | P2 |
| `HistoryRow` | Action history item with auto badge | P3 |
| `SelectableActionRow` | Checkbox + action info | P3 |

---

## Phase 1: Token Alignment (Foundation)

**Goal**: Ensure all UI components draw from centralized tokens.

### Task 1.1: Add Missing Color Tokens
```swift
// Add to Claude.swift
static let dangerBackground = Color.red.opacity(0.15)
static let brandDark = Color(red: 0.078, green: 0.078, blue: 0.075)  // #141413
static let brandLight = Color(red: 0.980, green: 0.976, blue: 0.961) // #faf9f5
```

**Files**: `ClaudeWatch/DesignSystem/Claude.swift`
**Success Criteria**: New tokens available, no compile errors

### Task 1.2: Add Mode Colors
```swift
enum ModeColors {
    static let normal = Claude.info      // Blue
    static let autoAccept = Claude.danger // Red
    static let plan = Color.purple        // Purple
}
```

**Files**: `ClaudeWatch/DesignSystem/Claude.swift`
**Success Criteria**: ModeSelector uses centralized colors

### Task 1.3: Typography Audit
Verify all views use `Claude.swift` typography instead of inline fonts:
- `Font.claudeLargeTitle`
- `Font.claudeHeadline`
- `Font.claudeBody`
- `Font.claudeCaption`
- `Font.claudeFootnote`
- `Font.claudeMono`

**Files**: All `*.swift` in `Views/`
**Success Criteria**: No inline `Font.system()` calls except for scaled metrics

---

## Phase 2: Danger Pattern (Sam's P1 Need)

**Goal**: Destructive operations (DELETE, rm, drop) show visual risk indicator.

### Task 2.1: Create DangerIndicator View
```swift
struct DangerIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Claude.danger)
            Text("Destructive")
                .font(.claudeCaption)
                .foregroundColor(Claude.danger)
        }
    }
}
```

**Files**: `ClaudeWatch/Views/Components/DangerIndicator.swift` (new)
**Success Criteria**: Component renders correctly in preview

### Task 2.2: Add Danger Detection Logic
```swift
extension PendingAction {
    var isDangerous: Bool {
        // File deletions
        if type == "file_delete" { return true }
        // Bash commands with dangerous keywords
        if type == "bash", let cmd = command?.lowercased() {
            let dangerKeywords = ["delete", "drop", "truncate", "rm -rf", "rm -r"]
            return dangerKeywords.contains { cmd.contains($0) }
        }
        return false
    }
}
```

**Files**: `ClaudeWatch/Models/ApprovalRequest.swift`
**Success Criteria**: Unit tests pass for danger detection

### Task 2.3: Update PrimaryActionCard for Danger State
```swift
// In PrimaryActionCard body
.overlay(
    action.isDangerous ? RoundedRectangle(cornerRadius: 16)
        .stroke(Claude.danger, lineWidth: 2) : nil
)
.background(action.isDangerous ? Claude.dangerBackground : .clear)
```

**Files**: `ClaudeWatch/Views/ActionViews.swift`
**Success Criteria**:
- Dangerous actions show red border
- Non-dangerous actions unchanged
- Preview shows both states

### Task 2.4: Swap Button Order for Danger
For dangerous actions, Reject should be prominent (right side):
```swift
if action.isDangerous {
    // Approve first (muted), Reject second (prominent)
    approveButton.tint(Claude.surface2)
    rejectButton.tint(Claude.danger)
} else {
    // Normal: Reject first, Approve second (prominent)
}
```

**Files**: `ClaudeWatch/Views/ActionViews.swift`
**Success Criteria**: Button order flips for dangerous actions

---

## Phase 3: Progress + ETA (Jordan's P2 Need)

**Goal**: Show estimated time remaining for long-running tasks.

### Task 3.1: Add ETA Model
```swift
struct TaskProgress {
    let current: Int
    let total: Int
    let elapsedSeconds: Int

    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var estimatedRemainingSeconds: Int? {
        guard current > 0, total > current else { return nil }
        let rate = Double(elapsedSeconds) / Double(current)
        return Int(rate * Double(total - current))
    }

    var formattedETA: String {
        guard let remaining = estimatedRemainingSeconds else { return "—" }
        if remaining < 60 { return "<1m" }
        return "~\(remaining / 60)m"
    }
}
```

**Files**: `ClaudeWatch/Models/TaskProgress.swift` (new)
**Success Criteria**: Unit tests for ETA calculation

### Task 3.2: Update WatchService for Progress Tracking
```swift
@Published var taskProgress: TaskProgress?
private var taskStartTime: Date?

func updateProgress(current: Int, total: Int) {
    let elapsed = Int(Date().timeIntervalSince(taskStartTime ?? Date()))
    taskProgress = TaskProgress(current: current, total: total, elapsedSeconds: elapsed)
}
```

**Files**: `ClaudeWatch/Services/WatchService.swift`
**Success Criteria**: Progress updates reflected in state

### Task 3.3: Create ETADisplay Component
```swift
struct ETADisplay: View {
    let progress: TaskProgress

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(Claude.textSecondary)
            Text(progress.formattedETA)
                .font(.claudeCaption)
                .foregroundColor(Claude.textSecondary)
        }
    }
}
```

**Files**: `ClaudeWatch/Views/Components/ETADisplay.swift` (new)
**Success Criteria**: Component shows formatted time

### Task 3.4: Integrate ETA into StatusHeader
```swift
// Add to StatusHeader progress section
if let eta = service.taskProgress?.formattedETA {
    ETADisplay(progress: service.taskProgress!)
}
```

**Files**: `ClaudeWatch/Views/MainView.swift`
**Success Criteria**: ETA visible during active tasks

---

## Phase 4: Expanded Detail View (Sam's P2 Need)

**Goal**: Long-press action card to see full details.

### Task 4.1: Create ActionDetailView
```swift
struct ActionDetailView: View {
    let action: PendingAction
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Claude.Spacing.md) {
                // Header
                ActionTypeHeader(action: action)

                // Full path
                if let path = action.filePath {
                    DetailSection(title: "Full Path") {
                        Text(path)
                            .font(.claudeMono)
                    }
                }

                // Description
                if let desc = action.description {
                    DetailSection(title: "Description") {
                        Text(desc)
                            .font(.claudeCaption)
                    }
                }

                // Buttons
                ActionButtons(action: action)
            }
            .padding()
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
    }
}
```

**Files**: `ClaudeWatch/Views/ActionDetailView.swift` (new)
**Success Criteria**: Full action info displayed

### Task 4.2: Add Long-Press Gesture to PrimaryActionCard
```swift
.onLongPressGesture {
    WKInterfaceDevice.current().play(.click)
    showingDetail = true
}
.sheet(isPresented: $showingDetail) {
    ActionDetailView(action: action)
}
```

**Files**: `ClaudeWatch/Views/ActionViews.swift`
**Success Criteria**: Long-press opens detail sheet

---

## Phase 5: Session History (Sam's P3 Need)

**Goal**: Audit trail of approved/rejected actions.

### Task 5.1: Create HistoryItem Model
```swift
struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let action: String
    let file: String
    let outcome: Outcome
    let wasAutoApproved: Bool
    let timestamp: Date

    enum Outcome: String, Codable {
        case approved, rejected
    }
}
```

**Files**: `ClaudeWatch/Models/HistoryItem.swift` (new)

### Task 5.2: Add History Storage to WatchService
```swift
@Published private(set) var history: [HistoryItem] = []
private let maxHistoryItems = 50

func recordAction(_ action: PendingAction, outcome: HistoryItem.Outcome, auto: Bool) {
    let item = HistoryItem(
        id: UUID(),
        action: action.type,
        file: action.filePath?.split(separator: "/").last.map(String.init) ?? action.title,
        outcome: outcome,
        wasAutoApproved: auto,
        timestamp: Date()
    )
    history.insert(item, at: 0)
    if history.count > maxHistoryItems {
        history.removeLast()
    }
}
```

**Files**: `ClaudeWatch/Services/WatchService.swift`

### Task 5.3: Create HistoryView
```swift
struct HistoryView: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        List(service.history) { item in
            HistoryRow(item: item)
        }
        .navigationTitle("History")
    }
}

struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(item.outcome == .approved ? Claude.success : Claude.danger)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading) {
                HStack {
                    Text(item.file)
                        .font(.claudeMono)
                        .lineLimit(1)
                    if item.wasAutoApproved {
                        Text("auto")
                            .font(.system(size: 8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Claude.surface2)
                            .clipShape(Capsule())
                    }
                }
                Text(item.outcome.rawValue.capitalized)
                    .font(.claudeCaption)
                    .foregroundColor(item.outcome == .approved ? Claude.success : Claude.danger)
            }

            Spacer()

            Text(item.timestamp.formatted(.relative(presentation: .numeric)))
                .font(.system(size: 9))
                .foregroundColor(Claude.textTertiary)
        }
    }
}
```

**Files**: `ClaudeWatch/Views/HistoryView.swift` (new)

### Task 5.4: Add History Navigation
Add "History" option to settings or main view.

**Files**: `ClaudeWatch/Views/SheetViews.swift`
**Success Criteria**: History accessible from settings

---

## Phase 6: Selective Queue (Sam's P3 Need)

**Goal**: Checkbox selection for batch approve/reject.

### Task 6.1: Add Selection State
```swift
@State private var selectedActions: Set<String> = []

var allSelected: Bool {
    selectedActions.count == service.state.pendingActions.count
}

func toggleSelection(_ id: String) {
    if selectedActions.contains(id) {
        selectedActions.remove(id)
    } else {
        selectedActions.insert(id)
    }
}
```

### Task 6.2: Create SelectableActionRow
```swift
struct SelectableActionRow: View {
    let action: PendingAction
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? Claude.orange : Claude.textSecondary)

                Image(systemName: action.icon)
                    .foregroundColor(action.isDangerous ? Claude.danger : Claude.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.claudeCaption)
                        .lineLimit(1)
                    Text(action.type)
                        .font(.system(size: 9))
                        .foregroundColor(action.isDangerous ? Claude.danger : Claude.textTertiary)
                }
            }
            .padding(8)
            .background(action.isDangerous ? Claude.dangerBackground : Claude.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
```

### Task 6.3: Create SelectiveQueueView
```swift
struct SelectiveQueueView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var selectedActions: Set<String> = []

    var body: some View {
        VStack(spacing: 8) {
            // Header
            HStack {
                Text("\(service.state.pendingActions.count) Pending")
                    .font(.claudeCaption)
                Spacer()
                Text("\(selectedActions.count) selected")
                    .font(.claudeCaption)
                    .foregroundColor(Claude.info)
            }

            // List
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(service.state.pendingActions) { action in
                        SelectableActionRow(
                            action: action,
                            isSelected: selectedActions.contains(action.id),
                            onToggle: { toggleSelection(action.id) }
                        )
                    }
                }
            }

            // Batch buttons
            HStack(spacing: 8) {
                Button("Reject (\(unselectedCount))") {
                    rejectUnselected()
                }
                .buttonStyle(.glassCompat)

                Button("Approve (\(selectedActions.count))") {
                    approveSelected()
                }
                .buttonStyle(.glassProminentCompat)
            }
        }
        .padding()
    }

    // ... helper methods
}
```

**Files**: `ClaudeWatch/Views/SelectiveQueueView.swift` (new)

---

## Implementation Order

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: Token Alignment                                       │
│  ✓ Foundation for all other work                                │
│  Files: Claude.swift                                            │
│  Dependency: None                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: Danger Pattern (P1)                                   │
│  ✓ Sam's critical need for risk visibility                      │
│  Files: ApprovalRequest.swift, ActionViews.swift                │
│  Dependency: Phase 1 (dangerBackground token)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3: Progress + ETA (P2)                                   │
│  ✓ Jordan's monitoring need                                     │
│  Files: TaskProgress.swift, WatchService.swift, MainView.swift  │
│  Dependency: None (parallel with Phase 2)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 4: Expanded Detail (P2)                                  │
│  ✓ Sam's detail view need                                       │
│  Files: ActionDetailView.swift, ActionViews.swift               │
│  Dependency: Phase 2 (danger indicators in detail)              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 5: Session History (P3)                                  │
│  ✓ Sam's audit need                                             │
│  Files: HistoryItem.swift, HistoryView.swift, WatchService.swift│
│  Dependency: None (parallel with Phase 4)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 6: Selective Queue (P3)                                  │
│  ✓ Sam's batch control need                                     │
│  Files: SelectiveQueueView.swift                                │
│  Dependency: Phase 2 (danger indicators in rows)                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Agentic Execution Notes

### For AI Agents

Each phase can be executed with these commands:

```bash
# Phase 1
/create-view Claude.swift updates

# Phase 2
/create-view DangerIndicator component
/watchos-testing ApprovalRequest danger detection

# Phase 3
/create-view ETADisplay component
/watchos-testing TaskProgress ETA calculation

# Phase 4
/create-view ActionDetailView

# Phase 5
/create-view HistoryView

# Phase 6
/create-view SelectiveQueueView
```

### Success Criteria Checklist

- [ ] All tokens in Claude.swift (no inline colors/fonts)
- [ ] Dangerous actions show red border
- [ ] ETA displays during long tasks
- [ ] Long-press opens detail view
- [ ] History accessible from settings
- [ ] Batch selection works for queue

### Testing Strategy

1. **Unit Tests**: `DesignSystemTests.swift` for token consistency
2. **Preview Tests**: Each component has working `#Preview`
3. **Integration**: Manual test on Simulator + physical watch

---

## Out of Scope (Deferred)

| Feature | Reason | Future Location |
|---------|--------|-----------------|
| iOS Companion App | Requires separate target | `.claude/scope-creep/IOS_COMPANION_APP.md` |
| Complications overhaul | Already functional | Future enhancement |
| Voice input redesign | Works currently | Future enhancement |

---

## References

- [React Prototype](../../../Design/ClaudeWatchDesignSystemComplete.swift) - Full design vision
- [Component Library](../context/COMPONENT_LIBRARY.md) - Detailed specs
- [User Personas](../context/USER_PERSONAS.md) - Alex, Jordan, Sam, Riley needs
- [Anthropic Brand Guidelines](https://www.anthropic.com/brand) - Official colors

---

*Plan created 2026-01-20. Execute phases in order for best results.*
