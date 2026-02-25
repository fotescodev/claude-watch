# watchOS Complications & Ambient Intelligence -- Design Spec

> Originated 2026-02-20 (4-agent brainstorm).
> Revised 2026-02-24 -- replaced gamification rings with awareness-focused gauge model.
> Revised 2026-02-25 -- deep dive: verified against SwiftUI implementation + watchOS 26 patterns.

---

## Implementation Status Key

| Marker | Meaning |
|--------|---------|
| SHIPPED | Code exists, tested, deployed |
| IN PROGRESS | Partial implementation exists |
| NOT STARTED | Design only, no code |

---

## 1. Design System Foundation

All complications reference the canonical design tokens in `ClaudeWatch/DesignSystem/Claude.swift`.
No raw hex values in view code. No inline colors. No approximations.

### 1.1 State Color Tokens

Colors are resolved through `ClaudeState.color`, which delegates to `Claude.*` tokens.
The first five states use **Apple semantic `Color.*` values** (adaptive across display modes).
The last three use **custom hex** values.

| Token | SwiftUI Value | Hex (dark mode approx) | Usage |
|-------|--------------|------------------------|-------|
| `Claude.idle` | `Color.gray` | ~#8E8E93 | Idle gauge tint |
| `Claude.info` | `Color.blue` | ~#007AFF | Working gauge tint |
| `Claude.warning` | `Color.orange` | ~#FF9500 | Approval/pending gauge tint, pending count text |
| `Claude.success` | `Color.green` | ~#34C759 | Success gauge tint |
| `Claude.destructive` | `Color.red` | ~#FF3B30 | Error gauge tint |
| `Claude.plan` | `Color(red: 0.369, green: 0.361, blue: 0.902)` | #5E5CE6 | Plan mode gauge tint |
| `Claude.context` | `Color(red: 1.0, green: 0.839, blue: 0.039)` | #FFD60A | Context warning gauge tint |
| `Claude.question` | `Color(red: 0.749, green: 0.353, blue: 0.949)` | #BF5AF2 | Question gauge tint |

Ref: `Claude.swift` lines 24-40, `ClaudeState.swift` lines 69-80

### 1.2 Brand Colors (Not Used in Complications)

| Token | Hex | Usage |
|-------|-----|-------|
| `Claude.anthropicOrange` | #d97757 | Logo, headers, primary accent |
| `Claude.anthropicDark` | #141413 | Elevated surfaces |
| `Claude.anthropicLight` | #faf9f5 | Text on dark backgrounds |

These are reserved for the app UI. Complications use state colors exclusively.

### 1.3 Typography Tokens Relevant to Complications

The design system provides named `Font` tokens. Complications currently use raw
`.system(size:weight:design:)` constructors -- these should be migrated to named tokens
where possible for consistency.

| Current (raw) | Nearest Named Token | Context |
|---------------|-------------------|---------|
| `.system(size: 14, weight: .bold, design: .monospaced)` | -- (no exact match) | Circular center: pending count |
| `.system(size: 12, weight: .bold, design: .monospaced)` | -- (no exact match) | Circular center: progress % |
| `.system(size: 10, weight: .semibold, design: .monospaced)` | `Font.claudeMonoBadge` | Circular center: state label |
| `.system(size: 16, weight: .bold, design: .monospaced)` | -- (no exact match) | Corner: pending count |
| `.system(size: 12, weight: .semibold, design: .monospaced)` | -- (no exact match) | Corner: state label |
| `.system(size: 12, design: .monospaced)` | `Font.claudeMonoSmall` | Inline text |

Note: WidgetKit complications have strict size constraints. Named tokens may not map
perfectly to complication needs. Custom sizes are acceptable when dictated by the widget
family's rendering bounds.

### 1.4 Surface & Fill Tokens

Available for future rectangular complication and interactive widget backgrounds:

| Token | Value | Purpose |
|-------|-------|---------|
| `Claude.background` | `Color.black` | Primary background (OLED) |
| `Claude.surface1` | #1C1C1E | Elevated surface level 1 |
| `Claude.surface2` | #2C2C2E | Elevated surface level 2 |
| `Claude.fillSubtle` | white 3% | Background tints |
| `Claude.fillCard` | white 7% | Card backgrounds |
| `Claude.fillInteractive` | white 12% | Tappable surfaces |

