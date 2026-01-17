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

Claude Watch uses **San Francisco** (SF Pro) exclusively, Apple's system font optimized for watchOS legibility at small sizes and various viewing distances.

**Font Scale:**

| Style | Size | Weight | Use Case | Example Location |
|-------|------|--------|----------|------------------|
| `.title` | 28pt | Bold | Rarely used (too large for watch) | - |
| `.title2` | 22pt | Bold | Page headers, empty states | "All Clear", "Offline" |
| `.title3` | 20pt | Semibold | AOD simplified status | AlwaysOnDisplayView |
| `.headline` | 17pt | Semibold | Card headers, status labels | "Running", "Edit File" |
| `.body` | 17pt | Regular/Bold | Body text, button labels | "Approve", "Reject" |
| `.subheadline` | 15pt | Regular/Semibold | Reconnecting status | "Reconnecting..." |
| `.footnote` | 13pt | Regular/Semibold | Secondary labels, buttons | "Voice Command", "Demo Mode" |
| `.caption` | 12pt | Regular | Tertiary text, metadata | "Last updated 2m ago" |
| `.caption2` | 11pt | Regular/Semibold | Smallest readable text | File paths, hints |

**Font Weight Hierarchy:**
```swift
// Bold - High emphasis, primary actions
Text("Approve All")
    .font(.body.weight(.bold))

// Semibold - Medium emphasis, headings
Text("Status")
    .font(.headline)  // Headline is semibold by default

// Regular - Normal text
Text("No pending actions")
    .font(.footnote)

// Light - Subtle, background elements (rare on watch)
Image(systemName: "tray")
    .font(.system(size: 32, weight: .light))
```

**Monospaced Variants:**

File paths and code snippets use monospaced design for clarity:

```swift
// File paths in action cards
Text("MainView.swift")
    .font(.caption2.monospaced())
    .foregroundColor(Claude.textSecondary)

// Generic monospaced body text
.font(.system(.body, design: .monospaced))
```

---

### Dynamic Type Support

All text and icons use **Dynamic Type** via `@ScaledMetric` to respect user accessibility preferences.

**Core Principle:** Icons and spacing scale proportionally with text to maintain visual harmony across all Dynamic Type sizes.

#### @ScaledMetric Usage Patterns

**Pattern 1: Icon Sizes Relative to Text**

Icons should scale with their associated text using the `relativeTo:` parameter:

```swift
// Icon for headline text (status header)
@ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
@ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14

// Icon for body text (action cards)
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
@ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40

// Icon for footnote text (compact cards)
@ScaledMetric(relativeTo: .footnote) private var compactIconSize: CGFloat = 12
@ScaledMetric(relativeTo: .footnote) private var compactIconContainerSize: CGFloat = 28
```

**Pattern 2: Component Heights Relative to Text**

Button and container heights scale with their text content:

```swift
// Command button minimum height
@ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52

// Badge size for caption text
@ScaledMetric(relativeTo: .caption) private var badgeFontSize: CGFloat = 13
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
```

**Pattern 3: Large Display Elements**

Empty states and large visual elements scale with title text:

```swift
// Empty state icon (scales with .title for prominence)
@ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32

// AOD status icon (scales with .title3)
@ScaledMetric(relativeTo: .title) private var statusIconSize: CGFloat = 36
```

#### Complete @ScaledMetric Reference

All `@ScaledMetric` declarations from the codebase:

| Variable | Base Value | Relative To | Use Case |
|----------|-----------|-------------|----------|
| `iconSize` | 12pt | `.body` | Toolbar icons |
| `statusIconContainerSize` | 32pt | `.headline` | Status header icon background |
| `statusIconSize` | 14pt | `.headline` | Status header icon |
| `badgeSize` | 28pt | `.body` | Pending count badge |
| `badgeFontSize` | 13pt | `.caption` | Badge text |
| `iconContainerSize` (empty) | 80pt | `.title` | Empty state icon background |
| `iconSize` (empty) | 32pt | `.title` | Empty state icon |
| `iconContainerSize` (action) | 40pt | `.body` | Action card icon background |
| `iconSize` (action) | 18pt | `.body` | Action card icon |
| `compactIconContainerSize` | 28pt | `.footnote` | Compact card icon background |
| `compactIconSize` | 12pt | `.footnote` | Compact card icon |
| `buttonHeight` | 52pt | `.body` | Command button minimum height |
| `modeIconContainerSize` | 28pt | `.footnote` | Mode selector icon background |
| `modeIconSize` | 12pt | `.footnote` | Mode selector icon |
| `statusIconSize` (AOD) | 36pt | `.title` | Always-On Display status icon |

#### Dynamic Type Environment Variables

Access user's Dynamic Type settings when needed:

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

// Conditionally adjust layout for accessibility sizes
if dynamicTypeSize >= .accessibility1 {
    VStack(spacing: 16) { /* Vertical layout */ }
} else {
    HStack(spacing: 12) { /* Horizontal layout */ }
}
```

**Benefits of @ScaledMetric:**
- ✅ Respects user's font size preferences (Settings → Accessibility → Text Size)
- ✅ Automatically scales icons proportionally with text
- ✅ Ensures readability for all users, including vision accessibility
- ✅ Maintains visual hierarchy across all Dynamic Type sizes
- ✅ No manual layout adjustments needed

---

## Spacing & Layout

### Padding Scale

Consistent spacing creates rhythm, visual hierarchy, and breathing room on the small watch screen. Claude Watch uses a **4px base unit** with multiples for predictable layout.

**Spacing System:**

| Token | Value | Use Case | Examples |
|-------|-------|----------|----------|
| **Micro** | 2pt | Icon internal padding, minimal gaps | Status icon badge spacing |
| **XXS** | 4pt | Tight horizontal margins | Screen edge padding (`.horizontal, 4`) |
| **XS** | 6pt | Chip internal padding, small gaps | Quick suggestion chips, badge spacing |
| **Small** | 8pt | VStack/HStack spacing, compact cards | Action queue spacing, toolbar spacing |
| **Medium** | 12pt | Standard card padding, VStack spacing | Main content spacing, card padding |
| **Large** | 14pt | Button internal padding, larger cards | Approve/reject button padding |
| **XL** | 16pt | Screen margins, major spacing | Status header horizontal padding |
| **XXL** | 20pt | Rare, very large spacing | Button horizontal padding |
| **XXXL** | 24pt | Extreme spacing, major sections | OfflineStateView button horizontal padding |

### Padding Patterns from Codebase

#### Container Padding

Cards and containers use consistent internal padding:

```swift
// Standard card padding (most common)
.padding(12)
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
)

// Large primary card
.padding(14)
.background(
    RoundedRectangle(cornerRadius: 20)
        .fill(.thinMaterial)
)

// Compact card
.padding(10)
.background(
    RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
)
```

#### Screen Margins

ScrollView content uses minimal horizontal margins for maximum watch screen real estate:

```swift
// Main content view - minimal horizontal padding
.padding(.horizontal, 4)
.padding(.bottom, 12)

// Modal sheets - standard horizontal padding
.padding(.horizontal, 16)

// Buttons in offline state - extra horizontal padding
.padding(.horizontal, 24)
```

#### Button Padding

Interactive elements use vertical padding for touch targets:

```swift
// Primary action buttons (Approve/Reject)
.padding(.vertical, 14)
.clipShape(Capsule())

// Secondary buttons
.padding(.vertical, 10)
.background(Claude.orange)
.clipShape(Capsule())

// Compact suggestion chips
.padding(.horizontal, 10)
.padding(.vertical, 6)
.background(.thinMaterial, in: Capsule())
```

### VStack & HStack Spacing

Vertical and horizontal stacks use consistent spacing for visual rhythm:

**VStack Spacing Hierarchy:**

| Spacing | Use Case | Example Location |
|---------|----------|------------------|
| `2pt` | Tightest grouping (label + sublabel) | Status header text, mode selector text |
| `3pt` | Very tight grouping | Action card title + path |
| `6pt` | Compact lists | Compact action cards |
| `8pt` | Standard spacing | Status header internals, action queue |
| `10pt` | Medium spacing | Settings buttons |
| `12pt` | Default spacing | Main content sections, voice input sheet |
| `16pt` | Large spacing | Empty state, offline state, settings sections |

**HStack Spacing Hierarchy:**

| Spacing | Use Case | Example Location |
|---------|----------|------------------|
| `4pt` | Icon + text in buttons | Reject/approve button icons |
| `6pt` | Status indicators | Connection status dot + text, quick suggestions |
| `8pt` | Standard horizontal spacing | Status header, compact cards, badges |
| `10pt` | Card content spacing | Action card icon + text, mode selector |
| `12pt` | Large button spacing | Voice input action buttons |

**Examples from Codebase:**

```swift
// Main content spacing (12pt - default)
VStack(spacing: 12) {
    StatusHeader(pulsePhase: pulsePhase)
    ActionQueue()
    CommandGrid(showingVoiceInput: $showingVoiceInput)
    ModeSelector()
}

// Status header (8pt - compact)
VStack(spacing: 8) {
    HStack(spacing: 8) {
        // Status icon + label
    }
    if service.state.status == .running {
        ProgressView(value: service.state.progress)
    }
}

// Action card content (12pt vertical, 10pt horizontal)
VStack(spacing: 12) {
    HStack(spacing: 10) {
        // Icon
        VStack(alignment: .leading, spacing: 3) {
            Text("Edit File")
            Text("MainView.swift")
        }
    }

    HStack(spacing: 8) {
        // Reject and Approve buttons
    }
}

// Empty state (16pt - large breathing room)
VStack(spacing: 16) {
    // Icon
    // Title
    // Subtitle
    // Connection status
}

// Button with icon + label (4pt - tight)
HStack(spacing: 4) {
    Image(systemName: "checkmark")
    Text("Approve")
}
```

### Corner Radius Scale

Rounded corners follow Apple's watchOS design language, with radius proportional to element size.

| Element Type | Radius | Use Case | Example |
|--------------|--------|----------|---------|
| **Compact Cards** | 10pt | Small text fields, settings items | TextField backgrounds |
| **Standard Cards** | 14pt | Compact action cards, voice command row | CompactActionCard |
| **Primary Cards** | 16pt | Status header, mode selector, settings containers | StatusHeader, ModeSelector |
| **Large Cards** | 20pt | Primary action card | PrimaryActionCard |
| **Icon Containers (Small)** | 8pt | Compact card type icons | CompactActionCard icon |
| **Icon Containers (Medium)** | 12pt | Primary card type icons, reconnecting card | PrimaryActionCard icon, ReconnectingView |
| **Buttons/Pills** | `Capsule()` | All button backgrounds, badges | Approve/Reject buttons, pending badge |

**Examples from Codebase:**

```swift
// Primary action card - large radius (20pt)
.background(
    RoundedRectangle(cornerRadius: 20)
        .fill(.thinMaterial)
)

