# Claude Watch V2 — Revised Implementation Plan

> **Goal:** Implement Claude Watch V2 with watchOS 26 features, hybrid colors, and streamlined architecture
>
> **Status:** PLANNING (not yet implementing)
> **Updated:** Based on design spec v2.0 feedback

---

## 1. Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Colors** | Hybrid | Anthropic accent (logo, headers), Apple semantic (success/error) |
| **Architecture** | 7-State | Simpler than Phase 8, keeps critical flows |
| **Typography** | System fonts | SF Pro - native rendering, accessibility |
| **watchOS 26** | All features | Controls, Siri, Action Button, RelevanceKit, Double Tap |

### Flows Kept vs Dropped

| Flow | Status | Reason |
|------|--------|--------|
| F16: Context Warning | **KEEP** | Critical alert, easy to implement |
| F18: Question Response | **KEEP** | Binary: accept recommended OR handle on Mac |
| F21: Background Task | **KEEP** | Just a notification |
| F15: Session Resume | DROP | Re-run `npx cc-watch` is 5 seconds |
| F17: Quick Undo | DROP | Too dangerous for watch |
| F19: Sub-Agent Monitor | DROP | Too complex for glanceable UI |
| F20: Todo Progress | DROP | Read-only on tiny screen isn't useful |

---

## 2. Color Strategy (Hybrid)

### Anthropic Accent (Brand Identity)
```swift
// Logo, headers, primary accent
static let anthropicOrange = Color(hex: "#d97757")  // Primary brand
static let anthropicDark = Color(hex: "#141413")    // Elevated backgrounds
static let anthropicLight = Color(hex: "#faf9f5")   // Text on dark
```

### Apple Semantic (Native Feel)
```swift
// States - use system colors for accessibility
static let success = Color.green      // #34C759 - approve, checkmarks
static let warning = Color.orange     // #FF9500 - approval needed
static let danger = Color.red         // #FF3B30 - reject, errors
static let info = Color.blue          // #007AFF - working state
static let idle = Color.gray          // #8E8E93 - idle state
```

### The 5 State Colors
| State | Color | Hex | Usage |
|-------|-------|-----|-------|
| Idle | Gray | `#8E8E93` | Status dot, background |
| Working | Blue | `#007AFF` | Spinner, progress |
| Needs Approval | Orange | `#FF9500` | Alert badge, buttons |
| Success | Green | `#34C759` | Checkmark, completion |
| Error | Red | `#FF3B30` | X mark, failures |

---

## 3. Architecture: 7-State Model

