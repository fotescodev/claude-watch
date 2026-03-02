# Session State - Claude Watch

> Last updated: 2026-03-02
> Session: TestFlight launch review + project template investigation
>
> **Branch:** `master` (also `claude/testflight-launch-review-renrC`)

## Single Source of Truth

**`.claude/plans/MIGRATION_PROGRESS.md`** — all workstream tracking, test counts, timeline.

## Current State

**TestFlight preparation. iOS debris cleaned from project. Ready for archive + upload attempt.**

```
[x] remmy-cli built (dist/cli.mjs, 14KB + dist/hooks/)
[x] remmy globally linked (/opt/homebrew/bin/remmy → dist/cli.mjs)
[x] 147 CLI tests passing (110 lib + 15 hooks + 22 commands)
[x] Cloud worker healthy (https://claude-watch.fotescodev.workers.dev)
[x] Hook installed at ~/.claude/hooks/watch-approval-cloud.py
[x] Hook registered in ~/.claude/settings.json (PreToolUse)
[x] All watch views E2E tested on simulator (see docs/E2E_TESTING.md)
[x] C1: Watch approval flow verified in live Claude session
[x] AskUserQuestion routes to watch — answer via /tmp/remmy-question-answer.json
[x] R5: KV TTL fixed — session data 5min → 1hr, deployed
[x] F1-F3: Legacy cleanup — 17 hook files, 6 cloud endpoints, stale config removed
[x] TestFlight fixes: localhost→cloud default, signing on test target, ATS cleanup
[x] Privacy policy written (docs/privacy-policy.md)
[x] App icons: alpha channels removed for App Store
[x] iOS debris removed: UISupportedInterfaceOrientations from Info.plist + pbxproj
```

## TestFlight Blocker — INVESTIGATION RESULTS

### What happened (2026-02-25)
User attempted first TestFlight upload. It failed. Initial conclusion was "wrong Xcode template."

### What we found (2026-03-02)
Deep analysis of the project.pbxproj reveals the project is **correctly structured** as a modern standalone watchOS app:

| Setting | Expected | Actual | Status |
|---------|----------|--------|--------|
| productType | `com.apple.product-type.application` | `com.apple.product-type.application` | **CORRECT** (Xcode 14+ single-target) |
| SDKROOT | watchos | watchos | CORRECT |
| TARGETED_DEVICE_FAMILY | 4 | 4 | CORRECT |
| WKApplication | true | true | CORRECT |
| WKWatchOnly | true | true | CORRECT |
| iOS companion target | absent | absent | CORRECT |
| WKCompanionAppBundleIdentifier | absent | absent | CORRECT |
| IPHONEOS_DEPLOYMENT_TARGET | absent | absent | CORRECT |
| UISupportedInterfaceOrientations | absent | ~~present~~ **REMOVED** | FIXED |

**Key insight:** `com.apple.product-type.application` IS the correct product type for Xcode 14+ single-target standalone watchOS apps. The old `watchapp2` type is for legacy two-target WatchKit structure. Do NOT change this.

**Possible Xcode 26 bug:** Apple Developer Forums thread reports Xcode 26 Organizer not showing "App Store Connect" upload option for standalone watchOS apps with this exact configuration. This may be the actual blocker, not a project configuration issue.

### Next Steps for TestFlight
1. **Try archive + upload again** with iOS debris removed
2. If Xcode 26 Organizer doesn't show upload option → try `xcrun altool` or Transporter app
3. If archive build fails → check the EXACT error message (see troubleshooting below)
4. If validation fails → check ITMS error codes against the reference below
5. **ONLY if all else fails** → recreate project from template (full migration plan ready)