### 1.5 Layout Constants

| Token | Value | Relevance |
|-------|-------|-----------|
| `Claude.Spacing.xs` | 4pt | Tight spacing within complications |
| `Claude.Spacing.sm` | 8pt | Standard spacing |
| `Claude.Spacing.md` | 12pt | Card padding |
| `Claude.Radius.small` | 8pt | Small corner radius |
| `Claude.Radius.medium` | 12pt | Standard corner radius |

---

## 2. Awareness Gauge Complications

Single gauge driven by `ClaudeState` (8 states). The complication answers one question:
**"What is happening right now?"** -- no rings, no streaks, no engagement metrics.

### 2.1 Design Principle

Gauge ring = task progress, tinted by `ClaudeState.color`. Center content priority:
1. Pending count (if > 0) -- `Claude.warning` color
2. Progress percentage (if working with progress > 0)
3. State short label (IDLE/WORK/WAIT/DONE/ERR/PLAN/CTX/ASK)

### 2.2 State Short Labels

Defined as `ClaudeState.shortLabel` computed property.

| State | Label | Color Token | SF Symbol (`ClaudeState.icon`) |
|-------|-------|-------------|-------------------------------|
| idle | IDLE | `Claude.idle` | `circle` |
| working | WORK | `Claude.info` | `circle.dotted.circle` |
| approval | WAIT | `Claude.warning` | `hand.raised.fill` |
| success | DONE | `Claude.success` | `checkmark.circle.fill` |
| error | ERR | `Claude.destructive` | `xmark.circle.fill` |
| plan | PLAN | `Claude.plan` | `pencil.and.outline` |
| context | CTX | `Claude.context` | `exclamationmark.triangle.fill` |
| question | ASK | `Claude.question` | `questionmark.circle.fill` |

Ref: `ClaudeState.swift` lines 27-38 (shortLabel), 55-66 (icon)

### 2.3 State Derivation Pipeline

```
WatchService.updateComplicationData()
    |
    v
ClaudeState.derive(pendingCount:sessionStatus:hasProgress:)
    |
    +-- pendingCount > 0  -->  .approval
    +-- hasProgress + completed  -->  .success
    +-- hasProgress + not completed  -->  .working
    +-- else  -->  ClaudeState(from: sessionStatus)
                       |
                       +-- .idle -> .idle
                       +-- .running -> .working
                       +-- .waiting -> .approval
                       +-- .completed -> .success
                       +-- .failed -> .error
```

Note: `.plan`, `.context`, and `.question` states are not derived from `SessionStatus`.
They require explicit transitions from the server-side protocol. Currently only 5 of 8
states are reachable via the derivation pipeline.

Ref: `ClaudeState.swift` lines 110-118, `SessionStatus.swift`

### 2.4 Reusable State Components

