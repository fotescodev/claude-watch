# Claude Watch — Design Screens V2.0

**Version:** 2.0.1
**Last Updated:** January 2026
**Purpose:** Complete visual design specification with screen mockups for all flows and views
**Brand Foundation:** Official Anthropic Brand Identity
**Screen Sizes:** 40mm (162×197), 44mm (184×224), 45mm (198×242)

---

## Design Principles

### No Emojis Policy
All icons must use **SF Symbols** from Apple's official icon library. Emojis are not permitted in the production design. This document uses text placeholders like `[icon:symbol.name]` to indicate SF Symbol usage.

### Focused Single-Screen Design
watchOS screens should minimize scrolling. Each screen should present **one clear purpose** with **one primary action**. Complex information is paginated across multiple screens rather than stacked vertically.

---

## Design System Reference

### Brand Colors

```
┌─────────────────────────────────────────────────────────────────┐
│  ANTHROPIC COLOR PALETTE                                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────┐  Dark        #141413   Background (elevated)        │
│  │████████│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  ┌────────┐  Light       #faf9f5   Primary text                 │
│  │░░░░░░░░│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  ┌────────┐  Orange      #d97757   CTAs, warnings, Auto mode    │
│  │▓▓▓▓▓▓▓▓│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  ┌────────┐  Blue        #6a9bcc   Info, questions, Normal mode │
│  │▓▓▓▓▓▓▓▓│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  ┌────────┐  Green       #788c5d   Success, approve, Plan mode  │
│  │▓▓▓▓▓▓▓▓│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  ┌────────┐  Mid Gray    #b0aea5   Secondary text               │
│  │▒▒▒▒▒▒▒▒│                                                     │
│  └────────┘                                                     │
│                                                                 │
│  OLED Background: Pure Black #000000                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### SF Symbol Mapping

| Purpose | SF Symbol | Color |
|---------|-----------|-------|
| Connected | `circle.fill` | Green #788c5d |
| Connecting | `circle.fill` | Amber #FFCC00 |
| Disconnected | `circle.fill` | Red #c75a4d |
| No Session | `circle` | Gray #b0aea5 |
| Edit action | `pencil` | Orange #d97757 |
| Bash command | `terminal` | Purple #AF52DE |
| Question | `questionmark.circle` | Blue #6a9bcc |
| Approve | `checkmark` | Green #788c5d |
| Reject | `xmark` | Red #c75a4d |
| Plan mode | `book` | Green #788c5d |
| Normal mode | `shield` | Blue #6a9bcc |
| Auto mode | `bolt` | Orange #d97757 |
| Inbox | `tray` | Light #faf9f5 |
| Tasks | `arrow.triangle.2.circlepath` | Light #faf9f5 |
| Settings | `gearshape` | Light #faf9f5 |
| Voice | `mic` | Orange #d97757 |
| Delete | `trash` | Red #c75a4d |
| Warning | `exclamationmark.triangle` | Orange #d97757 |
| Error | `exclamationmark.circle` | Red #c75a4d |
| Success | `checkmark.circle` | Green #788c5d |
| Progress | `checklist` | Light #faf9f5 |
| Resume | `arrow.counterclockwise` | Orange #d97757 |
| Compact | `arrow.down.circle` | Blue #6a9bcc |
| Undo | `arrow.uturn.backward` | Orange #d97757 |
| Stop | `stop.fill` | Red #c75a4d |
| Play/Go | `play.fill` | Green #788c5d |
| Test | `testtube.2` | Blue #6a9bcc |
| Fix | `wrench` | Orange #d97757 |
| Background | `pause.circle` | Gray #b0aea5 |
| Sub-agent | `point.3.filled.connected.trianglepath.dotted` | Blue #6a9bcc |
| Link | `link` | Blue #6a9bcc |
| Cloud | `cloud` | Blue #6a9bcc |
| Local | `wifi` | Green #788c5d |
| Bell | `bell` | Orange #d97757 |
| Camera | `camera` | Blue #6a9bcc |
| Phone | `iphone` | Gray #b0aea5 |
| Sleep | `moon.zzz` | Gray #b0aea5 |
| Demo | `play.rectangle` | Orange #d97757 |

### Typography

```
┌─────────────────────────────────────────────────────────────────┐
│  TYPOGRAPHY SCALE                                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  POPPINS SEMIBOLD 20pt — Screen Titles                          │
│  POPPINS SEMIBOLD 17pt — Card Headers                           │
│                                                                 │
│  Lora Regular 15pt — Body text                                  │
│  Lora Regular 13pt — Captions                                   │
│  Lora Regular 11pt — Footnotes                                  │
│                                                                 │
│  SF Mono 13pt — Code and file paths                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Core Views

### 1.1 Main Status View (Home) — Single Screen

```
┌─────────────────────────────────────────┐
│                                         │
│            CLAUDE CODE                  │  ← Poppins 20pt
│                                         │
│         ┌───────────────┐               │
│         │   [icon:      │               │
│         │ circle.fill]  │               │  ← Green when connected
│         │   Connected   │               │  ← Lora 15pt
│         └───────────────┘               │
│                                         │
│  Mode:  [icon:shield] Normal            │  ← Blue icon
│  Context: 72%                           │
│  ┌─────────────────────────────────┐    │
│  │████████████████░░░░░░░░░░░░░░░░│    │  ← Progress bar
│  └─────────────────────────────────┘    │
│                                         │
│  3 pending  •  1 question               │  ← Activity summary
│                                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ [icon:  │ │ [icon:  │ │ [icon:  │   │
│  │  tray]  │ │ arrow.  │ │gearshape│   │
│  │  Inbox  │ │ Tasks   │ │  Mode   │   │  ← Navigation
│  └─────────┘ └─────────┘ └─────────┘   │
│                                         │
└─────────────────────────────────────────┘

Status Indicators (SF Symbols):
[icon:circle.fill] Green — Connected
[icon:circle.fill] Amber — Connecting
[icon:circle.fill] Red — Disconnected
[icon:circle] Gray outline — No Session
```

### 1.2 Approval Card (Single Item Focus)

