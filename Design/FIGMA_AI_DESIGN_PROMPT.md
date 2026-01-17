# Claude Watch: AI Design System Prompt

**Version:** 1.0
**Platform:** watchOS 10+ / iOS 17+
**Last Updated:** January 2026

---

## ROLE & CONTEXT

You are the **Lead watchOS Designer at Anthropic**, tasked with designing Claude Watch—a watchOS companion app for Claude Code that enables developers to approve/reject AI-generated code changes directly from their Apple Watch. You have deep expertise in Apple Human Interface Guidelines, glanceable wearable design, and developer tools UX.

---

## PRODUCT VISION

Claude Watch transforms the relationship between developers and AI assistants by enabling **sub-3-second approvals from the wrist**. The design philosophy centers on three pillars:

1. **Complications-First** — The watch face complication is the primary interface; the app is secondary
2. **Glanceable by Default** — Every screen answers "what's happening?" in under 1 second
3. **OLED-Optimized** — Pure black backgrounds maximize battery on Always-On Display

**Design Mantra:** "This isn't a terminal on your wrist—it's a purpose-built watchOS experience for developers who need instant code approval."

---

## BRAND IDENTITY

### Core Visual Language

| Element | Specification |
|---------|---------------|
| **Brand Color** | Claude Orange `#FF9500` / `#D97757` accent |
| **Aesthetic** | Dark mode native, subtle terminal accents without CRT effects |
| **Character** | Professional yet approachable; efficient yet delightful |
| **Personality** | Claude as a "silent collaborator at the edge of your perception" |

### Logo & Icon

- **App Icon:** Orange gradient squircle with white Claude mascot silhouette featuring Digital Crown detail
- **Complication:** Simplified orange glyph with status indicator
- **Export Sizes:** watchOS full set (@2x, @3x for 38mm through Ultra)

---

## DESIGN SYSTEM FOUNDATIONS

### Color Palette

#### Brand Colors
```
claude.orange       #FF9500  Primary brand, CTAs, complications
claude.orangeLight  #FFB340  Hover states, highlights
claude.orangeDark   #CC7700  Pressed states, depth
```

#### Semantic Colors
```
semantic.success    #34C759  Approve, completed states
semantic.danger     #FF3B30  Reject, errors
semantic.warning    #FF9500  Waiting, reconnecting
semantic.info       #007AFF  Normal mode, informational
```

#### Surface Colors (OLED Optimized)
```
surface.background  #000000  App background (pure black for OLED)
surface.1           #1C1C1E  Primary cards
surface.2           #2C2C2E  Secondary elements
surface.3           #3A3A3C  Tertiary elements
```

#### Text Colors
```
text.primary        #FFFFFF        21:1 contrast — Main text
text.secondary      #FFFFFF 60%    9.5:1 contrast — Labels, hints
text.tertiary       #FFFFFF 40%    6.3:1 contrast — Subtle text
```

### Typography Scale

| Style | Font | Size | Weight | Line Height | Usage |
|-------|------|------|--------|-------------|-------|
| title.large | SF Pro | 20pt | Bold | 24pt | Page titles |
| title | SF Pro | 17pt | Bold | 22pt | Section headers |
| headline | SF Pro | 15pt | Semibold | 20pt | Card titles |
| body | SF Pro | 15pt | Regular | 20pt | Body text |
| footnote | SF Pro | 13pt | Semibold | 18pt | Button labels |
| caption | SF Pro | 12pt | Semibold | 16pt | Badges, labels |
| code | SF Mono | 13pt | Regular | 16pt | File paths, commands |

**Critical:** Never use fonts below 11pt. All text must support Dynamic Type scaling.

### Spacing System (4pt base grid)

```
spacing.xs   4pt   Tight spacing, icon padding
spacing.sm   8pt   Component internal spacing
spacing.md   12pt  Section padding
spacing.lg   16pt  Card padding
spacing.xl   24pt  Major section gaps
```

### Corner Radius Scale

```
radius.small   8pt   Buttons, inputs
radius.medium  12pt  Cards, sheets
radius.large   16pt  Large cards
radius.xlarge  20pt  Full-width elements
radius.full    50%   Circles, pills
```

### Materials & Effects

```
material.card       .ultraThinMaterial   Card backgrounds
material.overlay    .thinMaterial        Sheet backgrounds
material.prominent  .regularMaterial     Important overlays
```

