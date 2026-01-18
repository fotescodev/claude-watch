# Claude Watch: Component Library Specification

**Document Version:** 1.0
**Last Updated:** January 2026
**Author:** Design Lead
**Status:** Final

---

## Overview

This document provides comprehensive specifications for all UI components in Claude Watch. Each component includes measurements, states, colors, typography, spacing, and implementation notes.

---

## Design System Foundation

### Color Palette

#### Brand Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `claude.orange` | `#FF9500` | `rgb(255, 148, 0)` | Primary brand, CTA buttons |
| `claude.orangeLight` | `#FFB340` | `rgb(255, 179, 64)` | Highlights, hover states |
| `claude.orangeDark` | `#CC7700` | `rgb(204, 119, 0)` | Active states, depth |

#### Semantic Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `semantic.success` | `#34C759` | `rgb(52, 199, 89)` | Approve, completed |
| `semantic.danger` | `#FF3B30` | `rgb(255, 59, 48)` | Reject, errors |
| `semantic.warning` | `#FF9500` | `rgb(255, 148, 0)` | Waiting, reconnecting |
| `semantic.info` | `#007AFF` | `rgb(0, 122, 255)` | Normal mode, info |

#### Surface Colors (OLED Optimized)

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `surface.background` | `#000000` | `rgb(0, 0, 0)` | App background |
| `surface.1` | `#1C1C1E` | `rgb(28, 28, 30)` | Primary cards |
| `surface.2` | `#2C2C2E` | `rgb(44, 44, 46)` | Secondary elements |
| `surface.3` | `#3A3A3C` | `rgb(58, 58, 60)` | Tertiary elements |

#### Text Colors

| Token | Value | Contrast Ratio | Usage |
|-------|-------|----------------|-------|
| `text.primary` | `#FFFFFF` | 21:1 | Main text |
| `text.secondary` | `rgba(255,255,255,0.6)` | 9.5:1 | Labels, hints |
| `text.tertiary` | `rgba(255,255,255,0.4)` | 6.3:1 | Subtle text |

#### High Contrast Adaptations

| Token | Standard | High Contrast |
|-------|----------|---------------|
| `text.secondary` | 60% white | 75% white |
| `text.tertiary` | 40% white | 60% white |
| `border.default` | 0% white | 50% white |

---

### Typography Scale

#### Font Family
- **Primary:** SF Pro (system default)
- **Monospace:** SF Mono (code, file paths)

#### Type Scale

| Level | Font Size | Weight | Line Height | Usage |
|-------|-----------|--------|-------------|-------|
| `title.large` | 20pt | Bold | 24pt | Page titles |
| `title` | 17pt | Bold | 22pt | Section headers |
| `headline` | 15pt | Semibold | 20pt | Card titles |
| `subheadline` | 13pt | Semibold | 18pt | Subtitles |
| `body` | 15pt | Regular | 20pt | Body text |
| `footnote` | 13pt | Semibold | 18pt | Button labels |
| `caption` | 12pt | Semibold | 16pt | Badges, labels |
| `caption2` | 11pt | Regular | 14pt | Hints |

#### Dynamic Type Support

All text sizes use `@ScaledMetric` for accessibility:
```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
@ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 14
```

---

### Spacing System

#### Spacing Scale (4pt Base)

| Token | Value | Usage |
|-------|-------|-------|
| `spacing.xs` | 4pt | Tight spacing |
| `spacing.sm` | 8pt | Component internal |
| `spacing.md` | 12pt | Section padding |
| `spacing.lg` | 16pt | Card padding |
| `spacing.xl` | 24pt | Major sections |

#### Corner Radius Scale

| Token | Value | Usage |
|-------|-------|-------|
| `radius.small` | 8pt | Buttons, inputs |
| `radius.medium` | 12pt | Cards, sheets |
| `radius.large` | 16pt | Large cards |
| `radius.xlarge` | 20pt | Full-width elements |
| `radius.full` | 50% | Circles, pills |

---

### Materials (Glass Effects)

| Token | Material | Usage |
|-------|----------|-------|
| `material.card` | `.ultraThinMaterial` | Card backgrounds |
| `material.overlay` | `.thinMaterial` | Sheet backgrounds |
| `material.prominent` | `.regularMaterial` | Important overlays |

#### Liquid Glass (watchOS 26+)

```swift
// Future-ready glass effect
@available(watchOS 26, *)
extension View {
    func liquidGlassBackground() -> some View {
        self.background(.liquidGlass)
    }
}
```

---

### Animation Presets

#### Spring Animations

| Token | Parameters | Usage |
|-------|------------|-------|
| `spring.button` | response: 0.35, damping: 0.7 | Button press |
| `spring.bouncy` | stiffness: 200, damping: 15 | Playful elements |
| `spring.gentle` | response: 0.5, damping: 0.8 | Page transitions |
| `spring.snappy` | response: 0.2, damping: 0.9 | Quick feedback |