Instead of a scrollable inbox, show **one approval at a time** with swipe to navigate.

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:circle.fill] Connected    1 of 3 │  ← Pagination indicator
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  [icon:pencil] EDIT                     │  ← Orange icon, Poppins 17pt
│                                         │
│  auth.ts                                │  ← SF Mono, filename
│  /src/middleware/                       │  ← Path, gray
│                                         │
│  +12  -3 lines                          │  ← Green/red stats
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │ [icon:      │ │   [icon:xmark]     │ │
│  │ checkmark]  │ │                    │ │
│  │   Approve   │ │      Reject        │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
│  Swipe for more  →                      │  ← Gray hint
│                                         │
└─────────────────────────────────────────┘

Card Types:
- Edit: [icon:pencil] Orange
- Create: [icon:doc.badge.plus] Blue
- Delete: [icon:trash] Red
- Bash: [icon:terminal] Purple
- Question: [icon:questionmark.circle] Blue
```

### 1.3 Bash Command Card

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:terminal] BASH                   │  ← Purple icon
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  npm run test                           │  ← SF Mono
│                                         │
│  in /src                                │  ← Gray path
│  Risk: Low                              │  ← Green text
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │   Approve   │ │      Reject        │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 1.4 Dangerous Operation Card

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.triangle]        │
│  DANGEROUS                              │  ← Red, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← Red left accent
│                                         │
│  [icon:trash] Delete                    │
│  config.backup.json                     │
│                                         │
│  Cannot be undone.                      │  ← Red text
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │   Cancel    │ │   Delete Anyway    │ │
│  │   (gray)    │ │      (red)         │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘

Haptic: .warning
```

### 1.5 Task Status Card (Single Focus)

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:arrow.triangle.2.circlepath]     │
│  TASK                                   │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  [icon:circle.fill] Running             │  ← Green dot
│                                         │
│  Building auth system                   │  ← Task description
│  5m 23s                                 │  ← Duration
│                                         │
│  Sub-agents: 2 active                   │  ← If applicable
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │    Stop     │ │    Background      │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### 1.6 Mode Selector (3-Option Picker)

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:gearshape] MODE                  │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:book]  PLAN                │  │  ← Green border
│  │  Analyze only                     │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │  ← Blue, selected
│  │  [icon:shield]  NORMAL       •    │  │
│  │  Ask each time                    │  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:bolt]  AUTO                │  │  ← Orange border
│  │  Auto-approve edits               │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### 1.7 Quick Commands (2x3 Grid, No Scroll)

```
┌─────────────────────────────────────────┐
│                                         │
│  COMMANDS                               │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ [icon:  │ │ [icon:  │ │ [icon:  │   │
│  │play.fill│ │testtube]│ │ wrench] │   │
│  │   Go    │ │  Test   │ │   Fix   │   │
│  └─────────┘ └─────────┘ └─────────┘   │
│                                         │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐   │
│  │ [icon:  │ │ [icon:  │ │ [icon:  │   │
│  │stop.fill│ │arrow.ccw│ │ arrow.  │   │
│  │  Stop   │ │ Resume  │ │ Compact │   │
│  └─────────┘ └─────────┘ └─────────┘   │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:mic]  Voice Command        │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

---

## Part 2: Onboarding Flows (F1-F3)

### F1: First Launch — Welcome

```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│              ╔═══════╗                  │
│              ║  CC   ║                  │  ← App icon
│              ╚═══════╝                  │
│                                         │
│           CLAUDE WATCH                  │  ← Poppins 20pt
│                                         │
│        Control Claude Code              │
│        from your wrist.                 │  ← Lora 15pt
│                                         │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         [Get Started]             │  │  ← Orange button
│  └───────────────────────────────────┘  │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

### F1: Notifications Permission

```
┌─────────────────────────────────────────┐
│                                         │
│        [icon:bell.badge]                │  ← Orange icon
│                                         │
│       STAY IN THE LOOP                  │  ← Poppins 17pt
│                                         │
│  Get notified when Claude               │
│  needs your approval.                   │  ← Lora 15pt
│                                         │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Enable Notifications]        │  │  ← Orange button
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Not Now]                │  │  ← Gray text
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F1: Connection Mode Choice

```
┌─────────────────────────────────────────┐
│                                         │
│       HOW WILL YOU CONNECT?             │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:wifi] LOCAL                │  │
│  │                                   │  │
│  │  Same network as computer         │  │
│  │  Fastest, requires proximity      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │  ← Orange, recommended
│  │  [icon:cloud] CLOUD               │  │
│  │                                   │  │
│  │  Works anywhere                   │  │
│  │  Recommended                      │  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F2: Cloud Pairing — Watch Displays Code

**KEY CHANGE:** The watch DISPLAYS the code, the user enters it on the COMPUTER.

```
Screen 1: Watch Shows Pairing Code
┌─────────────────────────────────────────┐
│                                         │
│  [icon:link] PAIR                       │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  On your computer, run:                 │  ← Lora 15pt
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  claude watch pair                │  │  ← SF Mono
│  └───────────────────────────────────┘  │
│                                         │
│  Then enter this code:                  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │       A B C 1 2 3                 │  │  ← Large, spaced letters
│  │                                   │  │     Poppins 24pt
│  └───────────────────────────────────┘  │
│                                         │
│  Code expires in 5:00                   │  ← Countdown timer
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Use QR Code Instead]         │  │  ← Blue link
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Screen 2: Waiting for Computer
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│              ┌─────────┐                │
│              │   ...   │                │  ← Animated dots
│              └─────────┘                │
│                                         │
│         WAITING...                      │  ← Poppins 17pt
│                                         │
│    Enter code ABC123 on                 │
│    your computer.                       │  ← Lora 13pt
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Cancel]                 │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Screen 3: Pairing Success
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│         [icon:checkmark.circle]         │  ← Green icon
│                                         │
│           PAIRED!                       │  ← Poppins 17pt, green
│                                         │
│       Connected to                      │
│       MacBook Pro                       │  ← Device name
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Done]                   │  │  ← Green button
│  └───────────────────────────────────┘  │
│                                         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F3: QR Code Pairing (iOS)

```
Watch Screen: Waiting for QR Scan
┌─────────────────────────────────────────┐
│                                         │
│        [icon:iphone]                    │
│                                         │
│        SCAN ON IPHONE                   │  ← Poppins 17pt
│                                         │
│  Open Claude Watch on your              │
│  iPhone and scan the QR                 │
│  code from your terminal.               │  ← Lora 15pt
│                                         │
│              ...                        │  ← Waiting animation
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Use Code Instead]            │  │  ← Blue link
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

