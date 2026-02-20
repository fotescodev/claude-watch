# watchOS Complications & Ambient Intelligence Brainstorm

> Generated 2026-02-20 by 4-agent brainstorm team (UX, Platform, Voice, Product Vision)

---

## Core Concept: Build / Ship / Guard Rings

Three concentric rings (inspired by Activity) that tell a coding session story at a glance.

| Ring | Position | Color | Measures | Daily Goal |
|------|----------|-------|----------|------------|
| **Build** | Outer | Cyan `#00E5CC` | Active Claude tool calls (work volume) | ~200 tool-call points |
| **Ship** | Middle | Violet `#BF5AF2` | Completed tasks, commits, milestones | 5 shipped items |
| **Guard** | Inner | Amber `#FF9F0A` | Approvals reviewed, questions answered | Stay engaged |

**Key design insight**: Guard counts denials equally to approvals. Oversight is positive. The tension between Build and Guard prevents rewarding blind auto-approval.

### Visual Behavior
- **Beyond 100%**: Rings overlap themselves at 60% opacity
- **Streaks**: Flame icon with day count. Blue flame at 7 days. Never guilt on broken streaks
- **Guard ring can decrease**: Unanswered approvals >5min cost -2%/min (gentle urgency)
- **All rings closed**: Three sequential haptic taps + visual burst celebration

### Complication Families
- **accessoryCircular**: Three concentric rings, center shows pulsing dot (active) or pending count
- **accessoryRectangular**: Mini rings left + three horizontal bars with labels + streak line
- **accessoryCorner**: Guard ring arc + pending count (most actionable single ring)
- **accessoryInline**: `B:82% S:50% G:100% 🔥3`

### Data Mapping
From Claude Code sessions we track: tool calls (Bash, Edit, Write, Read), approvals (approved/denied), questions answered, session duration, model used, tasks created/completed (TodoWrite), files changed.

### Alternative Visual Metaphors
- **Commit Galaxy**: Stars per tool call, cluster by type, supernovas on completion
- **Circuit Board**: Glowing traces light up as code executes
- **Code Garden**: Procedural garden grows with activity

**Recommendation**: Ship rings first (familiar, legible), then Galaxy as premium alternate view.

---

## Three Killer Features

### P0: Double-Tap = Approve -- FIXED
`.handGestureShortcut(.primaryAction)` now applied directly to the Approve button (not the view wrapper).
Conditional on tier (disabled for Tier 3 / high-risk). Requires watchOS 11.0+, Series 9 / Ultra 2+.

### `@available` Annotations -- VERIFIED CORRECT
Compiler confirms: `ControlWidget` APIs are genuinely watchOS 26.0. `AppIntent` is watchOS 10.0 but
project targets watchOS 26 features, so the annotations are intentionally aligned.
`.handGestureShortcut` is watchOS 11.0 (fixed from 26.0 in the modifier).

### P1: Interactive Widget Buttons
Approve/Reject directly in Smart Stack widget using existing AppIntents + `Button(intent:)`. Requires migrating from `StaticConfiguration` to `AppIntentConfiguration`. The double-tap gesture also works on interactive widget buttons.

---

## Voice Integration

### Siri / App Intents (GREEN today)
```
"Hey Siri, what is Remmy doing?"     -> spoken status
"Hey Siri, approve with Remmy"       -> approves latest pending
"Hey Siri, tell Remmy [message]"     -> free-form instruction to Claude
```
Uses `AppIntent` + `AppShortcutsProvider`, fully supported watchOS 10+. Action Button on Ultra can be assigned to any shortcut.

### Claude Radio (Walkie-Talkie for Claude) — P3, 3-5 days
Press Action Button (or in-app button) -> speak -> transcription -> sent to Claude. Claude responds via notification. Maintains conversation context (unlike Siri one-shots).

**Technical constraint**: Hooks can only allow/deny, so voice commands write to temp file that Claude reads (same pattern as AskUserQuestion).

