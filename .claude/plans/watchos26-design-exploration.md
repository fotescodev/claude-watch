# watchOS 26 Design Exploration: Remmy Form Factors

> **Purpose**: Explore every watchOS 26 design surface where Remmy can deliver value.
> **Target**: watchOS 26 (Fall 2025), Apple Watch Series 6+, Liquid Glass design language.
> **Builds on**: `watchos-complications-brainstorm.md` (Build/Ship/Guard rings, double-tap, voice)

---

## What's New in watchOS 26 for Remmy

watchOS 26 introduces several capabilities that didn't exist when the original brainstorm was written. These change the design surface significantly.

| Capability | Impact on Remmy |
|-----------|----------------|
| **Liquid Glass** | Every surface gets a translucent, refractive material. Complications, notifications, and in-app UI should adopt `.glassEffect()` |
| **Widget Push Updates** | APNs can now update widgets directly — no more polling budgets. Real-time complications become viable |
| **RelevanceConfiguration** | New widget type designed for Smart Stack. Widgets appear only when relevant (e.g., when a Claude session is active) |
| **Controls** | Custom controls in Control Center, Action Button, and Smart Stack. Quick actions without opening the app |
| **Wrist Flick** | Dismiss notifications with a wrist flick (Series 9+). Changes how we think about notification persistence |
| **Smart Stack Hints** | System surfaces visual cues to guide users to relevant widgets |
| **Accented Rendering** | Five rendering modes for widget images. Better watch face integration |

---

## 1. Complications (Watch Face)

### Current State
Four complication families implemented in `ComplicationViews.swift` (circular, rectangular, corner, inline). Using `StaticConfiguration`. Not wired to live data. No widget extension target.

### watchOS 26 Upgrades

#### a. Liquid Glass Complications
All complications should adopt the Liquid Glass material. The current black-background monospace-green aesthetic was designed for pre-Liquid Glass watchOS.

```
┌──────────────────────────────────────────────┐
│  BEFORE (current)          AFTER (watchOS 26)│
│                                              │
│  ┌─────────┐               ┌─────────┐      │
│  │▓▓▓▓▓▓▓▓▓│               │░░░░░░░░░│      │
│  │▓ ⬤ 72% ▓│  Opaque       │ ◎ 72%   │ Glass│
│  │▓▓▓▓▓▓▓▓▓│  black bg     │░░░░░░░░░│ blur │
│  └─────────┘               └─────────┘      │
│                                              │
│  Circular: Green ring      Circular: Glass   │
│  on black. Terminal icon.  ring with subtle  │
│                            tint. Refracts    │
│                            watch face behind │
│                            it.               │
└──────────────────────────────────────────────┘
```

**Design direction**: Drop the explicit `.containerBackground(.black, for: .widget)`. Use `.glassEffect()` on key elements. Let the watch face show through. Use tint colors sparingly and with meaning (amber = needs attention, green = healthy, purple = model indicator).

#### b. Widget Push Updates (Replaces Timeline Polling)
The current `RemmyProvider` uses `TimelineProvider` with polling intervals (30s/60s/900s). watchOS 26 supports push-based widget updates via APNs.

```
Current:  Cloud → APNs → Watch App → UserDefaults → Widget polls (30-900s lag)
watchOS 26: Cloud → APNs → Widget directly (near-instant)
```

This is transformative. When a new approval arrives, the complication updates within seconds rather than waiting for the next timeline refresh. The `WidgetPushHandler` protocol replaces the reload budget concern entirely.

**Implementation sketch**:
```swift
struct RemmyWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        // Register widget push token with cloud worker
        // Cloud sends {"aps": {"content-changed": true}} on state changes
    }
}
```

#### c. Accented Rendering Modes
Watch faces that use accent colors (e.g., California, Typograph) tint complications. The new `widgetAccentedRenderingMode` modifier lets us control how Remmy's icons render in these contexts:

- **`.accented`** — Tint to the user's chosen accent color (good for status icons)
- **`.desaturated`** — Remove color, show as monochrome (good for the activity rings)
- **`.fullColor`** — Preserve our brand colors (best when possible)