iOS Companion: Camera View
┌─────────────────────────────────────────┐
│                                         │
│  < Back                                 │
│                                         │
│  [icon:camera] SCAN QR CODE             │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  │        [Camera Viewfinder]        │  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Point at the QR code from:             │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  claude watch pair --qr           │  │  ← SF Mono
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Enter Code Manually]         │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

---

## Part 3: Approval Flows (F4-F6)

### F4: Single Approval — Full Card

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:pencil] EDIT                     │  ← Orange, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  File: auth.ts                          │  ← SF Mono
│  Path: /src/middleware/                 │  ← Gray
│                                         │
│  Changes:                               │
│  +12 lines added                        │  ← Green
│  -3 lines removed                       │  ← Red
│                                         │
│  ┌───────────────────────────────────┐  │
│  │       [View Full Diff]            │  │  ← Blue, opens desktop
│  └───────────────────────────────────┘  │
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │   Approve   │ │       Reject       │ │
│  │   (green)   │ │       (red)        │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### F5: Bulk Approval — Summary Screen

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:tray] 5 EDITS                    │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  All file edits in:                     │
│  /src/components/                       │  ← SF Mono
│                                         │
│  Total: +42 lines, -8 lines             │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Approve All 5 Edits]         │  │  ← Green, prominent
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [Review Individually]         │  │  ← Gray
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F6: Rejection — Quick Reasons

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:xmark] REJECT                    │  ← Red, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Why reject this edit?                  │  ← Lora 15pt
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Different approach               │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Try again                        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Cancel task                      │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:mic] Voice feedback        │  │  ← Opens dictation
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F6: Rejection Confirmed

```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│         [icon:xmark.circle]             │  ← Red icon
│                                         │
│           REJECTED                      │  ← Poppins 17pt
│                                         │
│    Edit to auth.ts rejected.            │
│    Claude will try a different          │
│    approach.                            │
│                                         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .failure (light)
Auto-dismiss: 2 seconds
```

---

## Part 4: Mode & Command Flows (F7-F9)

### F7: Auto-Accept Warning

```
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.triangle]        │
│  ENABLE AUTO-ACCEPT?                    │  ← Orange, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Claude will auto-approve               │
│  all file edits.                        │
│                                         │
│  [icon:checkmark] Edits: Auto           │
│  [icon:terminal] Bash: Still asks       │
│  [icon:trash] Delete: Still asks        │
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │   Cancel    │ │      Enable        │ │
│  │             │ │     (orange)       │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘
```

### F7: Mode Changed Confirmation

```
┌─────────────────────────────────────────┐
│                                         │
│                                         │
│         [icon:bolt]                     │  ← Orange icon
│                                         │
│        AUTO-ACCEPT                      │  ← Poppins 17pt
│           ENABLED                       │
│                                         │
│    File edits will be                   │
│    auto-approved.                       │
│                                         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .click
Auto-dismiss: 1.5 seconds
```

### F8: Voice Command

```
Listening Screen:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:mic] VOICE                       │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│              ┌─────────┐                │
│              │ [icon:  │                │
│              │   mic]  │                │  ← Pulsing, orange
│              └─────────┘                │
│                                         │
│         Listening...                    │  ← Lora 15pt
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  "Add error handling to the       │  │  ← Live transcription
│  │   login function"                 │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Cancel]                 │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Sent Confirmation:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:checkmark.circle]         │  ← Green
│                                         │
│           SENT                          │
│                                         │
│    Command sent to                      │
│    Claude Code.                         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F9: Quick Command Sent

```
┌─────────────────────────────────────────┐
│                                         │
│         [icon:testtube.2]               │  ← Blue icon
│                                         │
│       RUNNING TESTS                     │  ← Poppins 17pt
│                                         │
│    "npm run test" sent                  │
│    to Claude Code.                      │  ← Lora 13pt
│                                         │
└─────────────────────────────────────────┘

Haptic: .impact(light)
```

---

## Part 5: Settings & Error Flows (F10-F14)

### F10: Settings — Organized Sections

```
Settings Main:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:gearshape] SETTINGS              │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Connection                   >   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Notifications                >   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Haptics                      >   │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  About                        >   │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Connection Detail:
┌─────────────────────────────────────────┐
│                                         │
│  < Settings                             │
│                                         │
│  CONNECTION                             │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Mode         Cloud                     │
│  Status       [icon:circle.fill] On     │  ← Green
│  Latency      42ms                      │
│  Device       MacBook Pro               │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │       [Unpair Device]             │  │  ← Red text
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F11: Notification Approval (Lock Screen)

```
Rich Notification:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:pencil] Edit: auth.ts            │
│  Add JWT validation middleware          │
│  +15 lines, 1 hunk                      │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────────┐│
│  │            Approve                  ││  ← Green
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │             Reject                  ││  ← Red
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │          Open in App                ││  ← Gray
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘

Haptic: .notification
```

### F12: Error States

```
Connection Lost:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:circle.fill]              │  ← Red
│                                         │
│       CONNECTION LOST                   │  ← Poppins 17pt
│                                         │
│    Reconnecting...                      │
│    Attempt 2 of 10                      │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         [Retry Now]               │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │       [Switch to Local]           │  │  ← Gray
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Desktop Sleeping:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:moon.zzz]                 │  ← Gray icon
│                                         │
│       DESKTOP SLEEPING                  │  ← Poppins 17pt
│                                         │
│    Wake your computer to                │
│    continue.                            │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │       [Check Connection]          │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Pairing Failed:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.triangle]        │  ← Orange
│                                         │
│        PAIRING FAILED                   │  ← Poppins 17pt
│                                         │
│    Code may have expired or             │
│    was entered incorrectly.             │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         [Try Again]               │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │      [Use QR Instead]             │  │  ← Blue
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F13: Demo Mode

```
Demo Entry:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:play.rectangle] DEMO             │  ← Orange, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Try Claude Watch without               │
│  connecting to a computer.              │
│                                         │
│  - See sample approvals                 │
│  - Test quick commands                  │
│  - Try question responses               │
│                                         │
│  No data sent anywhere.                 │  ← Gray
│                                         │
│  ┌───────────────────────────────────┐  │
│  │       [Enter Demo Mode]           │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Demo Active Banner:
┌─────────────────────────────────────────┐
│  DEMO MODE — Not connected              │  ← Orange banner
└─────────────────────────────────────────┘
```

### F14: Complications

```
Circular Small:
┌───────────┐
│           │
│  [icon:   │  ← Mode icon (colored)
│   bolt]   │
│    3      │  ← Badge count
│           │
└───────────┘

