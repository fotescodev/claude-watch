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