The Build/Ship/Guard rings should use `.desaturated` in accented mode so they don't clash with the watch face accent, but preserve their meaning through ring position rather than color.

---

## 2. Smart Stack Widgets

### Current State
`accessoryRectangular` widget serves as both watch face complication and Smart Stack entry. Basic text layout with task name, progress bar, pending count.

### watchOS 26 Upgrades

#### a. RelevanceConfiguration (New Widget Type)
Replace `StaticConfiguration` with `RelevanceConfiguration` for a Smart Stack-optimized widget that appears only when useful:

```
┌────────────────────────────────────┐
│  Relevant Widget Behavior          │
│                                    │
│  No active session → Widget hidden │
│  Session starts    → Widget appears│
│  Approval needed   → Widget rises  │
│                      to top        │
│  Session ends      → Widget fades  │
│                      out           │
└────────────────────────────────────┘
```

**Relevance signals**:
- **Date/time**: Surface during working hours (configurable)
- **Point of Interest**: Surface when near the user's development location (office, home desk)
- **Custom**: Surface when cloud reports an active session

This means Remmy doesn't clutter the Smart Stack when the user isn't coding.

#### b. Interactive Widget Buttons
The rectangular Smart Stack widget can contain `Button(intent:)` for direct approve/reject:

```
┌─────────────────────────────────────────┐
│  Smart Stack Widget (Interactive)       │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ ◎ REMMY              ● online  │    │
│  │                                 │    │
│  │ Bash: npm test                  │    │
│  │                                 │    │
│  │  ┌──────────┐  ┌──────────┐   │    │
│  │  │ ✓ Approve │  │ ✗ Reject │   │    │
│  │  └──────────┘  └──────────┘   │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Double-tap targets "Approve" button    │
│  via .handGestureShortcut               │
└─────────────────────────────────────────┘
```

Uses `AccessoryWidgetGroup` layout:
- **Label**: "REMMY" + connection indicator
- **Content 1**: Current action description
- **Content 2**: Approve button (`Button(intent: ApproveRemmyIntent())`)
- **Content 3**: Reject button (`Button(intent: RejectRemmyIntent())`)

#### c. Liquid Glass in Smart Stack
Smart Stack widgets in watchOS 26 adopt Liquid Glass automatically. The widget should:
- Use `.glassEffect()` on interactive buttons
- Use `.buttonStyle(.glass)` for approve, `.buttonStyle(.glassProminent)` with red tint for reject
- Let the translucent background show through rather than using opaque fills

#### d. Multiple Widget Instances
With `RelevanceConfiguration`, multiple Remmy widgets can appear simultaneously:
- One showing current approval request
- One showing session progress / activity rings
- One showing recent activity feed

The system manages which ones appear based on relevance scoring.

---

## 3. Controls (New in watchOS 26)

Controls are a brand-new surface. They're quick-action buttons that appear in three places:

### a. Control Center
Accessible via side button press. Remmy controls alongside system controls:

```
┌───────────────────────────────┐
│  Control Center               │
│                               │
│  ┌─────┐  ┌─────┐  ┌─────┐  │
│  │  ✈  │  │  🔦 │  │  📱 │  │
│  │ Air  │  │Torch│  │ Ping│  │
│  └─────┘  └─────┘  └─────┘  │
│                               │
│  ┌─────┐  ┌─────┐  ┌─────┐  │
│  │  ⏸  │  │  ✓  │  │  ✗  │  │
│  │Pause│  │ Appr│  │ Rej │  │
│  │Remmy│  │ ove │  │ ect │  │
│  └─────┘  └─────┘  └─────┘  │
│                               │
└───────────────────────────────┘
```

**Controls to expose**:
| Control | Symbol | Action |
|---------|--------|--------|
| Pause/Resume | `pause.fill` / `play.fill` | Toggle session pause |
| Approve | `checkmark.circle.fill` | Approve latest pending |
| Reject | `xmark.circle.fill` | Reject latest pending |
| Status | `terminal.fill` | Open Remmy app |

### b. Action Button (Ultra Only)
Apple Watch Ultra users can assign a Remmy control to the Action Button. The most natural mapping:
- **Single press**: Approve latest pending
- **Configure**: Let user choose between approve, status check, or pause

