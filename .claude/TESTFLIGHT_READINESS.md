# Remmy (Claude Watch) — TestFlight Readiness Report
> Generated: 2026-02-06 | 6-agent parallel audit | All agents complete

---

## Build Status: PASS (with minor warnings)

| Config | Result | Warnings | Errors | Tests |
|--------|--------|----------|--------|-------|
| Debug | BUILD SUCCEEDED | 2 (asset catalog + Sendable) | 0 | 89/92 pass |
| Release | BUILD SUCCEEDED | 2 (asset catalog + Sendable) | 0 | — |

- **Compiler warnings:** `AppIcon.appiconset` has 6 unassigned extra PNGs; `UNUserNotificationCenter` Sendable capture
- **3 test failures:** `testApproveActionChangesStatusToRunning`, `testApproveAllClearsPendingActions`, `testDemoModeLoadsData` (state-dependent async issues)
- **AppIntents:** All 5 discovered (Approve, Reject, Status, Pause, Resume)
- **Code signing:** Automatic, Team ID 98R5RJKR5F, separate debug/release entitlements

---

## Verdict: NOT READY — 13 Blockers Must Be Fixed

| Category | Blockers | Warnings | Info |
|----------|----------|----------|------|
| Build / Project Config | 5 | 6 | 7 |
| Architecture / Swift Code | 1 | 9 | 11 |
| Security | 2 | 4 | 8 |
| Design System / Accessibility | 2 | 10 | 8 |
| Performance / Battery | 3 | 6 | 6 |
| **TOTAL (deduplicated)** | **13** | **35** | **40** |

After deduplication (several findings overlap across agents), there are **13 unique blockers** that must be fixed before TestFlight upload.

---

## BLOCKERS — Must Fix Before TestFlight

### B1. `SKIP_INSTALL = YES` prevents archiving
- **File:** `project.pbxproj:546,644`
- **Impact:** Archive will be empty — cannot upload to App Store Connect
- **Fix:** Set `SKIP_INSTALL = NO` for main app target (Debug + Release)

### B2. Display name "Claude" vs "Remmy" conflict
- **File:** `project.pbxproj:535,633` overrides `Info.plist:8`
- **Impact:** App shows as "Claude" on Home Screen. Trademark risk with Anthropic's name.
- **Fix:** Set `INFOPLIST_KEY_CFBundleDisplayName = Remmy` in pbxproj

### B3. Phantom companion app reference
- **File:** `project.pbxproj:537,635` — `WKCompanionAppBundleIdentifier = com.anthropic.claudecode`
- **Impact:** App Store will reject — references a companion app that doesn't exist. App is standalone (`WKWatchOnly = true`).
- **Fix:** Remove `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` from both build configs

### B4. Legacy `CLKComplicationPrincipalClass` references non-existent class
- **File:** `Info.plist:23-24`
- **Impact:** References `ComplicationController` class that doesn't exist. May cause runtime issues.
- **Fix:** Remove the `CLKComplicationPrincipalClass` key entirely (using WidgetKit, not ClockKit)

### B5. Demo mode accessible to end users
- **Files:** `PairingView.swift:100-103` (long press), `SheetViews.swift:177-195` ("Try Demo" button), `StateViews.swift:92-99`
- **Impact:** Apple rejects apps with visible test/debug features. Demo shows "TEST SCREENS" grid with debug labels.
- **Fix:** Wrap demo mode behind `#if DEBUG` or remove from production builds

### B6. Private encryption key stored in UserDefaults (NOT Keychain)
- **File:** `EncryptionService.swift:155-158`
- **Impact:** Private key in plaintext plist. Extractable from backups. Breaks E2E encryption security.
- **Fix:** Migrate to Keychain with `kSecAttrAccessibleAfterFirstUnlock`

### B7. PairingId (auth credential) stored in UserDefaults
- **File:** `WatchService.swift:67-68`
- **Impact:** PairingId is the sole API auth. Plaintext in UserDefaults = extractable from backups.
- **Fix:** Migrate to Keychain. Zero the UserDefaults entry after migration.

### B8. Force unwraps on URL construction — crash risk
- **Files:** `WatchService.swift:1115,1358,1427` and `RemmyStatusIntent.swift:30`
- **Impact:** App crashes if URL construction fails or array is unexpectedly empty
- **Fix:** Use `guard let url = URL(string:) else { return/throw }` pattern

### B9. ATS localhost exception in production
- **File:** `Info.plist:25-37`
- **Impact:** May trigger App Review flag. Signals dev-only config in production.
- **Fix:** Wrap in `#if DEBUG` or remove if not needed (production uses `wss://`)

### B10. Missing accessibility labels on interactive elements
- **Files:** `ApprovalQueueView.swift` (6+ buttons), `PairingView.swift` (3+ buttons), `ConsentView.swift` (3+ buttons), `SheetViews.swift`, `FloatingSettingsButton.swift`, `WorkingView.swift`
- **Impact:** VoiceOver users cannot use the app. Apple may reject for accessibility.
- **Fix:** Add `.accessibilityLabel()` to every interactive element