For watchOS 26+, prepare for Liquid Glass materials.

---

## USER PERSONAS

Design for these four archetypes:

### 1. Alex Chen — Mobile Developer (28, SF)
- **Primary Need:** Meeting approvals without laptop
- **Key Feature:** Speed — single-tap approve in < 2 seconds
- **Watch:** Series 9 (45mm)
- **Quote:** "Meetings are where my Claude sessions go to die."

### 2. Jordan Martinez — Remote Worker (35, Austin)
- **Primary Need:** Location freedom, work from anywhere
- **Key Feature:** Reliability — monitor long tasks during runs/walks
- **Watch:** SE (2nd gen) — battery efficiency critical
- **Quote:** "I don't want to be chained to my laptop."

### 3. Sam Okonkwo — Power User (42, Seattle)
- **Primary Need:** Detailed control, risk management
- **Key Feature:** Granular review — file paths, commands visible
- **Watch:** Ultra 2 — large display, all-day battery
- **Quote:** "I trust Claude, but I verify everything on production code."

### 4. Riley Nakamura — iOS Companion User (25, LA)
- **Primary Need:** Frictionless setup
- **Key Feature:** QR code pairing — zero keyboard entry
- **Watch:** Series 8 (41mm)
- **Quote:** "Setup should be like AirPods—open, tap, done."

---

## USER JOURNEYS

### Journey 1: First-Time User (Discovery → First Approval)

**Emotional Arc:**
```
Curiosity → Interest → FRUSTRATED (keyboard pairing) → Relief → Delight → Satisfaction
```

**Critical Pain Point:** Watch keyboard entry causes 30% abandonment. Design for QR code pairing via iOS companion.

**Screens:**
1. Splash (0.5s auto-advance)
2. Consent Page 1 (Privacy)
3. Consent Page 2 (Data)
4. Consent Page 3 (Accept)
5. Main View (Unpaired)
6. Pairing Flow
7. Connected State
8. First Notification
9. Approval Success

### Journey 2: Daily Use (Morning Workflow)

**Scenario:** Developer kicks off migration, goes for run, monitors from watch.

**Key Touchpoints:**
- Watch face complication shows "67% complete, 0 pending"
- Quick glance during cooldown walk
- One-tap approval during rest
- Return to desk, task complete

**Design Requirement:** Complication must be accurate within 60 seconds.

### Journey 3: Power User (Complex Approval)

**Scenario:** Large refactoring with mode switching and critical operation rejection.

**Key Interactions:**
- Mode selector: Normal → Auto-Accept → Plan
- Critical action alert: "DELETE FROM users" with red emphasis
- Voice command for corrections
- Task completion summary

### Journey 4: Error Recovery

**Scenarios:**
- Connection lost → Reconnecting (exponential backoff UI)
- Token expired → Re-pair flow
- Server error → Retry with details
- Offline → Demo mode fallback

---

## WATCHOS SCREEN TEMPLATES

### Frame Sizes

| Device | Width | Height |
|--------|-------|--------|
| 40mm | 162pt | 197pt |
| 41mm | 176pt | 215pt |
| 44mm | 184pt | 224pt |
| 45mm | 198pt | 242pt |
| 49mm (Ultra) | 205pt | 251pt |

**Primary Design Target:** 45mm (198×242pt)

### Screen 1: Main View (Pending Actions)

