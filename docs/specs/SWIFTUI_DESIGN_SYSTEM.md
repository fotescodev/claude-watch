# SwiftUI Design System Specification

**Status:** Reference Documentation
**Created:** 2026-01-17
**Target:** Claude Watch v1.0+

---

## Overview

This document defines the complete design system for Claude Watch, a watchOS application built with SwiftUI. The design system ensures visual consistency, accessibility, and alignment with Apple's Human Interface Guidelines for watchOS.

**Design Principles:**
- **Glanceable**: Information accessible within 2-3 seconds
- **Minimal Interaction**: One-tap actions preferred
- **Accessibility First**: Dynamic Type, VoiceOver, Always-On Display support
- **Consistency**: Follows Apple's watchOS native patterns

---

## Color Palette

### Primary & Accent Colors

Claude Watch uses **orange** as its primary brand color, representing the Claude identity with high visibility on the watch face.

| Token | RGB Values | Hex | Use Case |
|-------|-----------|-----|----------|
| `Claude.orange` | (1.0, 0.584, 0.0) | `#FF9500` | Primary actions, pending badges, brand accent |
| `Claude.orangeLight` | (1.0, 0.702, 0.251) | `#FFB340` | Hover states, gradients (future use) |
| `Claude.orangeDark` | (0.8, 0.467, 0.0) | `#CC7700` | Pressed states (future use) |

**Usage:**
```swift
// Primary action button
.background(Claude.orange)

// Pending action badge
Text("\(count)")
    .background(Claude.orange)
```

---

### Semantic Colors

Semantic colors communicate state and intent, aligned with Apple's system colors for user familiarity.

| Token | RGB Values | Hex | Use Case |
|-------|-----------|-----|----------|
| `Claude.success` | (0.204, 0.780, 0.349) | `#34C759` | Approve buttons, connected state, completed tasks |
| `Claude.danger` | (1.0, 0.231, 0.188) | `#FF3B30` | Reject buttons, error states, destructive actions |
| `Claude.warning` | (1.0, 0.584, 0.0) | `#FF9500` | Reconnecting state, caution indicators |
| `Claude.info` | (0.0, 0.478, 1.0) | `#007AFF` | Information, normal mode, link colors |

**Semantic Color Mapping:**

| State | Color | Example |
|-------|-------|---------|
| **Connected** | `success` | Green dot in status header |
| **Disconnected** | `danger` | Red wifi slash icon |
| **Reconnecting** | `warning` | Orange spinner |
| **File Edit** | `orange` | File edit action card |
| **File Create** | `info` | File create action card |
| **File Delete** | `danger` | File delete action card |
| **Bash Command** | Purple (`Color.purple`) | Bash action card |

**Usage:**
```swift
// Approve button
.background(
    LinearGradient(
        colors: [Claude.success, Claude.success.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
)

// Reject button
.background(
    LinearGradient(
        colors: [Claude.danger, Claude.danger.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

---

### Surface Colors

Surface colors create depth and hierarchy using watchOS-native dark mode layers.

| Token | RGB Values | Hex | Use Case |
|-------|-----------|-----|----------|
| `Claude.background` | (0.0, 0.0, 0.0) | `#000000` | Screen background (pure black for OLED) |
| `Claude.surface1` | (0.110, 0.110, 0.118) | `#1C1C1E` | Cards, elevated containers |
| `Claude.surface2` | (0.173, 0.173, 0.180) | `#2C2C2E` | Secondary elevated containers |
| `Claude.surface3` | (0.227, 0.227, 0.235) | `#3A3A3C` | Tertiary elevated containers |

**Surface Hierarchy:**
```
background (black)
  └─ surface1 (cards)
      └─ surface2 (nested cards)
          └─ surface3 (rare, tertiary nesting)
```

**Usage:**
```swift
// Screen background
ZStack {
    Claude.background.ignoresSafeArea()
    // Content
}

// Card background
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(Claude.surface1)
)
```

**Note:** Prefer `.ultraThinMaterial` and `.thinMaterial` for glassmorphic effects over solid surface colors when overlaying dynamic content.