### B11. Decorative glow elements pollute VoiceOver tree
- **Files:** `AmbientGlow.swift:17-22`, `StateCard.swift:63-72`
- **Impact:** VoiceOver navigates to meaningless glow decorations
- **Fix:** Add `.accessibilityHidden(true)` to all decorative elements

### B12. 90 HTTP requests/minute polling is aggressive
- **Files:** `WatchService.swift:108` (2s interval), `WatchService.swift:1472-1488` (3 requests per cycle)
- **Impact:** Battery drain. watchOS has strict energy budget.
- **Fix:** Consolidate 3 endpoints into 1. Increase interval to 5s minimum. Add adaptive polling.

### B13. `updateComplicationData()` calls `reloadTimelines` too frequently
- **File:** `WatchService.swift:1880-1888`
- **Impact:** Exhausts WidgetKit's daily reload budget
- **Fix:** Throttle to once every 30-60s. Only reload on meaningful state changes.

---

## HIGH PRIORITY WARNINGS — Should Fix Before TestFlight

### Security
- **No API authentication** beyond pairingId (`WatchService.swift:1257`) — no Bearer token, no HMAC
- **PairingId in URL paths** — logged by Cloudflare, proxies (`WatchService.swift:1500,1608,1680`)
- **No certificate pinning** — default URLSession trust (`WatchService.swift:123`)
- **Empty HKDF salt** — reduces derived key entropy (`EncryptionService.swift:72-77`)

### Architecture
- **WatchService.swift is 3139 lines** — God Object with 15+ embedded model types
- **`try?` silently swallows errors** in notification handlers (`ClaudeWatchApp.swift:243,282,291`)
- **Actor isolation issue** in `observeFoundationModelsReadiness` (`WatchService.swift:184-199`)
- **Deprecated `completePairing` method** still in codebase (`WatchService.swift:1209`)

### Design / Accessibility
- **Fixed font sizes bypass Dynamic Type** — 119 instances of `.font(.system(size:))` vs 65 design system fonts
- **Tap targets below 44pt** — `ScreenSecondaryButton`, consent buttons, demo buttons
- **Hardcoded colors bypass design system** — 10+ instances of raw `Color(red:green:blue:)`
- **ScreenHint text** at 9pt/38% opacity fails WCAG AA contrast (1.6:1 vs required 4.5:1)

### App Store
- **Consent flow references Terms & Privacy Policy** with no actual links (`ConsentView.swift:172`)
- **No Widget Extension target** — WidgetKit code compiles but complications won't appear
- **Test files reference "Welcome to Claude Watch"** — outdated after rename (`UITests.swift:29,52`)
- **Deployment target mismatch** — code says 10.6, docs say 10.0

### Performance
- **ActivityStore saves to UserDefaults on every event** (`ActivityStore.swift:257-267`)
- **Foundation Models polling loop never cancels** (`WatchService.swift:184-199`)
- **High blur radii (35-40)** may cause frame drops on older watches (`AmbientGlow.swift`, `StateCard.swift`)

---

## POSITIVE FINDINGS

The audit also found strong foundations:

- **Crypto primitives are solid** — Curve25519 + ChaChaPoly via CryptoKit (no third-party crypto)
- **@Observable used correctly** for watchOS 10+
- **Liquid Glass backwards compatibility** well-implemented with `#available` checks
- **App Intents and ControlWidget** properly gated on watchOS 26
- **Good accessibility patterns exist** in some views — `@ScaledMetric`, `AccessibilityNotification.Announcement`, `accessibilityReduceMotion` support
- **State machine via `ViewState` enum** is clean and priority-based
- **Notification categories** registered correctly with custom dismiss action
- **Complication timeline strategy** is well-designed (30s active, 15min idle)
- **Memory management** is generally good — proper `[weak self]` throughout
- **No hardcoded secrets** — no API keys or passwords in source

---

## Recommended Fix Order

### Phase 1: Ship-Blocking (1-2 days)
1. Fix `SKIP_INSTALL`, companion app ref, display name in project.pbxproj
2. Remove `CLKComplicationPrincipalClass` from Info.plist
3. Gate demo mode behind `#if DEBUG`
4. Fix force unwraps (4 instances)
5. Remove/gate ATS localhost exception
6. Migrate private key + pairingId to Keychain

### Phase 2: Quality Bar (2-3 days)
7. Add accessibility labels to all buttons (~20 files)
8. Hide decorative elements from VoiceOver
9. Consolidate 3 poll endpoints into 1 + increase interval to 5s
10. Throttle complication updates
11. Add Terms/Privacy Policy links to consent flow
12. Replace hardcoded colors with design system tokens

### Phase 3: Hardening (ongoing)
13. Add API authentication (Bearer token / HMAC)
14. Implement certificate pinning
15. Migrate to Codable for API responses
16. Split WatchService.swift into focused services
17. Add Dynamic Type support to design system fonts
18. Implement adaptive polling based on activity