### c. Smart Stack Controls
Controls can appear in the Smart Stack alongside widgets. A Remmy control tile provides a persistent quick-action surface even when the full widget isn't showing.

### Implementation
Controls use the `ControlWidget` API with `AppIntent`:

```swift
struct ApproveControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ApproveControl") {
            ControlWidgetButton(action: ApproveRemmyIntent()) {
                Label("Approve", systemImage: "checkmark.circle.fill")
            }
        }
        .displayName("Approve Remmy")
    }
}
```

---

## 4. Notifications

### Current State
Standard `UNNotificationAction` buttons (Approve, Reject, Approve All). No custom notification UI. No `WKNotificationScene`.

### watchOS 26 Upgrades

#### a. Custom Notification Long Look (Liquid Glass)
Instead of the default notification chrome, implement a `WKNotificationScene` with a SwiftUI-based custom Long Look:

```
┌─────────────────────────────────────────┐
│                                         │
│     ◎ REMMY                             │
│     ─────────────────                   │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │                                 │    │
│  │  Edit: src/services/auth.ts     │    │
│  │                                 │    │
│  │  + import { hash } from 'bcrypt'│    │
│  │  + const salt = await genSalt() │    │
│  │  - // TODO: add hashing         │    │
│  │                                 │    │
│  │  Risk: Low · Model: opus        │    │
│  │                                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │          ✓ Approve              │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │          ✗ Reject               │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

**Key design decisions**:
- Show a compact diff preview (2-3 lines max, syntax-highlighted)
- Show the tool name and target file
- Risk tier indicator (Low/Medium/High) with color coding
- Model name badge (opus/sonnet/haiku)
- Buttons use `.glassEffect()` with `.interactive` modifier
- **The Approve button gets `.handGestureShortcut(.primaryAction)`** — double-tap approves from notification

#### b. Wrist Flick Interaction
watchOS 26's wrist flick gesture dismisses notifications. For Remmy, "dismiss" should mean "I'll handle it later" (snooze), not "reject." This needs to be communicated clearly:
- Dismissed notifications should re-surface after 2 minutes
- Or: dismissed = "defer to Mac" (falls through to terminal)

#### c. Notification Categories by Tool Type
Different tools deserve different notification experiences:

| Tool | Notification Style | Priority |
|------|-------------------|----------|
| **Bash** (commands) | Full Long Look with command preview | High — commands are irreversible |
| **Edit/Write** (file changes) | Long Look with diff preview | Medium |
| **Read/Glob/Grep** (reads) | Compact, auto-approve eligible | Low |
| **AskUserQuestion** | Custom UI with option buttons | High — requires choice |

#### d. Question Notifications
When Claude asks a question (routed through the hook), show a custom notification with tappable option buttons:

```
┌─────────────────────────────────────────┐
│                                         │
│     ◎ REMMY · Question                  │
│     ─────────────────                   │
│                                         │
│  Which database driver should I use?    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      PostgreSQL (Recommended)   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │      SQLite                     │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │      Handle on Mac              │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

This overcomes the current limitation where the watch can only approve/reject and cannot select from options. With `isInteractive = true` on the custom notification view, each option becomes a tappable button backed by an `AppIntent`.

---

## 5. Live Activities

### Current Assessment
Live Activities on watchOS require an iPhone companion app running the activity. Remmy's architecture is watch-only (no iPhone app).

### Viable Path: Companion-Free via Widget Push
Since watchOS 26 adds widget push updates, we can achieve the same UX as a Live Activity using a `RelevanceConfiguration` widget that:
- Appears at the top of the Smart Stack when a session starts
- Updates in real-time via APNs push
- Disappears when the session ends

This is functionally equivalent to a Live Activity without requiring an iPhone companion.

### Future: iPhone Companion App
If Remmy ever ships an iPhone companion app, Live Activities become the premium experience:

