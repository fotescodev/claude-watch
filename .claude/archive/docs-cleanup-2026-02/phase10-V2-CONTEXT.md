# Phase 10 Context: V2 Redesign + watchOS 26 Features

> Decisions captured: 2026-01-23
> Participants: dfotesco
> Source: Design spec v2.0 feedback + discussion

## Executive Summary

Phase 10 implements Claude Watch V2 with a streamlined 7-state architecture, hybrid colors, and all watchOS 26 features for eyes-free approval (Controls API, Siri, Action Button, Double Tap).

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Colors** | Hybrid | Anthropic accent (logo, headers), Apple semantic (success/error) |
| **Architecture** | 7-State | Simpler than Phase 8's 12+ states, keeps critical flows |
| **Typography** | System fonts | SF Pro - native rendering, accessibility |
| **watchOS 26** | All features | Controls, Siri, Action Button, RelevanceKit, Double Tap |

---

## Flows Kept vs Dropped

### From Phase 8 - KEPT

| Flow | Why Keep |
|------|----------|
| **F16: Context Warning** | Critical alert when context > 75%, easy to implement |
| **F18: Question Response** | Binary: accept recommended OR handle on Mac |
| **F21: Background Task** | Just a notification, trivial |

### From Phase 8 - DROPPED

| Flow | Why Drop |
|------|----------|
| F15: Session Resume | Re-run `npx cc-watch` is 5 seconds |
| F17: Quick Undo | Too dangerous for watch, use Mac |
| F19: Sub-Agent Monitor | Too complex for glanceable UI |
| F20: Todo Progress | Read-only on tiny screen isn't useful |

---

## Color Strategy (Hybrid)

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

---

## Architecture: 7-State Model

```
┌────────────────────────────────────────────────────────────────┐
│                    CLAUDE WATCH STATES                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│   CORE STATES (from design spec v2.0):                         │
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

## watchOS 26 Features

### Controls API (Critical - Eyes-Free Approval)

| Control | Kind | Action |
|---------|------|--------|
| Approve Next | Button | Approves next pending |
| Reject Next | Button | Rejects next pending |
| Pause/Resume | Toggle | Toggle session state |
| Session Status | Button | Opens app |

### App Intents & Siri

| Voice Command | Intent |
|---------------|--------|
| "Hey Siri, approve Claude" | ApproveClaudeIntent |
| "Hey Siri, reject Claude's request" | RejectClaudeIntent |
| "Hey Siri, what's Claude doing?" | ClaudeStatusIntent |
| "Hey Siri, pause Claude" | PauseClaudeIntent |
| "Hey Siri, resume Claude" | ResumeClaudeIntent |

### Action Button (Ultra)

| State | Single Press | Long Press |
|-------|-------------|------------|
| Idle | Open app | Open app |
| Working | Pause | Quick Actions |
| Needs Approval | **Approve** | Full approval screen |
| Paused | Resume | Quick Actions |

### Double Tap Gesture

| State | Double Tap Action |
|-------|-------------------|
| Working | Pause |
| Approval (normal) | **Approve** |
| Approval (destructive) | Cancel (safety) |
| Task Outcome | Dismiss |
| Paused | Resume |

### RelevanceKit & Smart Stack

Surface in Smart Stack when:
- Claude session is active
- During work hours (learned)
- User starts walking
- At work location (learned)

---

## File Structure

```
ClaudeWatch/
├── App/
│   ├── ClaudeWatchApp.swift
│   └── ContentView.swift
├── Screens/                          # RENAMED from Views/
│   ├── UnpairedView.swift
│   ├── PairingCodeView.swift
│   ├── ConnectedIdleView.swift
│   ├── WorkingView.swift            # NEW
│   ├── ApprovalView.swift
│   ├── ApprovalQueueView.swift      # NEW
│   ├── QuestionResponseView.swift   # NEW (F18)
│   ├── ContextWarningView.swift     # NEW (F16)
│   ├── TaskOutcomeView.swift        # NEW
│   ├── PausedView.swift             # NEW
│   ├── ErrorView.swift
│   ├── SettingsView.swift
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
│   ├── ClaudeComplication.swift
│   ├── ClaudeSmartStackWidget.swift
│   └── ClaudeRelevanceProvider.swift
├── DesignSystem/
│   └── Claude.swift                 # UPDATE
├── Services/
│   ├── ClaudeSessionManager.swift   # RENAME from WatchService
│   ├── CloudflareAPI.swift          # Extract
│   ├── NotificationManager.swift    # Extract
│   ├── OfflineQueue.swift           # NEW
│   └── ReconnectionManager.swift    # NEW
└── Models/
    ├── ClaudeState.swift            # NEW
    ├── Approval.swift
    ├── TaskProgress.swift           # NEW
    └── SessionOutcome.swift         # NEW
```

---

## Implementation Phases

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

## Event Types (Simplified)

Only 3 new events (dropped 8 from original Phase 8):

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
}
```

---

## Success Criteria

- [ ] Controls API: Approve from Control Center works
- [ ] Siri: "Hey Siri, approve Claude" works
- [ ] Double Tap: Approves in Approval state
- [ ] Action Button: Approves on Ultra
- [ ] Question Response: Binary accept/reject/voice
- [ ] Context Warning: Shows at 75%/85%/95% thresholds
- [ ] Approval Queue: Handles 2+ pending
- [ ] No regressions in existing functionality

---

## Reference Documents

- `/Users/dfotesco/.claude/plans/pure-churning-moore.md` - Full implementation plan
- `/Users/dfotesco/claude-watch/claude-watch/docs/USER_JOURNEYS.md` - Design spec v2.0
- `.claude/plans/phase8-CONTEXT.md` - Original Phase 8 (superseded)

---

*Created by /discuss-phase skill*
