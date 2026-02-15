# Typography & Spacing Standardization Plan

## Design Tokens to Use (from Claude.swift)

### Typography
- **claudeLargeTitle**: 18pt bold → Screen headers
- **claudeHeadline**: 15pt semibold → Section titles, card titles
- **claudeBody**: 14pt regular → Button labels, body text
- **claudeCaption**: 12pt regular → Subtitles, descriptions
- **claudeFootnote**: 11pt regular → Secondary info, hints
- **claudeMono**: 13pt monospaced → Badges, codes

### Spacing
- **Claude.Spacing.xs**: 4pt
- **Claude.Spacing.sm**: 8pt
- **Claude.Spacing.md**: 12pt
- **Claude.Spacing.lg**: 16pt
- **Claude.Spacing.xl**: 24pt

### Colors
- **Claude.textPrimary**: White
- **Claude.textSecondary**: 60% white
- **Claude.textDescription**: #9A9A9F
- **Claude.textMuted**: #6E6E73

## Changes by File

### StateViews.swift
- Line 30: `.font(.system(size: 12, weight: .semibold))` → `.font(.claudeFootnote.weight(.semibold))`
- Line 69,137: `.font(.headline)` → `.font(.claudeHeadline)`
- Line 73,141: `.font(.caption)` → `.font(.claudeCaption)`
- Line 85,95: `.font(.caption.weight(.semibold))` → `.font(.claudeBody.weight(.semibold))`
- Line 120: `.font(.system(size: 12, weight: .semibold))` → `.font(.claudeFootnote.weight(.semibold))`
- Line 327: `.font(.system(size: 15, weight: .semibold))` → `.font(.claudeHeadline)`
- Line 347: `.font(.system(size: 17, weight: .semibold))` → `.font(.claudeHeadline)` (17pt→15pt for consistency)
- Line 354: `.font(.system(size: 13))` → `.font(.claudeCaption)` (13pt→12pt)
- Line 360: `.font(.system(size: 11, weight: .medium))` → `.font(.claudeFootnote.weight(.medium))`
- All spacing values: 4→xs, 6→xs, 8→sm, 12→md, 16→lg, 20→lg, 24→xl

### WorkingView.swift
- All custom font sizes use design tokens
- Task row fonts already use system sizes (keep for glanceability)

### PausedView.swift
- Badge font already correct (.system(size: 10, weight: .bold, design: .monospaced))

### ApprovalView.swift
- Needs full refactor to use ScreenShell
- Font sizes: 11pt→claudeFootnote, 10pt for badges OK

### QuestionResponseView.swift
- Large "?" at 24pt can stay (emphasis element)
- Button fonts use claudeFootnote

### ContextWarningView.swift
- Large "75%" at 22pt can stay (emphasis element)
- Other fonts use design tokens

### TaskOutcomeView.swift
- Fonts already mostly standardized

## Key Principle
**Emphasis elements** (large icons, percentages, symbols) can use custom sizes.
**Text content** must use design tokens for consistency.