#### Animation Durations

| Token | Duration | Usage |
|-------|----------|-------|
| `duration.instant` | 0.1s | Micro-interactions |
| `duration.fast` | 0.2s | Button feedback |
| `duration.normal` | 0.3s | Standard transitions |
| `duration.slow` | 0.5s | Page transitions |
| `duration.pulse` | 2.0s | Looping animations |

---

## Component Specifications

### 1. StatusHeader

**Purpose:** Display current Claude Code session status

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│                                             │
│  ┌────┐  ● Running         ┌────┐          │
│  │ ▶️ │  Building feature   │ 42 │          │
│  └────┘  ▓▓▓▓▓▓▓░░░░░░░    └────┘          │
│                                             │
│   Icon    Status Text      Badge            │
│  32×32pt                   28×28pt          │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Icon container | 32×32pt (scaled) | Right: 8pt |
| Icon size | 14pt (scaled) | Centered |
| Status dot | 8pt diameter | Right: 4pt |
| Progress bar | 100% width, 4pt height | Top: 4pt |
| Badge | 28×28pt minimum | Left: auto |

#### States

| State | Icon | Color | Badge |
|-------|------|-------|-------|
| Idle | `checkmark` | Green | Hidden |
| Running | `play.fill` | Orange | Progress % |
| Waiting | `clock.fill` | Orange | Pending count |
| Completed | `checkmark.circle.fill` | Green | Hidden |
| Failed | `exclamationmark.triangle.fill` | Red | Hidden |
| Pending | `hand.raised.fill` | Orange | Pending count |

#### Animation

- **Icon Container:** Pulsing ring animation (2s loop, scale 1.0→1.2, opacity 0.3→0)
- **Progress Bar:** Smooth width animation (0.3s)
- **Badge:** Scale bounce on count change

#### Accessibility

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("Claude status: \(status), \(progress)% complete, \(pendingCount) pending")
```

---

### 2. PrimaryActionCard

**Purpose:** Display detailed view of primary pending action

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│ ┌────────────────────────────────────────┐  │
│ │ ┌────┐                                 │  │
│ │ │ 📝 │  Edit src/App.tsx              │  │
│ │ └────┘  Add dark mode toggle to       │  │
│ │         header component               │  │
│ │                                        │  │
│ │ ┌────────────┐  ┌────────────────────┐ │  │
│ │ │  Reject    │  │     Approve        │ │  │
│ │ │   (red)    │  │     (green)        │ │  │
│ │ └────────────┘  └────────────────────┘ │  │
│ └────────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Card padding | 14pt all sides | - |
| Icon container | 40×40pt (scaled) | Right: 12pt |
| Icon size | 18pt (scaled) | Centered |
| Title | Body weight: semibold | Bottom: 2pt |
| Description | Caption, secondary color | Bottom: 12pt |
| Button gap | 8pt | - |
| Button height | 40pt | - |

#### Action Type Icons

| Type | Icon | Gradient Colors |
|------|------|-----------------|
| `file_edit` | `pencil` | Orange → Orange 80% |
| `file_create` | `doc.badge.plus` | Blue → Blue 80% |
| `file_delete` | `trash` | Red → Red 80% |
| `bash` | `terminal` | Purple → Purple 80% |
| `tool_use` | `gearshape` | Orange → Orange 80% |

#### Button Specifications

| Button | Background | Text Color | Corner Radius |
|--------|------------|------------|---------------|
| Reject | Red gradient | White | Full (capsule) |
| Approve | Green gradient | White | Full (capsule) |

#### States

| State | Visual Change |
|-------|---------------|
| Default | As designed |
| Pressed (Reject) | Scale 0.92x, darker red |
| Pressed (Approve) | Scale 0.92x, darker green |
| Loading | Buttons disabled, spinner |
| Error | Error banner appears above |

#### Animation

- **Press:** Scale 0.92x with button spring (0.35s)
- **Appear:** Slide up + fade (0.3s)
- **Dismiss:** Slide out + fade (0.3s)

#### Haptic Feedback

| Action | Haptic |
|--------|--------|
| Approve | `.success` |
| Reject | `.error` |

---

### 3. CompactActionCard

**Purpose:** Display secondary actions in condensed format

#### Visual Specification

```
┌────────────────────┐  ┌────────────────────┐
│ ┌────┐             │  │ ┌────┐             │
│ │ 📄 │ Create      │  │ │ 📝 │ Edit        │
│ └────┘ test.ts     │  │ └────┘ index.ts    │
└────────────────────┘  └────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Card padding | 10pt all sides | - |
| Icon container | 28×28pt (scaled) | Right: 8pt |
| Icon size | 12pt (scaled) | Centered |
| Title | Footnote weight: semibold | - |
| Grid gap | 8pt | - |

