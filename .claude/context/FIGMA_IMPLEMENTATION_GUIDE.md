# Claude Watch: Figma Implementation Guide

**Document Version:** 1.0
**Last Updated:** January 2026
**Author:** Design Lead
**Status:** Ready for Implementation

---

## Overview

This guide provides step-by-step instructions for implementing the Claude Watch design system in Figma. It covers file structure, component organization, style definitions, prototyping, and asset export for development handoff.

---

## File Structure

### Recommended Figma Organization

```
Claude Watch Design System/
│
├── 📄 Cover Page
│   └── Project overview, version, last updated
│
├── 📁 1. Foundations
│   ├── 1.1 Colors
│   ├── 1.2 Typography
│   ├── 1.3 Spacing & Grid
│   ├── 1.4 Icons
│   └── 1.5 Effects (Shadows, Glass)
│
├── 📁 2. Components
│   ├── 2.1 Atoms (Buttons, Icons, Badges)
│   ├── 2.2 Molecules (Cards, Inputs)
│   ├── 2.3 Organisms (Action Queue, Command Grid)
│   └── 2.4 Templates (Screen Layouts)
│
├── 📁 3. watchOS Screens
│   ├── 3.1 Onboarding (Consent, Pairing)
│   ├── 3.2 Main Views (Status, Actions, Commands)
│   ├── 3.3 Sheets (Voice, Settings)
│   ├── 3.4 States (Empty, Error, Loading)
│   └── 3.5 Complications
│
├── 📁 4. iOS Companion Screens
│   ├── 4.1 Welcome
│   ├── 4.2 QR Scanner
│   ├── 4.3 Manual Entry
│   ├── 4.4 Syncing
│   └── 4.5 Connected
│
├── 📁 5. Prototypes
│   ├── 5.1 watchOS Flows
│   └── 5.2 iOS Flows
│
└── 📁 6. Assets & Handoff
    ├── 6.1 App Icons
    ├── 6.2 Screenshots
    └── 6.3 Export Specs
```

---

## 1. Setting Up Foundations

### 1.1 Color Styles

Create these color styles in Figma:

#### Brand Colors

| Style Name | Hex | Description |
|------------|-----|-------------|
| `Brand/Orange` | `#FF9500` | Primary brand |
| `Brand/Orange Light` | `#FFB340` | Highlights |
| `Brand/Orange Dark` | `#CC7700` | Active states |

#### Semantic Colors

| Style Name | Hex | Description |
|------------|-----|-------------|
| `Semantic/Success` | `#34C759` | Approve, completed |
| `Semantic/Danger` | `#FF3B30` | Reject, errors |
| `Semantic/Warning` | `#FF9500` | Waiting states |
| `Semantic/Info` | `#007AFF` | Normal mode, info |

#### Surface Colors

| Style Name | Hex | Description |
|------------|-----|-------------|
| `Surface/Background` | `#000000` | App background |
| `Surface/1` | `#1C1C1E` | Primary cards |
| `Surface/2` | `#2C2C2E` | Secondary |
| `Surface/3` | `#3A3A3C` | Tertiary |

#### Text Colors

| Style Name | Value | Description |
|------------|-------|-------------|
| `Text/Primary` | `#FFFFFF` | Main text |
| `Text/Secondary` | `#FFFFFF 60%` | Labels |
| `Text/Tertiary` | `#FFFFFF 40%` | Subtle |

### 1.2 Typography Styles

Create text styles for watchOS:

| Style Name | Font | Size | Weight | Line Height |
|------------|------|------|--------|-------------|
| `Title/Large` | SF Pro | 20 | Bold | 24 |
| `Title/Default` | SF Pro | 17 | Bold | 22 |
| `Headline` | SF Pro | 15 | Semibold | 20 |
| `Subheadline` | SF Pro | 13 | Semibold | 18 |
| `Body` | SF Pro | 15 | Regular | 20 |
| `Footnote` | SF Pro | 13 | Semibold | 18 |
| `Caption` | SF Pro | 12 | Semibold | 16 |
| `Caption 2` | SF Pro | 11 | Regular | 14 |
| `Code` | SF Mono | 13 | Regular | 16 |

### 1.3 Spacing Variables

Set up spacing as Figma variables:

```
Spacing/xs = 4
Spacing/sm = 8
Spacing/md = 12
Spacing/lg = 16
Spacing/xl = 24
```

### 1.4 Corner Radius Variables

```
Radius/small = 8
Radius/medium = 12
Radius/large = 16
Radius/xlarge = 20
Radius/full = 999 (for pills)
```