// Status header - standard radius (16pt)
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
)

// Compact action card - medium radius (14pt)
.background(
    RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
)

// Reconnecting banner - medium radius (12pt)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

// Settings text field - small radius (10pt)
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

// Icon container - medium radius (12pt)
RoundedRectangle(cornerRadius: 12)
    .fill(LinearGradient(...))
    .frame(width: 40, height: 40)

// Icon container (compact) - small radius (8pt)
RoundedRectangle(cornerRadius: 8)
    .fill(typeColor.opacity(0.2))
    .frame(width: 28, height: 28)

// All buttons - capsule (fully rounded)
.clipShape(Capsule())
```

### Layout Guidelines

**watchOS Screen Constraints:**
- **Screen width**: ~162-205pt (depending on watch size)
- **Safe area margins**: 4-8pt horizontal (minimal by design)
- **Vertical scrolling**: Preferred over horizontal scrolling
- **Touch target minimum**: 44pt × 44pt (Apple HIG)

**Best Practices:**

1. **Minimize horizontal margins** - Use `.padding(.horizontal, 4)` for main content to maximize screen real estate
2. **Use vertical layouts** - VStack is preferred over HStack for primary content
3. **Stack spacing consistency** - Use 8pt or 12pt for most VStack/HStack spacing
4. **Card hierarchy via radius** - Larger corner radius = more visual emphasis
5. **Capsule for all buttons** - Fully rounded buttons follow watchOS conventions

---

## Animation & Interaction Patterns

Claude Watch uses **physics-based animations** and **tactile interaction patterns** to create a natural, responsive user experience on the watch. All animations are optimized for watchOS performance and battery efficiency.

---

### Spring Animations

Spring animations provide natural, physics-based motion that feels organic and responsive. Claude Watch defines three standard spring types as `Animation` extensions.

#### Spring Animation Types

**1. Button Spring (`.buttonSpring`)**

Fast, responsive spring for interactive buttons and toggles.

```swift
static var buttonSpring: Animation {
    .spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
}
```

**Physics Parameters:**
- **Response**: 0.35s (350ms) - Fast reaction time
- **Damping Fraction**: 0.7 (70%) - Moderate bounce, settles quickly
- **Blend Duration**: 0 - No interpolation with other animations

**When to Use:**
- ✅ Primary action buttons (Approve, Reject)
- ✅ Command buttons (Go, Test, Fix, Stop)
- ✅ Interactive cards with press states
- ✅ Modal dismiss gestures
- ❌ Background status changes (too fast/distracting)
- ❌ Continuous animations (use pulse instead)

**Examples from Codebase:**
```swift
// Primary action button press
.scaleEffect(approvePressed ? 0.92 : 1.0)
.animation(.buttonSpring, value: approvePressed)

// Command button interaction
.scaleEffect(isPressed ? 0.92 : 1.0)
.animation(.buttonSpring, value: isPressed)

// Reject button press
.scaleEffect(rejectPressed ? 0.92 : 1.0)
.animation(.buttonSpring, value: rejectPressed)
```

---

**2. Bouncy Spring (`.bouncySpring`)**

Energetic spring with pronounced bounce for attention-grabbing elements.

```swift
static var bouncySpring: Animation {
    .interpolatingSpring(stiffness: 200, damping: 15)
}
```

**Physics Parameters:**
- **Stiffness**: 200 - High resistance to compression
- **Damping**: 15 - Low damping allows multiple oscillations
- **Result**: Visible bounce effect (~2-3 oscillations before settling)

**When to Use:**
- ✅ Approve All button (bulk positive action)
- ✅ Badge appearance animations (pending count)
- ✅ Success confirmation popups
- ✅ Attention-grabbing state changes
- ❌ Subtle UI transitions (too energetic)
- ❌ Frequent interactions (can feel jarring)

**Examples from Codebase:**
```swift
// Approve All button press (celebratory bounce)
.scaleEffect(approveAllPressed ? 0.95 : 1.0)
.animation(.bouncySpring, value: approveAllPressed)

// Badge pop-in animation (future enhancement)
.scaleEffect(showBadge ? 1.0 : 0.0)
.opacity(showBadge ? 1.0 : 0.0)
.animation(.bouncySpring, value: showBadge)
```

---

**3. Gentle Spring (`.gentleSpring`)**

Smooth, slow spring for subtle transitions and background state changes.

```swift
static var gentleSpring: Animation {
    .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
}
```

**Physics Parameters:**
- **Response**: 0.5s (500ms) - Slower reaction time
- **Damping Fraction**: 0.8 (80%) - Minimal bounce, smooth settle
- **Blend Duration**: 0 - No interpolation with other animations

**When to Use:**
- ✅ Content transitions (empty state → pending actions)
- ✅ Sheet presentations (voice input, settings)
- ✅ Mode selector changes (Normal → Auto-Accept → Plan)
- ✅ Status color transitions (connected → disconnected)
- ❌ Button press feedback (too slow for immediate interaction)
- ❌ User-initiated actions (not responsive enough)

**Examples from Codebase:**
```swift
// Mode selector press (subtle feedback)
.scaleEffect(isPressed ? 0.96 : 1.0)
.animation(.buttonSpring, value: isPressed)  // Note: Currently uses buttonSpring

// Future usage: Content fade transitions
.opacity(isVisible ? 1.0 : 0.0)
.animation(.gentleSpring, value: isVisible)
```

**Note:** Currently underutilized in codebase. Recommended for future enhancements:
- Reconnecting banner slide-in
- Status color transitions
- Empty state appearance

---

### Scale Effect Patterns

Scale transforms provide tactile feedback for button presses, creating the illusion of physical depth on the flat watch screen.

#### Button Press Scale Values

Different button types use different scale factors based on visual weight and importance:

| Scale Factor | Use Case | Button Type | Examples |
|--------------|----------|-------------|----------|
| **0.96** | Subtle press | Low-emphasis buttons, toggles | Mode selector |
| **0.92** | Medium press | Primary actions, standard buttons | Approve, Reject, Command buttons |
| **0.95** | Light press | Bulk actions, special states | Approve All |
| **0.88** | Heavy press | Destructive actions (future use) | Delete All, Reset |

#### Implementation Pattern

All button press interactions follow this pattern:

```swift
struct InteractiveButton: View {
    @State private var isPressed = false

    var body: some View {
        Button {
            // Action
            WKInterfaceDevice.current().play(.click)  // Haptic feedback
        } label: {
            Text("Button")
                .scaleEffect(isPressed ? 0.92 : 1.0)  // Scale down on press
                .animation(.buttonSpring, value: isPressed)  // Spring animation
        }
        .buttonStyle(.plain)  // Disable default button style
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)  // Track touch down/up
                .onChanged { _ in isPressed = true }   // Touch down
                .onEnded { _ in isPressed = false }     // Touch up
        )
    }
}
```

**Key Components:**
1. **@State isPressed** - Tracks touch state
2. **.scaleEffect()** - Applies scale transform
3. **.animation()** - Animates scale changes with spring physics
4. **.buttonStyle(.plain)** - Removes default button styling
5. **.simultaneousGesture()** - Captures touch events without blocking button action
6. **DragGesture(minimumDistance: 0)** - Immediate touch detection (no drag required)
7. **WKInterfaceDevice.current().play()** - Haptic feedback on action

#### Real Examples from Codebase

**Primary Action Buttons (0.92 scale):**

```swift
// Approve button in PrimaryActionCard
@State private var approvePressed = false

Button {
    service.approveAction(action.id)
    WKInterfaceDevice.current().play(.success)
} label: {
    HStack(spacing: 4) {
        Image(systemName: "checkmark")
        Text("Approve")
    }
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
    .scaleEffect(approvePressed ? 0.92 : 1.0)
    .animation(.buttonSpring, value: approvePressed)
}
.buttonStyle(.plain)
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in approvePressed = true }
        .onEnded { _ in approvePressed = false }
)
```

**Mode Selector (0.96 scale - subtle):**

```swift
// Mode selector in ModeSelector component
@State private var isPressed = false

Button {
    service.cycleMode()
    WKInterfaceDevice.current().play(.click)
} label: {
    // Mode selector UI
    .scaleEffect(isPressed ? 0.96 : 1.0)
    .animation(.buttonSpring, value: isPressed)
}
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
)
```

**Approve All Button (0.95 scale with bouncySpring):**

```swift
// Approve All in ActionQueue
@State private var approveAllPressed = false

Button {
    service.approveAll()
    WKInterfaceDevice.current().play(.success)
} label: {
    Text("Approve All (\(count))")
        .scaleEffect(approveAllPressed ? 0.95 : 1.0)
        .animation(.bouncySpring, value: approveAllPressed)  // Note: bouncy for celebration
}
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in approveAllPressed = true }
        .onEnded { _ in approveAllPressed = false }
)
```

#### Why Scale Instead of Opacity or Other Effects?

**✅ Scale Transform Advantages:**
- Creates illusion of physical depth (button "presses in")
- Works well on OLED (doesn't affect pixel brightness)
- Minimal performance impact (GPU-accelerated)
- Maintains accessibility (unlike opacity)
- Natural pairing with spring physics

**❌ Alternatives (Not Recommended):**
- **Opacity change**: Reduces contrast, harms accessibility
- **Color darkening**: Inconsistent across materials, less noticeable
- **Shadow effects**: Too subtle on small watch screen
- **Rotation**: Confusing, no clear "pressed" state

---

### Pulse Animations

Pulse animations draw attention to live status indicators and ongoing operations without user interaction.

#### Pulse Types

**1. Status Pulse (Slow, 2.0s)**

Used for ambient status indication in the status header when tasks are running or waiting.

```swift
// In MainView.onAppear
private func startPulse() {
    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
        pulsePhase = 1
    }
}

// In StatusHeader
Circle()
    .fill(statusColor.opacity(0.3))
    .frame(width: statusIconContainerSize, height: statusIconContainerSize)
    .scaleEffect(1 + pulsePhase * 0.2)  // Scale from 1.0 to 1.2
```

**Parameters:**
- Duration: 2.0s (slow, calming)
- Animation: `.easeInOut` (smooth acceleration/deceleration)
- Repeat: `.repeatForever(autoreverses: true)` (infinite loop)
- Scale range: 1.0 → 1.2 (20% growth)

**When to Use:**
- ✅ Status header when task is running
- ✅ Status header when waiting for response
- ✅ Background activity indicators
- ❌ Urgent notifications (too slow)
- ❌ Recording indicators (use fast pulse)

**Visual Effect:**
- Outer ring gently expands and contracts
- Draws subtle attention without distraction
- Indicates "something is happening" in background

---

**2. Recording Pulse (Fast, 0.8s)**

Used for recording indicators to comply with privacy requirements and grab immediate attention.

```swift
// Recording indicator (VoiceInputSheet)
withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
    pulseScale = 1.5
    pulseOpacity = 0.3
}

