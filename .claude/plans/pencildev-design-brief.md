# Pencil.dev Design Brief: Remmy for watchOS 26

> **For**: Design team lead + 6 parallel agents
> **Reference**: `.claude/plans/watchos26-design-exploration.md`
> **Date**: 2026-02-24

---

## For the Team Lead

You're leading the visual design exploration for **Remmy** — the first wearable interface for an AI coding assistant. Remmy lives on Apple Watch and lets developers approve, reject, and steer Claude Code sessions from their wrist.

We've completed the technical exploration (referenced above as "the plan"). Your team's job: **turn these capabilities into designs that feel native to watchOS 26's Liquid Glass language while establishing Remmy's own visual identity.**

### The Product in One Sentence
> Raise wrist. See what Claude is doing. Double-tap to approve. Lower wrist. Two seconds.

### What Makes Remmy Different
Remmy is **not** a notification app. It's an **ambient awareness layer** for AI-assisted development. The watch becomes a sixth sense — you *feel* your coding session through haptics, *glance* at progress through complications, and *act* with gestures. The less you think about using it, the better it's working.

---

## Design System: Remmy

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `remmy-cyan` | `#00E5CC` | Build ring, primary brand, connection healthy |
| `remmy-violet` | `#BF5AF2` | Ship ring, model indicator (opus), plan mode |
| `remmy-amber` | `#FF9F0A` | Guard ring, needs attention, warnings |
| `remmy-green` | `#30D158` | Approve actions, success states |
| `remmy-red` | `#FF453A` | Reject actions, destructive, auto-accept mode |
| `remmy-blue` | `#0A84FF` | Normal mode, info states |
| `remmy-glass` | System | Liquid Glass material — do NOT use opaque fills |

### Typography
- **SF Pro Rounded** for labels, counts, ring percentages
- **SF Mono** sparingly — only for file paths and command text (not body copy)
- Watch screen is tiny: **13pt minimum** for any text the user needs to read

### Iconography
- SF Symbols exclusively. No custom icons for v1.
- Key symbols: `terminal.fill`, `checkmark.circle.fill`, `xmark.circle.fill`, `pause.fill`, `play.fill`, `flame.fill`
- The Remmy brand mark is `◎` (bullseye) — used as app icon stand-in on complications

### The Three Rings
The **Build / Ship / Guard** concentric rings are Remmy's visual signature. They appear on every surface in some form:
- **Build** (outer): Cyan `#00E5CC` — measures tool calls / work volume
- **Ship** (middle): Violet `#BF5AF2` — measures tasks completed / commits
- **Guard** (inner): Amber `#FF9F0A` — measures approvals and responses

Rings use Liquid Glass track backgrounds (`.glassEffect(.clear)`) with solid fills that have a glass sheen. In accented watch faces, rings become three luminance levels of the accent color, distinguished by position.

### Interaction Model
| Gesture | Action | Surface |
|---------|--------|---------|
| **Double-tap** (Series 9+) | Approve | App, widget, notification |
| **Single tap** | Primary action of current screen | Everywhere |
| **Wrist flick** | Defer (NOT reject) | Notifications |
| **Crown scroll** | Browse queue / history | App |
| **Long press** | Reject / secondary action | Approve button |

### Risk Tiers (Visual Treatment)
| Tier | Color Tint | Glass Style | Example |
|------|-----------|-------------|---------|
| Low | Green tint | `.buttonStyle(.glass)` | Read file, run tests |
| Medium | Amber tint | `.buttonStyle(.glass)` | Edit file, install package |
| High | Red tint | `.buttonStyle(.glassProminent)` | `rm -rf`, force push, env files |

### Always-On Display Rules
- **Show**: Pending count, ring progress, connection dot
- **Redact** (`.privacySensitive()`): File paths, command text, diff content, question text
- Reduce glass effects to flat translucent fills in AOD

---

## Agent Assignments

Each agent explores one design surface. Work independently but maintain visual consistency through the shared design system above. **Every mockup should show both the "wrist up" and "always-on display" states.**

---

### Agent 1: Complications & Watch Face

**Your surface**: The watch face itself — the thing users see 500+ times a day.

**Design these**:
1. **accessoryCircular**: Build/Ship/Guard rings with center content (pending count or streak flame). Liquid Glass track. Under `isLuminanceReduced`, simplify to single ring + count.
2. **accessoryRectangular**: Mini rings left side, three labeled progress bars right side, streak at bottom. Show both "session active" and "idle" states.
3. **accessoryCorner**: Guard ring arc wrapping the corner with pending count. This is the most "glanceable" — optimize for one-number clarity.
4. **accessoryInline**: Text-only format: `B:82 S:50 G:100 🔥3`. Explore abbreviation that reads at a glance.
5. **"Developer Face" layout**: A curated Modular Compact face with all four Remmy complications placed. Show how they compose together.

**Constraints**:
- All complications use `RelevanceConfiguration` — they appear/disappear based on session state
- Widget push updates mean the data is real-time, design for live-feeling content
- In accented mode, rings become monochrome — design must be readable without color
- Five accented rendering modes available — specify which mode each complication uses