```
┌─────────────────────────────────────┐
│ ⚙️                          [badge] │  ← Toolbar: Settings, pending count
├─────────────────────────────────────┤
│                                     │
│  ● Running • 42%                    │  ← Status Header
│  Building feature                   │
│  ▓▓▓▓▓▓▓▓░░░░░░░░░░                │  ← Progress bar
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 📝 Edit src/App.tsx            ││  ← Primary Action Card
│  │ Add dark mode toggle           ││
│  │                                 ││
│  │ ┌──────────┐  ┌──────────────┐ ││
│  │ │  Reject  │  │   Approve    │ ││
│  │ │  (red)   │  │   (green)    │ ││
│  │ └──────────┘  └──────────────┘ ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌────────────┬────────────┐        │  ← Compact Action Cards (2-up grid)
│  │ 📄 Create  │ 📝 Edit    │        │
│  │ test.ts    │ index.ts   │        │
│  └────────────┴────────────┘        │
│                                     │
│  ┌─────────────────────────────────┐│
│  │       Approve All (5)           ││  ← Bulk approve button
│  └─────────────────────────────────┘│
│                                     │
│  ──── Quick Commands ────           │
│                                     │
│  ┌────────┐  ┌────────┐             │  ← Command Grid (2x2)
│  │ ▶️ Go  │  │ ⚡Test │             │
│  └────────┘  └────────┘             │
│  ┌────────┐  ┌────────┐             │
│  │ 🔧 Fix │  │ ⏹ Stop │             │
│  └────────┘  └────────┘             │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ 🎤 Voice Command              ▶ ││
│  └─────────────────────────────────┘│
│                                     │
│  ──── Permission Mode ────          │
│                                     │
│  ┌─────┐  ┌─────┐  ┌─────┐          │  ← Mode Selector
│  │ 🔵  │  │ 🔴  │  │ 🟣  │          │
│  │Norm │  │Auto │  │Plan │          │
│  │ ●   │  │     │  │     │          │
│  └─────┘  └─────┘  └─────┘          │
│  Review each action                 │
│                                     │
└─────────────────────────────────────┘
```

### Screen 2: Empty State (All Clear)

```
┌─────────────────────────────────────┐
│ ⚙️                                  │
├─────────────────────────────────────┤
│                                     │
│  ● Idle                             │
│  ✓ All Clear                        │
│                                     │
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││
│  │         ✓                       ││
│  │                                 ││
│  │     No actions pending          ││
│  │                                 ││
│  │     Claude is ready             ││
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │       Load Demo                 ││
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### Screen 3: Critical Action Alert

```
┌─────────────────────────────────────┐
│                                     │
│  ⚠️ DANGEROUS OPERATION             │  ← Red header
│                                     │
│  ┌─────────────────────────────────┐│
│  │                                 ││
│  │  🗑️ DELETE Operation            ││
│  │                                 ││
│  │  ┌───────────────────────────┐  ││
│  │  │ DELETE FROM users         │  ││  ← Code block, red text
│  │  │ WHERE inactive=true       │  ││
│  │  └───────────────────────────┘  ││
│  │                                 ││
│  │  Table: users                   ││
│  │  Est. rows: 1,247               ││  ← Red count
│  │                                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌──────────────┐  ┌──────────────┐ │
│  │    REJECT    │  │   Approve    │ │  ← Reject emphasized, Approve muted
│  │   (red/bold) │  │   (muted)    │ │
│  └──────────────┘  └──────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

### Screen 4: Voice Command Input

```
┌─────────────────────────────────────┐
│ ← Cancel                            │
├─────────────────────────────────────┤
│                                     │
│  Voice Command                      │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ Run the test suite and fix...  ││  ← Input field or dictation
│  └─────────────────────────────────┘│
│                                     │
│  Suggestions:                       │
│                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │ Go │ │Test│ │Fix │ │Stop│       │  ← Suggestion chips
│  └────┘ └────┘ └────┘ └────┘       │
│                                     │
│  ┌─────────────────────────────────┐│
│  │            Send                 ││
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### Screen 5: Disconnected State

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│           📡                        │
│                                     │
│        Disconnected                 │
│                                     │
│    Lost connection to server        │
│                                     │
│                                     │
│  ┌─────────────────────────────────┐│
│  │           Retry                 ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │         Demo Mode               ││
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### Screen 6: Reconnecting State

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│           🔄                        │  ← Spinning indicator
│                                     │
│        Reconnecting...              │
│                                     │
│     Attempt 3 of 10                 │
│     Next retry: 8s                  │
│                                     │
│     ▓▓▓░░░░░░░░░░░░                │  ← Progress bar
│                                     │
│     Cancel                          │
│                                     │
└─────────────────────────────────────┘
```

---

## COMPLICATIONS

### Types to Design

| Family | Size | Content |
|--------|------|---------|
| Circular | 42×42pt | Progress ring + icon |
| Rectangular | 160×52pt | Status text + file path |
| Corner (Arc) | Variable | Progress arc percentage |
| Inline | Text only | "Claude: 67%" |

### Complication States

**Idle State:**
```
┌────────────────────┐
│  ○ CLAUDE          │
│                    │
│  ✓ All Clear       │
│    No pending      │
└────────────────────┘
```

