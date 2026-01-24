# User Journey Design Context

> **Decisions captured**: 2026-01-19
> **Participants**: Lead Designer review session
> **Target**: watchOS 26 with Claude Code brand identity

---

## Design Philosophy

**"Claude-native on watchOS 26"** - The app should feel unmistakably like a Claude Code companion while embracing watchOS 26's Liquid Glass design language. Not a generic watch app, not a jarring brand intrusion - a thoughtful hybrid.

---

## Key Decisions

### 1. Visual Language: Hybrid Liquid Glass + Claude

**Choice**: Liquid Glass materials with Claude color system

**Implementation**:
```
┌─────────────────────────────────────────┐
│  LIQUID GLASS CARD                      │
│  ────────────────                       │
│                                         │
│  • Translucent background material      │
│  • Claude Orange (#F97316) accents      │
│  • Claude's text colors for hierarchy   │
│  • Depth via blur + subtle shadows      │
│  • Morphing transitions between states  │
│                                         │
│  NOT:                                   │
│  • Pure Apple system colors             │
│  • Solid opaque backgrounds             │
│  • Generic SF Symbol colors             │
└─────────────────────────────────────────┘
```

**Claude Color Integration**:
- Primary accent: Claude Orange `#F97316`
- Success: Claude Green `#22C55E`
- Danger: Claude Red `#EF4444`
- Background: Translucent with subtle warmth
- Text: Claude's primary/secondary/tertiary hierarchy

**User Note**: *"I have some design ideas / sketches I can share"* - awaiting visual references

---

### 2. Idle State: Ambient Breathing Animation

**Choice**: Claude orange accent element pulses

**Implementation**:
```
┌─────────────────────────────────────────┐
│  BREATHING ANIMATION                    │
│  ───────────────────                    │
│                                         │
│  ┌─────────────────────────────┐        │
│  │ ○ Ready                     │        │
│  │   ↑                         │        │
│  │   Claude orange ring        │        │
│  │   breathes: 0.7 → 1.0 scale │        │
│  │   over 3 second cycle       │        │
│  │                             │        │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━ │        │
│  │  (empty bar, also subtle    │        │
│  │   orange tint breathing)    │        │
│  └─────────────────────────────┘        │
│                                         │
│  Animation specs:                       │
│  • Duration: 3s ease-in-out             │
│  • Scale: 0.9 → 1.0                     │
│  • Opacity: 0.6 → 1.0                   │
│  • Respects Reduce Motion setting       │
└─────────────────────────────────────────┘
```

**Rationale**: The orange accent creates brand presence while communicating "alive and listening" - more active than static text, less distracting than full card animation.

---

### 3. Approval UX: Swipe with Color Fill Reveal

**Choice**: Swipe gestures with color fill feedback

**Implementation**:
```
┌─────────────────────────────────────────┐
│  SWIPE-TO-APPROVE                       │
│  ────────────────                       │
│                                         │
│  INITIAL STATE:                         │
│  ┌─────────────────────────────┐        │
│  │ 🟣 Edit: auth.ts            │        │
│  │                             │        │
│  │   ← swipe left    swipe →   │        │
│  │      reject       approve   │        │
│  └─────────────────────────────┘        │
│                                         │
│  SWIPING RIGHT (approve):               │
│  ┌─────────────────────────────┐        │
│  │████████░░░░░░░░░░░░░░░░░░░░│        │
│  │ GREEN  │ Edit: auth.ts      │        │
│  │ FILL   │                    │        │
│  │████████░░░░░░░░░░░░░░░░░░░░│        │
│  └─────────────────────────────┘        │
│  ↑ Green fills from left as you swipe  │
│                                         │
│  AT THRESHOLD (50%):                    │
│  • Strong haptic feedback               │
│  • Card snaps to complete               │
│  • Morphs to "✓ Approved"               │
│                                         │
│  SWIPING LEFT (reject):                 │
│  • Same pattern, red from right         │
│  • Morphs to "✗ Rejected"               │
│                                         │
│  CANCEL:                                │
│  • Release before threshold             │
│  • Card springs back                    │
│  • No action taken                      │
└─────────────────────────────────────────┘
```

**Interaction Details**:
- Swipe threshold: 50% of card width
- Haptic: `.heavy` impact at threshold
- Animation: 0.3s spring for snap
- Fallback: Tap buttons remain for accessibility

---

### 4. Task Outcome: Ship in v1.0

**Choice**: Critical for closure - must ship with initial release