#### Layout

- 2-column grid
- Equal width columns
- Cards fill available width

---

### 4. CommandGrid

**Purpose:** Quick command buttons for common actions

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│                                             │
│  ┌──────────────┐  ┌──────────────┐        │
│  │      ▶️      │  │      ⚡      │        │
│  │     Go       │  │     Test     │        │
│  └──────────────┘  └──────────────┘        │
│                                             │
│  ┌──────────────┐  ┌──────────────┐        │
│  │      🔧      │  │      ⏹️      │        │
│  │     Fix      │  │     Stop     │        │
│  └──────────────┘  └──────────────┘        │
│                                             │
│  ┌──────────────────────────────────┐      │
│  │  🎤  Voice Command           ▶   │      │
│  └──────────────────────────────────┘      │
│                                             │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Grid | 2×2 | Gap: 8pt |
| Button min height | 52pt (scaled) | - |
| Icon size | 18pt (scaled) | Bottom: 4pt |
| Button corner radius | 14pt | - |
| Voice button | Full width | Top: 12pt |

#### Commands

| Command | Icon | Action Text |
|---------|------|-------------|
| Go | `play.fill` | "Continue" |
| Test | `bolt.fill` | "Run tests" |
| Fix | `wrench.fill` | "Fix errors" |
| Stop | `stop.fill` | "Stop" |
| Voice | `waveform` | Custom dictation |

#### Button States

| State | Background | Icon Color |
|-------|------------|------------|
| Default | `surface.1` | Orange |
| Pressed | `surface.2` | Orange (darker) |
| Disabled | `surface.1` 50% | Gray |

---

### 5. ModeSelector

**Purpose:** Toggle between permission modes

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│                                             │
│  Permission Mode                            │
│                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │   🔵     │ │   🔴     │ │   🟣     │    │
│  │  Normal  │ │  Auto    │ │   Plan   │    │
│  │    ●     │ │          │ │          │    │
│  └──────────┘ └──────────┘ └──────────┘    │
│                                             │
│  Review each action                         │
│                                             │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Icon container | 28×28pt (scaled) | - |
| Icon size | 12pt (scaled) | Centered |
| Mode gap | 8pt | - |
| Selection indicator | 6pt dot | Below icon |

#### Modes

| Mode | Icon | Color | Description |
|------|------|-------|-------------|
| Normal | `shield` | Blue (`#007AFF`) | Review each action |
| Auto-Accept | `bolt.fill` | Red (`#FF3B30`) | Approve automatically |
| Plan | `book` | Purple (`#AF52DE`) | Read-only planning |

#### States

| State | Visual |
|-------|--------|
| Selected | Filled background, white icon, dot indicator |
| Unselected | Transparent background, color icon |
| Pressed | Scale 0.95x |

---

### 6. ErrorBanner

**Purpose:** Display inline error messages

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│  ⚠️  Connection failed. Retry?    ✕        │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Banner height | Auto (min 36pt) | - |
| Icon size | 14pt | Right: 8pt |
| Padding | 8pt vertical, 12pt horizontal | - |
| Corner radius | Full (capsule) | - |

#### Colors

| Element | Color |
|---------|-------|
| Background | `semantic.danger` |
| Icon | White |
| Text | White |
| Dismiss button | White 70% |

#### Behavior

- Auto-dismiss after 3 seconds (configurable)
- Swipe to dismiss
- Tap dismiss button to close

---

### 7. RecordingIndicator

**Purpose:** Show active voice recording state

#### Visual Specification

```
Recording:              Not Recording:
┌──────────────────┐   ┌──────────────────┐
│                  │   │                  │
│    ◯  (pulsing)  │   │       ●          │
│   🎤 Recording   │   │                  │
│                  │   │                  │
└──────────────────┘   └──────────────────┘
```

#### Measurements

| Element | Size |
|---------|------|
| Outer ring (recording) | 24pt diameter |
| Center dot | 8pt diameter |
| Icon | 12pt |

#### Animation

- **Pulsing:** Scale 1.0→1.5, opacity 1.0→0.3, duration 0.8s
- **Color:** Red when recording, gray when idle

---

### 8. ProgressRing (Complication)

**Purpose:** Circular progress indicator for watch face

#### Visual Specification

```
      ╭───────╮
     ╱         ╲
    │     67%   │
    │   ┌───┐   │
    │   │ 🖥️ │   │
    │   └───┘   │
     ╲         ╱
      ╰───────╯
```

#### Measurements

| Element | Size |
|---------|------|
| Ring diameter | Full available |
| Ring stroke | 4pt |
| Icon size | 18pt |
| Text | Caption, bold |

#### Colors