### 1.5 Effects

#### Glass Effect (Material)

Create background blur effect:
- **Background Blur:** 20px
- **Fill:** `#1C1C1E` at 60% opacity
- **Name:** `Effect/Glass Card`

#### Shadow (subtle depth)

- **X:** 0, **Y:** 2
- **Blur:** 8
- **Color:** `#000000` at 20%
- **Name:** `Effect/Card Shadow`

---

## 2. Building Components

### 2.1 Atoms

#### Button / Primary

**Structure:**
```
Frame (Auto Layout)
├── Label (Text)
└── [Optional] Icon (Instance)
```

**Properties (Component Properties):**
| Property | Type | Options |
|----------|------|---------|
| Label | Text | "Button" |
| State | Variant | Default, Pressed, Disabled |
| Color | Variant | Orange, Green, Red, Blue |
| HasIcon | Boolean | true/false |
| Icon | Instance Swap | Icon set |

**Variants:**
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Default          Pressed           Disabled                    │
│  ┌──────────┐    ┌──────────┐      ┌──────────┐               │
│  │  Label   │    │  Label   │      │  Label   │               │
│  └──────────┘    └──────────┘      └──────────┘               │
│   Opacity 100%    Scale 95%         Opacity 50%                │
│                                                                 │
│  Colors: Orange / Green / Red / Blue                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Figma Settings:**
- Auto Layout: Horizontal, Padding 14/24
- Fill: Linear gradient (Color → Color 80%)
- Corner Radius: 999 (full)
- Min Width: 120

#### Badge

**Structure:**
```
Frame (Fixed size)
├── Background (Fill)
└── Text (Number)
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| Count | Text | "5" |
| Size | Variant | Small (20), Default (28) |

#### Status Dot

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| Status | Variant | Idle, Running, Error, Warning |

**Colors by status:**
- Idle: Green
- Running: Orange
- Error: Red
- Warning: Orange

### 2.2 Molecules

#### Action Type Icon

**Structure:**
```
Frame (40×40)
├── Background (Rounded, Gradient)
└── Icon (SF Symbol)
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| Type | Variant | Edit, Create, Delete, Bash |
| Size | Variant | Small (28), Default (40) |

**Type configurations:**
| Type | Icon | Gradient |
|------|------|----------|
| Edit | pencil | Orange |
| Create | doc.badge.plus | Blue |
| Delete | trash | Red |
| Bash | terminal | Purple |

#### Input Field

**Structure:**
```
Frame (Auto Layout)
├── Label (Optional)
├── Input Container
│   ├── Placeholder/Value
│   └── Clear Button (Optional)
└── Helper Text (Optional)
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| State | Variant | Default, Focused, Error, Disabled |
| HasLabel | Boolean | true/false |
| Placeholder | Text | "Enter code..." |
| Value | Text | "" |

### 2.3 Organisms

#### Primary Action Card

**Structure:**
```
Frame (Auto Layout, Vertical)
├── Header (Auto Layout, Horizontal)
│   ├── Action Type Icon
│   └── Text Container
│       ├── Title
│       └── Description
├── Spacer
└── Button Row (Auto Layout, Horizontal)
    ├── Reject Button
    └── Approve Button
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| ActionType | Variant | Edit, Create, Delete, Bash |
| Title | Text | "Edit App.tsx" |
| Description | Text | "Add dark mode toggle" |
| State | Variant | Default, Loading, Error |

**Figma Settings:**
- Auto Layout: Vertical, Gap 12
- Padding: 14 all sides
- Fill: Effect/Glass Card
- Corner Radius: 12

#### Compact Action Card

