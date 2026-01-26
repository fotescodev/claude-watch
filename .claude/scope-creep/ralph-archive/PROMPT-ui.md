# UI & Accessibility Standards

This module is loaded for tasks tagged with: `ui`, `accessibility`, `hig`, `design`

---

## Accessibility (Required)
- Add `.accessibilityLabel()` to all interactive elements
- Add `.accessibilityHint()` for non-obvious actions
- Respect `@Environment(\.accessibilityReduceMotion)`
- Test with VoiceOver
- Use semantic views where possible

## UI Screenshot Capture

**If the task modified UI**, capture a screenshot:

```bash
# Boot simulator and capture
xcrun simctl boot "[Simulator Name]"
xcrun simctl io "[Simulator Name]" screenshot ~/Desktop/task-[ID]-after.png
```

## Haptic Feedback
- Use `.sensoryFeedback()` for haptics on watchOS
- Provide tactile confirmation for actions
- Use appropriate feedback types (success, warning, error)

## Design Principles
- Prefer single-tap interactions
- Use SF Symbols for icons
- Support Dynamic Type
- Respect Safe Area Insets
- Support Dark Mode
