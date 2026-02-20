# Design Token Mapping — Mechanical Replacement Guide

This file contains EXACT find-and-replace rules. No judgment needed.

## FONT REPLACEMENTS

### Exact matches (find → replace)
```
.font(.system(size: 24, weight: .bold))             → .font(.claudeHero)
.font(.system(size: 20, weight: .bold))              → .font(.claudeIconButton)
.font(.system(size: 20, weight: .semibold))          → .font(.claudeIconButton)
.font(.system(size: 20))                             → .font(.claudeIconButton)
.font(.system(size: 18, weight: .bold))              → .font(.claudeLargeTitle)
.font(.system(size: 18, weight: .semibold))          → .font(.claudeLargeTitle)
.font(.system(size: 17, weight: .semibold))          → .font(.claudeTitle)
.font(.system(size: 16, weight: .bold))              → .font(.claudeTitle)
.font(.system(size: 16, weight: .semibold))          → .font(.claudeTitle)
.font(.system(size: 16))                             → .font(.claudeTitle)
.font(.system(size: 15, weight: .semibold))          → .font(.claudeHeadline)
.font(.system(size: 14, weight: .bold))              → .font(.claudeBodyMedium)
.font(.system(size: 14, weight: .semibold))          → .font(.claudeBodyMedium)
.font(.system(size: 14, weight: .medium))            → .font(.claudeBodyMedium)
.font(.system(size: 14, weight: .regular))           → .font(.claudeBody)
.font(.system(size: 14))                             → .font(.claudeBody)
.font(.system(size: 13, weight: .semibold))          → .font(.claudeSubheadline)
.font(.system(size: 13, weight: .medium))            → .font(.claudeSubheadline)
.font(.system(size: 13))                             → .font(.claudeSubheadline)
.font(.system(size: 12, weight: .bold))              → .font(.claudeCaptionBold)
.font(.system(size: 12, weight: .semibold))          → .font(.claudeCaptionBold)
.font(.system(size: 12, weight: .medium))            → .font(.claudeCaptionMedium)
.font(.system(size: 12))                             → .font(.claudeCaption)
.font(.system(size: 11, weight: .bold))              → .font(.claudeFootnoteBold)
.font(.system(size: 11, weight: .semibold))          → .font(.claudeFootnoteBold)
.font(.system(size: 11, weight: .medium))            → .font(.claudeFootnoteMedium)
.font(.system(size: 11))                             → .font(.claudeFootnote)
.font(.system(size: 10, weight: .bold, design: .monospaced))  → .font(.claudeMicroMono)
.font(.system(size: 10, weight: .semibold))          → .font(.claudeMicroSemibold)
.font(.system(size: 10, weight: .medium))            → .font(.claudeMicroMedium)
.font(.system(size: 10, design: .monospaced))        → .font(.claudeMonoSmall)
.font(.system(size: 10))                             → .font(.claudeMicro)
.font(.system(size: 9, weight: .bold, design: .monospaced))   → .font(.claudeMonoTiny)
.font(.system(size: 9, weight: .bold))               → .font(.claudeNanoBold)
.font(.system(size: 9, weight: .semibold))           → .font(.claudeNano)
.font(.system(size: 9, weight: .medium))             → .font(.claudeNano)
.font(.system(size: 9))                              → .font(.claudeNano)
.font(.system(size: 7, weight: .bold, design: .monospaced))   → .font(.claudeMonoTiny)
.font(.system(size: 7, weight: .bold))               → .font(.claudeNanoBold)
.font(.system(size: 36, weight: .light))             → .font(.claudeIconLarge)
.font(.system(size: 40, weight: .light))             → .font(.claudeIconDisplay)
.font(.system(size: 32))                             → .font(.claudeHero)
.font(.system(size: 13, weight: .medium, design: .monospaced)) → .font(.claudeMono)
```

### Special cases — use judgment:
- If a view already uses `@ScaledMetric`, keep it
- Icon sizes inside Image(systemName:) with .font(.system(size: N)): use the closest token
- ScreenShell preview code: update to match tokens too

## COLOR REPLACEMENTS

### RGB Literal → Token
```
Color(red: 0.604, green: 0.604, blue: 0.624)  → Claude.textMuted
Color(red: 0.431, green: 0.431, blue: 0.451)  → Claude.textDisabled
Color(red: 0.557, green: 0.557, blue: 0.576)  → Claude.idle
```

### Duplicate System Colors → Token
```
Color(red: 0.204, green: 0.780, blue: 0.349)  → Claude.success    (was: greenColor)
Color(red: 1.0, green: 0.584, blue: 0.0)      → Claude.warning    (was: orangeColor)
Color(red: 1.0, green: 0.231, blue: 0.188)    → Claude.danger     (was: redColor)
```

### Remove local color constant declarations:
```
private let greenColor = Color(red: 0.204, ...)   → DELETE (use Claude.success)
private let orangeColor = Color(red: 1.0, ...)    → DELETE (use Claude.warning)
private let redColor = Color(red: 1.0, ...)       → DELETE (use Claude.danger)
```

### White Opacity → Token (for fills/backgrounds only, NOT for text)
```
Color.white.opacity(0.03)   → Claude.fillSubtle
Color.white.opacity(0.07)   → Claude.fill1
Color.white.opacity(0.08)   → Claude.fill1
Color.white.opacity(0.10)   → Claude.fill2
Color.white.opacity(0.1)    → Claude.fill2
Color.white.opacity(0.12)   → Claude.fill2
Color.white.opacity(0.15)   → Claude.fill3
```

### White Opacity → Token (for text foregroundStyle)
```
.foregroundStyle(Color.white.opacity(0.38))  → .foregroundStyle(Claude.textHint)
.foregroundStyle(Color.white.opacity(0.4))   → .foregroundStyle(Claude.textTertiary)
.foregroundStyle(Color.white.opacity(0.5))   → .foregroundStyle(Claude.textMuted)
.foregroundStyle(Color.white.opacity(0.6))   → .foregroundStyle(Claude.textSecondary)
.foregroundStyle(Color.white.opacity(0.7))   → .foregroundStyle(Claude.textSecondary)
.foregroundStyle(.white.opacity(0.38))       → .foregroundStyle(Claude.textHint)
.foregroundStyle(.white.opacity(0.4))        → .foregroundStyle(Claude.textTertiary)
.foregroundStyle(.white.opacity(0.5))        → .foregroundStyle(Claude.textMuted)
.foregroundStyle(.white.opacity(0.6))        → .foregroundStyle(Claude.textSecondary)
.foregroundStyle(.white.opacity(0.7))        → .foregroundStyle(Claude.textSecondary)
```

## WHAT NOT TO CHANGE

1. DO NOT change `.foregroundStyle(.white)` → it maps to Claude.textPrimary but .white is fine
2. DO NOT change color opacity used for state tints like `Claude.danger.opacity(0.15)` — those are intentional semantic tints
3. DO NOT change colors inside `LinearGradient` unless they match exact RGB patterns above
4. DO NOT change `@ScaledMetric` properties — they're already correct
5. DO NOT change fonts inside `#Preview` blocks at the end of files
6. DO NOT touch `Claude.swift` itself (it's the source of truth)
7. DO NOT change the `ScreenShell.swift`, `ScreenActionButton`, or `ScreenSecondaryButton` definitions — only update their USAGE in other files