**Implementation**:
```
┌─────────────────────────────────────────┐
│  OUTCOME DISPLAY                        │
│  ──────────────                         │
│                                         │
│  TRANSITION:                            │
│  Working → Complete (1s) → Outcome      │
│                                         │
│  ┌─────────────────────────────┐        │
│  │ ✓ Done                      │        │
│  │                             │        │
│  │ Fixed auth bug in           │ ← From │
│  │ src/auth.ts                 │   Claude│
│  │                             │        │
│  │ • Updated JWT validation    │ ← Key  │
│  │ • Added error handling      │   points│
│  │                             │        │
│  │ ─────────────────────────── │        │
│  │ 2 files · 47 lines · 23s    │ ← Stats│
│  └─────────────────────────────┘        │
│                                         │
│  DISMISS: Swipe down                    │
│  (consistent with notification pattern) │
│                                         │
│  TIMEOUT: 60s max, then auto-fade       │
│  to listening state                     │
└─────────────────────────────────────────┘
```

**Data Source Priority**:
1. Claude's explicit summary (if captured via hook)
2. Generated from completed task names
3. Generic "Tasks completed successfully"

---

## Implementation Priorities

| Priority | Feature | Complexity | Notes |
|----------|---------|------------|-------|
| **P0** | Swipe-to-approve | Medium | Core interaction change |
| **P0** | Task Outcome display | Medium | Critical for closure |
| **P1** | Liquid Glass styling | Low | CSS/SwiftUI styling |
| **P1** | Breathing animation | Low | Simple animation |
| **P2** | Color fill reveal | Medium | Custom gesture + animation |

---

## Open Items

### Awaiting User Input
- [ ] Design sketches for Claude + Liquid Glass hybrid
- [ ] Specific orange accent element placement preferences
- [ ] Outcome text formatting preferences

### Technical Questions
- [ ] How to capture Claude's summary text? (PostResponse hook?)
- [ ] File stats availability (files changed, lines, time)
- [ ] Swipe gesture conflict with system gestures?

---

## Accessibility Considerations

| Feature | Accessibility Fallback |
|---------|----------------------|
| Swipe gestures | Tap buttons remain available |
| Breathing animation | Solid indicator when Reduce Motion enabled |
| Color fill reveal | VoiceOver announces progress percentage |
| Swipe to dismiss | Tap anywhere also dismisses |

---

## watchOS 26 Specifics

### Liquid Glass Integration
```swift
// Use new watchOS 26 glass effect
.glassEffect(.regular)
.glassEffectUnselectedTint(Claude.orange.opacity(0.3))

// Morphing transitions between states
.matchedGeometryEffect(id: "mainCard", in: namespace)
```

### System Integration
- Leverage new `GlassEffectContainer` for card groups
- Use `SymbolEffect` for icon animations
- Respect new `colorSchemeContrast` environment

---

## Summary

The redesigned Claude Watch for watchOS 26 will feel like:

> **"A Liquid Glass window into Claude's mind - distinctly Claude-branded,
> natively watchOS, with satisfying swipe interactions and clear closure
> when tasks complete."**

Key differentiators from v1:
1. **Swipe approvals** - More intentional than tap
2. **Breathing idle** - Alive, not passive
3. **Task outcomes** - Complete feedback loop
4. **Liquid Glass + Claude** - Distinctive yet native

---

## Design System Analysis (from prototype)

> **Analyzed**: 2026-01-19
> **Source**: Claude Watch Design System.zip (React/TypeScript prototype)

### Color Palette (Updated from Prototype)

```swift
// Design System Colors
extension Claude {
    // Primary Brand
    static let orange = Color(hex: "#FF9500")       // Prototype uses Apple orange
    static let orangeLight = Color(hex: "#FFB340")  // Gradients, hover
    static let orangeDark = Color(hex: "#CC7700")   // Pressed states

    // Semantic Colors
    static let success = Color(hex: "#34C759")      // Apple green (not #22C55E)
    static let danger = Color(hex: "#FF3B30")       // Apple red (not #EF4444)
    static let info = Color(hex: "#007AFF")         // Apple blue

    // Surfaces (for Liquid Glass)
    static let surface1 = Color(hex: "#1C1C1E")     // Card backgrounds
    static let surface2 = Color(hex: "#2C2C2E")     // Secondary surfaces
    static let surface3 = Color(hex: "#3A3A3C")     // Tertiary/disabled

    // Text Hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.4)
}
```

### Liquid Glass Card (SwiftUI Implementation)