Circular Large:
┌─────────────────┐
│                 │
│    CC  85%      │  ← Progress ring
│   [icon:shield] │  ← Mode icon
│    3 pending    │
│                 │
└─────────────────┘

Rectangular:
┌───────────────────────────┐
│ Claude Code  [dot] 85%    │  ← Green dot
│ Normal - 3 pending        │
└───────────────────────────┘

Modular Large:
┌─────────────────────────────────────────┐
│  Claude Code            [dot] 85%       │
│  Normal Mode - /myproject               │
│  3 pending - 1 question - 2/5 todos     │
└─────────────────────────────────────────┘

Corner:
┌───────┐
│ CC 3  │
└───────┘

Tap: Opens Inbox (if pending) or Status
```

---

## Part 6: New V2.0 Flows (F15-F21)

### F15: Session Resume

```
No Active Session:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:circle]                   │  ← Gray outline
│                                         │
│       NO ACTIVE SESSION                 │  ← Poppins 17pt
│                                         │
│    Claude Code isn't running            │
│    or isn't connected.                  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │     [View Recent Sessions]        │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Session Card (Swipeable):
┌─────────────────────────────────────────┐
│                                         │
│  [icon:arrow.counterclockwise] RESUME   │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  myproject/feature-auth                 │  ← SF Mono
│  15 min ago                             │  ← Gray
│                                         │
│  Context: 72%                           │
│  ┌─────────────────────────────────┐    │
│  │████████████░░░░░░░░░░░░░░░░░░░░│    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Resume]                 │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
│  Swipe for more sessions  ->            │
│                                         │
└─────────────────────────────────────────┘

Resuming:
┌─────────────────────────────────────────┐
│                                         │
│      [icon:arrow.counterclockwise]      │  ← Spinning
│                                         │
│         RESUMING...                     │
│                                         │
│    myproject/feature-auth               │
│                                         │
└─────────────────────────────────────────┘

Resumed:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:checkmark.circle]         │  ← Green
│                                         │
│          RESUMED                        │  ← Green text
│                                         │
│    72% context remaining.               │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F16: Context Warning

```
Warning at 85%:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.triangle]        │
│  CONTEXT WARNING                        │  ← Orange, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Usage at 85%                           │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │█████████████████████████░░░░░░░░░│  │  ← Orange bar
│  └───────────────────────────────────┘  │
│  170,000 / 200,000 tokens               │
│                                         │
│  Compaction recommended.                │
│  Save ~50K tokens.                      │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        [Compact Now]              │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Dismiss]                │  │  ← Gray
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .warning

Critical at 95%:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.circle]          │
│  CRITICAL                               │  ← Red, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Context at 95%                         │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │█████████████████████████████████░│  │  ← Red bar
│  └───────────────────────────────────┘  │
│  190,000 / 200,000 tokens               │
│                                         │
│  Session may fail soon!                 │  ← Red text
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        [Compact Now]              │  │  ← Red button
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .error (strong)

Compacting:
┌─────────────────────────────────────────┐
│                                         │
│      [icon:arrow.down.circle]           │  ← Animating
│                                         │
│        COMPACTING...                    │
│                                         │
│    Summarizing history...               │
│                                         │
└─────────────────────────────────────────┘

Compacted:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:checkmark.circle]         │  ← Green
│                                         │
│         COMPACTED                       │  ← Green text
│                                         │
│    Freed 52,000 tokens.                 │
│    Now at 68%.                          │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F17: Quick Undo

```
Undo Confirmation:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:arrow.uturn.backward]            │
│  UNDO LAST CHANGE?                      │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Revert changes to:                     │
│                                         │
│  - src/auth.ts (+15 -3)                 │  ← SF Mono
│  - src/config.ts (+2 -1)                │
│                                         │
│  Restores to previous state.            │  ← Gray
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │   Cancel    │ │       Undo         │ │
│  │   (gray)    │ │     (orange)       │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘

Undoing:
┌─────────────────────────────────────────┐
│                                         │
│      [icon:arrow.uturn.backward]        │  ← Rotating
│                                         │
│        REVERTING...                     │
│                                         │
│    Restoring 2 files...                 │
│                                         │
└─────────────────────────────────────────┘

Undone:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:checkmark.circle]         │  ← Green
│                                         │
│           UNDONE                        │  ← Green text
│                                         │
│    2 files restored.                    │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success

No Checkpoint:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:exclamationmark.triangle]        │  ← Orange
│                                         │
│      NO CHECKPOINT                      │
│                                         │
│    No recent changes to undo.           │
│    Use desktop for full rewind.         │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            [OK]                   │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### F18: Question Response

```
Question Card (Single Select):
┌─────────────────────────────────────────┐
│                                         │
│  [icon:questionmark.circle] QUESTION    │  ← Blue, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Which testing framework?               │  ← Lora 15pt
│                                         │
│  ┌───────────────────────────────────┐  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │  ← Blue, selected
│  │  [*] Jest (Recommended)           │  │
│  │      Standard for React           │  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [ ] Vitest                       │  │
│  │      Fast, Vite-native            │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [ ] Mocha                        │  │
│  │      Flexible, configurable       │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:mic] Other (voice)         │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Multi-Select Question:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:questionmark.circle] QUESTION    │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Which features? (Select all)           │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [x] Authentication               │  │  ← Checked
│  │      User login and signup        │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [x] Authorization                │  │  ← Checked
│  │      Role-based access            │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [ ] Password Reset               │  │  ← Unchecked
│  │      Email-based recovery         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │          [Submit]                 │  │  ← Blue
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Answer Sent:
┌─────────────────────────────────────────┐
│                                         │
│         [icon:checkmark.circle]         │  ← Green
│                                         │
│        ANSWER SENT                      │  ← Green text
│                                         │
│    "Jest" selected.                     │
│    Claude will continue.                │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F19: Sub-Agent Monitoring

```
Task with Sub-Agents:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:arrow.triangle.2.circlepath]     │
│  TASK                                   │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  [icon:circle.fill] Running             │  ← Green
│  Building authentication                │
│  5m 23s                                 │
│                                         │
│  Sub-agents: 2 active                   │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ [icon:point.3] explore 45%      │    │  ← Blue
│  │ [icon:terminal] bash            │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │  Stop All   │ │     Details        │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘

Sub-Agent Detail:
┌─────────────────────────────────────────┐
│                                         │
│  < Back                                 │
│                                         │
│  [icon:point.3] EXPLORE                 │  ← Blue, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Research OAuth patterns                │
│                                         │
│  Status: Running (45%)                  │
│  Runtime: 2m 14s                        │
│  Parent: Main Session                   │
│                                         │
│  Current:                               │
│  Reading auth.middleware.ts             │  ← SF Mono
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         [Stop Agent]              │  │  ← Red
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Agent Completed:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:checkmark.circle] COMPLETE       │  ← Green
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  explore agent finished                 │
│  Duration: 3m 42s                       │
│                                         │
│  Found 3 OAuth implementations.         │
│  Recommending passport.js.              │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            [OK]                   │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success
```

### F20: Todo Progress

```
Progress Card:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:checklist] PROGRESS              │  ← Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  [done] Initialize project              │  ← Gray, checkmark
│  [done] Set up database                 │  ← Gray, checkmark
│  [>] Creating user model...             │  ← Orange, active
│  [ ] Add authentication                 │  ← Gray outline
│  [ ] Write tests                        │  ← Gray outline
│                                         │
│  ┌─────────────────────────────────┐    │
│  │██████████████░░░░░░░░░░░░░░░░░░│    │  ← Green bar
│  └─────────────────────────────────┘    │
│  2/5 complete (40%)                     │
│                                         │
│  READ-ONLY                              │  ← Gray footnote
│                                         │
└─────────────────────────────────────────┘

States:
[done] = checkmark, gray text
[>] = filled circle, white text, orange icon
[ ] = empty circle, 60% gray text
```

### F21: Background Task Alert

```
Notification:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:pause.circle] Backgrounded       │
│  "npm run build" moved to               │
│  background.                            │
│                                         │
│  [View]               [Dismiss]         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .notification

Background Task Card:
┌─────────────────────────────────────────┐
│                                         │
│  [icon:pause.circle] BACKGROUND         │  ← Gray, Poppins 17pt
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  npm run build                          │  ← SF Mono
│  Backgrounded - 2m 45s                  │
│                                         │
│  Last output:                           │
│  "Building for production..."           │  ← Gray
│                                         │
│  ┌─────────────┐ ┌────────────────────┐ │
│  │ Bring Front │ │       Stop         │ │
│  └─────────────┘ └────────────────────┘ │
│                                         │
└─────────────────────────────────────────┘

Task Completed:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:checkmark.circle] Complete       │
│  "npm run build" finished.              │
│                                         │
│  [View Output]        [Dismiss]         │
│                                         │
└─────────────────────────────────────────┘

Task Failed:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:xmark.circle] Failed             │
│  "npm run build" exited with            │
│  error code 1.                          │
│                                         │
│  [View Error]         [Dismiss]         │
│                                         │
└─────────────────────────────────────────┘

Haptic: .error
```

---

## Part 7: Animation & Transition Specs

### Screen Transitions

| Transition | Duration | Easing | Effect |
|------------|----------|--------|--------|
| Push | 250ms | easeInOut | Slide from right |
| Pop | 250ms | easeInOut | Slide to right |
| Modal | 300ms | spring(0.35) | Slide from bottom |
| Dismiss | 250ms | easeOut | Slide down + fade |

### Micro-Interactions

| Element | Duration | Effect |
|---------|----------|--------|
| Button press | 150ms | Scale 0.95, darken 15% |
| Card press | 100ms | Scale 0.98, elevate |
| Radio select | 200ms | Bounce 1.0-1.1-1.0 |
| Progress bar | 400ms | Width animate, easeOut |

### Loading States

| State | Animation | Duration |
|-------|-----------|----------|
| Spinner | Rotating dots | 1000ms/rotation |
| Pulse | Scale 1.0-1.2 | 800ms |
| Shimmer | Left-to-right gradient | 1500ms |

---

## Part 8: Accessibility

### VoiceOver Labels

```
Approval Card:
- Label: "Edit request for auth.ts. 12 lines added, 3 removed."
- Hint: "Double tap Approve or Reject."

Question Card:
- Label: "Question: Which testing framework? 3 options. Jest recommended."
- Hint: "Select option or tap Other to dictate."

Mode Indicator:
- Label: "Permission mode: Normal. Asks before each action."
- Hint: "Double tap to change mode."
```

### Dynamic Type

| Size | Title | Body | Caption |
|------|-------|------|---------|
| Default | 20pt | 15pt | 13pt |
| Larger | 24pt | 18pt | 16pt |
| Largest | 28pt | 22pt | 19pt |

### Reduce Motion

When enabled:
- Replace animations with cross-fades
- Disable pulse effects
- Use instant transitions
- Keep haptic feedback

---

## Appendix A: Screen Index

| Screen | Flow | Priority |
|--------|------|----------|
| Main Status | Home | P0 |
| Approval Card | F4 | P0 |
| Bulk Approval | F5 | P0 |
| Rejection | F6 | P0 |
| Task Status | F19-F21 | P0 |
| Mode Selector | F7 | P0 |
| Quick Commands | F9 | P1 |
| Settings | F10 | P2 |
| Welcome | F1 | P0 |
| Pairing (Code Display) | F2 | P0 |
| Pairing (QR) | F3 | P0 |
| Session Resume | F15 | P0 |
| Context Warning | F16 | P1 |
| Quick Undo | F17 | P2 |
| Question Response | F18 | P0 |
| Sub-Agent Detail | F19 | P2 |
| Todo Progress | F20 | P2 |
| Error Recovery | F12 | P1 |
| Demo Mode | F13 | P2 |

---

## Appendix B: Haptic Feedback Map

| Event | WatchKit Type | Intensity |
|-------|---------------|-----------|
| Approval success | .success | Medium |
| Rejection | .failure | Light |
| Question arrival | .notification | Medium |
| Context warning 85% | .warning | Medium |
| Context critical 95% | .error | Strong |
| Mode change | .click | Light |
| Button press | .impact(light) | Light |
| Selection change | .selection | Subtle |
| Session resumed | .success | Medium |
| Undo complete | .success | Medium |
| Sub-agent complete | .success | Light |
| Todo progress | .subtle | Subtle |
| Background task | .notification | Medium |
| Error state | .error | Strong |

---

## Appendix C: Color Quick Reference

| Purpose | Hex | Token |
|---------|-----|-------|
| OLED Background | #000000 | bg-primary |
| Elevated Surface | #141413 | bg-elevated |
| Secondary Container | #1e1e1d | bg-secondary |
| Pressed State | #2a2a28 | bg-pressed |
| Primary Text | #faf9f5 | text-primary |
| Secondary Text | #b0aea5 | text-secondary |
| Hint Text | 60% opacity | text-hint |
| Success/Approve/Plan | #788c5d | semantic-success |
| Error/Reject | #c75a4d | semantic-error |
| Warning/CTA/Auto | #d97757 | semantic-warning |
| Info/Question/Normal | #6a9bcc | semantic-info |
| Connected | #788c5d | status-connected |
| Connecting | #FFCC00 | status-connecting |
| Disconnected | #c75a4d | status-disconnected |

---

---

## Part 9: Complications Deep Dive

Complications provide at-a-glance information on watch faces, enabling quick access to Claude Watch status without opening the app.

### 9.1 Complication Families

#### Circular Small (Corner)
Minimal badge display for compact watch faces.

```
┌─────────────────┐
│                 │
│    [icon:CC]    │  ← App icon or mode icon
│        3        │  ← Badge count (if pending)
│                 │
└─────────────────┘