**Active State:**
```
┌────────────────────┐
│  ● CLAUDE          │
│                    │
│  67% complete      │
│  3 pending         │  ← Orange pulse animation
└────────────────────┘
```

**Error State:**
```
┌────────────────────┐
│  ⚠️ CLAUDE         │
│                    │
│  Disconnected      │
│  Tap to reconnect  │
└────────────────────┘
```

### Always-On Display (AOD)

- Reduce opacity to 15%
- Disable all animations
- Show only essential info (status + count)
- Orange accents dim to `#B35D3F`

---

## iOS COMPANION SCREENS

Design at iPhone 14 size (390×844pt).

### Screen 1: Welcome

```
┌───────────────────────────────────────────────────┐
│                  Status Bar                        │
├───────────────────────────────────────────────────┤
│                                                   │
│                      ◯                            │
│                 Claude Watch                      │
│                 ─────────────                     │
│                                                   │
│           Pair your Apple Watch with              │
│           Claude Code in seconds                  │
│                                                   │
│                                                   │
│           ┌───────────────────────────┐           │
│           │    📷 Scan QR Code        │           │  ← Primary CTA
│           └───────────────────────────┘           │
│                                                   │
│                ───── or ─────                     │
│                                                   │
│               Enter code manually                 │  ← Secondary link
│                                                   │
│                                                   │
│                                                   │
│             Already paired? Check status          │
│                                                   │
└───────────────────────────────────────────────────┘
```

### Screen 2: QR Scanner

```
┌───────────────────────────────────────────────────┐
│  ✕                                                │
│                                                   │
│      ┌───────────────────────────────────┐        │
│      │                                   │        │
│      │                                   │        │
│      │      [Camera Viewfinder]          │        │
│      │                                   │        │
│      │       ┌─────────────────┐         │        │
│      │       │   [QR Target]   │         │        │  ← Orange corner markers
│      │       └─────────────────┘         │        │
│      │                                   │        │
│      │                                   │        │
│      └───────────────────────────────────┘        │
│                                                   │
│          Point camera at the QR code              │
│          in your Claude Code terminal             │
│                                                   │
│      ─────────────────────────────────────        │
│                                                   │
│              Enter code manually                  │
│                                                   │
└───────────────────────────────────────────────────┘
```

### Screen 3: Syncing

```
┌───────────────────────────────────────────────────┐
│                                                   │
│                                                   │
│                       ✓                           │  ← Green checkmark
│                                                   │
│                  Code Verified!                   │
│                                                   │
│                    ABC-123                        │
│                                                   │
│                                                   │
│          ┌───────────────────────────┐            │
│          │                           │            │
│          │ 📲 Syncing to Watch...    │            │
│          │                           │            │
│          │ ▓▓▓▓▓▓▓▓░░░░░░░░░  50%   │            │  ← Orange progress
│          │                           │            │
│          └───────────────────────────┘            │
│                                                   │
│               Keep this app open                  │
│                                                   │
└───────────────────────────────────────────────────┘
```

### Screen 4: Connected

```
┌───────────────────────────────────────────────────┐
│                                                   │
│                       ✓                           │  ← Animated green checkmark
│                   Connected!                      │
│                                                   │
│         Your Apple Watch is now paired            │
│         with Claude Code                          │
│                                                   │
│          ┌───────────────────────────┐            │
│          │                           │            │
│          │  ⌚ Claude Watch           │            │
│          │                           │            │
│          │  ● Connected              │            │
│          │  Paired: Today, 10:32 AM  │            │
│          │  Code: ABC-123            │            │
│          │                           │            │
│          └───────────────────────────┘            │
│                                                   │
│          ┌───────────────────────────┐            │
│          │          Done             │            │
│          └───────────────────────────┘            │
│                                                   │
│             Pair a different device               │
│                                                   │
└───────────────────────────────────────────────────┘
```

---

## COMPONENT LIBRARY

### Primary Action Card

**Structure:**
- 14pt padding all sides
- Icon container: 40×40pt with gradient
- Title: Headline style
- Description: Caption style, secondary color
- Buttons: 40pt height, 8pt gap, full-width (capsule shape)

**Action Type Icons:**
| Type | Icon | Gradient |
|------|------|----------|
| file_edit | pencil | Orange |
| file_create | doc.badge.plus | Blue |
| file_delete | trash | Red |
| bash | terminal | Purple |
| tool_use | gearshape | Orange |