These exist in `ClaudeState.swift` but are **not currently used** in complications
(they're used in app views). Future rectangular complications could leverage them.

| Component | Purpose | Availability |
|-----------|---------|-------------|
| `ClaudeStateDot(state:size:)` | Colored circle indicator, 8pt default | App views |
| `ClaudeStateIcon(state:size:)` | SF Symbol with state color, 24pt default, `.symbolEffect(.replace)` transition | App views |

### 2.5 Complication Families -- SHIPPED

| Family | SwiftUI Implementation | File |
|--------|----------------------|------|
| `accessoryCircular` | `Gauge(value:).gaugeStyle(.accessoryCircularCapacity).tint(stateColor.opacity(dimFactor))` | `ComplicationViews.swift` |
| `accessoryCorner` | Body = pending count or state label. `.widgetLabel { Gauge(value:).gaugeStyle(.accessoryLinearCapacity) }` | `ComplicationViews.swift` |
| `accessoryInline` | `Text(displayText).font(.system(size: 12, design: .monospaced))` | `ComplicationViews.swift` |
| `accessoryRectangular` | NOT STARTED -- design below | -- |

### 2.6 Rectangular Complication Design -- NOT STARTED (P1)

Proposed layout for `accessoryRectangular` (most information-dense family):

```
+-------------------------------------------+
| [StateDot 6pt] WORK  auth-service    0:45 |
| [===========60%=======                   ] |
| 2 pending                          opus-4 |
+-------------------------------------------+
```

Row 1: State dot + short label + task name (truncated) + elapsed time
Row 2: Linear progress gauge, tinted by state color
Row 3: Pending count (if > 0) or session stats + model name

SwiftUI sketch:

```swift
struct RectangularWidgetView: View {
    let entry: RemmyEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    private var dimFactor: Double { isLuminanceReduced ? 0.5 : 1.0 }
    private var stateColor: Color { entry.sessionState.color }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1: State + task name
            HStack(spacing: 4) {
                Circle()
                    .fill(stateColor.opacity(dimFactor))
                    .frame(width: 6, height: 6)
                Text(entry.sessionState.shortLabel)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(stateColor.opacity(dimFactor))
                Text(entry.taskName.isEmpty ? "" : entry.taskName)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(dimFactor))
                    .lineLimit(1)
                Spacer()
            }
            // Row 2: Progress gauge
            Gauge(value: entry.progress) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(stateColor.opacity(dimFactor))
            // Row 3: Pending + model
            HStack {
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount) pending")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Claude.warning.opacity(dimFactor))
                } else {
                    Text(entry.sessionState.displayName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(dimFactor))
                }
                Spacer()
                Text(entry.model)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(dimFactor))
            }
        }
    }
}
```

### 2.7 Smart Stack Relevance -- SHIPPED

Dynamic `TimelineEntryRelevance` scoring surfaces the widget when the user needs to act.

| Condition | Score | Duration | Rationale |
|-----------|-------|----------|-----------|
| `pendingCount > 0` | 1.0 | 5 min | User must respond |
| `.error` or `.context` | 0.8 | 2 min | Something needs attention |
| `.working` | 0.6 | 1 min | Active session awareness |
| All other states | 0.1 | 15 min | Low priority background |

Ref: `ComplicationViews.swift` lines 17-32 (`RemmyEntry.relevance`)

### 2.8 Widget Data Pipeline

```
WatchService.updateComplicationData()
    |
    +-- Derives ClaudeState via ClaudeState.derive()
    +-- Creates ComplicationSnapshot (Equatable, for change detection)
    +-- Writes to shared UserDefaults ("group.com.remmy"):
    |     pendingCount: Int
    |     progress: Double
    |     taskName: String
    |     model: String
    |     isConnected: Bool
    |     session_state: String (ClaudeState.rawValue)
    |
    +-- Guards: snapshot != lastComplicationState (skip if unchanged)
    +-- Guards: 30s throttle (complicationUpdateMinInterval)
    |
    +-- WidgetReloadCoordinator.shared.requestReload()
              |
              +-- 5s trailing-edge debounce
              +-- WidgetCenter.shared.reloadTimelines(ofKind: "RemmyWidget")
```

Read path: `RemmyProvider.currentEntry()` reads from the same shared UserDefaults.

Ref: `WatchService.swift` lines 1941-1977, `WidgetReloadCoordinator.swift`

### 2.9 AppIntentConfiguration -- SHIPPED

Migrated from `StaticConfiguration` to `AppIntentConfiguration` with
`RemmyWidgetConfigIntent`. Interactive widget buttons can be added without migration.

```swift
AppIntentConfiguration(
    kind: "RemmyWidget",
    intent: RemmyWidgetConfigIntent.self,
    provider: RemmyProvider()
) { entry in
    RemmyWidgetEntryView(entry: entry)
        .containerBackground(.black, for: .widget)
}
```

Ref: `ComplicationViews.swift` lines 224-240

### 2.10 Always-On Display -- SHIPPED

All complication views respect `isLuminanceReduced` via `dimFactor` pattern:

```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced
private var dimFactor: Double { isLuminanceReduced ? 0.5 : 1.0 }

// Applied to all color references:
.tint(stateColor.opacity(dimFactor))
.foregroundStyle(color.opacity(dimFactor))
```

- Active: full opacity (1.0)
- AOD: dimmed (0.5) -- reduces OLED burn-in risk, meets Apple HIG
- Gauge tint dims automatically with the multiplier

### 2.11 Timeline Refresh Strategy -- SHIPPED

`RemmyProvider.timeline()` uses dynamic refresh intervals based on activity level:

| Activity Level | Refresh Interval | Rationale |
|---------------|-----------------|-----------|
| Pending approvals (`pendingCount > 0`) | 30s | Needs frequent updates |
| Task in progress (`0 < progress < 1.0`) | 60s | Moderate refresh |
| Idle (everything else) | 900s (15 min) | Conserve battery |

---

## 3. watchOS 26 Liquid Glass

### 3.1 Existing Liquid Glass Helpers in Claude.swift

| Helper | Signature | Purpose |
|--------|-----------|---------|
| `.glassEffectCompat(_:)` | `View -> View` | Standard `.glassEffect(.regular)` with `.ultraThinMaterial` fallback |
| `.glassEffectInteractive(_:)` | `View -> View` | Interactive `.glassEffect(.regular.interactive())` with material fallback |
| `.liquidGlassCard()` | `View -> View` | Shorthand: `glassEffectCompat(RoundedRectangle(cornerRadius: .large))` |
| `.liquidGlassCardInteractive()` | `View -> View` | Shorthand: interactive variant |
| `.glassEffectIDCompat(_:in:)` | `View -> View` | Morphing transitions with `matchedGeometryEffect` fallback |
| `GlassButtonStyleCompat` | `ButtonStyle` | Glass button with material fallback |
| `GlassProminentButtonStyleCompat` | `ButtonStyle` | Prominent glass button with `Claude.orange` tint |

All helpers use `@available(watchOS 26.0, *)` guards and fall back gracefully.

Note: `GlassEffectContainer` is a **SwiftUI framework type** (not a custom helper).
It is used directly in `MainView.swift` line 261 as:

```swift
if #available(watchOS 26.0, *) {
    GlassEffectContainer(spacing: 12) { content() }
} else {
    content()
}
```

Ref: `Claude.swift` lines 347-391 (view extensions), 393-458 (button styles)

### 3.2 Widget + Liquid Glass -- NOT STARTED (P1)

Current widget uses `.containerBackground(.black, for: .widget)`. On watchOS 26,
complications on Liquid Glass watch faces should use transparent backgrounds.

Required change in `RemmyWidgets.body`:

```swift
var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: RemmyWidgetConfigIntent.self, provider: RemmyProvider()) { entry in
        RemmyWidgetEntryView(entry: entry)
            .containerBackground(for: .widget) {
                if #available(watchOS 26.0, *) {
                    Color.clear
                } else {
                    Color.black
                }
            }
    }
    // ...
}
```

Impact: Allows gauge complications to integrate with Liquid Glass watch faces
instead of rendering a black background circle.

### 3.3 Interactive Widget Buttons -- NOT STARTED (P1)

Approve/reject directly in the Smart Stack widget using AppIntents.

Required components:
- `ApproveLatestIntent: AppIntent` -- calls WatchService to approve first pending action
- `RejectLatestIntent: AppIntent` -- calls WatchService to reject first pending action
- `accessoryRectangular` family (for layout space) or Smart Stack widget
- `Button(intent:)` -- requires WidgetKit interactive widgets (watchOS 11+)

SwiftUI pattern for interactive widget:

```swift
// In accessoryRectangular view when pendingCount > 0:
HStack(spacing: 8) {
    Button(intent: ApproveLatestIntent()) {
        Image(systemName: "checkmark")
            .foregroundStyle(Claude.success.opacity(dimFactor))
    }
    Button(intent: RejectLatestIntent()) {
        Image(systemName: "xmark")
            .foregroundStyle(Claude.destructive.opacity(dimFactor))
    }
}
```

---

## 4. Gestures and Shortcuts

### 4.1 Double-Tap = Approve -- SHIPPED

`.handGestureShortcut(.primaryAction)` applied on the Approve button directly
(not the view wrapper). Conditional on tier -- disabled for Tier 3 / high-risk actions.

Implementation pattern (`DoubleTapApproveModifier`):

```swift
struct DoubleTapApproveModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            if #available(watchOS 11.0, *) {
                content.handGestureShortcut(.primaryAction)
            } else { content }
        } else { content }
    }
}
```

Files using `.handGestureShortcut`:

| File | Availability Gate | Purpose |
|------|------------------|---------|
| `ApprovalView.swift:206` | watchOS 11.0 | Approve pending action |
| `ActionViews.swift:519` | watchOS 26.0 | Approve in action detail |
| `QuestionResponseView.swift:158` | watchOS 26.0 | Select first question option |
| `PausedView.swift:65` | watchOS 26.0 | Resume session |
| `TaskOutcomeView.swift:99` | watchOS 26.0 | Dismiss outcome |

Note: `.handGestureShortcut` was introduced in watchOS 11.0. Some files use
watchOS 26.0 gates (overly restrictive but harmless). The actual hardware
requirement is Series 9 / Ultra 2+.

### 4.2 API Availability Reference

| API | watchOS Version | Notes |
|-----|----------------|-------|
| `AppIntent`, `AppShortcutsProvider` | 10.0 | Project deployment target |
| `.handGestureShortcut(.primaryAction)` | 11.0 | Series 9 / Ultra 2+ hardware |
| `ControlWidget`, `ControlWidgetButton` | 26.0 | Control Center actions |
| `FoundationModels`, `@Generable` | 26.0 | On-device language model |
| `.glassEffect()` | 26.0 | Liquid Glass rendering |
| `GlassEffectContainer` | 26.0 | SwiftUI framework type |
| Core Haptics | N/A | Not on watchOS |

---

## 5. Haptic Vocabulary -- SHIPPED

All haptic calls go through `WatchService.playHaptic(_ type: WKHapticType)`.
Core Haptics is NOT available on watchOS -- limited to 9 predefined `WKHapticType` values.

### 5.1 User-Facing Haptic Events

| Event | WKHapticType | Meaning |
|-------|-------------|---------|
| Approval needed (new action queued) | `.notification` | Needs attention |
| Approved (single or batch) | `.success` | Confirmed |
| Rejected (single or batch) | `.failure` | Denied |
| Task completed | `.success` | Outcome shipped |
| Task failed | `.failure` | Something broke |
| Error state | `.failure` | Something broke |
| Connection established | `.success` | Paired successfully |
| Context warning (< 85%) | `.notification` | Moderate concern |
| Context warning (>= 85%) | `.failure` | Urgent concern |
| Context dismissed | `.click` | Acknowledged |

### 5.2 Mode-Change Haptics

| Mode Transition | WKHapticType | Meaning |
|----------------|-------------|---------|
| Enter Normal mode | `.click` | Neutral confirmation |
| Enter Auto-Accept mode | `.start` | Active/continuous feel |
| Enter Plan mode | `.stop` | Paused/deliberate feel |

### 5.3 Internal Haptics (Low-Level)

| Event | WKHapticType |
|-------|-------------|
| Session reset | `.click` |
| Question posted to cloud | `.notification` |
| Demo mode finalized | `.notification` or `.success` |

---

## 6. Voice Integration

### 6.1 Siri / App Intents -- NOT STARTED (P2)

Uses `AppIntent` + `AppShortcutsProvider`, fully supported on watchOS 10+.
Action Button on Ultra can be assigned to any shortcut.

### 6.2 Claude Radio (Walkie-Talkie for Claude) -- NOT STARTED (P3)

Press Action Button (or in-app button) --> speak --> transcription --> sent to Claude.
Claude responds via notification. Maintains conversation context (unlike Siri one-shots).

**Technical constraint**: Hooks can only allow/deny, so voice commands write to
a temp file that Claude reads (same pattern as AskUserQuestion flow).

---

## 7. Ambient Intelligence

### 7.1 Wrist Raise = Instant Context

Raise wrist --> 0.5s --> see gauge tinted by state + pending count or progress --> lower wrist.
Over time, developers build a sixth sense for session state.

### 7.2 Product Journey

| Phase | State | What Makes It Stick |
|-------|-------|---------------------|
| Phase 1 (current) | "I can approve from my watch" | Utility -- tool approvals, questions |
| Phase 2 | Ambient awareness, async coding | Walk away from Mac, watch keeps you connected |
| Phase 3 | "Can't code without my watch" | Haptic sixth sense, voice integration |

### 7.3 What Remmy Is Not

- Not a code viewer or mini-IDE
- Not a terminal on the wrist
- Not a notification firehose
- Not a project manager
- Not a gamification/engagement platform

---

## 8. Platform Capabilities Reference

| Capability | Status | watchOS | Impact |
|-----------|--------|---------|--------|
| Interactive widgets | Available | 11.0 | Approve/reject in Smart Stack |
| Double-tap gesture | SHIPPED | 11.0 | Zero-friction approve |
| APNs complication push | Available | 10.0 | Near-real-time widget updates |
| Watch face sharing | Available | 10.0 | Onboarding -- share "Developer" face |
| AppIntentConfiguration | SHIPPED | 10.0 | Configurable widget, interactive buttons ready |
| Smart Stack relevance | SHIPPED | 11.0 | Dynamic surfacing based on state |
| RelevantContext API | Available | 11.0 | Working-hours Smart Stack surfacing |
| Liquid Glass | SHIPPED (app) | 26.0 | Glass effects on cards, buttons, containers |
| ControlWidget | Available | 26.0 | Control Center quick actions |
| FoundationModels | Available | 26.0 | On-device language model |
| Core Haptics | N/A | -- | Not on watchOS, 9 predefined types only |

---

## 9. Implementation Priority (Revised)

| Priority | Feature | Status | Effort | Rationale |
|----------|---------|--------|--------|-----------|
| P1 | Rectangular complication (`accessoryRectangular`) | NOT STARTED | 1-2 days | Most information-dense family |
| P1 | Interactive widget buttons (approve/reject in Smart Stack) | NOT STARTED | 2-3 days | Approve without opening app |
| P1 | Liquid Glass widget background gate | NOT STARTED | <1 day | Glass face integration on watchOS 26 |
| P1 | APNs complication push | NOT STARTED | 2-3 days | Real-time widget updates vs polling |
| P2 | App Intents + Siri commands | NOT STARTED | 1-2 days | "Hey Siri, approve with Remmy" |
| P2 | Watch face sharing bundle | NOT STARTED | 1 day | Onboarding polish |
| P2 | ControlWidget (Control Center) | NOT STARTED | 1-2 days | Quick approve/session status |
| P3 | Claude Radio (walkie-talkie voice) | NOT STARTED | 3-5 days | Voice conversation with Claude |
| P3 | Spoken summaries (AirPods) | NOT STARTED | 2-3 days | Accessibility / hands-free |

### Already Shipped

| Feature | Reference |
|---------|-----------|
| Awareness gauge complications (circular, corner, inline) | `ComplicationViews.swift` |
| `ClaudeState.shortLabel` for complication center text | `ClaudeState.swift` |
| `ClaudeState.icon` SF Symbols for all 8 states | `ClaudeState.swift` |
| `ClaudeStateDot` / `ClaudeStateIcon` reusable components | `ClaudeState.swift` |
| `session_state` written to shared UserDefaults | `WatchService.swift` |
| `ComplicationSnapshot` change detection + 30s throttle | `WatchService.swift` |
| Smart Stack relevance scoring | `RemmyEntry.relevance` |
| Widget timeline debounce (5s trailing-edge) | `WidgetReloadCoordinator` |
| Dynamic timeline refresh (30s/60s/900s) | `RemmyProvider.timeline()` |
| AppIntentConfiguration | `RemmyProvider: AppIntentTimelineProvider` |
| Always-on display support | `isLuminanceReduced` + `dimFactor` pattern |
| Double-tap = Approve | `.handGestureShortcut(.primaryAction)` |
| Liquid Glass helpers (app UI) | `Claude.swift` glass extensions |
| Full haptic vocabulary | `WatchService.playHaptic()` |
| ModeIndicator component (N/P/A badges) | `ModeIndicator.swift` |

---

## 10. Open Design Questions

1. **State derivation gaps**: Only 5 of 8 `ClaudeState` values are reachable via `ClaudeState.derive()`.
   `.plan`, `.context`, and `.question` require explicit server protocol messages.
   Should `derive()` be extended, or should the server send these states directly?

2. **Rectangular complication: interactive or static?**: Should `accessoryRectangular` show
   approve/reject buttons (requires interactive widgets, watchOS 11+) or remain a richer
   information display? Both approaches have trade-offs for the glance-and-go model.

3. **Complication typography: raw vs tokens?**: Current complications use raw font constructors
   for precise pixel control. Should these be migrated to named `Font.claude*` tokens, or
   should complication-specific tokens be added to the design system (e.g., `Font.claudeGaugeCenter`)?

4. **Liquid Glass in complications**: watchOS 26 gauge rendering on glass watch faces may need
   color adjustments. Should `dimFactor` be adjusted for glass faces, or does the system
   handle vibrancy automatically?