```
┌────────────────────────────────────────────────────────────────┐
│                    CLAUDE WATCH STATES                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│   CORE STATES (from feedback doc):                             │
│   ┌───────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────┐ │
│   │ Idle  │→ │ Working │→ │ Approval │→ │ Success │  │Error │ │
│   │ Gray  │  │  Blue   │  │  Orange  │  │  Green  │  │ Red  │ │
│   └───────┘  └─────────┘  └──────────┘  └─────────┘  └──────┘ │
│                    ↓           ↓                               │
│   KEPT V2 STATES:  │           │                               │
│                    ↓           ↓                               │
│   ┌────────────────────┐  ┌────────────────────┐              │
│   │  Context Warning   │  │  Question (binary) │              │
│   │     (F16)          │  │      (F18)         │              │
│   └────────────────────┘  └────────────────────┘              │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Screen List (11 total)

| # | Screen | State | Entry |
|---|--------|-------|-------|
| 1 | Unpaired | — | Fresh launch |
| 2 | Pairing Code | — | Tap "Pair with Code" |
| 3 | Connected Idle | Idle | Pairing success |
| 4 | Working | Working | Task begins |
| 5 | Approval Request | Approval | PreToolUse hook |
| 6 | Approval Queue | Approval | 2+ pending |
| 7 | Question Response | Approval | AskUserQuestion (binary) |
| 8 | Context Warning | Warning | Context > 75% |
| 9 | Task Outcome | Success | Task completes |
| 10 | Paused | — | User taps pause |
| 11 | Error | Error | Various failures |

---

## 4. watchOS 26 Features (ALL)

### 4.1 Controls API (Critical)

**Files to create:**
- `ClaudeWatch/Controls/ApproveControl.swift`
- `ClaudeWatch/Controls/RejectControl.swift`
- `ClaudeWatch/Controls/PauseResumeControl.swift`
- `ClaudeWatch/Controls/StatusControl.swift`

| Control | Kind | Action |
|---------|------|--------|
| Approve Next | Button | Approves next pending |
| Reject Next | Button | Rejects next pending |
| Pause/Resume | Toggle | Toggle session state |
| Session Status | Button | Opens app |

### 4.2 App Intents & Siri

**Files to create:**
- `ClaudeWatch/Intents/ApproveClaudeIntent.swift`
- `ClaudeWatch/Intents/RejectClaudeIntent.swift`
- `ClaudeWatch/Intents/ClaudeStatusIntent.swift`
- `ClaudeWatch/Intents/PauseClaudeIntent.swift`
- `ClaudeWatch/Intents/ResumeClaudeIntent.swift`
- `ClaudeWatch/Intents/ClaudeShortcuts.swift`

| Voice Command | Intent |
|---------------|--------|
| "Hey Siri, approve Claude" | ApproveClaudeIntent |
| "Hey Siri, reject Claude's request" | RejectClaudeIntent |
| "Hey Siri, what's Claude doing?" | ClaudeStatusIntent |
| "Hey Siri, pause Claude" | PauseClaudeIntent |
| "Hey Siri, resume Claude" | ResumeClaudeIntent |

### 4.3 Action Button (Ultra)

| State | Single Press | Long Press |
|-------|-------------|------------|
| Idle | Open app | Open app |
| Working | Pause | Quick Actions |
| Needs Approval | **Approve** | Full approval screen |
| Paused | Resume | Quick Actions |

### 4.4 RelevanceKit & Smart Stack

**Files to create:**
- `ClaudeWatch/Widgets/ClaudeRelevanceProvider.swift`
- `ClaudeWatch/Widgets/ClaudeSmartStackWidget.swift`

Surface in Smart Stack when:
- Claude session is active
- During work hours (learned)
- User starts walking
- At work location (learned)

### 4.5 Double Tap Gesture

| State | Double Tap Action |
|-------|-------------------|
| Working | Pause |
| Approval (normal) | **Approve** |
| Approval (destructive) | Cancel (safety) |
| Task Outcome | Dismiss |
| Paused | Resume |

---

## 5. File Structure (Revised)

```
ClaudeWatch/
├── App/
│   ├── ClaudeWatchApp.swift
│   └── ContentView.swift
├── Screens/                          # RENAMED from Views/
│   ├── UnpairedView.swift           # Existing, update
│   ├── PairingCodeView.swift        # Existing (PairingView.swift)
│   ├── ConnectedIdleView.swift      # Existing (MainView.swift)
│   ├── WorkingView.swift            # NEW
│   ├── ApprovalView.swift           # Existing (ActionViews.swift)
│   ├── ApprovalQueueView.swift      # NEW
│   ├── QuestionResponseView.swift   # NEW (F18, binary)
│   ├── ContextWarningView.swift     # NEW (F16)
│   ├── TaskOutcomeView.swift        # NEW
│   ├── PausedView.swift             # NEW
│   ├── ErrorView.swift              # Existing (StateViews.swift)
│   ├── SettingsView.swift           # Existing (SheetViews.swift)
│   └── QuickActionsView.swift       # NEW
├── Controls/                         # NEW DIRECTORY
│   ├── ApproveControl.swift
│   ├── RejectControl.swift
│   ├── PauseResumeControl.swift
│   └── StatusControl.swift
├── Intents/                          # NEW DIRECTORY
│   ├── ApproveClaudeIntent.swift
│   ├── RejectClaudeIntent.swift
│   ├── ClaudeStatusIntent.swift
│   ├── PauseClaudeIntent.swift
│   ├── ResumeClaudeIntent.swift
│   └── ClaudeShortcuts.swift
├── Widgets/                          # NEW DIRECTORY
│   ├── ClaudeComplication.swift     # Move from Complications/
│   ├── ClaudeSmartStackWidget.swift
│   └── ClaudeRelevanceProvider.swift
├── DesignSystem/
│   └── Claude.swift                 # UPDATE with hybrid colors
├── Services/
│   ├── ClaudeSessionManager.swift   # RENAME/REFACTOR WatchService
│   ├── CloudflareAPI.swift          # Extract from WatchService
│   ├── NotificationManager.swift    # Extract from App
│   ├── OfflineQueue.swift           # NEW
│   └── ReconnectionManager.swift    # NEW
└── Models/
    ├── ClaudeState.swift            # NEW (5 states enum)
    ├── Approval.swift               # Existing (ApprovalRequest)
    ├── TaskProgress.swift           # NEW
    └── SessionOutcome.swift         # NEW