**Explore**: What does the complication look like when there's *nothing* happening? Idle state is the most common state. It should feel calm, not broken.

---

### Agent 2: Smart Stack Widgets & Controls

**Your surface**: The scrollable widget area (Crown scroll up from watch face) and Control Center.

**Design these**:
1. **Interactive approval widget**: Shows current pending action with Approve/Reject buttons. Double-tap targets Approve. Liquid Glass buttons. Show tool name, file/command, risk tier badge.
2. **Session progress widget**: Activity rings + current task name + time elapsed. No buttons — purely informational.
3. **Activity feed widget**: Last 3-5 actions (approved/rejected) as a compact timeline. Scrollable if the system allows.
4. **Control Center tiles**: Pause/Resume, Approve, Reject, Open Remmy. Show the 2x3 grid layout from the plan. These are SF Symbol + label only.
5. **Smart Stack hint**: The circular Liquid Glass icon that appears at the bottom of the watch face when an approval is waiting. What symbol? What tint?

**Constraints**:
- `RelevanceConfiguration` means widgets appear/disappear. Design the *transition* — does it fade in? Slide?
- Interactive buttons use `Button(intent:)` with AppIntents
- Maximum two buttons per widget row
- `.buttonStyle(.glass)` for approve, `.buttonStyle(.glassProminent)` with red tint for reject
- Control Center tiles must use system-standard sizing

**Explore**: How does the widget look when 1 action is pending vs. 5 vs. 12? Does the layout change? Is there a "bulk" mode?

---

### Agent 3: Notifications

**Your surface**: The thing that taps the user's wrist and demands a decision.

**Design these**:
1. **Tool approval notification (Long Look)**: Custom `WKNotificationScene` with tool name, file/command preview (2-3 lines max), risk tier badge, model badge, and Approve/Reject buttons. This is the core interaction — spend the most time here.
2. **Question notification**: Claude is asking the user a question with 2-3 tappable option buttons. Show how options render on the small screen. Include "Handle on Mac" as last option always.
3. **Batch notification**: "3 actions pending" when multiple arrive at once. Should this show the first one expanded with a "+2 more" indicator?
4. **Session event notifications**: Task complete, session started, session ended, error. These are informational, not actionable. Keep them minimal.
5. **Short Look**: The brief flash when wrist is raised. What do users see in the 0.5s before Long Look? Just the risk tier color + tool type?

**Constraints**:
- Approve button gets `.handGestureShortcut(.primaryAction)` — double-tap approves
- Wrist flick = dismiss = defer (NOT reject). Design must make this clear without explicit instruction
- Diff preview: syntax-highlighted, 2-3 lines max, monospace. Show `+` lines in green, `-` lines in red
- Risk tier drives notification priority AND visual weight — high risk should feel heavier
- Haptic vocabulary is fixed: `.notification` for arrival, `.success` for approve, `.failure` for reject
- No custom haptics (Core Haptics unavailable on watchOS)

**Explore**: How does the notification feel different for a `Read` (low risk, maybe auto-approve) vs. a `Bash: rm -rf` (high risk, needs careful review)? Can you design a visual "weight" system?

---

### Agent 4: Activity Rings Deep Dive

**Your surface**: Remmy's visual identity — the Build/Ship/Guard ring system.

**Design these**:
1. **Ring rendering across all 4 complication families**: Circular (concentric rings), Rectangular (rings + bars), Corner (single ring arc), Inline (text). Each needs a spec.
2. **Ring states**: 0%, 25%, 50%, 75%, 100%, 150% (overlapping). What happens beyond 100%? The plan says "overlap at 60% opacity" — show this.
3. **Streak visualization**: Flame icon with day count. Blue flame at 7+ days. Where does the streak live? Center of circular? End of rectangular? Design the streak badge.
4. **"Close your rings" notification**: End-of-day nudge. "Your Guard ring is at 60%. You have 3 unanswered approvals." What does this notification look like?
5. **All rings closed celebration**: The plan says "three sequential haptic taps + visual burst." Design the visual burst. Brief, joyful, not obnoxious. This happens on the watch face complication.
6. **Ring in glass**: How do concentric rings render on a Liquid Glass surface? The track is translucent glass, the fill is solid with a glass sheen. Mock this up.

**Constraints**:
- Rings must be readable at 38mm AND 49mm (Ultra)
- In accented mode, all three rings become shades of one color — position is the only differentiator
- Guard ring can *decrease* (unanswered approvals cost -2%/min) — how is this shown? Pulsing? Draining animation?
- The center content of the circular complication changes: pulsing dot (active session), pending count (waiting), streak flame (idle but has streak)
- Ring data comes from the cloud — design for 1-2 second data staleness

**Explore**: The plan asks an open question — should rings reset daily (like Activity) or weekly? Design both and show which feels more natural for coding sessions that span multiple days.

---

### Agent 5: Main App Views

**Your surface**: The in-app experience when the user actually opens Remmy.