### Common ITMS Errors Reference
| Error | Cause | Fix |
|-------|-------|-----|
| ITMS-90683 | Missing root-level Info.plist permissions | Add required usage description keys |
| ITMS-90362 | Invalid UIRequiredDeviceCapabilities | Remove iOS-specific device capabilities |
| ITMS-90334 | Code signature / Bundle ID mismatch | Fix signing identity |
| ITMS-90081 | Architecture mismatch | Check WATCHOS_DEPLOYMENT_TARGET |
| ITMS-90539 | Invalid nested bundle structure | Fix widget extension embedding |

## Architecture

```
remmy-cli → install hook → spawn claude (native TUI)
                ↓
     watch-approval-cloud.py (PreToolUse hook)
                ↓
         Cloud Worker ← Watch polls
```

### AskUserQuestion Flow

```
Claude calls AskUserQuestion
  → Hook intercepts, POSTs to /question on cloud
  → Watch shows QuestionResponseView with options
  → User taps an option
  → Watch POSTs answer to /question/:questionId
  → Hook polls, gets answer, writes /tmp/remmy-question-answer.json
  → Hook denies tool (exit 2)
  → Claude reads temp file, proceeds with user's choice
```

Graceful degradation: cloud failure or "Handle on Mac" → falls through to terminal.

## Recent Commits

| Commit | Description |
|--------|-------------|
| `abdc677` | fix: remove alpha channel from app icons for App Store validation |
| `355c022` | docs: add privacy policy for App Store Connect |
| `57cee28` | fix: TestFlight readiness — replace localhost default, fix signing, clean ATS |
| `546e796` | feat: add RemmyWidget extension, complications redesign, activity tracking |
| `3f77d3c` | Merge PR #39 from design-sprint |

## What's Next

| Priority | Item | Status |
|----------|------|--------|
| **P0** | **TestFlight upload** | Retry with iOS debris fix. See troubleshooting above. |
| **P0** | Accessibility gaps (8 views) | Identified, not yet fixed. See `.claude/plans/testflight-migration-plan.md` |
| P1 | Activity Rings (Build/Ship/Guard) | Brainstormed |
| P1 | Interactive widget approve/reject buttons | Brainstormed |
| P1 | APNs complication push for real-time widget updates | Brainstormed |
| P2 | Session mood ring complication | Brainstormed |
| -- | E1-E5: New capabilities | PENDING |
| -- | R8, R10: Test coverage gaps | PENDING |

## File Inventory (for project recreation if needed)

Full inventory documented in `.claude/plans/testflight-migration-plan.md`:
- **61 Swift source files** (17 views, 11 components, 5 services, 5 models, 5 intents, 4 controls, 2 design system, 1 complication, 1 app entry, 10 tests)
- **3 entitlements files** (Debug, Release, Widget)
- **2 Info.plist files** (main app, widget)
- **1 privacy manifest** (PrivacyInfo.xcprivacy)
- **29 asset files** (23 icons, 2 logo variants, 4 Contents.json)
- **3 widget extension files**
- **0 SPM dependencies** (all system frameworks)

## Key Learnings

1. Claude Code hooks can only allow/deny — cannot inject answers into interactive tools
2. Workaround: deny AskUserQuestion + write answer to temp file + Claude reads it
3. Cloud KV TTL of 5 min was too short — long thinking pauses caused session data to expire
4. The watch QuestionResponseView already supported multi-option questions — only the hook was missing
5. `--sdk-url` is undocumented and potentially unsupported — hooks approach is safer long-term
6. `.handGestureShortcut(.primaryAction)` requires watchOS 11.0 — was incorrectly gated at 26.0
7. `ControlWidget` APIs genuinely require watchOS 26.0 — not available earlier
8. `.claude/inbox/` consolidated into `.claude/plans/` — single directory
9. **`com.apple.product-type.application` IS correct for Xcode 14+ standalone watchOS apps** — do NOT change to `watchapp2` (that's the old two-target WatchKit type)
10. `UISupportedInterfaceOrientations` is iOS-only — must not be in watchOS Info.plist or build settings
11. Xcode 26 may have a bug with Organizer upload for standalone watchOS apps — try `xcrun altool` or Transporter as alternative
