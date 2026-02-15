# Claude Watch V3 Complications Specifications

> **Source**: `/Users/dfotesco/CLAUDE/v2.pen`
> **Flow I Node ID**: `iC508`
> **Flow J Node ID**: `X3I9c`

---

## Complication Types Overview

| Type | Size | States | Use Case |
|------|------|--------|----------|
| Circular | 64×64 | 3 | Modular Compact, corners |
| Rectangular | 180×50 | 3 | Info Graph corners |
| Corner | 44×44 | 4 | Infograph corners |
| Graphic Extra Large | 180×90 | 2 | Large info display |

---

## Circular Complications

**Container Node ID**: `DLvnX`

### Specs
- **Size**: 64×64 pixels (circular)
- **Background**: `#1C1C1E` (dark gray)
- **Icon Size**: 24×24 pixels, 6px corner radius
- **Text**: 10-14pt Inter
- **Layout**: Icon top, text bottom

### States

#### 1. Idle State
**Node ID**: `b8ttB`

```
    ┌────────────────┐
   ╱                  ╲
  │   [🟧 24×24]      │
  │                    │
  │      Idle          │  ← 10pt 500 #8E8E93
   ╲                  ╱
    └────────────────┘
```

- Icon: `#d97757` (brand orange), 24×24, 6px radius
- Label: "Idle", 10pt Inter 500, `#8E8E93`

#### 2. Working State
**Node ID**: `oBly7`

```
    ┌────────────────┐
   ╱                  ╲
  │   [🟦 24×24]      │
  │                    │
  │      67%           │  ← 11pt 600 #007AFF
   ╲                  ╱
    └────────────────┘
```

- Icon: `#007AFF` (working blue), 24×24, 6px radius
- Label: "67%", 11pt Inter 600, `#007AFF`

#### 3. Approval State
**Node ID**: `aOYzL`

```
    ┌────────────────┐
   ╱                  ╲
  │   [🟩 24×24]      │
  │                    │
  │       1            │  ← 14pt 700 #34C759
   ╲                  ╱
    └────────────────┘
```

- Icon: `#34C759` (success green), 24×24, 6px radius
- Label: pending count, 14pt Inter 700, `#34C759`

---

## Rectangular Complications

**Container Node ID**: `JDkyt`

### Specs
- **Size**: 180×50 pixels
- **Background**: `#1C1C1E`, 12px corner radius
- **Padding**: 8px vertical, 12px horizontal
- **Gap**: 10px between icon and text
- **Icon Size**: 28×28 pixels, 8px corner radius

### States

#### 1. Idle State
**Node ID**: `Xz9cc`

```
┌─────────────────────────────────────┐
│  [🟧 28×28]   Claude Code           │
│               Ready                  │
└─────────────────────────────────────┘
```

- Icon: `#d97757`, 28×28, 8px radius
- Title: "Claude Code", 12pt Inter 600, `#FFFFFF`
- Subtitle: "Ready", 10pt Inter, `#8E8E93`

#### 2. Working State
**Node ID**: `NDCte`

```
┌─────────────────────────────────────┐
│  [🟦 28×28]   Working 67%           │
│               Update auth service    │
└─────────────────────────────────────┘
```

- Icon: `#007AFF`, 28×28, 8px radius
- Title: "Working 67%", 12pt Inter 600, `#007AFF`
- Subtitle: current task, 10pt Inter, `#9A9A9F`

#### 3. Approval State
**Node ID**: `CgLAk`

```
┌─────────────────────────────────────┐
│  [🟩 28×28    1 Pending             │
│   with "1"]   Edit auth.ts          │
└─────────────────────────────────────┘
```

- Icon: `#34C759` with count inside, 28×28, 8px radius
- Count inside: 14pt Inter 700, `#000000` (black on green)
- Title: "1 Pending", 12pt Inter 600, `#34C759`
- Subtitle: action description, 10pt Inter, `#9A9A9F`

---