// Visual implementation
ZStack {
    // Pulsing outer ring
    Circle()
        .fill(Color.red.opacity(pulseOpacity))  // Fades in/out
        .frame(width: 20, height: 20)
        .scaleEffect(pulseScale)  // Expands from 1.0 to 1.5

    // Solid inner dot
    Circle()
        .fill(Color.red)
        .frame(width: 8, height: 8)
}
```

**Parameters:**
- Duration: 0.8s (fast, urgent)
- Animation: `.easeInOut` (smooth)
- Repeat: `.repeatForever(autoreverses: true)`
- Scale range: 1.0 → 1.5 (50% growth)
- Opacity range: 1.0 → 0.3 (fade out)

**When to Use:**
- ✅ Voice recording active
- ✅ Microphone in use (privacy requirement)
- ✅ Real-time data streaming
- ❌ Background tasks (too urgent/distracting)
- ❌ Static status (not ongoing operation)

**Privacy Compliance:**
- **Red color** is required by Apple for recording indicators
- **Pulse animation** ensures user cannot miss recording state
- **Always visible** when microphone is active

---

#### Pulse Duration Guidelines

| Duration | Speed | Use Case | Example |
|----------|-------|----------|---------|
| **0.5-0.8s** | Fast | Active recording, urgent attention | Recording indicator, critical alerts |
| **1.0-1.5s** | Medium | Background activity, processing | Data sync, loading states |
| **2.0s+** | Slow | Ambient status, subtle indication | Status header (running/waiting) |

---

### Material Backgrounds

SwiftUI materials provide glassmorphic effects that adapt to background content, creating depth and visual hierarchy. Materials are preferred over solid surface colors for overlays and cards.

#### Material Types

| Material | Opacity | Blur | Use Case |
|----------|---------|------|----------|
| `.ultraThinMaterial` | Very low (10-15%) | High | Compact cards, secondary containers, overlays |
| `.thinMaterial` | Low (20-30%) | Medium | Primary cards, important containers |
| `.regularMaterial` | Medium (40-50%) | Low | Rarely used on watchOS (too opaque) |
| `.thickMaterial` | High (60-70%) | Very low | Not used (too heavy for watch) |

#### Usage Guidelines

**Use `.ultraThinMaterial` for:**
- Status header background
- Compact action cards
- Mode selector background
- Command grid buttons
- Settings UI backgrounds
- Reconnecting banner

**Use `.thinMaterial` for:**
- Primary action card background
- Voice input suggestion chips
- Modal sheet overlays (future use)

**Use solid colors for:**
- Buttons (Approve, Reject) - Require strong contrast
- Badges - Must be highly visible
- Icon containers - Need solid color identity

#### Real Examples

**Status Header (ultraThin):**

```swift
VStack(spacing: 8) {
    // Status content
}
.padding(12)
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)  // Subtle glassmorphic effect
)
```

**Primary Action Card (thin):**

```swift
VStack(spacing: 12) {
    // Action card content
}
.padding(14)
.background(
    RoundedRectangle(cornerRadius: 20)
        .fill(.thinMaterial)  // More prominent glassmorphic effect
)
```

**Compact Action Card (ultraThin):**

```swift
HStack(spacing: 8) {
    // Compact content
}
.padding(10)
.background(
    RoundedRectangle(cornerRadius: 14)
        .fill(.ultraThinMaterial)
)
```

**Buttons (solid colors, NOT materials):**

```swift
// Approve button - needs strong contrast, no material
.background(
    LinearGradient(
        colors: [Claude.success, Claude.success.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
)
.clipShape(Capsule())
```

#### Material + Shape Pattern

Materials are always paired with shapes (RoundedRectangle, Capsule, Circle) to define clipping bounds:

```swift
// ✅ CORRECT - Material with shape
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial)
)

// ✅ CORRECT - Shorthand with in: parameter
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

// ❌ INCORRECT - Material without shape (no corner radius)
.background(.ultraThinMaterial)
```

#### Material Benefits

**Advantages:**
- ✅ Adapts to background content (dynamic)
- ✅ Provides depth without heavy opacity
- ✅ Maintains legibility over varied backgrounds
- ✅ Follows Apple's watchOS design language
- ✅ Better battery efficiency than full opacity layers

**When NOT to Use:**
- ❌ Buttons requiring high contrast (use solid colors)
- ❌ Badges and labels (use solid backgrounds)
- ❌ Icon containers (use solid color for type identity)
- ❌ Alert dialogs (future - use system styles)

---

### Animation Performance Optimization

watchOS has limited GPU resources - animations must be lightweight.

**Best Practices:**
- ✅ Use `.animation(_, value:)` modifier (SwiftUI explicit animations)
- ✅ Animate only necessary properties (scale, opacity, offset)
- ✅ Limit simultaneous animations (max 3-4 at once)
- ✅ Use `withAnimation` for one-off transitions
- ❌ Avoid `.animation()` without value parameter (implicit, less performant)
- ❌ Don't animate complex shapes or gradients if avoidable
- ❌ Avoid animating large images or complex views

**GPU-Accelerated Properties (Fast):**
- `scaleEffect()` ✅
- `opacity()` ✅
- `offset()` ✅
- `rotationEffect()` ✅

**CPU-Heavy Properties (Slow):**
- `frame()` ⚠️
- `padding()` ⚠️
- Color interpolation ⚠️
- Shape morphing ⚠️

---

### Interaction Timing

All animations are synchronized with haptic feedback for cohesive user experience.

**Timing Pattern:**

```swift
Button {
    // 1. Trigger action immediately
    service.approveAction(id)

    // 2. Play haptic feedback (same frame)
    WKInterfaceDevice.current().play(.success)

    // 3. Animation plays automatically via @State change
} label: {
    Text("Approve")
        .scaleEffect(isPressed ? 0.92 : 1.0)  // Animation
        .animation(.buttonSpring, value: isPressed)
}
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in
            isPressed = true  // Triggers animation instantly
        }
        .onEnded { _ in
            isPressed = false  // Triggers release animation
        }
)
```

**Timeline:**
1. **T+0ms**: User touches button → `isPressed = true`
2. **T+0ms**: Scale animation begins (0.92 scale)
3. **T+0ms**: Haptic feedback plays
4. **T+~200ms**: User lifts finger → `isPressed = false`
5. **T+~200ms**: Scale animation reverses (1.0 scale)
6. **T+~550ms**: Animation completes (350ms spring response + 200ms settle)

**Critical Rule:** Haptics MUST play in the same frame as visual feedback begins. Delayed haptics feel disconnected and reduce perceived responsiveness.

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

## Component Hierarchy & Architecture

### Component Tree

Claude Watch follows a hierarchical component architecture with clear separation of concerns. The main view conditionally renders different state-specific views, while shared components handle reusable UI patterns.

```
MainView (Root Container)
├── [Conditional State Views]
│   ├── AlwaysOnDisplayView (when isLuminanceReduced)
│   ├── PairingView (when cloud mode && !paired)
│   ├── OfflineStateView (when disconnected)
│   ├── ReconnectingView (when reconnecting)
│   ├── EmptyStateView (when no pending actions)
│   └── mainContentView (default active state)
│       ├── StatusHeader
│       ├── ActionQueue (when pendingActions > 0)
│       │   ├── PrimaryActionCard (first action)
│       │   ├── CompactActionCard (additional actions)
│       │   └── "Approve All" Button
│       ├── CommandGrid (when pendingActions == 0)
│       │   ├── CommandButton × 4 (2×2 grid)
│       │   └── "Voice Command" Button
│       └── ModeSelector
├── [Modal Sheets]
│   ├── VoiceInputSheet (sheet presentation)
│   │   ├── RecordingBanner (when recording)
│   │   ├── RecordingIndicator
│   │   ├── TextField (with dictation)
│   │   ├── Quick Suggestion Chips
│   │   └── Action Buttons (Cancel/Send)
│   └── SettingsSheet (sheet presentation)
│       ├── Connection Status Indicator
│       ├── Demo Mode Section (when isDemoMode)
│       ├── Cloud Mode Section (when useCloudMode)
│       ├── Server URL Input (when WebSocket mode)
│       └── About Section (Version, Privacy, Support)
└── [Toolbar]
    └── Connection Status Button (top-right)
```

---

### Component Documentation

#### 1. MainView
**Type:** Container View
**Purpose:** Root view that manages app state and conditionally renders content based on connection status, pairing state, and pending actions.

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared  // Global app state
@State private var showingVoiceInput = false                // Voice sheet visibility
@State private var showingSettings = false                  // Settings sheet visibility
@State private var pulsePhase: CGFloat = 0                  // Animation phase for pulse effects
```

**Environment Variables:**
```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced   // Always-On Display detection
@Environment(\.dynamicTypeSize) var dynamicTypeSize         // User's text size preference
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 12  // Toolbar icon size
```

**Conditional Rendering Logic:**
1. If `isLuminanceReduced` → Show `AlwaysOnDisplayView` (simplified AOD UI)
2. Else if cloud mode && not paired → Show `PairingView`
3. Else if disconnected → Show `OfflineStateView`
4. Else if reconnecting → Show `ReconnectingView` overlay
5. Else if no pending actions && idle → Show `EmptyStateView`
6. Else → Show `mainContentView` (active content)

**Lifecycle:**
- `onAppear`: Connects to WebSocket or starts cloud polling, initiates pulse animation

---

#### 2. StatusHeader
**Type:** Display Component
**Purpose:** Shows current session status, task name, progress bar, and pending action count.

**Props:**
```swift
let pulsePhase: CGFloat  // Animation phase passed from MainView
```

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared  // Observes status changes
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
@ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
@ScaledMetric(relativeTo: .caption) private var badgeFontSize: CGFloat = 13
```

**Features:**
- Pulsing status icon (when running/waiting)
- Progress bar (when running/waiting)
- Pending count badge (when actions > 0)
- Dynamic color based on status (idle=green, running=orange, failed=red)

---

#### 3. ActionQueue
**Type:** List Container
**Purpose:** Displays pending actions requiring approval, with primary card + compact list + bulk approve.

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@State private var approveAllPressed = false  // Button press animation state
```

**Child Components:**
- `PrimaryActionCard` - First pending action (full detail)
- `CompactActionCard` - Additional actions 2-3 (collapsed view)
- Overflow indicator - "+X more" text (if > 3 actions)
- "Approve All" button - Bulk approval (if > 1 action)