```
┌───────────────────────────────────────────┐
│  Live Activity in Smart Stack             │
│                                           │
│  ┌───────────────────────────────────┐    │
│  │ ◎ Remmy · Session Active          │    │
│  │                                    │    │
│  │ ██████████░░░░░░░░░░░░ 42%        │    │
│  │ Writing tests for auth module...   │    │
│  │                                    │    │
│  │ 12 approved · 2 rejected · 45min  │    │
│  └───────────────────────────────────┘    │
│                                           │
│  Updates in real-time. Tapping opens      │
│  the Remmy app with full session view.    │
└───────────────────────────────────────────┘
```

**Recommendation**: Don't build a companion app just for Live Activities. The widget push approach achieves 90% of the value.

---

## 6. Activity Rings (Build / Ship / Guard)

> From the original brainstorm. Updated for watchOS 26.

### Liquid Glass Rings
The three concentric rings should use Liquid Glass materials:
- Ring tracks: `.glassEffect(.clear)` for subtle translucent background
- Ring fills: Solid color with glass sheen
- Center content: Glass-backed pending count or streak flame

### Widget Rendering
The rings work across all four complication families:

```
Circular:            Rectangular:           Corner:         Inline:
┌─────────┐         ┌──────────────────┐   ┌──────┐      B:82 S:50 G:100 🔥3
│  ╭───╮  │         │ ◎ BUILD  ████░ 82%│   │ ╭──╮ │
│  │╭─╮│  │         │   SHIP   ███░░ 50%│   │ │3 │ │
│  ││3 ││  │         │   GUARD  █████ 100│   │ ╰──╯ │
│  │╰─╯│  │         │         🔥 3 days │   └──────┘
│  ╰───╯  │         └──────────────────┘
└─────────┘
```

### Accented Mode
In accented rendering, the three rings should use `.desaturated` mode — they become three shades of the watch face accent color, distinguished by position (outer/middle/inner) rather than hue. This preserves readability on any watch face.

### Ring Data Sources
| Ring | Source | Calculation |
|------|--------|-------------|
| Build | Tool calls (Bash, Edit, Write, Read) | Points per call, weighted by type. Goal: ~200/day |
| Ship | Completed todos, commits | Extracted from TodoWrite updates + git events |
| Guard | Approvals + rejections + questions answered | Each response = points. Goal: respond within 2min |

### "Close Your Rings" Notification
At end of work day (configurable), if rings aren't closed:
> "Your Guard ring is at 60%. You have 3 unanswered approvals."

This creates the same habit loop as Apple's Activity rings but for developer oversight.

---

## 7. Watch Face Sharing

### "Developer Face" Package
Remmy can offer a curated watch face configuration during onboarding:

**Recommended face**: Modular Compact (best complication density)
- **Top left**: Remmy circular (Build/Ship/Guard rings)
- **Top right**: Calendar (next meeting)
- **Center**: Remmy rectangular (session status + approve buttons)
- **Bottom left**: Remmy inline (quick status text)
- **Bottom right**: Remmy corner (Guard ring with pending count)

**Implementation**: Use `addWatchFace(from: URL)` with a `.watchface` file bundled in the app. Offered during post-pairing onboarding.

---

## 8. Gestures

### Double-Tap (Series 9+)
Already planned. `.handGestureShortcut(.primaryAction)` on the Approve button in:
- Main app view
- Smart Stack interactive widget
- Custom notification Long Look

### Wrist Flick (Series 9+, watchOS 26)
New in watchOS 26. Dismisses current notification / returns to watch face.

**Remmy behavior when flicked**:
- **Approval notification**: Defer to Mac (not reject). Re-notify in 2 minutes.
- **Question notification**: Skip question, let it fall through to terminal.
- **Progress notification**: Normal dismiss, no re-notify.

This is system-level behavior, not customizable per-app. But our notification design should account for users who dismiss by flick (make sure dismiss != reject).

---

## 9. App Intents & Siri

### Current State
Five intents implemented: Approve, Reject, Pause, Resume, Status. Available watchOS 26.0+.

### watchOS 26 Upgrades

#### Apple Intelligence Integration
On devices with Apple Intelligence, Siri can understand more natural language and chain intents:
- "Hey Siri, what did Claude do while I was away?" → Status + recent activity
- "Hey Siri, approve everything from Claude" → Approve All
- "Hey Siri, tell Claude to stop" → Pause

