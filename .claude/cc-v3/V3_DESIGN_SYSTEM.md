# Claude Watch V3 Design System

> **Source**: `/Users/dfotesco/CLAUDE/v2.pen`
> **Last Updated**: 2026-01-26
> **Watch Size**: 45mm Apple Watch (198×242 pixels)

---

## Color Palette (11 Tokens)

| Token | Hex | Swatch | Usage | Node ID |
|-------|-----|--------|-------|---------|
| **Brand** | `#d97757` | ![](https://via.placeholder.com/20/d97757/d97757) | Logo, headers, primary accent, Claude icon | `7feWQ` |
| **Success** | `#34C759` | ![](https://via.placeholder.com/20/34C759/34C759) | Approve, checkmarks, completion, Tier 1 | `mmumu` |
| **Warning** | `#FF9500` | ![](https://via.placeholder.com/20/FF9500/FF9500) | Approval needed, attention, Tier 2 | `al2Mf` |
| **Error** | `#FF3B30` | ![](https://via.placeholder.com/20/FF3B30/FF3B30) | Reject, errors, destructive, Tier 3 | `n8rX7` |
| **Muted** | `#8E8E93` | ![](https://via.placeholder.com/20/8E8E93/8E8E93) | Inactive, neutral, secondary text | `hJYKS` |
| **Working** | `#007AFF` | ![](https://via.placeholder.com/20/007AFF/007AFF) | Active, progress, working state | `9I1B8` |
| **Idle** | `#8E8E93` | ![](https://via.placeholder.com/20/8E8E93/8E8E93) | Listening state (same as Muted) | `DawX1` |
| **Plan** | `#5E5CE6` | ![](https://via.placeholder.com/20/5E5CE6/5E5CE6) | Plan mode indicator | `0L16p` |
| **Context** | `#FFD60A` | ![](https://via.placeholder.com/20/FFD60A/FFD60A) | Context usage warning | `KdFe0` |
| **Question** | `#BF5AF2` | ![](https://via.placeholder.com/20/BF5AF2/BF5AF2) | Question/input needed | `D9zov` |

### Card Background (Gradient)

```css
/* Card gradient - subtle glass effect */
background: linear-gradient(180deg, #ffffff12 0%, #ffffff08 100%);
```

Node ID: `9h3de`

### Glow Colors (30% opacity)

| Glow | Fill | Node ID |
|------|------|---------|
| GlowSuccess | `#34c75930` | `Js5cj` |
| GlowWarning | `#FF950030` | `vRGO1` |
| GlowError | `#FF3B3030` | `cxyD9` |
| GlowBrand | `#d9775730` | `6stpW` |
| GlowWorking | `#007AFF30` | `jIrsu` |
| GlowPlan | `#5E5CE630` | `gTjM3` |
| GlowContext | `#FFD60A30` | `v4qmR` |
| GlowQuestion | `#BF5AF230` | `5sGcV` |

**Glow Specs**: 100×80px ellipse, 35px blur radius

---

## Typography

### Font Families

| Family | Usage | Example |
|--------|-------|---------|
| **Poppins** | Titles, headers | "Claude Watch V2" (28pt 600) |
| **Inter** | Body text, labels, buttons | Most UI text |
| **JetBrains Mono** | Code, badges, digits | "EDIT", "A7X9" |

### Type Scale

| Size | Weight | Usage | Example |
|------|--------|-------|---------|
| 28pt | 600 (Poppins) | Main title | "Claude Watch V2" |
| 20pt | 600 (Poppins) | Flow headers | "Onboarding & Session" |
| 18pt | 600 (Inter) | Section titles | "Design Tokens" |
| 17pt | 600 (Inter) | Card titles | "Fixed auth bug" |
| 16pt | 600 (JetBrains) | Code digits | "A" in pairing code |
| 15pt | 600 (Inter) | Card primary | "src/auth.ts" |
| 14pt | 600 (Inter) | Button labels | "Approve", "Reject" |
| 13pt | normal (Inter) | Body | "2 min ago" |
| 12pt | normal (Inter) | Descriptions | "Update JWT validation" |
| 11pt | 600 (Inter) | Status text | "1 pending" |
| 11pt | normal (Inter) | Instructions | "Enter code from terminal" |
| 10pt | 700 (JetBrains) | Badges | "EDIT", "RUN", "DELETE" |
| 10pt | 600 (Inter) | Percentage | "67%" |
| 10pt | normal (Inter) | Hints | "Double tap to dismiss" |
| 9pt | 500 (Inter) | Hint text | Subtle hints |

### Text Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#FFFFFF` | Main text |
| Secondary | `#9A9A9F` | Descriptions |
| Tertiary | `#6E6E73` | Hints, stats |
| Muted | `#8E8E93` | Inactive, time |
| Disabled | `#636366` | Disabled icons |

---

## Spacing & Layout

### WatchFrame

```
Width: 198px
Height: 242px
Corner Radius: 40px
Padding: 16px
Background: #000000
Layout: vertical, space-between
```

Node ID: `xq1TN`

### Radius Tokens

| Element | Radius |
|---------|--------|
| WatchFrame | 40px |
| Cards | 16px |
| Buttons | 20px |
| Badges | 6px |
| Code digits | 6px |
| Status dots | 4px |
| Icon backgrounds | 8-12px |

### Padding/Gap Tokens

| Element | Padding | Gap |
|---------|---------|-----|
| WatchFrame | 16px | - |
| Cards | 14-16px | 8-10px |
| Buttons | 12px × 24px | - |
| Badges | 2px × 8px | - |
| Status bar | - | 6px |
| Footer nav | - | space-around |

---

## Components (52 Total)

### Core Layout

| Component | Node ID | Description |
|-----------|---------|-------------|
| WatchFrame | `xq1TN` | 198×242, 40px radius, black fill |
| StatusBar | `owt0z` | Status dot + label + time |
| FooterNav | `bnp90` | History + Settings buttons |

### Cards

| Component | Node ID | Description |
|-----------|---------|-------------|
| TaskCard | `DyPD1` | Badge + title + description |
| ActivityCard | `qZtDo` | Title + time ago + stats |
| StateCard | `GQAr2` | Icon + title + description |
| QueueItem | `Zn2U9` | Dot + text (compact) |
| TimelineEvent | `xIDkR` | Time + event type + detail |

### Buttons

| Component | Node ID | Description |
|-----------|---------|-------------|
| ApproveButton | `hRRRh` | Green gradient, black text |
| RejectButton | `HWrpH` | Red fill, white text |
| PrimaryButton | `UKM5L` | Brand color, white text |
| SecondaryButton | `kCR66` | White 20% fill, white text |
| PauseButton | `FuJHm` | White 10% fill, pause icon |
| ActionButtonRow | `s1LF1` | Yes/No button pair |

### Mode Indicators

| Component | Node ID | Shape | Color |
|-----------|---------|-------|-------|
| ModeNormal | `UTp3g` | Circle | `#34C759` |
| ModePlan | `x66K4` | Rounded square | `#5E5CE6` |
| ModeAuto | `py2vf` | Pill | `#FF9500` |

### Badges

| Component | Node ID | Color | Text Color |
|-----------|---------|-------|------------|
| BadgeEdit | `VqvhO` | `#34C759` | Black |
| BadgeRun | `4DEUE` | `#FF9500` | Black |
| BadgeDelete | `qF0Vr` | `#FF3B30` | White |

### Status Dots (8×8, 4px radius)

| Component | Node ID | Color |
|-----------|---------|-------|
| StatusDotSuccess | `2POpe` | `#34C759` |
| StatusDotWarning | `vsTAG` | `#FF9500` |
| StatusDotError | `gZ7Il` | `#FF3B30` |
| StatusDotWorking | `EsmaD` | `#007AFF` |
| StatusDotIdle | `SZbC7` | `#8E8E93` |
| StatusDotQuestion | `XraV9` | `#BF5AF2` |
| StatusDotContext | `qaZyx` | `#FFD60A` |
| StatusDotBrand | `qKzkx` | `#d97757` |

### Icons

| Component | Node ID | Size | Radius |
|-----------|---------|------|--------|
| ClaudeIconLarge | `WHyA0` | 48×48 | 12px |
| ClaudeIconMedium | `rmFbi` | 32×32 | 8px |
| ClaudeIconSmall | `78mpp` | 28×28 | 8px |
| IconSuccess | `8E6HD` | ✓ 28pt | - |
| IconError | `lSVr5` | ✕ 28pt | - |
| IconQuestion | `GHlqm` | ? 24pt | - |

### Task Checklist

| Component | Node ID | Icon | Color |
|-----------|---------|------|-------|
| TaskCheckDone | `Ywufr` | check_circle | `#34C759` |
| TaskCheckActive | `zVQDv` | pending | `#007AFF` |
| TaskCheckPending | `OEFWF` | circle outline | `#6E6E73` |

### Progress

| Component | Node ID | Description |
|-----------|---------|-------------|
| ProgressBar | `lAs4K` | Bar + percentage (140px wide) |

### Navigation

| Component | Node ID | Description |
|-----------|---------|-------------|
| HistoryButton | `XvJzx` | 44×44, lucide history icon |
| SettingsButton | `KFs0p` | 44×44, lucide settings icon |
| BackButton | `F9zRN` | Chevron + "Back" |

### Pairing

| Component | Node ID | Description |
|-----------|---------|-------------|
| CodeDigit | `mGZmx` | Single character (A7X9) |

### Notifications

| Component | Node ID | Description |
|-----------|---------|-------------|
| NotificationBanner | `WRKjZ` | Icon + title + body |

### Glows (Ambient)

| Component | Node ID | Size | Blur |
|-----------|---------|------|------|
| GlowSuccess | `Js5cj` | 100×80 | 35px |
| GlowWarning | `vRGO1` | 100×80 | 35px |
| GlowError | `cxyD9` | 100×80 | 35px |
| GlowBrand | `6stpW` | 100×80 | 35px |
| GlowWorking | `jIrsu` | 100×80 | 35px |
| GlowPlan | `gTjM3` | 100×80 | 35px |
| GlowContext | `v4qmR` | 100×80 | 35px |
| GlowQuestion | `5sGcV` | 100×80 | 35px |

### Misc

| Component | Node ID | Description |
|-----------|---------|-------------|
| HintText | `DVk12` | 9pt hint text |

---

## Button Gradients

### Approve Button
```css
background: linear-gradient(180deg, #4ade80 0%, #34C759 100%);
```

### Primary Button
```css
background: #d97757; /* or gradient for pairing */
background: linear-gradient(180deg, #e08862 0%, #d97757 100%);
```

---

## SwiftUI Implementation Reference

```swift
extension Claude {
    // NEW V3 Colors
    static let plan = Color(hex: "#5E5CE6")
    static let context = Color(hex: "#FFD60A")
    static let question = Color(hex: "#BF5AF2")

    // Existing (verified)
    static let anthropicOrange = Color(hex: "#d97757")
    static let success = Color(hex: "#34C759")
    static let warning = Color(hex: "#FF9500")
    static let danger = Color(hex: "#FF3B30")
    static let info = Color(hex: "#007AFF")
    static let idle = Color(hex: "#8E8E93")

    // Card gradient
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.07),
                Color.white.opacity(0.03)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Glow modifier
    static func glow(for state: ClaudeState) -> some View {
        Ellipse()
            .fill(state.color.opacity(0.18))
            .frame(width: 100, height: 80)
            .blur(radius: 35)
    }
}
```

---

## Design System Frame

**Node ID**: `Q0NWg`

The design system is organized in the Pencil file under:
- Design Tokens (Colors)
- Components (organized in rows)
  - Row 1: WatchFrame, StatusBar, TaskCard, Buttons, ModeButtons, Glows, Badges, Notification
  - Row 2: CodeDigit, IconButtons, ActivityCard, TimelineEvent, FooterNav, ClaudeIcons, ProgressBar, PauseButton, TaskCheck
  - Row 3: StatusDots, HintText, SecondaryButton, StateIcons, QueueItem, StateCard, ActionButtonRow