**Design these**:
1. **Dashboard / home**: Connection status, current task, pending count, rings summary. This is what you see 0.5s after tapping the complication. Liquid Glass cards.
2. **Approval detail view**: Full context for a pending action. Tool type icon, file path (SF Mono), command/diff preview, risk tier, model badge, large Approve/Reject buttons. The crown shouldn't scroll here — everything above the fold.
3. **Approval queue**: List of pending actions when >1 is waiting. Each row: tool icon + file/command name + risk badge. Tap to expand. "Approve All" floating button.
4. **Session history**: Scrollable list of recent actions with approve/reject status. Small green/red dots. Timestamp. Useful for "what did I approve while not paying attention?"
5. **Settings**: Pairing status, cloud URL, notification preferences, ring goals (daily targets for B/S/G), auto-approve rules. Keep it boring — settings aren't the product.
6. **Pairing flow**: Watch displays the code, user enters it in CLI. Show the code prominently (large SF Mono, spaced characters like "ABC-123"). Show the "waiting for pairing" spinner and the "paired!" confirmation.

**Constraints**:
- Every actionable view must support double-tap approve (`.handGestureShortcut`)
- Views should be glanceable in 2 seconds — no scrolling required for the primary action
- Use `NavigationStack` with `.navigationTitle` — standard watchOS chrome
- Liquid Glass cards, not opaque black backgrounds
- Minimum 44pt tap targets
- No more than 3 taps to reach any function

**Explore**: What does the app look like when there's *nothing* to do? (No active session, no pending actions.) This is the most common state. It should feel restful, not empty. Maybe the rings + streak are the idle content?

---

### Agent 6: Motion, Transitions & Micro-interactions

**Your surface**: The connective tissue — how everything *moves*.

**Design these**:
1. **Approval flow animation**: User taps Approve -> button compresses -> green pulse radiates outward -> card slides away -> next card slides in (or "all clear" state). Time budget: 300ms.
2. **Rejection flow animation**: Red pulse, card slides away with a slight shake. Heavier than approve. 300ms.
3. **Ring fill animation**: When a ring segment fills (approval counted), how does it animate? Smooth sweep? Jump? The ring should feel *alive*.
4. **Ring drain animation**: Guard ring decreasing due to unanswered approvals. Slow, visible drain. Creates gentle urgency without alarm.
5. **Connection state transitions**: Disconnected -> Connecting (pulsing) -> Connected (solid). Reconnecting (pulsing with amber tint). Use the connection dot in the top-right as the anchor.
6. **Widget appearance**: When a `RelevanceConfiguration` widget appears in the Smart Stack (session started), how does it enter? System default fade, or can we influence it?
7. **Notification -> App handoff**: User taps a notification and it opens the app. The notification content should *morph* into the approval detail view, not jump-cut.
8. **Celebration burst**: All rings closed. Brief radial burst from the ring center (200ms), then settle. Three haptic taps in sequence (`.success`, `.success`, `.success`).
9. **Glass material behavior**: When scrolling, how does the Liquid Glass refraction shift? Follow system defaults but document expectations.

**Constraints**:
- watchOS animation budget: aim for 60fps, never drop below 30fps
- No `Core Animation` on watchOS — SwiftUI animations only (`.animation(.spring)`, `.matchedGeometryEffect`, etc.)
- Haptic vocabulary is FIXED (9 `WKHapticType` values) — no custom haptic patterns
- All animations must degrade gracefully on Series 6 (no ProMotion, lower GPU)
- AOD: NO animations. Static frames only.
- Every animation should have a clear purpose (feedback, orientation, delight) — no decoration

**Explore**: What is Remmy's "personality" in motion? Apple's system animations are precise and physical. Remmy should feel... what? Responsive and minimal (like a good CLI)? Warm and supportive (like a co-pilot)? Define the motion personality in 3 adjectives and design from there.

---

## Deliverables per Agent

1. **Mockups**: High-fidelity screens for each assigned surface. Show both 41mm and 45mm sizes.
2. **AOD variants**: Every screen in always-on (luminance-reduced) mode.
3. **State matrix**: Each surface in every relevant state (empty, single item, multiple items, error, loading, disconnected).
4. **Redlines**: Spacing, font sizes, colors with tokens from the design system above.
5. **Annotations**: Call out which watchOS 26 APIs drive each design element (`.glassEffect()`, `RelevanceConfiguration`, `Button(intent:)`, etc.).

## What "Good" Looks Like

- A developer glances at their watch and *knows* whether Claude needs them — without reading a single word
- The approval flow is faster than pulling out a phone
- The rings create a daily ritual that makes developers *want* to stay engaged with their AI sessions
- Nothing looks like a shrunken phone app — every surface is designed for the wrist
- The Liquid Glass aesthetic feels native to watchOS 26, not bolted on

## What to Avoid

- This is NOT a code viewer or mini-IDE
- This is NOT a terminal on the wrist
- This is NOT a notification firehose — quality over quantity
- No social/competitive features — rings are personal
- No guilt mechanics for broken streaks — "never guilt" is a design principle
- No opaque black cards — Liquid Glass everywhere
- No custom fonts or icons — SF Pro Rounded + SF Symbols only