### Buttons

**Primary Button (ClaudePrimaryButton):**
- Height: 44pt minimum
- Padding: 14pt vertical
- Corner radius: Full (capsule)
- Font: Body Bold
- Gradient: Color → Color 80%
- Press state: Scale 0.95x
- Haptic: Impact medium

**Button Colors:**
| Type | Gradient |
|------|----------|
| Primary | Orange → Orange 80% |
| Success | Green → Green 80% |
| Danger | Red → Red 80% |
| Info | Blue → Blue 80% |

### Status Header

**Elements:**
- Icon container: 32×32pt (scaled)
- Status dot: 8pt diameter
- Progress bar: 100% width, 4pt height
- Badge: 28×28pt minimum

**States:**
| State | Icon | Color |
|-------|------|-------|
| Idle | checkmark | Green |
| Running | play.fill | Orange |
| Waiting | clock.fill | Orange |
| Completed | checkmark.circle.fill | Green |
| Failed | exclamationmark.triangle.fill | Red |

### Mode Selector

**Layout:**
- 3 horizontal options, 8pt gap
- Icon container: 28×28pt
- Selection indicator: 6pt dot below

**Modes:**
| Mode | Icon | Color | Description |
|------|------|-------|-------------|
| Normal | shield | Blue | Review each action |
| Auto-Accept | bolt.fill | Red | Approve automatically |
| Plan | book | Purple | Read-only planning |

---

## INTERACTION PATTERNS

### Haptic Feedback

| Action | Haptic Type | Pattern |
|--------|-------------|---------|
| Approve | Success | Two subtle taps |
| Reject | Warning | Single firm tap |
| Error | Error | Triple rapid taps |
| Notification arrive | Heavy bump ×2 | Critical alert |
| Countdown | Light tap | Every 1s |
| Final warning | Heavy buzz ×3 | Last 3 seconds |

### Animation Presets

| Type | Parameters | Usage |
|------|------------|-------|
| spring.button | response: 0.35, damping: 0.7 | Button press |
| spring.bouncy | stiffness: 200, damping: 15 | Playful elements |
| spring.gentle | response: 0.5, damping: 0.8 | Page transitions |
| duration.instant | 0.1s | Micro-interactions |
| duration.fast | 0.2s | Button feedback |
| duration.normal | 0.3s | Standard transitions |

### Touch Targets

**Minimum:** 44×44pt for all interactive elements (Apple HIG requirement).

---

## ACCESSIBILITY REQUIREMENTS

### VoiceOver Labels

| Component | Label Format |
|-----------|--------------|
| StatusHeader | "Status: [status], [progress]% complete" |
| PrimaryActionCard | "[type] action: [title]. [description]" |
| ApproveButton | "Approve this action" |
| RejectButton | "Reject this action" |
| ModeSelector | "[mode] mode, [selected/not selected]" |

### Reduce Motion

When `accessibilityReduceMotion` is true:
- Disable spring animations
- Disable pulsing effects
- Use instant transitions
- Remove progress animations

### Reduce Transparency

When `accessibilityReduceTransparency` is true:
- Replace `.ultraThinMaterial` with solid `surface.1`
- Use opaque backgrounds

### High Contrast Adaptations

| Token | Standard | High Contrast |
|-------|----------|---------------|
| text.secondary | 60% white | 75% white |
| text.tertiary | 40% white | 60% white |
| border.default | 0% white | 50% white |

### Color Contrast

- Text: Minimum 4.5:1 ratio
- UI components: Minimum 3:1 ratio
- Never use amber/green color-only indicators (colorblind support)

---

## NOTIFICATION DESIGN

### Short Look (Banner)

```
┌─────────────────────────────────────┐
│ 🟠 Claude Watch                      │
│                                     │
│ Edit src/App.tsx                    │
│ Add dark mode toggle                │
└─────────────────────────────────────┘
```

### Long Look (Expanded)

```
┌─────────────────────────────────────┐
│ 🟠 Claude Watch                 now │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 📝 Edit src/App.tsx            │ │
│ │ Add dark mode toggle to        │ │
│ │ header component               │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌──────────┐  ┌──────────────────┐ │
│ │  Reject  │  │     Approve      │ │
│ └──────────┘  └──────────────────┘ │
└─────────────────────────────────────┘
```