---

### Text Colors

Text hierarchy follows Apple's watchOS contrast guidelines for optimal legibility.

| Token | White Value | Alpha | Use Case |
|-------|------------|-------|----------|
| `Claude.textPrimary` | 1.0 (white) | 1.0 | Headings, primary labels, high-emphasis text |
| `Claude.textSecondary` | 0.6 (gray) | 1.0 | Body text, secondary labels, medium-emphasis |
| `Claude.textTertiary` | 0.4 (dark gray) | 1.0 | Captions, hints, low-emphasis text |

**Contrast Ratios:**
- textPrimary on background: **21:1** (WCAG AAA)
- textSecondary on background: **7.5:1** (WCAG AA)
- textTertiary on background: **4.5:1** (WCAG AA Large Text)

**Usage:**
```swift
// Primary heading
Text("Status")
    .foregroundColor(Claude.textPrimary)

// Secondary label
Text("Last updated 2m ago")
    .foregroundColor(Claude.textSecondary)

// Tertiary hint
Text("Tap to refresh")
    .foregroundColor(Claude.textTertiary)
```

---

## Dark Mode & Always-On Display

### Dark Mode Strategy

Claude Watch is **dark-mode only** by design, optimized for watchOS OLED displays:
- Pure black (`#000000`) background for OLED power efficiency
- No light mode variant (watchOS apps are typically dark by default)
- All colors pre-optimized for dark backgrounds

### Always-On Display (AOD)

When the watch enters Always-On Display mode, the UI automatically dims via the `isLuminanceReduced` environment variable.

**Dimming Strategy:**

| Element | Normal Opacity | AOD Opacity |
|---------|---------------|-------------|
| Primary colors | 1.0 | 0.5 - 0.6 |
| Background shapes | 0.3 | 0.15 |
| Icons | 1.0 | 0.6 |
| Text | 1.0 (white) | 0.6 (gray) |

**Implementation:**
```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced

// Auto-dimming color
.foregroundColor(Claude.success.opacity(isLuminanceReduced ? 0.5 : 1.0))

// Auto-dimming background
.fill(Claude.orange.opacity(isLuminanceReduced ? 0.15 : 0.3))
```

**Examples from Codebase:**
```swift
// Complication progress ring
Circle()
    .stroke(progressColor.opacity(isLuminanceReduced ? 0.5 : 1.0), ...)

// Icon in circular complication
.foregroundColor(iconColor.opacity(isLuminanceReduced ? 0.6 : 1.0))

// Rectangular widget text
.foregroundColor(isLuminanceReduced ? .gray : .white)
```

---

## Typography

### Font System

Claude Watch uses **San Francisco** (SF Pro) exclusively, Apple's system font optimized for watchOS legibility.

**Font Scale:**

| Style | Size | Weight | Use Case |
|-------|------|--------|----------|
| `.title` | 28pt | Bold | Rarely used (too large for watch) |
| `.title2` | 22pt | Bold | Page headers, empty states |
| `.title3` | 20pt | Semibold | Section headers |
| `.headline` | 17pt | Semibold | Card headers, primary labels |
| `.body` | 17pt | Regular | Body text, button labels |
| `.footnote` | 13pt | Regular | Secondary text |
| `.caption` | 12pt | Regular | Tertiary text |
| `.caption2` | 11pt | Regular | Smallest readable text |

**Monospaced Variants:**
```swift
.font(.system(.body, design: .monospaced))  // For codes, file paths
```

### Dynamic Type Support

All text uses **Dynamic Type** via `@ScaledMetric` for accessibility:

```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
@ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 32
```

**Benefits:**
- Respects user's font size preferences
- Automatically scales icons proportionally
- Ensures readability for all users

---

## Spacing & Layout

### Padding Scale

Consistent spacing creates rhythm and visual hierarchy.

| Token | Value | Use Case |
|-------|-------|----------|
| **Micro** | 2px | Icon padding, tight spacing |
| **XXS** | 4px | Chip padding, minimal gaps |
| **XS** | 6px | List item spacing |
| **Small** | 8px | Card internal spacing |
| **Medium** | 12px | Default card padding |
| **Large** | 16px | Screen margins |
| **XL** | 20px | Section spacing |
| **XXL** | 24px | Major section spacing |