```swift
struct LiquidGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial.opacity(0.8))
            .background(Color(hex: "#121212").opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .top) {
                // Edge highlight
                LinearGradient(
                    colors: [.clear, .white.opacity(0.25), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .opacity(0.5)
            }
            .overlay {
                // Surface depth gradient
                LinearGradient(
                    colors: [.white.opacity(0.02), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .shadow(color: .black.opacity(0.8), radius: 24, y: 8)
    }
}
```

### Typography Scale

| Size | Weight | Usage | SwiftUI |
|------|--------|-------|---------|
| 9px | Various | Stats, labels | `.system(size: 9)` |
| 10px | Bold | Subtitles, metadata | `.system(size: 10, weight: .bold)` |
| 11px | Regular | Body text | `.system(size: 11)` |
| 12px | Black | Section headers | `.system(size: 12, weight: .black)` |
| 14px | Bold | Primary labels | `.system(size: 14, weight: .bold)` |
| 15px | Bold | Card titles | `.system(size: 15, weight: .bold)` |
| 18px | Bold | Screen titles | `.system(size: 18, weight: .bold)` |

### Action Card Type Icons

```swift
enum ActionType {
    case edit, create, delete, bash, tool

    var icon: String {
        switch self {
        case .edit: return "📝"
        case .create: return "📄"
        case .delete: return "🗑️"
        case .bash: return "▶️"
        case .tool: return "⚙️"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .edit, .tool:
            return LinearGradient(colors: [Color(hex: "#FF9500"), Color(hex: "#D97757")], ...)
        case .create:
            return LinearGradient(colors: [Color(hex: "#007AFF"), Color(hex: "#0051D5")], ...)
        case .delete:
            return LinearGradient(colors: [Color(hex: "#FF3B30"), Color(hex: "#D32F2F")], ...)
        case .bash:
            return LinearGradient(colors: [Color(hex: "#9B59D0"), Color(hex: "#7B3FB2")], ...)
        }
    }
}
```

### Animation Specifications

| Animation | Duration | Easing | Values |
|-----------|----------|--------|--------|
| Breathing pulse | 2s | Infinite | scale: 1 → 1.1 → 1 |
| Card stack offset | spring | damping: 25, stiffness: 200 | |
| Progress bar | 300ms | ease | |
| Tap feedback | instant | | scale: 0.95 |
| Screen transitions | spring | | x: 20 → 0 → -20 |
| Cursor blink | 0.8s | Infinite | opacity: 1 → 0 |

### Task Outcome Screen Layout

```
┌─────────────────────────────────────┐
│ ✓ Done                    [⚙️]     │ ← Header with green dot
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Replacing Ready view...         │ │ ← Title (15px bold)
│ │ Success - 2 tasks completed     │ │ ← Subtitle (10px)
│ │                                 │ │
│ │ • Fix notification suppression  │ │ ← Task list
│ │ • Replace session progress      │ │   (orange bullets)
│ │                                 │ │
│ │ ─────────────────────────────── │ │
│ │ +42/-18 lines      2m 37s       │ │ ← Stats footer
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │       OK, Got it                │ │ ← Orange button
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Dashboard Idle State Layout

```
┌─────────────────────────────────────┐
│ ● Connected            [⚙️]        │ ← Status bar
├─────────────────────────────────────┤
│                                     │
│ ┌─────────────────────────────────┐ │
│ │          🎤                      │ │ ← Mic icon (disabled)
│ │                                 │ │
│ │      Listening...               │ │ ← 16px bold
│ │   Activity will appear here     │ │ ← 10px tertiary
│ │                                 │ │
│ │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │ │ ← Progress bar (0%)
│ │ 0%                         0/0  │ │
│ │                                 │ │
│ │        [ NORMAL → ]             │ │ ← Mode selector
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │    🎤 Voice                     │ │ ← Footer nav
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Critical Implementation Notes

1. **Orange Value**: Prototype uses `#FF9500` (Apple system orange), not `#F97316` (Tailwind orange). Consider which to use for brand consistency.

2. **Approve All Button**: Shows when `actionDeck.length > 1` with count badge.

3. **Card Stack**: Uses 3D perspective with:
   - `perspective: 1000px`
   - Scale: `1 - (idx * 0.04)` per card
   - Y offset: `idx * 6px` (collapsed) or `idx * 160px` (expanded)

4. **Terminal Output**: During execution, shows scrolling log with blinking cursor.

5. **Stats Format**: `+42/-18 lines` and `2m 37s` - monospace, tertiary color.

---

*Design system analyzed. Ready to implement Task Outcome screen and refine existing components.*