**Structure:**
```
Frame (Auto Layout, Horizontal)
├── Action Type Icon (Small)
└── Title
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| ActionType | Variant | Edit, Create, Delete, Bash |
| Title | Text | "Create test.ts" |

**Figma Settings:**
- Auto Layout: Horizontal, Gap 8
- Padding: 10 all sides
- Fill: Surface/1
- Corner Radius: 8

#### Status Header

**Structure:**
```
Frame (Auto Layout, Horizontal)
├── Icon Container
│   ├── Pulse Ring (Hidden when idle)
│   └── Status Icon
├── Text Container
│   ├── Status Line (Dot + Text)
│   ├── Task Name
│   └── Progress Bar
└── Badge (Optional)
```

**Properties:**
| Property | Type | Options |
|----------|------|---------|
| Status | Variant | Idle, Running, Waiting, Complete, Error |
| TaskName | Text | "Building feature" |
| Progress | Number | 0-100 |
| PendingCount | Number | 0+ |

#### Command Grid

**Structure:**
```
Frame (Auto Layout, Vertical)
├── Grid Row 1
│   ├── Go Button
│   └── Test Button
├── Grid Row 2
│   ├── Fix Button
│   └── Stop Button
└── Voice Button (Full width)
```

**Use Auto Layout Grid:**
- Direction: Vertical
- Gap: 8
- Nested horizontal frames for rows

#### Mode Selector

**Structure:**
```
Frame (Auto Layout, Vertical)
├── Label
├── Mode Options (Auto Layout, Horizontal)
│   ├── Normal Mode
│   ├── Auto Mode
│   └── Plan Mode
└── Description
```

**Mode Option Sub-component:**
```
Frame (Auto Layout, Vertical)
├── Icon Container (Circle)
│   └── Icon
├── Label
└── Selection Indicator (Dot)
```

---

## 3. Screen Templates

### watchOS Frame Size

| Device | Width | Height |
|--------|-------|--------|
| 40mm | 162 | 197 |
| 41mm | 176 | 215 |
| 44mm | 184 | 224 |
| 45mm | 198 | 242 |
| 49mm (Ultra) | 205 | 251 |

**Recommended:** Design for 45mm, scale for others

### Screen Template Structure

```
Frame (198×242 for 45mm)
├── Safe Area (Padding 4/4/8/4)
├── Content Area
│   └── Components...
└── [Optional] Toolbar Area
```

### Main View Screen

```
┌─────────────────────────┐
│        [Toolbar]        │  ← Settings gear
├─────────────────────────┤
│                         │
│    [Status Header]      │
│                         │
│    [Primary Action]     │
│                         │
│    [Compact Cards]      │
│                         │
│    [Approve All]        │
│                         │
│    [Command Grid]       │
│                         │
│    [Mode Selector]      │
│                         │
└─────────────────────────┘
```

### iOS Frame Sizes

| Device | Width | Height |
|--------|-------|--------|
| iPhone SE | 375 | 667 |
| iPhone 14 | 390 | 844 |
| iPhone 14 Pro Max | 430 | 932 |
| iPhone 15 Pro | 393 | 852 |

**Recommended:** Design for iPhone 14 (390×844)

---

## 4. Prototyping

### Setting Up Interactions

#### Button Press Animation

1. Select button Default variant
2. Add interaction: On Click → Change To (Pressed variant)
3. Animation: Smart Animate, 100ms, Ease Out
4. Add interaction: After Delay 100ms → Change To (Default)

#### Screen Transitions

| Transition | Animation | Duration | Easing |
|------------|-----------|----------|--------|
| Navigate forward | Smart Animate | 300ms | Ease Out |
| Navigate back | Smart Animate | 300ms | Ease Out |
| Present sheet | Move In (Bottom) | 300ms | Spring |
| Dismiss sheet | Move Out (Bottom) | 250ms | Ease In |

#### Flow Connections

**First Launch Flow:**
```
Splash → Consent 1 → Consent 2 → Consent 3 → Main (Unpaired)
```

**Pairing Flow:**
```
Main (Unpaired) → Pairing View → [Connecting] → Main (Paired)
```

**Approval Flow:**
```
Main (With Action) → [Tap Approve] → Main (Cleared)
```

### Interactive Components

Use Figma's Component Properties for state changes:
- Hover states (for documentation, not watchOS)
- Press states
- Loading states
- Error states

---

## 5. Handoff & Export

### Developer Handoff Checklist

#### For Each Screen

1. **Annotations:**
   - Component names matching Swift files
   - Spacing callouts
   - Color token references
   - Typography style references

2. **Measurements:**
   - Enable "Inspect" panel access
   - Use consistent units (pt)
   - Document responsive behavior

3. **States Documentation:**
   - All component states visible
   - State transition notes
   - Edge case handling

### Export Settings

#### Icons (SF Symbols)

For custom icons not in SF Symbols:
- Format: PDF (vector)
- Scale: @1x (auto-generate @2x, @3x)
- Color: Template mode

#### App Icons

**watchOS:**
| Size | Scale | Purpose |
|------|-------|---------|
| 24×24 | @2x | Notification Center |
| 27.5×27.5 | @2x | Notification Center |
| 29×29 | @2x, @3x | Settings |
| 40×40 | @2x | Home Screen (38mm) |
| 44×44 | @2x | Home Screen (40mm) |
| 50×50 | @2x | Home Screen (44mm) |
| 86×86 | @2x | Short Look (38mm) |
| 98×98 | @2x | Short Look (42mm) |
| 108×108 | @2x | Short Look (44mm) |
| 1024×1024 | @1x | App Store |

**iOS Companion:**
| Size | Scale | Purpose |
|------|-------|---------|
| 20×20 | @2x, @3x | iPad Notifications |
| 29×29 | @2x, @3x | iPhone Settings |
| 40×40 | @2x, @3x | Spotlight |
| 60×60 | @2x, @3x | iPhone Home |
| 76×76 | @1x, @2x | iPad Home |
| 83.5×83.5 | @2x | iPad Pro Home |
| 1024×1024 | @1x | App Store |

#### Screenshots

**watchOS App Store:**
| Device | Size | Required |
|--------|------|----------|
| Series 9 (41mm) | 176×215 @2x | Yes |
| Series 9 (45mm) | 198×242 @2x | Yes |
| Ultra 2 | 205×251 @2x | Yes |

**iOS App Store:**
| Device | Size | Required |
|--------|------|----------|
| 6.7" (iPhone 15 Pro Max) | 1290×2796 | Yes |
| 6.5" (iPhone 14 Plus) | 1284×2778 | Yes |
| 5.5" (iPhone 8 Plus) | 1242×2208 | Optional |

### Naming Convention

Use consistent naming for exported assets:

```
[platform]-[screen]-[variant]-[state].[ext]