**Layout:**
```swift
VStack(spacing: 8) {
    PrimaryActionCard(action: first)
    VStack(spacing: 6) {
        ForEach(actions.dropFirst().prefix(2)) { action in
            CompactActionCard(action: action)
        }
        if count > 3 { Text("+\(count - 3) more") }
    }
    if count > 1 { ApproveAllButton }
}
```

---

#### 4. PrimaryActionCard
**Type:** Interactive Card
**Purpose:** Displays detailed view of a single pending action with approve/reject buttons.

**Props:**
```swift
let action: PendingAction  // The action to display
```

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@State private var rejectPressed = false   // Reject button press state
@State private var approvePressed = false  // Approve button press state
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
```

**Features:**
- Type icon with gradient background (file_edit=orange, file_create=blue, file_delete=red, bash=purple)
- Action title and file path (truncated to filename only)
- Reject button (red gradient, left side)
- Approve button (green gradient, right side)
- Spring animation on button press (scale to 0.92)
- Haptic feedback on tap (success/failure)

**Actions:**
- Calls `service.respondToCloudRequest()` (cloud mode) or `service.approveAction()`/`service.rejectAction()` (WebSocket mode)

---

#### 5. CompactActionCard
**Type:** Display Component (non-interactive)
**Purpose:** Shows condensed view of pending actions beyond the first.

**Props:**
```swift
let action: PendingAction  // The action to display
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .footnote) private var iconContainerSize: CGFloat = 28
@ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 12
```

**Features:**
- Smaller type icon with tinted background (20% opacity)
- Action title only (no file path)
- No interactive buttons (tap opens detail view in future enhancement)

---

#### 6. CommandGrid
**Type:** Interactive Grid
**Purpose:** Provides quick-access command buttons for common actions when no pending actions exist.

**Props:**
```swift
@Binding var showingVoiceInput: Bool  // Controls voice sheet presentation
```

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
```

**Child Components:**
- `CommandButton` × 4 (Go, Test, Fix, Stop) in 2×2 grid
- "Voice Command" button - Opens voice input sheet

**Layout:**
```swift
VStack(spacing: 8) {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        ForEach(commands) { CommandButton(...) }
    }
    VoiceCommandButton
}
```

---

#### 7. CommandButton
**Type:** Interactive Button
**Purpose:** Single command button that sends a predefined prompt to Claude Code.

**Props:**
```swift
let icon: String   // SF Symbol name
let label: String  // Button label
let prompt: String // Prompt to send
```

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@State private var isPressed = false  // Press animation state
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
@ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52
```

**Features:**
- Orange icon + gray label
- Spring animation on press (scale to 0.92)
- Haptic click feedback
- Calls `service.sendPrompt(prompt)` on tap

---

#### 8. ModeSelector
**Type:** Interactive Toggle
**Purpose:** Displays current permission mode and cycles through modes on tap (Normal → Auto-Accept → Plan).

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@State private var isPressed = false  // Press animation state
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .footnote) private var modeIconContainerSize: CGFloat = 28
@ScaledMetric(relativeTo: .footnote) private var modeIconSize: CGFloat = 12
```

**Features:**
- Mode icon in colored circle (blue=Normal, red=Auto-Accept, purple=Plan)
- Mode name and description
- Tinted background (subtle color wash)
- Border stroke matching mode color
- Spring animation on press (scale to 0.96 - subtle)
- Calls `service.cycleMode()` on tap

**Mode Colors:**
| Mode | Icon | Color | Background |
|------|------|-------|------------|
| Normal | `hand.raised` | `Claude.info` | `Claude.surface1` |
| Auto-Accept | `bolt.fill` | `Claude.danger` | `danger.opacity(0.1)` |
| Plan | `doc.text` | `Color.purple` | `purple.opacity(0.1)` |

---

#### 9. VoiceInputSheet
**Type:** Modal Sheet
**Purpose:** Allows user to dictate or type a custom command to send to Claude Code.

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@Environment(\.dismiss) var dismiss  // Sheet dismissal
@State private var transcribedText = ""  // User input
@State private var showSentConfirmation = false  // Success feedback
@State private var isRecording = false  // Dictation active
```

**Features:**
- TextField with dictation support (watchOS native)
- Recording indicator (red dot + pulse) when dictation active
- Quick suggestion chips (Continue, Run tests, Fix errors, Commit)
- Sending indicator (spinner + "Sending...")
- Sent confirmation (checkmark + "Sent")
- Cancel button (red tinted)
- Send button (green, appears when text not empty)
- Auto-dismisses 1s after successful send

**Dictation Detection:**
- Monitors `transcribedText` changes to detect recording start
- Plays `.start` haptic when recording begins
- Plays `.stop` haptic when recording ends (onSubmit)

---

#### 10. SettingsSheet
**Type:** Modal Sheet
**Purpose:** Displays connection status, pairing controls, demo mode toggle, server URL input (WebSocket), and app info.

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@Environment(\.dismiss) var dismiss
@State private var serverURL: String = ""  // WebSocket URL input
@State private var showingPairing = false  // Pairing sheet
@State private var showingPrivacy = false  // Privacy info sheet
```

**Sections:**
1. **Connection Status** - Colored dot + status text (connected/disconnected/reconnecting)
2. **Demo Mode** (if active) - Warning badge + "Exit Demo Mode" button
3. **Cloud Mode** (if enabled):
   - **Paired** - Green checkmark + "Unpair" button
   - **Not Paired** - Orange "Pair with Code" button
4. **WebSocket Mode** (if enabled) - Server URL text field + Save/Cancel buttons
5. **About Section**:
   - Version number
   - Privacy & Consent button → `PrivacyInfoView` sheet
   - Privacy Policy link (external web)
   - Support link (external web)

---

#### 11. EmptyStateView
**Type:** State View
**Purpose:** Displayed when connected but no pending actions exist (idle state).

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
@State private var showingPairing = false  // Pairing sheet
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32
```

**Features:**
- Large centered icon (tray if paired, link.circle if not)
- "All Clear" / "Not Paired" title
- Connection status indicator (green dot if paired, orange if not)
- "Pair with Code" button (if cloud mode && not paired)
- "Load Demo" button (if paired or WebSocket mode)

---

#### 12. OfflineStateView
**Type:** State View
**Purpose:** Displayed when WebSocket connection is disconnected and not in demo mode.

**State Properties:**
```swift
@ObservedObject private var service = WatchService.shared
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32
```

**Features:**
- Large wifi.slash icon
- "Offline" title + "Can't connect to Claude" subtitle
- "Retry" button (blue) - Calls `service.connect()`
- "Demo Mode" button (orange text) - Loads demo data
- Triple-tap icon - Hidden easter egg to load demo data

---

#### 13. ReconnectingView
**Type:** Overlay Banner
**Purpose:** Displays reconnection progress when WebSocket connection is lost.

**Props:**
```swift
let status: ConnectionStatus  // Contains attempt number and retry countdown
```

**Features:**
- Circular progress spinner (orange)
- "Reconnecting..." text
- Attempt count and next retry countdown (e.g., "Attempt 3 • 5s")
- Glassmorphic background (.ultraThinMaterial)
- Overlays on top of main content (does not replace it)

---

#### 14. AlwaysOnDisplayView
**Type:** State View
**Purpose:** Simplified view shown when watch enters Always-On Display mode (isLuminanceReduced).

**Props:**
```swift
let connectionStatus: ConnectionStatus
let pendingCount: Int
let status: SessionStatus
```

**Scaled Metrics:**
```swift
@ScaledMetric(relativeTo: .title) private var statusIconSize: CGFloat = 36
```

**Features:**
- Connection status indicator (dimmed color dot + text)
- Large status icon (checkmark, play, clock, etc.)
- Status text (Ready, Active, Waiting, etc.)
- Pending count (if > 0)
- All colors dimmed to 50-60% opacity per Apple HIG
- No interactive elements (AOD is display-only)

---

### State Management Patterns

#### @State
Used for **local component state** that doesn't need to persist across navigation or be shared with other views.

**Examples:**
```swift
// Button press animations
@State private var isPressed = false
@State private var approvePressed = false
@State private var rejectPressed = false

// Modal sheet visibility
@State private var showingVoiceInput = false
@State private var showingSettings = false
@State private var showingPairing = false

// Animation phases
@State private var pulsePhase: CGFloat = 0
@State private var pulseScale: CGFloat = 1.0

// User input
@State private var transcribedText = ""
@State private var serverURL = ""

// Temporary UI state
@State private var showSentConfirmation = false
@State private var isRecording = false
```

**Pattern:**
- Always marked `private` (encapsulated within view)
- Initialized with default value
- Automatically triggers view re-render when changed
- Does not persist when view is deallocated

---

#### @ObservedObject
Used for **shared global state** managed by `WatchService.shared` singleton.

**Examples:**
```swift
@ObservedObject private var service = WatchService.shared
```

**Observed Properties in WatchService:**
```swift
@Published var state: WatchState                  // Task status, pending actions, mode
@Published var connectionStatus: ConnectionStatus // WebSocket connection state
@Published var isDemoMode: Bool                   // Demo mode flag
@Published var isPaired: Bool                     // Cloud pairing state
@Published var pairingId: String                  // Cloud pairing ID
@Published var isSendingPrompt: Bool              // Prompt submission state
```

**Pattern:**
- Single source of truth for app-wide state
- All views observe the same service instance
- Changes propagate to all observing views automatically
- State persists across view lifecycle

---

#### @Environment
Used for **system-provided values** and **dependency injection**.

**Examples:**
```swift
// Always-On Display detection
@Environment(\.isLuminanceReduced) var isLuminanceReduced

// Dynamic Type size
@Environment(\.dynamicTypeSize) var dynamicTypeSize

// Sheet dismissal
@Environment(\.dismiss) var dismiss
```

**Pattern:**
- Read-only access to SwiftUI environment
- Automatically updated by system
- Used for accessibility, presentation state, system settings

---

#### @ScaledMetric
Used for **Dynamic Type support** - scales fixed sizes proportionally with user's text size preference.

**Examples:**
```swift
// Icon sizes relative to text
@ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
@ScaledMetric(relativeTo: .footnote) private var compactIconSize: CGFloat = 12

// Container sizes
@ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40
@ScaledMetric(relativeTo: .title) private var emptyStateIconSize: CGFloat = 80

// Component dimensions
@ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
```

**Pattern:**
- Always paired with `relativeTo:` text style
- Scales proportionally when user increases/decreases text size
- Maintains visual hierarchy across all Dynamic Type sizes
- Used for icons, spacing, and layout dimensions

---

#### @Binding
Used for **two-way data flow** between parent and child components.

**Examples:**
```swift
// CommandGrid receives binding from MainView
struct CommandGrid: View {
    @Binding var showingVoiceInput: Bool