## Corner Complications

**Container Node ID**: `bTACK`

### Specs
- **Size**: 44×44 pixels
- **Background**: `#1C1C1E`, 22px corner radius (circular)
- **Icon Size**: 20×20 pixels, 5px corner radius

### States

#### 1. Idle State
**Node ID**: `7J2u0`

```
  ┌────────┐
 ╱  [🟧]   ╲
│   20×20   │
 ╲         ╱
  └────────┘
```

- Background: `#1C1C1E`, fully circular
- Icon: `#d97757`, 20×20, 5px radius

#### 2. Working State
**Node ID**: `C7J6N`

```
  ┌────────┐
 ╱  [🟦]   ╲
│   20×20   │
 ╲         ╱
  └────────┘
```

- Background: `#1C1C1E`
- Icon: `#007AFF`, 20×20, 5px radius

#### 3. Approval State
**Node ID**: `lG8Td`

```
  ┌────────┐
 ╱    1    ╲     ← 16pt 700 black text
│  🟩 fill  │     ← Green background
 ╲         ╱
  └────────┘
```

- Background: `#34C759` (green fill, not dark)
- Text: count, 16pt Inter 700, `#000000`

#### 4. Error State
**Node ID**: `Xthba`

```
  ┌────────┐
 ╱   ⚠️    ╲     ← error icon (Material Symbols)
│  🟥 fill  │     ← Red background
 ╲         ╱
  └────────┘
```

- Background: `#FF3B30` (red fill)
- Icon: Material Symbols "error", 20×20, `#FFFFFF`

---

## Graphic Extra Large Complications

**Container Node ID**: `eknaH`

### Specs
- **Size**: 180×90 pixels
- **Background**: `#1C1C1E`, 16px corner radius
- **Icon Size**: 36×36 pixels, 10px corner radius
- **Glow**: 80×60 ellipse, 25px blur, 30% opacity

### States

#### 1. Idle State
**Node ID**: `l3OmW`

```
┌─────────────────────────────────────┐
│                          [🟧 36×36] │
│                      (with glow)    │
│                                     │
│  Claude Code                        │  ← 15pt 600 #FFFFFF
│  Idle • Ready to work               │  ← 11pt #8E8E93
└─────────────────────────────────────┘
```

- Icon: `#d97757`, 36×36, 10px radius, positioned top-right
- Glow: `#d9775730`, 80×60, 25px blur
- Title: "Claude Code", 15pt Inter 600, `#FFFFFF`
- Subtitle: "Idle • Ready to work", 11pt Inter, `#8E8E93`

#### 2. Working State
**Node ID**: `ase1n`

```
┌─────────────────────────────────────┐
│                          [🟦 36×36] │
│                      (with glow)    │
│                                     │
│  Working 67%                        │  ← 15pt 600 #007AFF
│  Update auth service                │  ← 11pt #9A9A9F
└─────────────────────────────────────┘
```

- Icon: `#007AFF`, 36×36, 10px radius
- Glow: `#007AFF30`, 80×60, 25px blur
- Title: "Working 67%", 15pt Inter 600, `#007AFF`
- Subtitle: current task, 11pt Inter, `#9A9A9F`

---

## Watch Face Integration (Flow J)

**Container Node ID**: `X3I9c`

### Supported Watch Faces

| Face | Node ID | Complication Slots |
|------|---------|-------------------|
| Modular Compact | `vuvwu` | Circular center |
| Infograph | `Jb9r9` | 4 corner complications |
| California | `mz9To` | Circular subdial |
| Metropolitan | `7FFaV` | Rectangular bottom |

### Modular Compact Face
**Node ID**: `vuvwu`

- Uses: Circular complication in center
- Best for: Quick glance at status
- Example: Shows Working state with percentage

### Infograph Face
**Node ID**: `Jb9r9`

- Uses: 4 Corner complications
- Best for: Multiple Claude states visible
- Example: Claude in one corner, other apps in others

