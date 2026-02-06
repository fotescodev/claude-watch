# Screen Layout Standards

Quick reference for all layout constants used in Remmy's core-flow screens.

## ScreenShell (required for all core-flow screens)

All screens in the main user flow (working, approval, paused, complete, question) must use `ScreenShell` as their root layout container.

| Property | Value | Token |
|----------|-------|-------|
| Root spacing | 6pt | `Claude.Screen.Shell.rootSpacing` |
| Top padding | 4pt | `Claude.Screen.Shell.topPadding` |
| Bottom padding | 8pt | `Claude.Screen.Shell.bottomPadding` |
| Button horizontal padding | 16pt | `Claude.Screen.Shell.buttonHorizontalPadding` |
| Card external padding | none | ScreenShell handles positioning |

## Toolbar Status (MainView)

- `HStack`: 6pt dot + 4pt gap + text + `Spacer(minLength: 0)`
- Font: `.claudeFootnote.weight(.medium)`
- Color: state-specific

## StateCard

| Property | Value | Token |
|----------|-------|-------|
| Internal padding | 12pt | all sides |
| Corner radius | 16pt | `Claude.Radius.large` |

## Buttons

| Context | Vertical padding | Corner radius | Token |
|---------|-----------------|---------------|-------|
| Primary action | 10pt | 20pt | `Claude.Radius.xlarge` |
| Approval (approve/reject) | 10pt | 22pt | `Claude.Radius.button` |
| Queue row | 10pt, `frame(maxWidth: .infinity)` | 20pt | `Claude.Radius.xlarge` |
| In-card (Question) | 8pt (`Claude.Spacing.sm`) | 12pt | `Claude.Radius.medium` |

## Hint Text

Use `ScreenHint("text")` component for all hints below the action row.

Equivalent manual style: `.claudeFootnote.weight(.medium)`, `Claude.textMuted`

## Badges

| Property | Value |
|----------|-------|
| Font | `.system(size: 10, weight: .bold, design: .monospaced)` |
| Horizontal padding | 8pt (`Claude.Spacing.sm`) |
| Vertical padding | 2pt |
| Corner radius | 8pt (`Claude.Radius.small`) |

## DO NOT

- Use hardcoded spacing values — always use `Claude.Spacing.*` or `Claude.Screen.Shell.*`
- Use `Claude.Spacing.*` for corner radii — use `Claude.Radius.*` (separate concerns)
- Roll custom `VStack` layouts for core screens — use `ScreenShell`
- Add `.padding(.horizontal)` to cards inside `ScreenShell` — the shell handles positioning
- Use `.padding(.horizontal, Claude.Spacing.lg)` on button rows — `ScreenShell` applies 16pt automatically