| State | Ring Color | Fill |
|-------|------------|------|
| Progress | Green | Transparent |
| Pending | Orange | Transparent |
| Error | Red | Transparent |

#### AOD (Always-On Display)

| Mode | Opacity |
|------|---------|
| Active | 100% |
| AOD | 15% |

---

### 9. ClaudePrimaryButton

**Purpose:** Primary call-to-action button

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│                                             │
│               Approve All                   │
│                                             │
└─────────────────────────────────────────────┘
```

#### Measurements

| Property | Value |
|----------|-------|
| Height | 44pt minimum |
| Padding | 14pt vertical |
| Corner radius | Full (capsule) |
| Font | Body, bold |

#### Colors by Type

| Type | Gradient Start | Gradient End |
|------|----------------|--------------|
| Primary | Orange | Orange 80% |
| Success | Green | Green 80% |
| Danger | Red | Red 80% |
| Info | Blue | Blue 80% |

#### States

| State | Visual Change |
|-------|---------------|
| Default | As designed |
| Pressed | Scale 0.95x |
| Disabled | 50% opacity |
| Loading | Spinner replaces text |

#### Animation

```swift
.scaleEffect(configuration.isPressed ? 0.95 : 1.0)
.animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
```

#### Haptic

`.sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)`

---

### 10. VoiceInputSheet

**Purpose:** Voice command input interface

#### Visual Specification

```
┌─────────────────────────────────────────────┐
│  ← Cancel                                   │
│                                             │
│  Voice Command                              │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │ Run the test suite and fix errors   │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  Suggestions:                               │
│                                             │
│  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐   │
│  │  Go   │ │ Test  │ │  Fix  │ │ Stop  │   │
│  └───────┘ └───────┘ └───────┘ └───────┘   │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │              Send                    │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

#### Measurements

| Element | Size | Spacing |
|---------|------|---------|
| Input field | Full width, min 44pt | Bottom: 12pt |
| Suggestion chips | Auto width | Gap: 8pt |
| Send button | Full width | Top: 16pt |

#### States

| State | Input Field | Send Button |
|-------|-------------|-------------|
| Empty | Placeholder visible | Disabled |
| Recording | Red border, waveform | Disabled |
| Has text | Text visible | Enabled |
| Sending | Disabled | Loading spinner |
| Sent | "Sent" checkmark | Hidden |

---

## Accessibility Specifications

### Touch Targets

All interactive elements: **minimum 44×44pt**

### VoiceOver Labels

| Component | Label Format |
|-----------|--------------|
| StatusHeader | "Status: [status], [progress]% complete" |
| PrimaryActionCard | "[type] action: [title]. [description]" |
| ApproveButton | "Approve this action" |
| RejectButton | "Reject this action" |
| ModeSelector | "[mode] mode, [selected/not selected]" |

### Reduce Motion

All components respect `@Environment(\.accessibilityReduceMotion)`:
- Disable spring animations
- Disable pulsing effects
- Use instant transitions

### Reduce Transparency

Fallback to solid colors when transparency reduced:
```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

.background(reduceTransparency ? Claude.surface1 : .ultraThinMaterial)
```

---

## Implementation Notes

### SwiftUI Component Structure

```swift
// Example: PrimaryActionCard
struct PrimaryActionCard: View {
    let action: PendingAction
    let onApprove: () -> Void
    let onReject: () -> Void

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isApprovePressed = false
    @State private var isRejectPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: Claude.Spacing.md) {
            // Icon + Text header
            HStack(spacing: Claude.Spacing.md) {
                ActionTypeIcon(type: action.type, size: iconSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.headline)
                    Text(action.description)
                        .font(.caption)
                        .foregroundStyle(Claude.textSecondary)
                }
            }

            // Buttons
            HStack(spacing: Claude.Spacing.sm) {
                RejectButton(isPressed: $isRejectPressed, action: onReject)
                ApproveButton(isPressed: $isApprovePressed, action: onApprove)
            }
        }
        .padding(Claude.Spacing.lg)
        .background(Claude.Materials.card)
        .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.medium))
    }
}
```

### File Organization

```
ClaudeWatch/
├── DesignSystem/
│   └── Claude.swift           # All tokens
├── Views/
│   ├── Components/
│   │   ├── StatusHeader.swift
│   │   ├── PrimaryActionCard.swift
│   │   ├── CompactActionCard.swift
│   │   ├── CommandGrid.swift
│   │   ├── ModeSelector.swift
│   │   ├── ErrorBanner.swift
│   │   └── RecordingIndicator.swift
│   └── Sheets/
│       ├── VoiceInputSheet.swift
│       └── SettingsSheet.swift
└── Complications/
    └── ComplicationViews.swift
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2026 | Initial component library |

---

*Document maintained by Design Lead. Update when components change.*
