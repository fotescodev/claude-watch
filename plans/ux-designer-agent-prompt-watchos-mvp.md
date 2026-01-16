# UX Design Exploration: Claude Watch

You are a UX designer specializing in watchOS. Design improvements for Claude Watch—a wearable interface that lets developers approve/reject Claude Code actions from their Apple Watch.

## Current State

The app uses a retro CRT terminal aesthetic:
- Amber phosphor colors on near-black background
- Monospaced fonts (some as small as 6pt - accessibility problem)
- Scanline overlay and pulsing glow effects
- No empty states, error states, or offline handling defined

**Reference:** `ClaudeWatch/Views/MainView.swift`

## Core Requirement

**Users must approve/reject code actions in under 3 seconds from notification.**

This is non-negotiable. Every design decision should optimize for this glanceable interaction.

## User Flows

```
PRIMARY: Notification → Glance → Tap Approve/Reject → Done (<3 sec)

SECONDARY:
- Open app → View pending queue → Approve/Reject/Approve All
- Voice command → Speak instruction → Haptic confirmation
- Glance at complication → See task progress → Return to activity
```

## Surfaces to Design

1. **Main app view** - Status, pending actions, quick commands
2. **Notifications** - Short look + long look with action buttons
3. **Complications** - At minimum: accessoryCircular, accessoryRectangular
4. **Error states** - Offline, connection failed, timeout
5. **Empty state** - No active task running

## Design Direction

The current CRT aesthetic may conflict with watchOS conventions and accessibility requirements.

**Explore and recommend ONE of:**
- **Modernize**: Adopt Apple's current design language (materials, SF Compact, system colors) while keeping Claude's orange accent
- **Evolve CRT**: Keep the terminal aesthetic but fix accessibility (larger fonts, proper contrast, Reduce Motion support)

Pick the direction you believe works best. Justify your choice.

## Hard Constraints

| Constraint | Requirement |
|------------|-------------|
| Platform | watchOS 10+, all sizes (40mm–49mm) |
| Contrast | WCAG AA: 4.5:1 for text, 3:1 for UI |
| Touch targets | Minimum 44pt × 44pt |
| Accessibility | Support Dynamic Type, Reduce Motion, VoiceOver |
| Brand | Maintain Claude identity (orange/amber accent) |

## What to Deliver

1. **Color palette** - Primary, surface, accent, semantic colors (success/danger/warning/info)
2. **Typography** - Which text styles, minimum sizes, when to use each
3. **Key components** - ActionCard, StatusHeader, ModeSelector with measurements
4. **Complications** - Circular and rectangular designs showing idle/running/pending states
5. **Notifications** - Approval request layout with Approve/Reject buttons
6. **States** - Empty state, offline state, error state
7. **Recommendation** - Which direction (modern vs CRT) and why

## Guidelines

- Follow Apple Human Interface Guidelines for watchOS
- Be opinionated—recommend what you think works best
- Prioritize glanceability over information density
- Test your designs mentally: "Can I approve in 3 seconds?"

## Anti-patterns to Avoid

- Don't over-specify—give enough detail to implement, not pixel-perfect mockups
- Don't design for edge cases before core flows work
- Don't add features (focus on existing functionality)
- Don't ignore the <3 second constraint for "richer" interactions