    var body: some View {
        Button {
            showingVoiceInput = true  // Modifies parent's @State
        } label: {
            Text("Voice Command")
        }
    }
}

// Usage in MainView
CommandGrid(showingVoiceInput: $showingVoiceInput)
```

**Pattern:**
- Child component can read AND write parent's state
- Prefixed with `$` when passed from parent
- Creates bidirectional binding
- Used for sheet presentation, toggles, text input

---

### Component Communication

#### Parent → Child (Props)
**Pattern:** Pass immutable data as `let` properties.

```swift
// Parent
PrimaryActionCard(action: pendingAction)

// Child
struct PrimaryActionCard: View {
    let action: PendingAction  // Immutable prop
}
```

---

#### Child → Parent (Bindings)
**Pattern:** Pass `@Binding` for child to modify parent state.

```swift
// Parent
@State private var isVisible = false
ChildView(isVisible: $isVisible)

// Child
struct ChildView: View {
    @Binding var isVisible: Bool

    func toggle() {
        isVisible.toggle()  // Modifies parent
    }
}
```

---

#### Global State (Singleton)
**Pattern:** All components observe `WatchService.shared`.

```swift
// Any view
@ObservedObject private var service = WatchService.shared

// Modify shared state
service.approveAction(id)
service.cycleMode()
service.connect()
```

---

#### Sheet Presentation
**Pattern:** Use `@State` + `.sheet(isPresented:)` modifier.

```swift
@State private var showingSheet = false

Button { showingSheet = true } label: { Text("Open") }
    .sheet(isPresented: $showingSheet) {
        SheetView()
    }
```

---

### Architectural Principles

1. **Single Source of Truth**: `WatchService.shared` holds all app state
2. **Unidirectional Data Flow**: State changes flow from service → views
3. **Component Composition**: Complex views built from small, focused components
4. **Prop Drilling Avoidance**: Use `@ObservedObject` instead of passing props through multiple layers
5. **Separation of Concerns**:
   - **Views** - UI rendering, user interaction
   - **WatchService** - Business logic, networking, state management
   - **Models** - Data structures (PendingAction, WatchState, etc.)
6. **Conditional Rendering**: MainView uses state-based view switching instead of navigation
7. **Accessibility First**: All components use `@ScaledMetric`, `.accessibilityLabel()`, and support VoiceOver

---

## Accessibility

Claude Watch follows **Accessibility First** design principles, ensuring all users can interact with the app regardless of visual ability, motor skills, or environmental conditions. This section provides comprehensive guidelines for VoiceOver, Dynamic Type, Always-On Display, and Haptic Feedback.

---

### VoiceOver Support

VoiceOver is Apple's screen reader technology that enables visually impaired users to navigate apps through audio descriptions. Every interactive element in Claude Watch must be accessible to VoiceOver users.

#### Core Principles

1. **Every interactive element MUST have an accessibility label**
2. **Labels should describe WHAT the element is, not HOW to interact with it**
3. **Hints should explain WHAT HAPPENS when activated**
4. **Avoid redundant phrases like "button" or "tap" - VoiceOver adds these automatically**

#### Accessibility Modifiers

**`.accessibilityLabel()`**
- Describes the element's purpose or content
- Required for all buttons, links, and custom controls
- Should be concise (1-5 words)
- Do NOT include the element type ("button", "image")

**`.accessibilityHint()`**
- Optional - explains the result of activation
- Use when the action isn't obvious from the label
- Should be a brief sentence (3-8 words)
- Examples: "Opens voice input", "Approves all pending actions"

**`.accessibilityAddTraits()`**
- Adds semantic role information
- Common traits: `.isButton`, `.isHeader`, `.isSelected`, `.isLink`
- SwiftUI adds traits automatically for most native controls

**`.accessibilityValue()`**
- Provides dynamic state information
- Use for progress indicators, toggles, sliders
- Examples: "50 percent", "3 pending", "Connected"

**`.accessibilityHidden()`**
- Hides decorative elements from VoiceOver
- Use sparingly - only for purely visual elements
- Examples: background shapes, decorative dividers, redundant icons

#### Label Patterns from Codebase

**Pattern 1: Descriptive Action Labels**

```swift
// ✅ GOOD - Describes purpose + context
Button { showingSettings = true } label: {
    Image(systemName: connectionIcon)
}
.accessibilityLabel("Settings and connection status")

// ❌ BAD - Too generic
.accessibilityLabel("Settings")

// ❌ BAD - Includes element type
.accessibilityLabel("Settings button")
```

**Pattern 2: Action Cards with Context**

```swift
// Primary action card - include action type + target
Button { service.approveAction(action.id) } label: {
    HStack {
        Image(systemName: "checkmark")
        Text("Approve")
    }
}
.accessibilityLabel("Approve \(action.title)")
.accessibilityHint("Approves \(action.filePath.filename)")

// Examples:
// - "Approve file edit" + "Approves MainView.swift"
// - "Approve bash command" + "Approves npm install"
// - "Approve file create" + "Approves NewComponent.tsx"
```

**Pattern 3: Status Indicators**

```swift
// Connection status with value
HStack {
    Circle()
        .fill(connectionColor)
        .frame(width: 8, height: 8)
    Text(connectionText)
}
.accessibilityElement(children: .ignore)  // Combine children
.accessibilityLabel("Connection status")
.accessibilityValue(connectionText)  // "Connected", "Disconnected", etc.
```

**Pattern 4: Mode Selector with State**

```swift
// Mode selector - include current mode and action
Button { service.cycleMode() } label: {
    // Mode icon + label
}
.accessibilityLabel("Permission mode")
.accessibilityValue(service.state.mode.name)  // "Normal", "Auto-Accept", "Plan"
.accessibilityHint("Cycles to next permission mode")
.accessibilityAddTraits(.isButton)  // Redundant but explicit
```

**Pattern 5: Progress Indicators**

```swift
// Progress bar with percentage
ProgressView(value: service.state.progress)
    .accessibilityLabel("Task progress")
    .accessibilityValue("\(Int(service.state.progress * 100)) percent")
```

**Pattern 6: Badges and Counts**

```swift
// Pending count badge
ZStack {
    Circle().fill(Claude.orange)
    Text("\(count)")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("\(count) pending actions")
```

**Pattern 7: Hiding Decorative Elements**

```swift
// Decorative background pulse - hide from VoiceOver
Circle()
    .fill(statusColor.opacity(0.3))
    .scaleEffect(1 + pulsePhase * 0.2)
    .accessibilityHidden(true)
```

#### VoiceOver Testing Checklist

Before marking a feature complete, verify:

- [ ] Every button has a descriptive label
- [ ] Labels describe purpose, not interaction method
- [ ] Dynamic content (counts, status) uses `.accessibilityValue()`
- [ ] Decorative elements are hidden with `.accessibilityHidden(true)`
- [ ] Complex views group related elements with `.accessibilityElement(children: .combine)`
- [ ] Navigation flows logically (top-to-bottom, left-to-right)
- [ ] VoiceOver focus doesn't get stuck in loops
- [ ] All state changes announce updates (automatic with `@Published`)

#### Testing on Device

Enable VoiceOver on Apple Watch:
1. Open **Settings** → **Accessibility** → **VoiceOver**
2. Toggle **VoiceOver** on
3. Rotate Digital Crown to navigate
4. Double-tap to activate

**Common Issues:**
- Missing labels → VoiceOver reads "Button, Button, Button"
- Redundant labels → "Settings button button" (don't include "button")
- Hidden content → Use `.accessibilityHidden()` for decorative elements only
- Complex layouts → Use `.accessibilityElement(children: .combine)` to group

---

### Dynamic Type Support

Dynamic Type allows users to customize text size system-wide (Settings → Accessibility → Text Size). All text and associated UI elements MUST scale proportionally to respect user preferences.

#### Core Principles

1. **ALL text uses native SwiftUI fonts** (`.body`, `.headline`, `.caption`, etc.)
2. **ALL fixed-size elements use `@ScaledMetric`** (icons, spacing, containers)
3. **Icons scale with their associated text** using `relativeTo:` parameter
4. **Layout adapts for accessibility sizes** (vertical stacking when needed)

#### @ScaledMetric Property Wrapper

`@ScaledMetric` scales fixed CGFloat values proportionally with the user's Dynamic Type setting.

**Syntax:**
```swift
@ScaledMetric(relativeTo: .textStyle) private var metricName: CGFloat = baseValue
```

**Parameters:**
- `relativeTo:` - The text style this metric scales with (`.body`, `.headline`, `.caption`, etc.)
- Base value - The default size at standard Dynamic Type setting

#### Scaling Relationships

**Golden Rule:** Icons and containers should scale with the text they accompany.

| Text Style | Icon Size (Base) | Container Size (Base) | Use Case |
|------------|------------------|----------------------|----------|
| `.title` | 32-36pt | 80pt | Empty state icons, AOD status |
| `.title2` | 24-28pt | 60pt | Large headers |
| `.title3` | 20-24pt | 50pt | Page headers |
| `.headline` | 14-18pt | 32-40pt | Status header, card headers |
| `.body` | 16-18pt | 40-52pt | Action cards, buttons |
| `.footnote` | 12-14pt | 28-32pt | Compact cards, chips |
| `.caption` | 10-12pt | 20-28pt | Metadata, badges |

#### @ScaledMetric Patterns from Codebase

**Pattern 1: Icon Sizes Relative to Text**

```swift
// MainView toolbar icon (body text in toolbar)
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 12

// Status header icon (headline text)
@ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
@ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14

// Action card icon (body text)
@ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40
@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18

// Compact card icon (footnote text)
@ScaledMetric(relativeTo: .footnote) private var compactIconContainerSize: CGFloat = 28
@ScaledMetric(relativeTo: .footnote) private var compactIconSize: CGFloat = 12

// Empty state icon (title text for prominence)
@ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
@ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32
```

**Pattern 2: Component Heights**

```swift
// Button height scales with body text
@ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52

// Badge size scales with badge text (caption)
@ScaledMetric(relativeTo: .caption) private var badgeFontSize: CGFloat = 13
@ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
```

**Pattern 3: Usage in Layout**

```swift
struct StatusHeader: View {
    @ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
    @ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 8) {
            // Icon container automatically scales with user's text size
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: statusIconContainerSize, height: statusIconContainerSize)

                Image(systemName: statusIcon)
                    .font(.system(size: statusIconSize, weight: .bold))
                    .foregroundColor(statusColor)
            }

            // Text scales automatically with .headline
            VStack(alignment: .leading, spacing: 2) {
                Text("Running")
                    .font(.headline)  // Scales automatically
                Text("Refactoring code...")
                    .font(.caption2)  // Scales automatically
            }
        }
    }
}
```

#### Dynamic Type Environment Variable

Access the user's current Dynamic Type setting when needed:

```swift
@Environment(\.dynamicTypeSize) var dynamicTypeSize