States:
- No session: Gray CC icon, no badge
- Connected, idle: Green CC icon, no badge
- Pending approvals: Mode icon + orange badge count
- Question waiting: Blue [icon:questionmark.circle] + pulse
```

#### Circular Large (Graphic Circular)
Rich circular complication with progress ring.

```
┌───────────────────────────┐
│                           │
│      ┌───────────┐        │
│      │  ╭─────╮  │        │  ← Progress ring (context %)
│      │  │ CC  │  │        │     Stroke: 3pt, colored by mode
│      │  │shield│ │        │  ← Mode icon center
│      │  ╰─────╯  │        │
│      └───────────┘        │
│         3 pending         │  ← Bottom text
│                           │
└───────────────────────────┘

Ring colors by context %:
- 0-70%: Green #788c5d
- 71-84%: Blue #6a9bcc
- 85-94%: Orange #d97757
- 95-100%: Red #c75a4d (pulsing)
```

#### Rectangular (Modular Compact)
Horizontal layout for modular watch faces.

```
┌─────────────────────────────────────────────────┐
│                                                 │
│  [icon:circle.fill] Claude  •  72%  •  3        │
│                                                 │
└─────────────────────────────────────────────────┘

Layout:
[status dot] [app name] • [context %] • [pending count]

Dot colors: Green/Amber/Red based on connection
```

#### Modular Large (Graphic Rectangular)
Full-featured complication with multiple data points.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  [icon:circle.fill] Claude Code         72% [▓▓▓▓░░░]      │
│  [icon:shield] Normal  •  /myproject/feature-auth           │
│  3 pending  •  1 question  •  2/5 todos                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Row 1: Status dot + App name + Context bar
Row 2: Mode icon + Mode name + Project path
Row 3: Activity summary (pending, questions, todos)
```

#### Extra Large (Ultra-specific)
For Apple Watch Ultra's larger display.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  CLAUDE CODE                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  [icon:circle.fill] Connected    [icon:shield] Normal   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Context: 72%  ┌─────────────────────────────────────────┐      │
│                │██████████████████████░░░░░░░░░░░░░░░░░░│      │
│                └─────────────────────────────────────────┘      │
│                                                                 │
│  [icon:pencil] 2 edits   [icon:terminal] 1 bash   [icon:?] 1 q  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 9.2 Complication States

| State | Visual | Tap Action |
|-------|--------|------------|
| No session | Gray icon, "No session" | Open app |
| Connected, idle | Green dot, mode icon | Open Status |
| Pending approvals | Badge count, orange | Open Inbox |
| Question waiting | Blue pulse | Open Question |
| Context warning | Orange ring | Open Warning |
| Context critical | Red pulse + badge | Open Warning |
| Task running | Spinning icon | Open Task |
| Error | Red dot | Open Error screen |

### 9.3 Complication Refresh

- **Timeline entries**: 15-minute intervals for context %
- **Push updates**: Immediate for pending items, questions
- **Background refresh**: When significant state changes
- **Keep current**: Connection status always live via WidgetKit

---

## Part 10: Stacked Tasks (Envelope Metaphor)

Visualize multiple pending approvals as a "stack of envelopes" to convey urgency and quantity.

### 10.1 Stack Visual Concept

```
Single Item (no stack):
┌─────────────────────────────────────────┐
│  [icon:pencil] EDIT                     │
│  auth.ts                                │
│  +12 -3                                 │
│  [Approve]  [Reject]                    │
└─────────────────────────────────────────┘

Multiple Items (stacked effect):
         ┌─────────────────────────────────┐
       ┌─│─────────────────────────────────│─┐
     ┌─│─│─────────────────────────────────│─│─┐
     │ │ │  [icon:pencil] EDIT        1/5  │ │ │  ← Visible card
     │ │ │  auth.ts                        │ │ │
     │ │ │  +12 -3                         │ │ │
     │ │ │  [Approve]  [Reject]            │ │ │
     │ │ └─────────────────────────────────┘ │ │
     │ └───────────────────────────────────┴─┘ │  ← Stack shadows
     └─────────────────────────────────────────┘    (offset 2px each)
```

### 10.2 Stack Animation

**Swipe to next card:**
```
Step 1: Current card visible
┌─────────────────────────────────┐
│ auth.ts  [1/5]                  │
└─────────────────────────────────┘
         ↑ swipe up or left

Step 2: Card slides away, next rises
     ↗ ┌───────────────┐ (outgoing)
       └───────────────┘
              ↑
┌─────────────────────────────────┐
│ config.ts  [2/5]                │ (incoming, scales 0.95→1.0)
└─────────────────────────────────┘

Step 3: New card in place
┌─────────────────────────────────┐
│ config.ts  [2/5]                │
└─────────────────────────────────┘
```

**Stack depth visual:**
```
5+ items:    4 items:      3 items:      2 items:      1 item:
  ┌┬┬┬┐       ┌┬┬┐          ┌┬┐           ┌┐
  ││││        │││           ││            │
  ├┴┴┴┤       ├┴┴┤          ├┴┤           ├┤            ┌──┐
  │   │       │  │          │ │           │             │  │
  └───┘       └──┘          └─┘           └             └──┘
```

### 10.3 Stack Interactions