### California Face
**Node ID**: `mz9To`

- Uses: Circular complication in subdial position
- Best for: Classic look with Claude status
- Example: Idle state with brand icon

### Metropolitan Face
**Node ID**: `7FFaV`

- Uses: Rectangular complication at bottom
- Best for: More detail (task name visible)
- Example: Working state with current task

---

## SwiftUI Implementation Reference

```swift
import WidgetKit
import SwiftUI

// MARK: - Complication Entry
struct ClaudeComplicationEntry: TimelineEntry {
    let date: Date
    let state: ClaudeState
    let progress: Double?
    let pendingCount: Int
    let currentTask: String?
}

// MARK: - Circular Complication
struct CircularComplicationView: View {
    let entry: ClaudeComplicationEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#1C1C1E"))

            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(entry.state.color)
                    .frame(width: 24, height: 24)

                Text(labelText)
                    .font(.system(size: fontSize, weight: fontWeight))
                    .foregroundColor(entry.state.color)
            }
        }
    }

    var labelText: String {
        switch entry.state {
        case .idle: return "Idle"
        case .working: return "\(Int((entry.progress ?? 0) * 100))%"
        case .approval: return "\(entry.pendingCount)"
        default: return ""
        }
    }
}

// MARK: - Corner Complication
struct CornerComplicationView: View {
    let entry: ClaudeComplicationEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            content
        }
        .frame(width: 44, height: 44)
    }

    var backgroundColor: Color {
        switch entry.state {
        case .approval: return Claude.success
        case .error: return Claude.danger
        default: return Color(hex: "#1C1C1E")
        }
    }

    @ViewBuilder
    var content: some View {
        switch entry.state {
        case .approval:
            Text("\(entry.pendingCount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
        default:
            RoundedRectangle(cornerRadius: 5)
                .fill(entry.state.color)
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Rectangular Complication
struct RectangularComplicationView: View {
    let entry: ClaudeComplicationEntry

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(entry.state.color)
                    .frame(width: 28, height: 28)

                if entry.state == .approval {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(titleColor)

                Text(subtitleText)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#9A9A9F"))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "#1C1C1E"))
        .cornerRadius(12)
    }

    var titleText: String {
        switch entry.state {
        case .idle: return "Claude Code"
        case .working: return "Working \(Int((entry.progress ?? 0) * 100))%"
        case .approval: return "\(entry.pendingCount) Pending"
        default: return "Claude Code"
        }
    }
}

// MARK: - Graphic Extra Large
struct GraphicExtraLargeView: View {
    let entry: ClaudeComplicationEntry

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1C1C1E"))

            // Glow effect
            Ellipse()
                .fill(entry.state.color.opacity(0.18))
                .frame(width: 80, height: 60)
                .blur(radius: 25)
                .offset(x: 50, y: -15)

            // Icon
            RoundedRectangle(cornerRadius: 10)
                .fill(entry.state.color)
                .frame(width: 36, height: 36)
                .offset(x: 50, y: -20)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(titleColor)

                Text(subtitleText)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#8E8E93"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            .padding(.top, 35)
        }
        .frame(width: 180, height: 90)
    }
}
```

---

## Complication Families Reference

| watchOS Family | V3 Equivalent | Size |
|----------------|---------------|------|
| `circularSmall` | Circular | 64×64 |
| `rectangularSmall` | Rectangular | 180×50 |
| `corner` | Corner | 44×44 |
| `graphicExtraLarge` | Graphic Extra Large | 180×90 |
| `graphicCircular` | Circular | 64×64 |
| `graphicCorner` | Corner | 44×44 |
| `graphicRectangular` | Rectangular | 180×50 |

---

## Priority Implementation Order

1. **Corner** (P0) - Most versatile, works on Infograph
2. **Circular** (P0) - Works on Modular, California
3. **Rectangular** (P1) - More detail, Metropolitan
4. **Graphic Extra Large** (P2) - Visual polish