var body: some View {
    if dynamicTypeSize >= .accessibility1 {
        // Accessibility size (very large) - use vertical layout
        VStack(spacing: 16) {
            Image(systemName: "checkmark")
            Text("Approve")
        }
    } else {
        // Standard size - use horizontal layout
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
            Text("Approve")
        }
    }
}
```

**Dynamic Type Size Scale:**
- `.xSmall` to `.xxxLarge` - Standard sizes
- `.accessibility1` to `.accessibility5` - Accessibility sizes (enabled in Settings)

#### Font Scaling Best Practices

**✅ DO:**
- Use native SwiftUI text styles (`.body`, `.headline`, `.caption`)
- Use `@ScaledMetric(relativeTo:)` for all fixed sizes
- Match icon scaling to associated text style
- Test with accessibility sizes enabled (`.accessibility3` and above)
- Allow layout to reflow for large text (vertical stacking)

**❌ DON'T:**
- Use `.font(.system(size: 14))` without `.scaledMetric`
- Hardcode frame sizes without `@ScaledMetric`
- Use `.minimumScaleFactor()` or `.lineLimit(1)` to prevent wrapping
- Assume fixed layout will work at all sizes
- Ignore accessibility sizes in testing

#### Testing Dynamic Type

**Simulator:**
1. Settings → Accessibility → Larger Text
2. Enable "Larger Accessibility Sizes"
3. Drag slider to test extreme sizes

**Device:**
1. iPhone Settings → Display & Brightness → Text Size
2. Apple Watch Settings → Accessibility → Text Size

**What to Test:**
- [ ] Text doesn't truncate at largest size
- [ ] Icons scale proportionally with text
- [ ] Buttons remain tappable (44pt minimum)
- [ ] Layout doesn't break (vertical stacking if needed)
- [ ] No overlapping elements
- [ ] Scrollable when content overflows

---

### Always-On Display (AOD) Patterns

When the Apple Watch enters Always-On Display mode, the screen dims to conserve battery and reduce burn-in. Claude Watch detects this state and adapts the UI accordingly.

#### Core Principles

1. **Detect AOD with `@Environment(\.isLuminanceReduced)`**
2. **Dim colors to 50-60% opacity**
3. **Show simplified UI** (optional - use a dedicated AOD view)
4. **No animations** (system pauses animations automatically)
5. **High contrast text** (white → gray transition)

#### AOD Detection

```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced

var body: some View {
    if isLuminanceReduced {
        // Always-On Display mode - show simplified view
        AlwaysOnDisplayView(...)
    } else {
        // Normal mode - show full interactive UI
        MainContentView(...)
    }
}
```

#### Dimming Strategies

**Strategy 1: Opacity Modifiers**

Apply opacity reduction to colors when in AOD mode:

```swift
// Primary colors dim to 50-60%
.foregroundColor(Claude.success.opacity(isLuminanceReduced ? 0.5 : 1.0))

// Background shapes dim to 15-20%
Circle()
    .fill(Claude.orange.opacity(isLuminanceReduced ? 0.15 : 0.3))

// Icons dim to 60%
Image(systemName: "checkmark")
    .foregroundColor(iconColor.opacity(isLuminanceReduced ? 0.6 : 1.0))

// Text transitions to gray
Text("Status")
    .foregroundColor(isLuminanceReduced ? .gray : .white)
```

**Strategy 2: Color Substitution**

Replace bright colors with muted alternatives:

```swift
var displayColor: Color {
    if isLuminanceReduced {
        return .gray  // Muted color for AOD
    } else {
        return statusColor  // Full color (orange, green, red)
    }
}

Circle()
    .fill(displayColor)
```

#### Dimming Reference Table

| Element Type | Normal Opacity | AOD Opacity | Example |
|--------------|----------------|-------------|---------|
| **Primary Colors** | 1.0 | 0.5 - 0.6 | Status icons, progress rings |
| **Background Shapes** | 0.2 - 0.3 | 0.15 | Icon container backgrounds |
| **Icons** | 1.0 | 0.6 | SF Symbols |
| **Primary Text** | 1.0 (white) | 1.0 (gray) | Headings, labels |
| **Secondary Text** | 0.6 (gray) | 0.5 (darker gray) | Metadata, captions |
| **Strokes/Borders** | 0.5 | 0.3 | Progress ring strokes |

#### Real Examples from Codebase

**Complication Progress Ring:**
```swift
// Full-color progress ring dims to 50% in AOD
Circle()
    .stroke(
        progressColor.opacity(isLuminanceReduced ? 0.5 : 1.0),
        style: StrokeStyle(lineWidth: 4, lineCap: .round)
    )
```

**Circular Complication Icon:**
```swift
// Icon dims to 60% in AOD
Image(systemName: icon)
    .font(.system(size: 18, weight: .bold))
    .foregroundColor(iconColor.opacity(isLuminanceReduced ? 0.6 : 1.0))
```

**Rectangular Widget Text:**
```swift
// Text transitions from white to gray
VStack(alignment: .leading, spacing: 2) {
    Text("Status")
        .foregroundColor(isLuminanceReduced ? .gray : .white)
    Text("Running")
        .foregroundColor(isLuminanceReduced ? Color.gray.opacity(0.6) : Claude.textSecondary)
}
```

**Status Header Background:**
```swift
// Background shape dims significantly
Circle()
    .fill(statusColor.opacity(isLuminanceReduced ? 0.15 : 0.3))
    .frame(width: statusIconContainerSize, height: statusIconContainerSize)
```

#### Simplified AOD View

For complex screens, show a simplified view in AOD mode:

```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced

var body: some View {
    if isLuminanceReduced {
        // Minimal AOD view - no interactive elements
        AlwaysOnDisplayView(
            connectionStatus: service.connectionStatus,
            pendingCount: service.state.pendingActions.count,
            status: service.state.status
        )
    } else {
        // Full interactive UI
        mainContentView
    }
}
```

**AlwaysOnDisplayView Features:**
- Large status icon with dimmed color
- Connection status (dimmed)
- Pending count (if > 0)
- No buttons or interactive elements
- Maximum legibility with minimal power usage

#### AOD Best Practices

**✅ DO:**
- Dim all colors to 50-60% opacity
- Simplify complex UIs (show essential info only)
- Use high-contrast text (white or gray on black)
- Test on device (Simulator doesn't accurately show AOD)
- Follow Apple's AOD guidelines for watchOS

**❌ DON'T:**
- Show interactive elements (buttons won't work in AOD)
- Use bright colors (causes burn-in, drains battery)
- Animate (system disables animations automatically)
- Display excessive text (hard to read when dimmed)
- Forget to test AOD mode on physical device

#### Testing AOD Mode

**On Device:**
1. Deploy app to Apple Watch
2. Launch app
3. Lower wrist → watch enters AOD mode
4. Verify colors dim appropriately
5. Raise wrist → watch exits AOD mode

**Simulator Limitation:**
- Xcode Simulator DOES NOT accurately simulate AOD dimming
- Always test on physical device for final verification

**What to Test:**
- [ ] Colors dim to 50-60% opacity
- [ ] Text remains legible (high contrast)
- [ ] No interactive elements shown (or disabled)
- [ ] Layout doesn't shift between AOD and normal mode
- [ ] Animations pause automatically
- [ ] UI appears within 2-3 seconds of wrist raise

---

### Haptic Feedback

Haptic feedback provides tactile confirmation of actions, especially important on a small watch screen where visual feedback may be subtle. WatchKit provides five distinct haptic types via `WKInterfaceDevice`.

#### Core Principles

1. **Every user action MUST have haptic feedback**
2. **Match haptic type to action semantics** (success = success haptic, reject = failure)
3. **Play haptics synchronously** with visual feedback (same frame)
4. **Don't overuse** - avoid rapid repeated haptics (jarring)
5. **Test on device** - Simulator cannot play haptics

#### Haptic Types

| Haptic | Intensity | Use Case | Example |
|--------|-----------|----------|---------|
| **`.click`** | Light | General button taps, toggles, mode changes | Settings button, mode selector, voice command |
| **`.success`** | Medium | Positive confirmations, successful operations | Approve action, successful pairing, send prompt |
| **`.failure`** | Medium | Negative confirmations, errors | Reject action, pairing error, connection failure |
| **`.start`** | Medium | Beginning of ongoing operation | Voice recording starts, task begins |
| **`.stop`** | Medium | End of ongoing operation | Voice recording ends, task completes |
| **`.notification`** | Strong | Alert, important event | Incoming approval request (via system notification) |

**Note:** `.notification` is typically triggered by system notifications (APNs), not in-app.

#### Haptic Usage Patterns

**Pattern 1: Approve Action (Success)**

```swift
Button {
    service.approveAction(action.id)
    WKInterfaceDevice.current().play(.success)  // ✅ Positive action
} label: {
    Text("Approve")
}
```

**Pattern 2: Reject Action (Failure)**

```swift
Button {
    service.rejectAction(action.id)
    WKInterfaceDevice.current().play(.failure)  // ❌ Negative action
} label: {
    Text("Reject")
}
```

**Pattern 3: General Button (Click)**

```swift
Button {
    showingSettings = true
    WKInterfaceDevice.current().play(.click)  // Generic tap
} label: {
    Image(systemName: "gear")
}
.accessibilityLabel("Settings and connection status")
```

**Pattern 4: Mode Cycle (Click)**

```swift
Button {
    service.cycleMode()
    WKInterfaceDevice.current().play(.click)  // State change
} label: {
    // Mode selector UI
}
```

**Pattern 5: Voice Recording Start/Stop**

```swift
// Recording starts
.onChanged { _ in
    isRecording = true
    WKInterfaceDevice.current().play(.start)  // Operation begins
}