Examples:
watchos-main-paired-default.png
watchos-action-card-edit-pressed.png
ios-scanner-scanning.png
icon-watchos-1024.png
```

---

## 6. Design Tokens Export

### For SwiftUI Implementation

Export color tokens as Swift code:

```swift
// Generated from Figma - Claude Watch Design System

import SwiftUI

public enum Claude {
    // Brand
    public static let orange = Color(hex: "FF9500")
    public static let orangeLight = Color(hex: "FFB340")
    public static let orangeDark = Color(hex: "CC7700")

    // Semantic
    public static let success = Color(hex: "34C759")
    public static let danger = Color(hex: "FF3B30")
    public static let warning = Color(hex: "FF9500")
    public static let info = Color(hex: "007AFF")

    // Surface
    public static let background = Color(hex: "000000")
    public static let surface1 = Color(hex: "1C1C1E")
    public static let surface2 = Color(hex: "2C2C2E")
    public static let surface3 = Color(hex: "3A3A3C")

    // Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.6)
    public static let textTertiary = Color.white.opacity(0.4)

    // Spacing
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    // Radius
    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 20
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue >> 16) & 0xff) / 255,
            green: Double((rgbValue >> 8) & 0xff) / 255,
            blue: Double(rgbValue & 0xff) / 255
        )
    }
}
```

---

## 7. Version Control

### Figma Branching

Use Figma branching for major updates:
- `main` - Production-ready designs
- `feature/ios-companion` - iOS app work
- `feature/liquid-glass` - watchOS 26 updates

### Version History

Document changes in Figma page:

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2026 | Initial design system |
| 1.1 | - | iOS Companion app |
| 1.2 | - | Liquid Glass materials |

---

## 8. Collaboration

### Design Review Process

1. **Create branch** for new feature
2. **Build components** following this guide
3. **Request review** from team
4. **Address feedback** in comments
5. **Merge to main** when approved

### Developer Sync

Weekly sync checklist:
- [ ] Review new components
- [ ] Discuss implementation questions
- [ ] Update tokens if changed
- [ ] Export updated assets
- [ ] Document any deviations

---

## Appendix: Figma Plugins Recommended

| Plugin | Purpose |
|--------|---------|
| **Stark** | Accessibility contrast checking |
| **Iconify** | SF Symbols access |
| **Tokens Studio** | Design token management |
| **Autoflow** | User flow diagrams |
| **Figma to Code** | Export to SwiftUI |

---

## Quick Reference Card

### Color Tokens
```
Brand:    #FF9500 (Orange)
Success:  #34C759 (Green)
Danger:   #FF3B30 (Red)
Info:     #007AFF (Blue)
```

### Spacing Scale
```
xs=4  sm=8  md=12  lg=16  xl=24
```

### Radius Scale
```
small=8  medium=12  large=16  xlarge=20  full=999
```

### Typography
```
Title: 17pt Bold
Body: 15pt Regular
Caption: 12pt Semibold
```

### Watch Sizes
```
40mm: 162×197
45mm: 198×242
49mm: 205×251
```

---

*Document maintained by Design Lead. Update when Figma structure changes.*
