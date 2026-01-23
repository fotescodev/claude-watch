# Claude Watch — Figma Kit Requirements V2.0

**Version:** 2.0
**Last Updated:** January 2026
**Purpose:** Complete Figma component library for Claude Watch watchOS interface
**Brand Foundation:** Official Anthropic brand identity
**Changelog:** Added Question Card, Todo Progress, Session List, Context Warning, Sub-Agent components, Quick Undo screen

---

## 1. Design Tokens

### 1.1 Color Palette — Anthropic Brand

Based on [Official Anthropic Brand Guidelines](https://www.anthropic.com/brand).

#### Core Brand Colors

| Token | Hex | Usage | Brand Reference |
|-------|-----|-------|-----------------|
| `--anthropic-dark` | `#141413` | Primary dark, text on light | Anthropic Dark |
| `--anthropic-light` | `#faf9f5` | Light backgrounds, text on dark | Anthropic Light (Parchment) |
| `--anthropic-mid-gray` | `#b0aea5` | Secondary elements, muted text | Anthropic Mid Gray |
| `--anthropic-light-gray` | `#e8e6dc` | Subtle backgrounds, dividers | Anthropic Light Gray |

#### Accent Colors

| Token | Hex | Usage | Brand Reference |
|-------|-----|-------|-----------------|
| `--anthropic-orange` | `#d97757` | Primary accent, CTAs, warnings | Anthropic Orange |
| `--anthropic-blue` | `#6a9bcc` | Secondary accent, info, questions | Anthropic Blue |
| `--anthropic-green` | `#788c5d` | Success, completed, approve | Anthropic Green |

#### Semantic Colors (Derived)

| Token | Hex | Usage | Derivation |
|-------|-----|-------|------------|
| `--cc-approve` | `#788c5d` | Approve actions | Anthropic Green |
| `--cc-reject` | `#c75a4d` | Reject, errors | Brand-derived red |
| `--cc-warning` | `#d97757` | Warnings, context pressure | Anthropic Orange |
| `--cc-info` | `#6a9bcc` | Informational, questions | Anthropic Blue |
| `--cc-neutral` | `#b0aea5` | Disabled, secondary | Anthropic Mid Gray |

#### Mode Colors

| Token | Hex | Usage | Mode |
|-------|-----|-------|------|
| `--cc-mode-normal` | `#6a9bcc` | Normal mode indicator | Anthropic Blue |
| `--cc-mode-auto` | `#d97757` | Auto-Accept indicator | Anthropic Orange |
| `--cc-mode-plan` | `#788c5d` | Plan mode indicator | Anthropic Green |

#### Background Colors (OLED-Optimized)

| Token | Hex | Usage |
|-------|-----|-------|
| `--cc-bg-primary` | `#000000` | Main background (pure black) |
| `--cc-bg-elevated` | `#141413` | Cards, sheets |
| `--cc-bg-secondary` | `#1e1e1d` | Secondary containers |
| `--cc-bg-tertiary` | `#2a2a28` | Hover/pressed states |

#### Text Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--cc-text-primary` | `#faf9f5` | Primary text |
| `--cc-text-secondary` | `#b0aea5` | Secondary text |
| `--cc-text-tertiary` | `rgba(176,174,165,0.6)` | Hints |
| `--cc-text-inverse` | `#141413` | Text on light |

### 1.2 Typography — Anthropic Brand Fonts

| Context | Font | Fallback |
|---------|------|----------|
| Headings | Poppins | SF Pro Rounded → Arial |
| Body | Lora | SF Pro Text → Georgia |
| Monospace | SF Mono | Menlo → Courier |

#### Type Scale

| Token | Size | Weight | Font | Usage |
|-------|------|--------|------|-------|
| `--cc-type-title-lg` | 20pt | 600 | Poppins | Screen titles |
| `--cc-type-title` | 17pt | 600 | Poppins | Card titles |
| `--cc-type-body` | 15pt | 400 | Lora | Body text |
| `--cc-type-body-emphasis` | 15pt | 600 | Lora | Emphasis |
| `--cc-type-caption` | 13pt | 400 | Lora | Captions |
| `--cc-type-footnote` | 11pt | 400 | Lora | Fine print |
| `--cc-type-code` | 13pt | 400 | SF Mono | Code |

### 1.3 Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `--cc-space-xxs` | 2pt | Minimal gaps |
| `--cc-space-xs` | 4pt | Tight spacing |
| `--cc-space-sm` | 8pt | Standard |
| `--cc-space-md` | 12pt | Card padding |
| `--cc-space-lg` | 16pt | Section spacing |
| `--cc-space-xl` | 20pt | Screen padding |
| `--cc-space-xxl` | 24pt | Large breaks |

### 1.4 Corner Radius

| Token | Value | Usage |
|-------|-------|-------|
| `--cc-radius-sm` | 6pt | Small buttons |
| `--cc-radius-md` | 10pt | Cards |
| `--cc-radius-lg` | 14pt | Sheets |
| `--cc-radius-pill` | 9999pt | Pills |
| `--cc-radius-circle` | 50% | Circular |

### 1.5 Animation Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--cc-duration-fast` | 150ms | Micro-interactions |
| `--cc-duration-normal` | 250ms | Standard |
| `--cc-duration-slow` | 400ms | Page transitions |

---

## 2. Component Library

### 2.1 Approval Card

**Variants**: Edit, Create, Delete (danger), Bash, Tool

```
┌─────────────────────────────────────┐
│  [Icon] Edit: auth.ts               │  <- Poppins Semibold, primary
│  +12 -3 lines • 2 hunks             │  <- Lora Regular, secondary
│                                     │
│  ┌─────────────┐ ┌────────────────┐ │
│  │   Approve   │ │     Reject     │ │
│  │   (green)   │ │     (red)      │ │
│  └─────────────┘ └────────────────┘ │
└─────────────────────────────────────┘

Danger Variant (Delete):
- Red left border (4pt)
- Warning icon
- Reject button prominent
```

**Specs**:
- Width: Screen width - 16pt
- Background: `--cc-bg-elevated`
- Corner radius: `--cc-radius-md`
- Padding: 12pt
- Button height: 44pt (Apple minimum)
- Button spacing: 8pt

### 2.2 Question Card **NEW V2.0**

**Purpose**: Display AskUserQuestion from Claude

```
┌─────────────────────────────────────┐
│  ❓ QUESTION                        │  <- Poppins Semibold, blue
├─────────────────────────────────────┤
│                                     │
│  Which testing framework?           │  <- Lora Regular, primary
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ● Jest (Recommended)            ││  <- Selected option
│  │   Standard for React            ││  <- Description, secondary
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Vitest                        ││  <- Unselected
│  │   Fast, Vite-native             ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Mocha                         ││
│  │   Flexible, configurable        ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │    🎤 Other (dictate)           ││  <- Voice input option
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Multi-Select Variant:
- Checkbox instead of radio
- "Submit" button at bottom
```

**Specs**:
- Header icon: `questionmark.circle.fill` (SF Symbols)
- Header color: `--anthropic-blue`
- Option row height: 52pt minimum
- Radio/checkbox size: 22pt
- Selected state: Blue border + fill

### 2.3 Todo Progress Card **NEW V2.0**

**Purpose**: Read-only display of TodoWrite progress

```
┌─────────────────────────────────────┐
│  📋 PROGRESS                        │  <- Poppins Semibold
├─────────────────────────────────────┤
│                                     │
│  ✓ Initialize project               │  <- Completed (dimmed)
│  ✓ Set up database                  │  <- Completed
│  ● Creating user model...           │  <- In progress (highlighted)
│  ○ Add authentication               │  <- Pending
│  ○ Write tests                      │  <- Pending
│                                     │
│  ────────────────────────────────   │
│  2/5 complete                       │  <- Progress summary
│                                     │
└─────────────────────────────────────┘
```

**Specs**:
- ✓ Completed: `--cc-text-secondary`, strikethrough optional
- ● In progress: `--anthropic-orange`, animated pulse
- ○ Pending: `--cc-text-tertiary`
- Progress bar: `--anthropic-green` fill

### 2.4 Session List Item **NEW V2.0**

**Purpose**: Display resumable session in F15 flow

```
┌─────────────────────────────────────┐
│  myproject/feature-auth             │  <- Poppins Semibold
│  15 min ago                         │  <- Lora Caption, secondary
│                                     │
│  ┌───────────────────┐              │
│  │ Context: 72%      │              │  <- Progress pill
│  │ ████████░░        │              │
│  └───────────────────┘              │
│                                     │
│  ┌─────────────────────────────────┐│
│  │          [Resume]               ││  <- Primary action
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Specs**:
- Context indicator: Inline progress bar
- Resume button: `--anthropic-orange` background
- Timestamp: Relative time ("15 min ago")

### 2.5 Context Warning Card **NEW V2.0**

**Purpose**: Proactive alert for context pressure (F16)

```
┌─────────────────────────────────────┐
│  ⚠️ CONTEXT WARNING                 │  <- Orange header
├─────────────────────────────────────┤
│                                     │
│  Context usage at 85%               │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ████████████████░░░ 170K/200K   ││  <- Progress bar
│  └─────────────────────────────────┘│
│                                     │
│  Compaction recommended.            │
│  Estimated savings: ~50K tokens     │
│                                     │
│  ┌─────────────────────────────────┐│
│  │       [Compact Now]             ││  <- Primary action
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │         [Dismiss]               ││  <- Secondary action
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Specs**:
- Progress bar colors:
  - 0-74%: `--anthropic-green`
  - 75-84%: `--anthropic-orange`
  - 85%+: `--cc-reject` (red)
- Compact button: `--anthropic-orange`

### 2.6 Sub-Agent Task Row **NEW V2.0**

**Purpose**: Nested display of sub-agents in Tasks view (F19)

```
┌─────────────────────────────────────┐
│  🟢 Main Session                    │
│     Building auth system            │
│                                     │
│     └─ 🔵 explore (45%)            │  <- Nested, indented
│        Research OAuth patterns      │
│                                     │
│     └─ 🔵 Bash                     │  <- Second sub-agent
│        npm install                  │
└─────────────────────────────────────┘
```

**Specs**:
- Indent: 24pt for nested items
- Connection line: 1pt, `--cc-text-tertiary`
- Progress inline: "(45%)" in caption style

### 2.7 Quick Undo Confirmation **NEW V2.0**

**Purpose**: Simplified rewind confirmation (F17)

```
┌─────────────────────────────────────┐
│  ↶ UNDO LAST CHANGE?                │  <- Poppins Semibold
├─────────────────────────────────────┤
│                                     │
│  Revert changes to:                 │
│                                     │
│  • src/auth.ts (+15 -3)             │  <- File list
│  • src/config.ts (+2 -1)            │
│                                     │
│  ┌─────────────┐ ┌────────────────┐ │
│  │   Cancel    │ │     Undo       │ │
│  │   (gray)    │ │    (orange)    │ │
│  └─────────────┘ └────────────────┘ │
└─────────────────────────────────────┘
```

**Specs**:
- Undo button: `--anthropic-orange`
- Cancel button: `--cc-bg-tertiary`
- File list: Monospace, `--cc-type-code`

### 2.8 Mode Selector

**Purpose**: Permission mode toggle

```
┌─────────────────────────────────────┐
│  ⚙️ PERMISSION MODE                 │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────────┐│
│  │  📖  PLAN                       ││  <- Green border when selected
│  │      Claude analyzes only       ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │  🛡️  NORMAL  ●                  ││  <- Blue border when selected
│  │      Ask before each action     ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │  ⚡  AUTO-ACCEPT                ││  <- Orange border when selected
│  │      Auto-approve file edits    ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Specs**:
- Selected: 2pt colored border + dot indicator
- Mode colors: Plan=Green, Normal=Blue, Auto=Orange

### 2.9 Status Header

**Purpose**: Top-of-screen status summary

```
┌─────────────────────────────────────┐
│  🟢 Connected         Normal  🛡️    │
│  myproject • main     72% ████░░   │
└─────────────────────────────────────┘
```

**Specs**:
- Height: 44pt
- Connection indicator: 8pt circle
- Mode icon: 16pt, colored per mode
- Context bar: 40pt wide

### 2.10 Task Card

**Variants**: Running, Background, Failed, Completed

```
Running:
┌─────────────────────────────────────┐
│  🟢 npm run build                   │
│  Running • 2m 34s                   │
│  "Building for production..."       │
│  [Stop] [Background]                │
└─────────────────────────────────────┘

Failed:
┌─────────────────────────────────────┐
│  🔴 lint:fix                        │
│  Failed • Exit 1                    │
│  "ESLint: 3 errors found"           │
│  [View Error] [Retry]               │
└─────────────────────────────────────┘
```

**Specs**:
- Status indicators:
  - 🟢 Running: `--anthropic-green`
  - 🔵 Background: `--anthropic-blue`
  - 🔴 Failed: `--cc-reject`
  - ✅ Completed: `--cc-text-secondary`
- Last line: `--cc-type-code`, truncated

### 2.11 Quick Command Button

**Purpose**: Go, Test, Fix, Stop, Resume, Compact, Undo

```
┌───────────┐
│   ▶️      │  <- SF Symbol
│   Go      │  <- Caption text
└───────────┘
```

**V2.0 New Commands**:
- Resume: `arrow.counterclockwise`
- Compact: `arrow.down.circle`
- Undo: `arrow.uturn.backward`

**Specs**:
- Size: 44×52pt (icon + label)
- Icon: 24pt SF Symbol
- Background: `--cc-bg-elevated`
- Active: `--anthropic-orange` tint

### 2.12 Notification Banner

**Purpose**: Push notification inline display

```
┌─────────────────────────────────────┐
│  📝 Edit: App.tsx                   │
│  Add dark mode toggle               │
│                                     │
│  [Approve]            [Reject]      │
└─────────────────────────────────────┘
```

**Specs**:
- Appears at top of screen
- Swipe to dismiss
- Action buttons: 44pt height

---

## 3. Screen Templates

### 3.1 Approval Inbox Screen

```
┌─────────────────────────────────────┐
│  Status Header                      │
├─────────────────────────────────────┤
│  📥 APPROVALS (3)                   │
│                                     │
│  [Approval Card 1]                  │
│  [Approval Card 2]                  │
│  [Question Card] <- V2.0            │
│                                     │
│  [Approve All Edits]                │
└─────────────────────────────────────┘
```

### 3.2 Tasks Screen

```
┌─────────────────────────────────────┐
│  Status Header                      │
├─────────────────────────────────────┤
│  🔄 TASKS (2)                       │
│                                     │
│  [Task Card - Main]                 │
│    └─ [Sub-Agent Row] <- V2.0       │
│    └─ [Sub-Agent Row]               │
│  [Task Card - Background]           │
│                                     │
│  [Todo Progress Card] <- V2.0       │
└─────────────────────────────────────┘
```

### 3.3 Session Resume Screen **NEW V2.0**

```
┌─────────────────────────────────────┐
│  ↻ RECENT SESSIONS                  │
├─────────────────────────────────────┤
│                                     │
│  [Session List Item 1]              │
│  [Session List Item 2]              │
│  [Session List Item 3]              │
│                                     │
│  No active session                  │
└─────────────────────────────────────┘
```

### 3.4 Context Warning Screen **NEW V2.0**

```
┌─────────────────────────────────────┐
│  [Context Warning Card]             │
└─────────────────────────────────────┘
```

### 3.5 Question Response Screen **NEW V2.0**

```
┌─────────────────────────────────────┐
│  [Question Card - Full Screen]      │
└─────────────────────────────────────┘
```

### 3.6 Quick Undo Screen **NEW V2.0**

```
┌─────────────────────────────────────┐
│  [Quick Undo Confirmation]          │
└─────────────────────────────────────┘
```

### 3.7 Status Glance Screen

```
┌─────────────────────────────────────┐
│  CLAUDE CODE                        │
├─────────────────────────────────────┤
│  🟢 Connected                       │
│                                     │
│  Model: Claude Sonnet 4             │
│  Mode:  Normal                      │
│                                     │
│  Project: /myapp                    │
│  Branch:  main (dirty)              │
│                                     │
│  Context: 72% [████████░░]          │
│                                     │
│  📥 3 approvals                     │
│  ❓ 1 question <- V2.0              │
│  🔄 2 tasks                         │
│  📋 2/5 todos <- V2.0               │
│                                     │
│  [Inbox] [Tasks] [Mode]             │
└─────────────────────────────────────┘
```

### 3.8 Mode Selection Screen

```
┌─────────────────────────────────────┐
│  [Mode Selector Component]          │
└─────────────────────────────────────┘
```

---

## 4. Watch Face Complications

### 4.1 Circular Small

```
┌───────┐
│  ⚡   │  <- Mode icon (colored)
│  3    │  <- Badge count
└───────┘
```

### 4.2 Circular Large

```
┌───────────┐
│   CC 85%  │  <- Progress ring
│    🛡️     │  <- Mode icon
│   3 📥    │  <- Pending count
└───────────┘
```

### 4.3 Rectangular

```
┌─────────────────┐
│ Claude    🟢 85%│
│ Normal • 3 📥   │
└─────────────────┘
```

### 4.4 Inline

```
CC: 85% • 3 pending
```

---

## 5. Interaction States

### 5.1 Button States

| State | Background | Text | Border |
|-------|------------|------|--------|
| Default | Token color | `--cc-text-primary` | None |
| Pressed | Darkened 15% | Primary | None |
| Disabled | `--cc-bg-tertiary` | `--cc-text-tertiary` | None |

### 5.2 Card States

| State | Background | Effect |
|-------|------------|--------|
| Default | `--cc-bg-elevated` | None |
| Pressed | `--cc-bg-tertiary` | Scale 0.98 |
| Selected | Elevated | Colored border |

### 5.3 Haptic Feedback

| Event | Haptic | WatchKit |
|-------|--------|----------|
| Approval success | Success | `.success` |
| Rejection | Error | `.failure` |
| Question arrival | Notification | `.notification` |
| Context warning | Warning | `.warning` |
| Mode change | Click | `.click` |
| Error | Strong | `.error` |

---

## 6. Accessibility

### 6.1 Contrast Ratios (WCAG AA)

| Combination | Ratio | Pass |
|-------------|-------|------|
| Primary text on black | 18.5:1 | ✓ |
| Secondary text on black | 8.4:1 | ✓ |
| Orange on black | 5.2:1 | ✓ |
| Blue on black | 4.8:1 | ✓ |
| Green on black | 4.5:1 | ✓ |

### 6.2 Touch Targets

- Minimum: 44×44pt (Apple guideline)
- Recommended: 48×48pt
- Button spacing: 8pt minimum

### 6.3 VoiceOver Labels

All interactive elements include:
- Accessible label
- Accessibility hint
- Accessibility traits

---

## 7. Brand Implementation Checklist

### Colors ✓
- [ ] Anthropic Orange (#d97757) as primary CTA
- [ ] Anthropic Blue (#6a9bcc) for info/questions
- [ ] Anthropic Green (#788c5d) for success/approve
- [ ] Pure black background for OLED
- [ ] Anthropic Light (#faf9f5) for text

### Typography ✓
- [ ] Poppins for all headings
- [ ] Lora for body text
- [ ] SF Mono for code/paths

### Components V2.0 ✓
- [ ] Approval Card (5 variants)
- [ ] Question Card (single/multi-select)
- [ ] Todo Progress Card
- [ ] Session List Item
- [ ] Context Warning Card
- [ ] Sub-Agent Task Row
- [ ] Quick Undo Confirmation
- [ ] Mode Selector
- [ ] Status Header
- [ ] Task Card (4 variants)
- [ ] Quick Command Button (7 commands)
- [ ] Notification Banner

### Screens V2.0 ✓
- [ ] Approval Inbox
- [ ] Tasks (with sub-agents, todos)
- [ ] Session Resume
- [ ] Context Warning
- [ ] Question Response
- [ ] Quick Undo
- [ ] Status Glance
- [ ] Mode Selection

---

## Appendix A: Design Token Summary

```
╔══════════════════════════════════════════════════════════════════╗
║  CLAUDE WATCH V2.0 — DESIGN TOKEN REFERENCE                      ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ANTHROPIC COLORS                                                ║
║  ┌──────┐ Dark    #141413    ┌──────┐ Orange  #d97757           ║
║  │██████│                    │██████│ Primary CTA                ║
║  └──────┘                    └──────┘                            ║
║  ┌──────┐ Light   #faf9f5    ┌──────┐ Blue    #6a9bcc           ║
║  │░░░░░░│ Text               │██████│ Info/Questions             ║
║  └──────┘                    └──────┘                            ║
║  ┌──────┐ Mid     #b0aea5    ┌──────┐ Green   #788c5d           ║
║  │▓▓▓▓▓▓│ Secondary          │██████│ Success/Approve            ║
║  └──────┘                    └──────┘                            ║
║                                                                  ║
║  MODE COLORS                                                     ║
║  Normal:  Blue (#6a9bcc)                                         ║
║  Auto:    Orange (#d97757)                                       ║
║  Plan:    Green (#788c5d)                                        ║
║                                                                  ║
║  TYPOGRAPHY                                                      ║
║  Headings: Poppins Semibold                                      ║
║  Body:     Lora Regular                                          ║
║  Code:     SF Mono                                               ║
║                                                                  ║
║  V2.0 NEW COMPONENTS                                             ║
║  • Question Card (AskUserQuestion)                               ║
║  • Todo Progress Card (TodoWrite)                                ║
║  • Session List Item (Resume)                                    ║
║  • Context Warning Card                                          ║
║  • Sub-Agent Task Row (Task tool)                                ║
║  • Quick Undo Confirmation                                       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

*Document V2.0 - Complete Figma kit requirements for Claude Watch with Anthropic branding and all new components for flows F15-F21.*