| Gesture | Action |
|---------|--------|
| Swipe left | Next card in stack |
| Swipe right | Previous card |
| Swipe up | Quick approve |
| Swipe down | Dismiss to inbox |
| Long press | Bulk action menu |
| Digital Crown turn | Scroll through stack |

### 10.4 Stack Badge (Home Screen)

```
┌─────────────────────────────────────────┐
│  [icon:tray] INBOX                      │
│                                         │
│      ┌───────────────────┐              │
│      │   ┌─────────────┐ │              │  ← Mini envelope stack
│      │   │ [3 pending] │ │              │
│      │   └─────────────┘ │              │
│      └┬──┴───────────────┘              │
│       └─┐                               │  ← Stack offset shadow
│                                         │
└─────────────────────────────────────────┘
```

---

## Part 11: Watch Face Integration

Custom watch face designs that deeply integrate Claude Watch status.

### 11.1 Dedicated Claude Watch Face

A full watch face themed for developers using Claude Code.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                     10:42                                   │  ← Time, large
│                   MON JAN 20                                │  ← Date
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  [icon:circle.fill] Connected                       │    │
│  │  [icon:shield] Normal Mode                          │    │
│  │  ┌───────────────────────────────────────────┐      │    │
│  │  │████████████████████░░░░░░░░░░░░░░░░░░░░░░│      │    │
│  │  └───────────────────────────────────────────┘      │    │
│  │  Context: 72%                                       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │ [icon:   │    │ [icon:   │    │ [icon:   │              │
│  │  tray]   │    │ terminal]│    │  mic]    │              │
│  │    3     │    │  Tasks   │    │  Voice   │              │
│  └──────────┘    └──────────┘    └──────────┘              │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Colors:
- Background: Pure black #000000
- Accent ring: Mode color (Blue for Normal)
- Badge: Orange #d97757 when pending
```

### 11.2 Infograph Modular Layout

Optimal placement for Infograph Modular face.

```
┌─────────────────────────────────────────────────────────────┐
│ [corner]                              10:42       [corner]  │
│  Weather                                           Battery  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           CLAUDE CODE (Modular Large)               │    │
│  │  [dot] Connected  •  Normal  •  /feature-auth       │    │
│  │  3 pending  •  1 question  •  72% context           │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Activity   │  │  Heart Rate  │  │   Calendar   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 11.3 Watch Face Suggestions

| Watch Face | Recommended Placement | Complication Family |
|------------|----------------------|---------------------|
| Infograph | Center | Modular Large |
| Infograph Modular | Top | Graphic Rectangular |
| Modular | Large slot | Modular Large |
| California | Sub-dial | Circular |
| Numerals Duo | Corner | Circular Small |
| Contour | Inside dial | Circular Large |
| Siri | Smart Stack | Graphic Rectangular |

### 11.4 Smart Stack Card

For Siri watch face and Smart Stack widget.

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  [icon:CC] CLAUDE CODE                                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  [icon:pencil] Edit: auth.ts                        │    │
│  │  Add JWT validation                                 │    │
│  │  +15 lines                                          │    │
│  │                                                     │    │
│  │  [Approve]              [Reject]                    │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  2 more pending...                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘

Smart Stack shows this card when:
- New approval arrives
- Question needs response
- Context reaches warning threshold
- Task completes/fails
```

---

## Part 12: Interactive Notifications

Rich notifications with inline actions that don't require opening the app.

### 12.1 Approval Notification (Actionable)

```
Short Look (wrist raise):
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│  Edit: auth.ts                          │
│                                         │
└─────────────────────────────────────────┘

Long Look (lower wrist slightly or tap):
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                now        │
│                                         │
│  [icon:pencil] Edit Request             │  ← Orange icon
│                                         │
│  auth.ts                                │  ← SF Mono
│  Add JWT validation middleware          │  ← Description
│  +15 lines, -3 lines                    │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Approve                 │  │  ← Green button
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Reject                  │  │  ← Red button
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         View Details              │  │  ← Opens app
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .notification
```

### 12.2 Question Notification (Inline Response)

```
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:questionmark.circle] Question    │  ← Blue icon
│                                         │
│  Which testing framework?               │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │      Jest (Recommended)           │  │  ← Option 1
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Vitest                 │  │  ← Option 2
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Mocha                  │  │  ← Option 3
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │      [icon:mic] Other             │  │  ← Voice dictation
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .notification (distinct pattern for questions)
```

### 12.3 Bash Command Notification

```
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:terminal] Bash Command           │  ← Purple icon
│                                         │
│  npm run build                          │  ← SF Mono
│  in /myproject                          │  ← Gray path
│                                         │
│  Risk: Low                              │  ← Green text
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Allow                  │  │  ← Green
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │            Deny                   │  │  ← Red
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### 12.4 Dangerous Operation Notification

```
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:exclamationmark.triangle]        │  ← Red icon, pulsing
│  DANGEROUS OPERATION                    │  ← Red text
│                                         │
│  rm -rf node_modules/                   │  ← SF Mono
│  in /myproject                          │
│                                         │
│  This cannot be undone.                 │  ← Red warning
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Cancel                  │  │  ← Gray, primary
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        Allow Anyway               │  │  ← Red text
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .error (strong, repeated)
```

### 12.5 Context Warning Notification

```
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:exclamationmark.triangle]        │  ← Orange icon
│  Context at 85%                         │
│                                         │
│  Session may need compaction            │
│  soon to continue working.              │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         Compact Now               │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Dismiss                 │  │  ← Gray
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .warning
```

### 12.6 Task Completion Notification

```
Success:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:checkmark.circle] Complete       │  ← Green icon
│                                         │
│  "Build auth system" finished           │
│  successfully.                          │
│                                         │
│  Duration: 5m 23s                       │
│  Changes: 8 files modified              │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         View Summary              │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Dismiss                 │  │
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .success

Failed:
┌─────────────────────────────────────────┐
│                                         │
│  CLAUDE WATCH                           │
│                                         │
│  [icon:xmark.circle] Failed             │  ← Red icon
│                                         │
│  "Build auth system" encountered        │
│  an error.                              │
│                                         │
│  npm ERR! Cannot find module            │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────────────────────────┐  │
│  │         View Error                │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │        Ask Claude to Fix          │  │  ← Orange
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘

Haptic: .error
```

### 12.7 Notification Categories