#### Control Center / Action Button Intents
The same `AppIntent` structs power Controls, so no additional work needed — the intents we have already work as controls.

#### Spotlight Integration
Index active approval requests as Spotlight items. When the user searches on watch, pending approvals appear:
```
Search: "remmy"
→ Pending: Bash npm test (Approve / Reject)
→ Pending: Edit auth.ts (Approve / Reject)
```

---

## 10. Always-On Display

### Current State
All complications already support `isLuminanceReduced` with dimmed colors and reduced opacity.

### watchOS 26 Considerations

#### Sensitive Content Redaction
File paths, command text, and diff content are sensitive developer information. In always-on mode:
- **Redact**: File paths, command content, diff previews
- **Show**: Pending count, ring progress, connection status
- **Use**: `.privacySensitive()` modifier on text containing code/paths

```
Wrist up:                    Wrist down (AOD):
┌──────────────────────┐     ┌──────────────────────┐
│ Edit: src/auth.ts    │     │ 1 pending approval   │
│ + import bcrypt      │     │                      │
│                      │     │ ● Connected           │
│ [Approve] [Reject]   │     │                      │
└──────────────────────┘     └──────────────────────┘
```

#### Glass Material in AOD
Liquid Glass effects should be reduced in always-on mode. The system handles this automatically for standard `.glassEffect()` usage, but custom glass implementations should check `isLuminanceReduced` and fall back to simpler visuals.

---

## Design Principles for Remmy on watchOS 26

1. **Glass-first**: Every surface should feel like it belongs in the Liquid Glass ecosystem. No opaque black cards.

2. **Push-driven**: Use widget push updates everywhere. Polling was a battery-draining workaround. watchOS 26 makes it unnecessary for complications.

3. **Relevance-aware**: Remmy should appear when needed and disappear when not. Use `RelevanceConfiguration` aggressively.

4. **Approve in 2 seconds**: The golden path (raise wrist → double-tap → approved) should work from any surface: complication, widget, notification, control.

5. **Rings as identity**: The Build/Ship/Guard rings are Remmy's visual identity. Every form factor should show some version of them.

6. **No reading on the watch**: Show what happened (tool name, file name, risk level), not the full details. The Mac has the details. The watch has the decision.

7. **Gestures over taps**: Double-tap to approve, wrist flick to defer. Minimize touch interaction.

---

## Implementation Roadmap

### Phase A: Foundation (Widget Extension + Push)
1. Create Widget Extension target (currently missing — ship blocker)
2. Implement `WidgetPushHandler` for real-time widget updates
3. Wire complications to live data via App Groups
4. Adopt Liquid Glass (`.glassEffect()`, `.containerBackground` removal)
5. Remove legacy `CLKComplicationPrincipalClass` from Info.plist

### Phase B: Interactive Surfaces
1. Migrate from `StaticConfiguration` to `RelevanceConfiguration`
2. Add interactive widget buttons (approve/reject with `Button(intent:)`)
3. Implement `ControlWidget` for Control Center + Action Button + Smart Stack
4. Custom notification Long Look with `WKNotificationScene`

### Phase C: Activity Rings
1. Build/Ship/Guard ring data model and persistence
2. Ring views for all four complication families
3. Accented rendering support
4. "Close your rings" end-of-day notification
5. Streak tracking

### Phase D: Polish & Delight
1. Watch Face Sharing (curated "Developer Face")
2. Question notifications with tappable options
3. Sensitive content redaction in AOD
4. Spotlight indexing for pending approvals
5. Haptic vocabulary refinement

---

## Open Questions

1. **Should rings reset daily?** Activity Rings do. But coding sessions span multiple days. Maybe weekly rings, or per-project rings?

2. **What happens when wrist-flicked?** Defer to Mac? Snooze? Auto-approve after timeout? This needs user research.

3. **Multiple sessions**: If a developer runs two Claude sessions, how do complications show this? Aggregate? Latest? Split?

4. **Ring gamification vs. utility**: Rings create habit loops, but developers might find them patronizing. Should rings be opt-in?

5. **Companion iPhone app**: Would unlock Live Activities, but adds maintenance burden. Worth it?