// Recording ends (onSubmit)
.onSubmit {
    isRecording = false
    WKInterfaceDevice.current().play(.stop)  // Operation ends
}
```

**Pattern 6: Send Prompt (Success)**

```swift
func sendPrompt() {
    service.sendPrompt(transcribedText)
    WKInterfaceDevice.current().play(.success)  // Action completed
    showSentConfirmation = true

    // Auto-dismiss after 1 second
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        dismiss()
    }
}
```

**Pattern 7: Approve All (Success)**

```swift
Button {
    service.approveAll()
    WKInterfaceDevice.current().play(.success)  // Bulk positive action
} label: {
    Text("Approve All")
}
```

**Pattern 8: Pairing Success/Failure**

```swift
func completePairing(success: Bool) {
    if success {
        WKInterfaceDevice.current().play(.success)  // ✅ Pairing succeeded
        isPaired = true
    } else {
        WKInterfaceDevice.current().play(.failure)  // ❌ Pairing failed
        showError = true
    }
}
```

#### Haptic Decision Tree

```
User Action
├── Positive Outcome? → `.success`
│   ├── Approve action
│   ├── Send prompt
│   ├── Successful pairing
│   └── Approve all
├── Negative Outcome? → `.failure`
│   ├── Reject action
│   ├── Pairing error
│   └── Connection failure
├── Start Operation? → `.start`
│   ├── Recording begins
│   ├── Task starts
│   └── Timer starts
├── Stop Operation? → `.stop`
│   ├── Recording ends
│   ├── Task completes
│   └── Timer stops
└── General Interaction? → `.click`
    ├── Settings button
    ├── Mode selector
    ├── Retry button
    └── Voice command button
```

#### Haptic Best Practices

**✅ DO:**
- Play haptic immediately on user action (same frame as visual feedback)
- Match haptic to action semantics (success/failure/click)
- Use `.success` for positive confirmations
- Use `.failure` for negative confirmations or errors
- Use `.click` for neutral interactions (settings, mode changes)
- Test on physical device (Simulator doesn't play haptics)

**❌ DON'T:**
- Play multiple haptics in rapid succession (< 200ms apart)
- Use `.success` for destructive actions (use `.click` or `.failure`)
- Play haptics for system-triggered events (notifications already have haptics)
- Forget to add haptics to custom buttons
- Use `.notification` in-app (reserved for system notifications)

#### Accessibility Considerations

Haptic feedback is especially important for:
- **VoiceOver users** - Confirms action when audio feedback may be unclear
- **Low vision users** - Tactile confirmation when visual feedback is hard to see
- **Noisy environments** - Tactile feedback works when audio is inaudible

**Reduced Motion:**
- Haptics are NOT affected by Reduce Motion accessibility setting
- Continue to play haptics even when animations are disabled
- Haptics provide confirmation when visual animations are reduced

#### Testing Haptics

**On Device:**
1. Deploy app to Apple Watch
2. Ensure watch is NOT in Silent Mode (or muted)
3. Tap each interactive element
4. Feel for haptic feedback

**Common Issues:**
- No haptic → Verify `WKInterfaceDevice.current().play()` is called
- Wrong haptic type → Review decision tree above
- Haptic too subtle → Watch may be in Silent Mode or battery saver
- Simulator shows haptic logs → Simulator CANNOT play haptics (device only)

**What to Test:**
- [ ] Every button plays a haptic
- [ ] Approve actions use `.success`
- [ ] Reject actions use `.failure`
- [ ] General buttons use `.click`
- [ ] Recording start/stop uses `.start`/`.stop`
- [ ] Haptic timing matches visual feedback (synchronous)
- [ ] No rapid repeated haptics (< 200ms apart)

---

### Accessibility Testing Checklist

Before shipping any feature, verify:

**VoiceOver:**
- [ ] Every interactive element has `.accessibilityLabel()`
- [ ] Labels describe purpose, not interaction ("Settings" not "Settings button")
- [ ] Complex views group elements with `.accessibilityElement(children: .combine)`
- [ ] Decorative elements use `.accessibilityHidden(true)`
- [ ] Navigation flow is logical (top-to-bottom, left-to-right)

**Dynamic Type:**
- [ ] All text uses native SwiftUI fonts (`.body`, `.headline`, `.caption`)
- [ ] All icons use `@ScaledMetric(relativeTo:)`
- [ ] Layout tested at `.accessibility3` size
- [ ] No text truncation at largest size
- [ ] Buttons remain tappable (44pt minimum)

**Always-On Display:**
- [ ] AOD detected with `@Environment(\.isLuminanceReduced)`
- [ ] Colors dim to 50-60% opacity in AOD mode
- [ ] Text remains legible (high contrast)
- [ ] Tested on physical device (Simulator inaccurate)

**Haptic Feedback:**
- [ ] Every button plays a haptic
- [ ] Haptic type matches action semantics (success/failure/click)
- [ ] Haptic timing is synchronous with visual feedback
- [ ] Tested on physical device (Simulator cannot play haptics)

**Device Testing:**
- [ ] Tested on Apple Watch (Simulator is insufficient for AOD and haptics)
- [ ] VoiceOver navigation works correctly
- [ ] Dynamic Type tested at multiple sizes
- [ ] AOD appearance verified
- [ ] Haptic feedback felt on all interactions

---

## Contribution Guidelines

This section provides a comprehensive checklist and requirements for creating new SwiftUI components in Claude Watch. Follow these guidelines to ensure consistency, accessibility, and maintainability across the codebase.

**Target Audience:** Developers contributing new UI components or modifying existing views.

---

### Component Creation Checklist

Use this checklist when creating a new SwiftUI component:

#### 1. Component Structure

- [ ] **File Organization**: Component placed in `ClaudeWatch/Views/` directory
- [ ] **MARK Comments**: Use `// MARK: - ComponentName` for primary sections
- [ ] **Component Type**: Use `struct` (value type) for all SwiftUI views
- [ ] **Preview Provider**: Include `#Preview { ComponentName() }` at bottom of file
- [ ] **Import Statements**: Only import `SwiftUI` and `WatchKit` (minimize dependencies)
- [ ] **Line Length**: Keep component under 150 lines; extract subviews if longer

**Example Structure:**
```swift
import SwiftUI
import WatchKit

// MARK: - Status Badge Component
struct StatusBadge: View {
    let status: ConnectionStatus
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        // Implementation
    }
}

// MARK: - Preview
#Preview {
    StatusBadge(status: .connected)
}
```

#### 2. State Management

- [ ] **Local State**: Use `@State` only for view-local UI state (toggles, animations, presentation)
- [ ] **Shared State**: Use `@ObservedObject private var service = WatchService.shared` for app state
- [ ] **Environment Values**: Use `@Environment` for system values (`.isLuminanceReduced`, `.dynamicTypeSize`)
- [ ] **Avoid Prop Drilling**: Access `WatchService.shared` directly in child views instead of passing props
- [ ] **Immutable Props**: Component inputs should be `let` constants, not `@Binding` unless required

**Example:**
```swift
struct ActionCard: View {
    let action: PendingAction // Immutable input
    @ObservedObject private var service = WatchService.shared // Shared state
    @State private var isPressed = false // Local UI state
    @Environment(\.isLuminanceReduced) var isLuminanceReduced // System state

    var body: some View {
        // Implementation
    }
}
```

#### 3. Design System Compliance

- [ ] **Colors**: Use only `Claude.*` color tokens (no raw `Color.red` or hex values)
- [ ] **Typography**: Use native SwiftUI font styles (`.body`, `.headline`, `.caption`, `.footnote`)
- [ ] **Spacing**: Use multiples of 4pt from spacing scale (4, 8, 12, 16, 20, 24)
- [ ] **Corner Radius**: Use standardized radii (8pt small, 12pt medium, 16pt large, 20pt extra-large)
- [ ] **Shadows**: Avoid shadows (watchOS prefers flat design)
- [ ] **Gradients**: Use subtle gradients for buttons (top: color, bottom: color.opacity(0.8))

**Example:**
```swift
// ✅ GOOD - Uses design tokens
Text("Status")
    .font(.headline)
    .foregroundColor(Claude.textPrimary)
    .padding(12) // Multiple of 4

RoundedRectangle(cornerRadius: 16)
    .fill(Claude.surface1)

// ❌ BAD - Raw values
Text("Status")
    .font(.system(size: 17))
    .foregroundColor(Color(hex: "#FFFFFF"))
    .padding(13) // Not on spacing scale
```

#### 4. Accessibility Requirements

**All components MUST meet these accessibility criteria:**

- [ ] **VoiceOver Labels**: Every interactive element has `.accessibilityLabel()`
- [ ] **Label Quality**: Labels describe purpose, not interaction ("Settings" not "Settings button")
- [ ] **Hints (Optional)**: Use `.accessibilityHint()` when action result isn't obvious
- [ ] **Value (Dynamic State)**: Use `.accessibilityValue()` for progress, toggles, counts
- [ ] **Hidden Decorations**: Decorative elements use `.accessibilityHidden(true)`
- [ ] **Grouped Elements**: Complex cards use `.accessibilityElement(children: .combine)`
- [ ] **Dynamic Type**: All text uses native fonts, all icons use `@ScaledMetric(relativeTo:)`
- [ ] **Large Text Support**: Component tested at `.accessibility3` size (no truncation)
- [ ] **Tap Target Size**: Interactive elements ≥ 44pt minimum hit area
- [ ] **AOD Support**: Component dims gracefully with `isLuminanceReduced`
- [ ] **Color Contrast**: Text meets WCAG AA (4.5:1) or AAA (7:1) contrast ratios

**Example:**
```swift
Button {
    service.approveAction(action.id)
    WKInterfaceDevice.current().play(.success)
} label: {
    HStack(spacing: 8) {
        Image(systemName: "checkmark")
            .font(.system(size: iconSize, weight: .semibold))
        Text("Approve")
            .font(.body)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(minHeight: 44) // Minimum tap target
}
.accessibilityLabel("Approve \(action.title)")
.accessibilityHint("Approves \(action.filePath.filename)")
```

#### 5. Animation & Interaction

- [ ] **Haptic Feedback**: Every button calls `WKInterfaceDevice.current().play(.click)`
- [ ] **Semantic Haptics**: Use `.success` for approve, `.failure` for reject, `.click` for navigation
- [ ] **Spring Animations**: Use `.buttonSpring` for buttons, `.gentleSpring` for subtle transitions
- [ ] **Animation Timing**: Keep animations under 0.5s (watchOS prefers quick interactions)
- [ ] **No Over-Animation**: Limit simultaneous animations (max 2-3 elements animating together)
- [ ] **Reduced Motion**: Respect `.accessibilityReduceMotion` for critical animations

**Example:**
```swift
Button {
    WKInterfaceDevice.current().play(.success) // Haptic
    withAnimation(.buttonSpring) { // Spring animation
        service.approveAction(action.id)
    }
} label: {
    Text("Approve")
}
.scaleEffect(isPressed ? 0.95 : 1.0) // Subtle press effect
.animation(.buttonSpring, value: isPressed)
```

#### 6. Code Style & Conventions

- [ ] **Swift Style**: Follow Apple's Swift API Design Guidelines
- [ ] **Naming**: Use descriptive names (`connectionStatus` not `cs`, `isLoading` not `loading`)
- [ ] **Guard Statements**: Use `guard` for early exits and unwrapping
- [ ] **Force Unwrapping**: Avoid `!` unless justified with comment
- [ ] **Async/Await**: Use `async/await` for all async operations (no completion handlers)
- [ ] **No Print**: Remove all `print()` statements (use proper logging if needed)
- [ ] **No Debug Code**: Remove commented code, TODO markers before commit
- [ ] **File Header**: No file headers (Xcode default template)