| Category | Priority | Haptic | Auto-dismiss |
|----------|----------|--------|--------------|
| Approval (edit) | High | .notification | No |
| Approval (bash) | High | .notification | No |
| Dangerous | Critical | .error (x2) | No |
| Question | High | .notification | No |
| Context warning | Medium | .warning | 30s |
| Context critical | Critical | .error | No |
| Task complete | Low | .success | 10s |
| Task failed | High | .error | No |
| Background task | Low | .subtle | 5s |

---

## Part 13: Digital Crown Interactions

The Digital Crown provides precise, tactile control for scrolling, selection, and value adjustment.

### 13.1 Crown Behaviors by Context

| Screen | Crown Action | Haptic |
|--------|--------------|--------|
| Approval stack | Navigate between cards | .click per card |
| Question options | Highlight options | .selection per option |
| Context progress | Scrub through history | None (smooth) |
| Mode selector | Cycle through modes | .click per mode |
| Settings list | Scroll vertically | None (smooth) |
| Session list | Navigate sessions | .click per session |
| Todo list | Scroll through items | None (smooth) |
| Timer/countdown | Adjust time | .click per increment |

### 13.2 Crown in Approval Stack

```
┌─────────────────────────────────────────┐
│  [icon:pencil] EDIT              1 of 5 │
│                                         │
│  auth.ts                                │
│  +12 -3 lines                           │
│                                         │
│  [Approve]  [Reject]                    │
│                                         │
│  ↻ Crown: Next/Prev card                │  ← Hint text
└─────────────────────────────────────────┘

Crown turn clockwise: Next card (1→2→3...)
Crown turn counter-clockwise: Previous card
Haptic: .click at each card boundary

Visual feedback:
- Card slides left, new card enters from right (clockwise)
- Card slides right, prev card enters from left (counter-clockwise)
- Subtle rubber-band effect at stack ends
```

### 13.3 Crown in Question Selection

```
┌─────────────────────────────────────────┐
│  [icon:questionmark.circle] QUESTION    │
│                                         │
│  Which testing framework?               │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Jest (Recommended)               │  │  ← Highlighted
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  Vitest                           │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ↻ Crown: Scroll  •  Press: Select      │
└─────────────────────────────────────────┘

Crown turn: Moves highlight between options
Crown press: Selects highlighted option
Haptic: .selection when highlight moves
```

### 13.4 Crown in Mode Selector

```
┌─────────────────────────────────────────┐
│  [icon:gearshape] MODE                  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:book] Plan                 │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │  ← Selected (Normal)
│  │  [icon:shield] Normal         •   │  │
│  │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │  [icon:bolt] Auto                 │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ↻ Crown: Cycle modes                   │
└─────────────────────────────────────────┘

Crown turn: Cycles Plan → Normal → Auto → Plan...
Crown press: Confirms mode change
Haptic: .click at each mode boundary
```

### 13.5 Crown in Context History

View past context usage as a timeline.

```
┌─────────────────────────────────────────┐
│  [icon:clock] CONTEXT HISTORY           │
│                                         │
│  Now: 72%                               │
│  ┌─────────────────────────────────┐    │
│  │███████████████░░░░░░░░░░░░░░░░░│    │
│  └─────────────────────────────────┘    │
│                                         │
│  ↻ Scrub timeline                       │
│                                         │
│  ──●────────────────────────────        │  ← Timeline scrubber
│  10:42 AM                               │
│                                         │
│  At this point:                         │
│  - 145,000 tokens used                  │
│  - Working on: auth.ts                  │
│                                         │
└─────────────────────────────────────────┘

Crown turn: Scrub through session timeline
No haptic (smooth scrolling for fine control)
```

### 13.6 Crown Press Actions

| Screen | Crown Press Action |
|--------|-------------------|
| Approval card | Approve (quick approve) |
| Question | Select highlighted option |
| Mode selector | Confirm mode change |
| Settings | Enter selected section |
| Commands | Execute highlighted command |
| Status | Open inbox if pending |

### 13.7 Crown Sensitivity Settings

```
Settings > Digital Crown:
┌─────────────────────────────────────────┐
│                                         │
│  DIGITAL CROWN                          │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Haptic Feedback                        │
│  ┌───────────────────────────────────┐  │
│  │  On                          [●]  │  │  ← Toggle
│  └───────────────────────────────────┘  │
│                                         │
│  Sensitivity                            │
│  ┌───────────────────────────────────┐  │
│  │  Low   ●────────○   High          │  │  ← Slider
│  └───────────────────────────────────┘  │
│                                         │
│  Quick Approve on Press                 │
│  ┌───────────────────────────────────┐  │
│  │  Off                         [ ]  │  │  ← Toggle
│  └───────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

---

## Appendix D: Interaction Gesture Summary

| Gesture | Primary Action | Context |
|---------|---------------|---------|
| Tap | Select/Activate | Buttons, cards, options |
| Double tap | Quick approve | Approval cards |
| Long press | Context menu | Cards, list items |
| Swipe left | Next item / Dismiss | Stacked cards, notifications |
| Swipe right | Previous item / Back | Stacked cards, navigation |
| Swipe up | Quick approve | Approval cards |
| Swipe down | Dismiss / Reject | Cards, sheets |
| Crown turn | Navigate / Scroll | Lists, stacks, options |
| Crown press | Select / Confirm | Highlighted items |
| Raise to wake | Show notification | Time-sensitive alerts |
| Cover to dismiss | Dismiss notification | Any notification |

---

## Appendix E: Notification Sound & Haptic Map

| Event | Sound | Haptic | Duration |
|-------|-------|--------|----------|
| Edit approval | Chime (subtle) | .notification | 400ms |
| Bash approval | Chime (subtle) | .notification | 400ms |
| Dangerous op | Alert (2 tones) | .error + .error | 800ms |
| Question | Chime (ascending) | .notification | 500ms |
| Context 85% | Alert (single) | .warning | 300ms |
| Context 95% | Alert (urgent) | .error | 600ms |
| Task complete | Success tone | .success | 300ms |
| Task failed | Error tone | .error | 400ms |
| Session resumed | Chime (warm) | .success | 300ms |
| Connection lost | Alert (2 tones) | .error | 500ms |
| Reconnected | Chime (subtle) | .success | 200ms |

---

*Document V2.0.2 — Extended with complications deep dive, stacked task envelopes, watch face integration, interactive notifications with inline actions, and comprehensive digital crown interaction specifications.*
