# Liquid Glass Design Audit

Audit SwiftUI views for iOS 26 / watchOS 26 "Liquid Glass" design language readiness.

## Liquid Glass Characteristics

### Materials
- `.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`
- Backdrop blur effects
- Vibrancy for text over glass
- Dynamic adaptation to content behind

### Depth & Layering
- Subtle shadows for elevation
- Color-tinted glows
- Z-depth progression
- 3D perspective transforms

### Motion
- Spring animations (response, dampingFraction)
- Gesture-driven interactions
- State transition animations
- Symbol effect transitions

### Color System
- Semantic colors (`.label`, `.secondaryLabel`)
- Dynamic dark/light mode
- High contrast mode support
- Accessibility color mappings

### Typography
- SF Pro with proper weights
- Dynamic Type support
- Tracking (letter-spacing) for elegance
- System text styles

## Audit Process

1. Search for hardcoded colors → Replace with semantic
2. Search for `.background(Color.X)` → Replace with materials
3. Search for missing `.animation()` → Add spring animations
4. Search for fixed font sizes → Replace with text styles
5. Check button styles → Add press states and haptics

## WWDC Sessions to Reference

Query `apple-docs` for:
- `search_wwdc_videos("design system")`
- `search_wwdc_videos("materials SwiftUI")`
- `search_wwdc_videos("animation SwiftUI")`

Provide before/after code examples for each recommendation.