### Wispr Flow Verdict: RED on watchOS
iOS keyboard replacement with no watchOS component. Native watchOS dictation is sufficient for short commands. `DictationTranscriber` on watchOS 26 may improve technical term accuracy.

---

## Ambient Intelligence

### Wrist Raise = Instant Context
Raise wrist -> 0.5s -> see "Writing tests for UserService..." -> lower wrist. Over ~4 weeks, developers build a sixth sense for session state.

### Session Mood Ring
Complication tints based on session health: green (smooth), amber (issues), red (help needed). Visible in peripheral vision.

### Haptic Vocabulary
| Event | Haptic | Meaning |
|-------|--------|---------|
| Approval needed | `.notification` | "I need you" |
| Approved | `.success` | "We're good" |
| Rejected | `.failure` | "Not that" |
| Task complete | `.success` x2 | "Something shipped" |
| Session paused | `.stop` | "I'm waiting" |
| Error | `.retry` | "Something broke" |

Note: Core Haptics NOT available on watchOS. Limited to 9 predefined `WKHapticType` values.

---

## Platform Capabilities

| Capability | Status | Impact |
|-----------|--------|--------|
| Interactive widgets (watchOS 11) | Available | Approve in Smart Stack |
| Double-tap gesture (watchOS 10.1) | Available | Zero-friction approve |
| APNs complication push | Available | Near-real-time widget updates |
| Watch face sharing | Available | "Developer" face during onboarding |
| AppIntentConfiguration | Available | User-customizable widget |
| RelevantContext API (watchOS 11) | Available | Working-hours Smart Stack surfacing |
| Live Activities | Requires iPhone companion | Not viable for watch-only arch |
| Core Haptics | Not on watchOS | 9 predefined types only |
| TTS (AVSpeechSynthesizer) | Available, low quality | Haptics preferred |

---

## Product Journey

| Phase | State | What Makes It Stick |
|-------|-------|---------------------|
| **Phase 1** (now) | "I can approve from my watch" | Utility |
| **Phase 2** | Ambient awareness, async coding | Walk away from Mac, watch keeps you connected |
| **Phase 3** | "Can't code without my watch" | Activity rings ritual, haptic sixth sense, voice steering |

### What NOT to Build
- Not a code viewer or mini-IDE
- Not a terminal on the wrist
- Not a notification firehose
- Not a project manager
- Not competitive/social

---

## Implementation Priority

| Priority | Feature | Effort | Why |
|----------|---------|--------|-----|
| ~~P0~~ | ~~Double-tap = Approve~~ | ~~Done~~ | FIXED: modifier on button, watchOS 11.0 |
| ~~P0~~ | ~~Fix `@available` annotations~~ | ~~Done~~ | VERIFIED: watchOS 26.0 is correct for project scope |
| **P1** | Activity Rings (Build/Ship/Guard) | 1-2 weeks | Differentiating visual identity |
| **P1** | Interactive widget buttons | 2-3 days | Approve without opening app |
| **P1** | APNs complication push | 2-3 days | Real-time widget updates |
| **P2** | App Intents + Siri commands | 1-2 days | "Hey Siri, approve with Remmy" |
| **P2** | Session mood ring complication | 1-2 days | Ambient awareness at a glance |
| **P2** | Watch face sharing | 1 day | Onboarding polish |
| **P3** | Claude Radio (walkie-talkie) | 3-5 days | Voice conversation with Claude |
| **P3** | Spoken summaries (AirPods) | 2-3 days | Accessibility / hands-free |
| **P3** | Developer daily dashboard | 1 week | Closing-rings dopamine loop |

---

## Codebase Issues Found

1. ~~`.handGestureShortcut(.primaryAction)` applied to view wrapper~~ — **FIXED**: now on Approve button
2. ~~`@available(watchOS 26.0, *)` annotations~~ — **VERIFIED CORRECT**: project targets watchOS 26 features
3. `StaticConfiguration` used instead of `AppIntentConfiguration` — no interactive widget support (P1)
4. No `WKNotificationScene` for custom notification UI with approve/reject buttons (P2)