**Example:**
```swift
// ✅ GOOD
guard let action = service.state.pendingActions.first else {
    return Text("No actions")
}

// ❌ BAD
let action = service.state.pendingActions.first!
```

#### 7. Testing Requirements

**All components MUST be tested:**

- [ ] **Xcode Preview**: Component renders in Xcode Canvas preview
- [ ] **Simulator Testing**: Tested on watchOS Simulator (Apple Watch Series 9 45mm minimum)
- [ ] **Device Testing**: Tested on physical Apple Watch (for AOD and haptics)
- [ ] **VoiceOver Testing**: Navigated with VoiceOver enabled (Settings → Accessibility → VoiceOver)
- [ ] **Dynamic Type Testing**: Tested at `.accessibility3` size (largest accessibility size)
- [ ] **AOD Testing**: Verified appearance in Always-On Display mode (physical device only)
- [ ] **Haptic Testing**: Verified haptic feedback on physical device (Simulator cannot play haptics)
- [ ] **State Variations**: Tested all component states (loading, success, error, empty)
- [ ] **Edge Cases**: Tested with long text, missing data, extreme values

**Testing Checklist:**
```markdown
## Component Testing Log

### Xcode Preview
- [ ] Renders without errors
- [ ] All states visible in preview

### Simulator Testing
- [ ] Launches successfully
- [ ] Interactions work correctly
- [ ] Animations smooth (60 FPS)

### Device Testing (Physical Watch)
- [ ] AOD appearance verified
- [ ] Haptics felt on interactions
- [ ] VoiceOver navigation works
- [ ] Dynamic Type scales correctly

### Edge Cases
- [ ] Long text (truncation/wrapping)
- [ ] Empty state
- [ ] Loading state
- [ ] Error state
```

#### 8. Performance Requirements

- [ ] **No Main Thread Blocking**: All network/disk operations run on background threads
- [ ] **Efficient Rendering**: Minimize `body` re-evaluations (use `let` computed properties)
- [ ] **List Performance**: Use `LazyVStack` for scrolling lists (>5 items)
- [ ] **Image Optimization**: SF Symbols preferred over custom images
- [ ] **No Memory Leaks**: No strong reference cycles (use `[weak self]` in closures)
- [ ] **OLED Optimization**: Use pure black (`Claude.background`) to save battery

---

### Code Organization Patterns

#### Component Hierarchy

**Follow this component extraction pattern:**

1. **Single-Screen Views** (e.g., `MainView.swift`)
   - Orchestrates layout and state-based view switching
   - Should NOT contain business logic (use `WatchService`)
   - Maximum 200 lines

2. **Feature Components** (e.g., `ActionQueue`, `StatusHeader`)
   - Self-contained UI modules (50-150 lines)
   - Extract when a section exceeds 50 lines or is reused
   - Use `// MARK: - ComponentName` above definition

3. **Primitive Components** (e.g., buttons, badges, cards)
   - Highly reusable, single-purpose (20-50 lines)
   - Should be stateless (accept inputs, render output)
   - Example: `StatusBadge`, `ConnectionIndicator`

**Example Hierarchy:**
```
MainView (orchestrator)
├── StatusHeader (feature component)
│   ├── ConnectionIndicator (primitive)
│   └── StatusBadge (primitive)
├── ActionQueue (feature component)
│   └── ActionCard (primitive)
└── CommandGrid (feature component)
    └── CommandButton (primitive)
```

#### File Organization

```
ClaudeWatch/Views/
├── MainView.swift              # Primary screen
├── PairingView.swift           # Pairing flow
├── OfflineStateView.swift      # Error states
├── Components/                 # Shared components (future)
│   ├── StatusBadge.swift
│   ├── ActionCard.swift
│   └── ConnectionIndicator.swift
└── Sheets/                     # Modal presentations (future)
    ├── SettingsSheet.swift
    └── VoiceInputSheet.swift
```

**Current Structure:**
- All components currently live in `MainView.swift` as inline subviews
- Extract to separate files when a component:
  - Exceeds 100 lines
  - Is reused in multiple screens
  - Has complex internal state

---

### Common Patterns

#### Pattern 1: Action Card Component

**Use Case:** Display a pending action with approve/reject buttons

**Requirements:**
- Uses semantic colors based on action type (file edit, bash command, etc.)
- VoiceOver labels include action type and target
- Haptic feedback on approve/reject
- Accessible tap targets (≥44pt)

**Example:**
```swift
struct ActionCard: View {
    let action: PendingAction
    @ObservedObject private var service = WatchService.shared
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 12) {
            // Action info
            HStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(actionColor)
                Text(action.title)
                    .font(.headline)
                    .foregroundColor(Claude.textPrimary)
                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                // Approve
                Button {
                    WKInterfaceDevice.current().play(.success)
                    service.approveAction(action.id)
                } label: {
                    Label("Approve", systemImage: "checkmark")
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(Claude.success)
                .cornerRadius(12)
                .accessibilityLabel("Approve \(action.title)")

                // Reject
                Button {
                    WKInterfaceDevice.current().play(.failure)
                    service.rejectAction(action.id)
                } label: {
                    Label("Reject", systemImage: "xmark")
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .background(Claude.danger)
                .cornerRadius(12)
                .accessibilityLabel("Reject \(action.title)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Claude.surface1)
        )
        .accessibilityElement(children: .contain)
    }

    private var actionColor: Color {
        switch action.actionType {
        case .fileEdit: return Claude.orange
        case .fileCreate: return Claude.info
        case .fileDelete: return Claude.danger
        case .bash: return Color.purple
        default: return Claude.textSecondary
        }
    }
}
```

#### Pattern 2: Status Indicator with Pulse

**Use Case:** Display connection status with animated pulse effect

**Requirements:**
- Color reflects state (green = connected, red = disconnected, orange = reconnecting)
- Pulse animation for active states
- AOD dimming support
- VoiceOver describes current state

**Example:**
```swift
struct ConnectionIndicator: View {
    let status: ConnectionStatus
    @State private var pulsePhase: CGFloat = 0
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        ZStack {
            // Base circle
            Circle()
                .fill(statusColor.opacity(isLuminanceReduced ? 0.3 : 0.5))
                .frame(width: 12, height: 12)

            // Pulse ring (only when connecting/reconnecting)
            if status == .connecting || status == .reconnecting {
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 12, height: 12)
                    .scaleEffect(1 + pulsePhase * 0.5)
                    .opacity(1 - pulsePhase)
            }
        }
        .accessibilityLabel(statusText)
        .accessibilityAddTraits(.isStaticText)
        .onAppear { startPulse() }
    }

    private var statusColor: Color {
        switch status {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }

    private var statusText: String {
        switch status {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .reconnecting: return "Reconnecting"
        case .disconnected: return "Disconnected"
        }
    }

    private func startPulse() {
        guard status == .connecting || status == .reconnecting else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulsePhase = 1
        }
    }
}
```

#### Pattern 3: Empty State View

**Use Case:** Display when no data is available

**Requirements:**
- Uses tertiary text color
- Includes SF Symbol icon
- Provides contextual message
- Accessible description

**Example:**
```swift
struct EmptyStateView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 48

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: iconSize, weight: .light))
                .foregroundColor(Claude.success.opacity(0.5))

            Text("All Clear")
                .font(.headline)
                .foregroundColor(Claude.textPrimary)

            Text("No pending actions")
                .font(.caption)
                .foregroundColor(Claude.textTertiary)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All clear. No pending actions.")
    }
}
```

---

### Pre-Commit Checklist

**Before committing a new component, verify:**

- [ ] Code compiles without warnings
- [ ] Xcode preview works
- [ ] Component tested in Simulator
- [ ] Component tested on physical device (if modifying AOD/haptics)
- [ ] All accessibility labels added
- [ ] VoiceOver tested (if interactive)
- [ ] Dynamic Type tested at `.accessibility3`
- [ ] No `print()` or debug code
- [ ] No force unwrapping (`!`) without justification
- [ ] Follows design system (colors, typography, spacing)
- [ ] Haptic feedback on all buttons
- [ ] Commit message descriptive (`feat: Add status indicator component`)

**Git Commit Format:**
```bash
# Feature
git commit -m "feat: Add ActionCard component with approve/reject buttons"

# Bug fix
git commit -m "fix: Correct VoiceOver label for settings button"

# Refactor
git commit -m "refactor: Extract StatusHeader into separate component"

# Documentation
git commit -m "docs: Add accessibility guidelines for action cards"
```

---

### Troubleshooting

#### Issue: Component doesn't appear in Preview

**Solution:**
- Ensure `#Preview` is outside the component struct
- Check for missing required properties in preview instantiation
- Verify `import SwiftUI` is present

```swift
// ✅ GOOD
struct MyComponent: View {
    let title: String
    var body: some View { Text(title) }
}

#Preview {
    MyComponent(title: "Test")
}

// ❌ BAD - Missing required property
#Preview {
    MyComponent() // Error: Missing argument for parameter 'title'
}
```

#### Issue: VoiceOver reads incorrect label

**Solution:**
- Use `.accessibilityElement(children: .combine)` to group elements
- Ensure `.accessibilityLabel()` is on the correct element
- Test with VoiceOver rotor to verify reading order

#### Issue: Animation stutters or lags

**Solution:**
- Use `.animation(.buttonSpring, value: state)` instead of implicit animations
- Avoid animating complex paths or large images
- Reduce animation duration (watchOS prefers <0.5s)

#### Issue: Tap targets too small

**Solution:**
- Add `.frame(minHeight: 44)` to button content
- Increase padding: `.padding(.vertical, 12)`
- Test with finger on physical device (not just Simulator)

---

### Additional Resources

**Apple Documentation:**
- [Human Interface Guidelines - watchOS](https://developer.apple.com/design/human-interface-guidelines/watchos)
- [SwiftUI Views - Apple Developer](https://developer.apple.com/documentation/swiftui/views)
- [Accessibility - Apple Developer](https://developer.apple.com/accessibility/)

**Project Files:**
- `ClaudeWatch/Views/MainView.swift` - Reference implementation
- `CLAUDE.md` - Project coding standards
- `docs/specs/SWIFTUI_DESIGN_SYSTEM.md` (this file) - Design system reference

**Tools:**
- **Accessibility Inspector** (Xcode → Open Developer Tool → Accessibility Inspector)
- **VoiceOver Practice** (iPhone → Settings → Accessibility → VoiceOver → Practice Gestures)
- **SF Symbols App** (Download from Apple Developer)

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
