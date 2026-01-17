---
title: "watchOS views must be glanceable - no scrolling"
category: ui-bugs
tags:
  - watchOS
  - SwiftUI
  - design-pattern
  - UX
component: ClaudeWatch/Views/
severity: high
date_solved: 2026-01-17
symptoms:
  - Content cut off on watch screen
  - User needs to scroll to see all options
  - Views designed for larger screens
root_cause: >
  watchOS views were designed without considering the small screen constraint.
  Scrolling on a watch is a design smell - content should fit in a single glance.
---

# watchOS Glanceable Design Principles

## The Rule

**If you need to scroll, redesign the content to fit.**

watchOS interactions should be:
- Single glance to understand state
- Single tap to take action
- No hunting for content

## Problems Fixed

### 1. EmptyStateView
- Removed redundant subtitle and status indicator
- Smaller icon (36pt)
- Used Spacers for natural centering
- Both buttons always visible

### 2. Demo Mode Disconnection
- Added `guard !isDemoMode else { return }` to lifecycle handlers
- Demo mode now fully isolated from connection logic

### 3. Non-functional CommandGrid
- Removed entirely - dead code has no place in UI

### 4. Conditional Button Visibility
- Changed from mode-gated to always-visible
- Users should see all available options

## Design Patterns

### Compact Layout
```swift
VStack(spacing: 12) {
    Spacer()
    // Icon (36pt max)
    // Title (.headline)
    Spacer()
    // Buttons at bottom
    .padding(.bottom, 8)
}
```

### Mode Guard
```swift
func handleAppDidBecomeActive() {
    guard !isDemoMode else { return }
    // connection logic
}
```

## Key Learnings

| Principle | Description |
|-----------|-------------|
| Scrolling is a design smell | Redesign content to fit, don't add scroll |
| Show all options | Don't gate UI based on mode settings |
| Demo mode isolation | All lifecycle methods check mode flags first |
| Remove dead code | Non-functional UI is worse than no UI |