**Examples:**
```swift
// Card padding
.padding(12)  // Medium

// Screen margins
.padding(.horizontal, 16)  // Large

// Icon in container
.padding(2)  // Micro
```

### Corner Radius

Rounded corners soften the UI and follow Apple's design language.

| Element | Radius | Use Case |
|---------|--------|----------|
| **Buttons** | 8-10px | Small interactive elements |
| **Chips/Pills** | `Capsule()` | Tags, mode indicators |
| **Cards** | 14-16px | Action cards, containers |
| **Large Cards** | 20px | Primary action card |
| **Sheets** | 16px | Modal backgrounds |

**Examples:**
```swift
// Standard card
.clipShape(RoundedRectangle(cornerRadius: 16))

// Pill button
.clipShape(Capsule())

// Compact card
.clipShape(RoundedRectangle(cornerRadius: 14))
```

---

## Animation System

### Spring Animations

Claude Watch uses **spring physics** for natural, responsive interactions.

**Standard Springs:**

```swift
extension Animation {
    /// Standard spring for interactive buttons (35ms response, 70% damping)
    static var buttonSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
    }

    /// Bouncy spring for attention-grabbing elements (200 stiffness, 15 damping)
    static var bouncySpring: Animation {
        .interpolatingSpring(stiffness: 200, damping: 15)
    }

    /// Gentle spring for subtle transitions (50ms response, 80% damping)
    static var gentleSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }
}
```

**Usage:**
```swift
// Button press feedback
.scaleEffect(isPressed ? 0.92 : 1.0)
.animation(.buttonSpring, value: isPressed)

// Attention-grabbing pop
.scaleEffect(showBadge ? 1.0 : 0.8)
.animation(.bouncySpring, value: showBadge)
```

### Pulse Animations

Used for status indicators and live activity feedback.

```swift
// Recording indicator pulse
withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
    pulseScale = 1.5
    pulseOpacity = 0.3
}

// Status header pulse (running/waiting states)
Circle()
    .scaleEffect(1 + pulsePhase * 0.2)
```

**Duration Guidelines:**
- **Fast pulse** (0.5-0.8s): Active recording, urgent attention
- **Medium pulse** (1.0-1.5s): Background activity
- **Slow pulse** (2.0s): Ambient status indication

---

## Component Patterns

### Button States

Interactive elements use scale transforms for tactile feedback.

**Press Interaction:**
```swift
@State private var isPressed = false

Button { /* action */ } label: {
    Text("Approve")
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.buttonSpring, value: isPressed)
}
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
)
```

**Scale Values:**
- **Light press**: 0.96 (mode selector, subtle elements)
- **Medium press**: 0.92 (approve/reject buttons)
- **Heavy press**: 0.88 (primary CTA, destructive actions)

### Gradient Backgrounds

Buttons use subtle gradients for depth.