```

---

## 6. Implementation Phases

### Phase A: Design System Update
**Effort:** Low | **Priority:** P0

- [ ] Update `Claude.swift` with hybrid colors
- [ ] Add `ClaudeState` enum (idle/working/approval/success/error)
- [ ] Add state color mapping
- [ ] Keep Liquid Glass modifiers (already exist)

### Phase B: Core Screens Refactor
**Effort:** Medium | **Priority:** P0

- [ ] Rename/reorganize into `Screens/` directory
- [ ] Create `WorkingView.swift` (task progress)
- [ ] Create `TaskOutcomeView.swift` (success summary)
- [ ] Create `PausedView.swift` (pause state)
- [ ] Create `QuickActionsView.swift` (swipe menu)

### Phase C: V2 Screens (Kept Flows)
**Effort:** Medium | **Priority:** P1

- [ ] Create `QuestionResponseView.swift` (F18 binary)
- [ ] Create `ContextWarningView.swift` (F16)
- [ ] Create `ApprovalQueueView.swift` (multiple pending)
- [ ] Add `QUESTION_ASKED`, `CONTEXT_WARNING` event handlers

### Phase D: Controls API (watchOS 26)
**Effort:** Medium | **Priority:** P0 (Critical)

- [ ] Create `Controls/` directory
- [ ] Implement `ApproveControl.swift`
- [ ] Implement `RejectControl.swift`
- [ ] Implement `PauseResumeControl.swift`
- [ ] Implement `StatusControl.swift`
- [ ] Register controls in app

### Phase E: App Intents & Siri
**Effort:** Medium | **Priority:** P0 (Critical)

- [ ] Create `Intents/` directory
- [ ] Implement 5 intents
- [ ] Create `ClaudeShortcuts.swift` for discoverable phrases
- [ ] Test Siri integration

### Phase F: RelevanceKit & Widgets
**Effort:** Low | **Priority:** P1

- [ ] Create `ClaudeRelevanceProvider.swift`
- [ ] Create `ClaudeSmartStackWidget.swift`
- [ ] Move complications to `Widgets/`
- [ ] Configure relevance contexts

### Phase G: Double Tap & Action Button
**Effort:** Low | **Priority:** P1

- [ ] Add `.handGestureShortcut(.primaryAction)` to approval
- [ ] Document Action Button configuration

---

## 7. Event Types (Simplified)

Only 3 new event types needed (dropped 8):

```swift
enum WatchEvent: String, Codable {
    // Existing
    case toolApprovalRequest = "TOOL_APPROVAL_REQUEST"
    case toolApprovalResponse = "TOOL_APPROVAL_RESPONSE"
    case sessionStart = "SESSION_START"
    case sessionEnd = "SESSION_END"

    // V2 Kept (3 only)
    case questionAsked = "QUESTION_ASKED"      // F18
    case questionAnswered = "QUESTION_ANSWERED" // F18
    case contextWarning = "CONTEXT_WARNING"     // F16
    // F21 Background Task uses existing notification system
}
```

**Dropped events:**
- ~~TODO_UPDATE~~ (F20 dropped)
- ~~SUBAGENT_*~~ (F19 dropped)
- ~~SESSION_LIST~~ (F15 dropped)
- ~~SESSION_RESUMED~~ (F15 dropped)
- ~~QUICK_UNDO_AVAILABLE~~ (F17 dropped)

---

## 8. Verification

### Build
```bash
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

### Test Checklist

**Controls API:**
- [ ] Approve Control appears in Control Center
- [ ] Tapping Approve Control approves next pending
- [ ] Reject Control works
- [ ] Pause/Resume toggle works

**Siri:**
- [ ] "Hey Siri, approve Claude" works
- [ ] "Hey Siri, what's Claude doing?" works
- [ ] Shortcuts appear in Shortcuts app

**Double Tap:**
- [ ] Double Tap approves in Approval state
- [ ] Double Tap pauses in Working state

**V2 Screens:**
- [ ] Question response shows binary options
- [ ] Context warning appears at 75%/85%/95%
- [ ] Approval queue handles 2+ pending

---

## 9. Summary

### What We're Building

| Category | Items |
|----------|-------|
| **New directories** | Controls/, Intents/, Widgets/ |
| **New screens** | 5 (Working, Outcome, Paused, QuickActions, ApprovalQueue) |
| **V2 screens** | 2 (QuestionResponse, ContextWarning) |
| **Controls** | 4 (Approve, Reject, PauseResume, Status) |
| **Intents** | 5 + Shortcuts provider |
| **New events** | 3 (questionAsked, questionAnswered, contextWarning) |

### What We're NOT Building

| Dropped | Reason |
|---------|--------|
| SessionListView (F15) | Re-run `npx cc-watch` instead |
| QuickUndoView (F17) | Too dangerous for watch |
| SubAgentRow (F19) | Too complex for glanceable |
| TodoProgressView (F20) | Tiny screen, read-only |
| 8 event types | Flows dropped |

### Priority Order

1. **P0:** Design System + Controls API + Siri (eyes-free approval)
2. **P1:** Core Screens + V2 Screens + RelevanceKit
3. **P2:** Polish, accessibility, animations