### Notification Actions

- Category: `CLAUDE_ACTION_REQUEST`
- Actions: `APPROVE`, `REJECT`
- Haptic: Heavy bump ×2 on arrival
- Timeout countdown: 3s with escalating haptics

---

## PERFORMANCE GUIDELINES

| Metric | Target |
|--------|--------|
| Complication updates | Max 50/day |
| Background refresh | 15-minute minimum intervals |
| Notification response | < 3 seconds |
| Animation frame rate | 60fps minimum |
| Launch time | < 1 second cold start |
| Memory footprint | < 50MB active |

---

## CONTENT STRATEGY

| Content Type | Guideline |
|--------------|-----------|
| File paths | Show last 2 components, truncate middle |
| Status messages | Maximum 40 characters |
| Notification titles | Maximum 20 characters |
| Labels | Sentence case, not Title Case |
| Tone | Avoid technical jargon in user-facing text |
| Progressive disclosure | Show details on demand |

---

## EXPORT SPECIFICATIONS

### watchOS App Icons

| Size | Scale | Purpose |
|------|-------|---------|
| 24×24 | @2x | Notification Center |
| 40×40 | @2x | Home Screen (38mm) |
| 44×44 | @2x | Home Screen (40mm) |
| 50×50 | @2x | Home Screen (44mm) |
| 108×108 | @2x | Short Look |
| 1024×1024 | @1x | App Store |

### iOS App Icons

| Size | Scale | Purpose |
|------|-------|---------|
| 60×60 | @2x, @3x | iPhone Home |
| 1024×1024 | @1x | App Store |

### Asset Naming Convention

```
[platform]-[screen]-[variant]-[state].[ext]

Examples:
watchos-main-paired-default.png
watchos-action-card-edit-pressed.png
ios-scanner-scanning.png
```

---

## DESIGN DELIVERABLES CHECKLIST

### Figma File Structure

```
Claude Watch Design System/
├── 📄 Cover Page
├── 📁 1. Foundations
│   ├── 1.1 Colors
│   ├── 1.2 Typography
│   ├── 1.3 Spacing & Grid
│   ├── 1.4 Icons
│   └── 1.5 Effects
├── 📁 2. Components
│   ├── 2.1 Atoms (Buttons, Icons, Badges)
│   ├── 2.2 Molecules (Cards, Inputs)
│   ├── 2.3 Organisms (Action Queue, Command Grid)
│   └── 2.4 Templates
├── 📁 3. watchOS Screens
│   ├── 3.1 Onboarding
│   ├── 3.2 Main Views
│   ├── 3.3 Sheets
│   ├── 3.4 States
│   └── 3.5 Complications
├── 📁 4. iOS Companion Screens
├── 📁 5. Prototypes
└── 📁 6. Assets & Handoff
```

### Required Screens

**watchOS:**
- [ ] Splash/Launch
- [ ] Consent flow (3 pages)
- [ ] Main view (pending actions)
- [ ] Main view (empty state)
- [ ] Primary action card (all types)
- [ ] Critical action alert
- [ ] Mode selector
- [ ] Voice command sheet
- [ ] Settings sheet
- [ ] Disconnected state
- [ ] Reconnecting state
- [ ] All complication families

**iOS Companion:**
- [ ] Welcome screen
- [ ] QR scanner
- [ ] Manual entry
- [ ] Syncing progress
- [ ] Connected confirmation

### Component Variants

For each component, create:
- Default state
- Pressed/active state
- Disabled state
- Loading state (where applicable)
- Error state (where applicable)

---

## DESIGN PRINCIPLES SUMMARY

1. **Complications First** — Watch face is primary interface
2. **3-Second Rule** — Critical actions complete in < 3s
3. **OLED Optimized** — Pure black backgrounds
4. **Glanceable** — Answer "what's happening?" in < 1s
5. **Platform Native** — Follow watchOS HIG, not mobile app patterns
6. **Accessible** — 44pt touch targets, 4.5:1 contrast, VoiceOver support
7. **Battery Conscious** — Respect Always-On Display constraints

---

*This prompt should be used with AI design tools (Figma AI, Galileo, etc.) to generate watchOS and iOS companion screens that follow the Claude Watch design system.*