```swift
.background(
    LinearGradient(
        colors: [Claude.success, Claude.success.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

**Pattern:** Top color at 100% → Bottom color at 80% opacity

### Material Effects

watchOS materials provide depth and context.

| Material | Use Case |
|----------|----------|
| `.ultraThinMaterial` | Compact cards, secondary containers |
| `.thinMaterial` | Primary cards, overlays |
| `.regularMaterial` | Rarely used (too opaque for watch) |

**Usage:**
```swift
// Card with glassmorphic effect
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
)
```

### Icon Containers

Icons are wrapped in colored shapes for emphasis.

**Circle Container Pattern:**
```swift
ZStack {
    Circle()
        .fill(Claude.orange.opacity(0.2))
        .frame(width: 32, height: 32)

    Image(systemName: "checkmark")
        .font(.system(size: 14, weight: .bold))
        .foregroundColor(Claude.orange)
}
```

**Rounded Rectangle Container Pattern:**
```swift
ZStack {
    RoundedRectangle(cornerRadius: 12)
        .fill(
            LinearGradient(
                colors: [typeColor, typeColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(width: 40, height: 40)

    Image(systemName: icon)
        .foregroundColor(.white)
}
```

---

## Accessibility

### VoiceOver Support

All interactive elements include:
- `.accessibilityLabel()` - Describes the element
- `.accessibilityHint()` - Explains the action result
- `.accessibilityAddTraits()` - Adds role semantics

**Example:**
```swift
Button { service.approveAction(id) } label: {
    Text("Approve")
}
.accessibilityLabel("Approve file edit")
.accessibilityHint("Approves the pending file change")
```

### Haptic Feedback

WatchKit haptics provide tactile confirmation.

| Haptic | Use Case |
|--------|----------|
| `.click` | Button taps, mode changes |
| `.success` | Approve action, successful pairing |
| `.failure` | Reject action, pairing error |
| `.start` | Recording begins |
| `.stop` | Recording ends |

**Usage:**
```swift
Button {
    service.approveAction(id)
    WKInterfaceDevice.current().play(.success)
} label: { /* ... */ }
```

### Dynamic Type

Use `@ScaledMetric` for all fixed sizes:
```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
```

This ensures icons and spacing scale with user-preferred text size.

---

## Mode-Specific Colors

Claude Watch has three permission modes, each with distinct colors.

| Mode | Primary Color | Background | Use Case |
|------|--------------|------------|----------|
| **Normal** | `Claude.info` (blue) | `Claude.surface1` | Manual approve each action |
| **Auto-Accept** | `Claude.danger` (red) | `danger.opacity(0.1)` | Automatically approve all |
| **Plan** | `Color.purple` | `purple.opacity(0.1)` | Read-only planning mode |

**Mode Selector Implementation:**
```swift
var modeColor: Color {
    switch mode {
    case .normal: return Claude.info
    case .autoAccept: return Claude.danger
    case .plan: return Color.purple
    }
}

var modeBackground: Color {
    switch mode {
    case .normal: return Claude.surface1
    case .autoAccept: return Claude.danger.opacity(0.1)
    case .plan: return Color.purple.opacity(0.1)
    }
}
```

---

## Widget Complications

Watch face complications use **system colors** (green, orange, purple) for widget families.

### Complication Color Usage

| State | Color | Hex | Use Case |
|-------|-------|-----|----------|
| **Progress/Connected** | Green | `#34C759` | Progress rings, connection indicator |
| **Pending Actions** | Orange | `#FF9500` | Pending count badge |
| **Model/Plan Mode** | Purple | `#AF52DE` | Model indicator, plan mode |

**Always-On Dimming:**
- Normal: `Color.green.opacity(1.0)`
- AOD: `Color.green.opacity(0.5)`

**Example:**
```swift
// Circular complication progress
Circle()
    .stroke(Color.green.opacity(isLuminanceReduced ? 0.5 : 1.0), ...)

// Pending badge
Text("\(count)")
    .foregroundColor(Color.orange.opacity(isLuminanceReduced ? 0.6 : 1.0))
```

---

## Recording Indicator

Voice recording states use **red** for privacy compliance and visibility.

### Recording Colors

| Element | Color | Use Case |
|---------|-------|----------|
| **Pulse Ring** | `Color.red.opacity(0.3)` | Outer pulsing ring |
| **Solid Dot** | `Color.red` | Inner recording dot |
| **Banner Background** | `Color.red.opacity(0.15)` | Recording banner overlay |
| **Text** | `Color.red` | "Recording..." label |

**Animation:**
```swift
// Pulse effect
withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
    pulseScale = 1.5
    pulseOpacity = 0.3
}
```

---

## Design Tokens Reference

### Complete Color Token List

```swift
// Primary & Accent
Claude.orange          // #FF9500
Claude.orangeLight     // #FFB340
Claude.orangeDark      // #CC7700

// Semantic
Claude.success         // #34C759 (green)
Claude.danger          // #FF3B30 (red)
Claude.warning         // #FF9500 (orange, same as primary)
Claude.info            // #007AFF (blue)

// Surfaces
Claude.background      // #000000 (pure black)
Claude.surface1        // #1C1C1E
Claude.surface2        // #2C2C2E
Claude.surface3        // #3A3A3C

// Text
Claude.textPrimary     // #FFFFFF (white)
Claude.textSecondary   // #999999 (60% white)
Claude.textTertiary    // #666666 (40% white)

// System Colors (for specific use cases)
Color.purple           // #AF52DE (bash actions, plan mode)
Color.green            // #34C759 (complications, matches success)
Color.red              // #FF3B30 (recording indicator, matches danger)
```

---

## Migration from Legacy Code

If you encounter hardcoded colors in existing code, migrate to tokens:

| Legacy | Token | Notes |
|--------|-------|-------|
| `.orange` | `Claude.orange` | Use semantic token |
| `.green` | `Claude.success` | Use semantic token (or `Color.green` for complications) |
| `.red` | `Claude.danger` | Use semantic token (or `Color.red` for recording) |
| `.blue` | `Claude.info` | Use semantic token |
| `.black` | `Claude.background` | Use semantic token |
| `.white` | `Claude.textPrimary` | Use semantic token |
| `.gray` | `Claude.textSecondary` or `.textTertiary` | Choose based on hierarchy |
| `Color(white: 0.6)` | `Claude.textSecondary` | Matches exactly |

---

## Usage Examples

### Primary Action Card

```swift
VStack(spacing: 12) {
    // Header
    HStack(spacing: 10) {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Claude.orange, Claude.orange.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)

            Image(systemName: "pencil")
                .foregroundColor(.white)
        }

        VStack(alignment: .leading, spacing: 3) {
            Text("Edit File")
                .font(.headline)
                .foregroundColor(Claude.textPrimary)

            Text("MainView.swift")
                .font(.caption2.monospaced())
                .foregroundColor(Claude.textSecondary)
        }
    }

    // Action buttons
    HStack(spacing: 8) {
        // Reject
        Button { /* reject */ } label: {
            Text("Reject")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [Claude.danger, Claude.danger.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
        }

        // Approve
        Button { /* approve */ } label: {
            Text("Approve")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [Claude.success, Claude.success.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(Capsule())
        }
    }
}
.padding(14)
.background(
    RoundedRectangle(cornerRadius: 20)
        .fill(.thinMaterial)
)
```

### Status Header with Pulse

```swift
HStack(spacing: 8) {
    // Status icon with pulse
    ZStack {
        Circle()
            .fill(Claude.orange.opacity(0.2))
            .frame(width: 32, height: 32)

        Circle()
            .fill(Claude.orange.opacity(0.3))
            .frame(width: 32, height: 32)
            .scaleEffect(1 + pulsePhase * 0.2)

        Image(systemName: "play.fill")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Claude.orange)
    }

    VStack(alignment: .leading, spacing: 2) {
        Text("Running")
            .font(.headline)
            .foregroundColor(Claude.textPrimary)

        Text("Refactoring code...")
            .font(.caption2)
            .foregroundColor(Claude.textSecondary)
    }
}
.padding(12)
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
)
```

---

## Future Considerations

### Planned Enhancements
1. **Tint Color Customization**: Allow users to choose accent color
2. **High Contrast Mode**: Increase contrast ratios for accessibility
3. **Color Blind Modes**: Alternative palettes for color vision deficiency
4. **Light Mode (Low Priority)**: Not currently planned, but tokens would support it

### Extensibility
All color tokens are centralized in the `Claude` enum, making it easy to:
- Add new semantic colors
- Introduce theming support
- Support dynamic color schemes
- A/B test alternative palettes

---

## References

- [Apple Human Interface Guidelines - watchOS](https://developer.apple.com/design/human-interface-guidelines/watchos)
- [SF Symbols Documentation](https://developer.apple.com/sf-symbols/)
- [WCAG 2.1 Contrast Guidelines](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [SwiftUI Animation API](https://developer.apple.com/documentation/swiftui/animation)

---

**Last Updated:** 2026-01-17
**Maintained By:** Claude Watch Team
