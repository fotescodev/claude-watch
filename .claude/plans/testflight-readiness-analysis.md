# TestFlight Readiness Analysis

**Date:** 2026-02-06
**Methodology:** Axiom-framework parallel audit (6 agents: UI/UX, Architecture, Performance, Accessibility, Security, Ship-Check)
**Overall Verdict:** NOT READY - 4 blockers, 12 high-priority fixes needed

---

## Executive Summary

The app has solid architecture foundations and good functional coverage, but suffers from a **design system adoption gap** — the design system exists but ~90% of views ignore it, creating the "vibe coded" appearance. Additionally, there are 4 blocking issues that must be resolved before TestFlight submission.

### Blocker Count by Category

| Category | Blockers | High | Medium | Low/Pass |
|----------|----------|------|--------|----------|
| UI/UX Design | 2 | 6 | 3 | 0 |
| Architecture | 2 | 4 | 3 | 5 pass |
| Accessibility | 4 | 1 | 2 | 2 pass |
| Security | 1 | 0 | 2 | 7 pass |
| Ship-Check | 1 | 0 | 2 | 8 pass |
| **TOTAL** | **4 unique** | **11** | **12** | **22** |

---

## BLOCKERS (Must Fix Before TestFlight)

### B1. CRITICAL: Bundle ID Mismatch
**Category:** Ship-Check
**Impact:** Push notifications will silently fail in production

The Xcode project uses `com.edgeoftrust.remmy` but ALL server infrastructure references `com.edgeoftrust.claudewatch`:
- Cloudflare Worker (`wrangler.toml`): `APNS_BUNDLE_ID = "com.edgeoftrust.claudewatch"`
- All Claude hooks (`watch-approval-cloud.py`, `question-handler.py`, `context-warning.py`)
- All documentation and test scripts

**Fix:** Align all references to a single bundle ID. Either change Xcode to `com.edgeoftrust.claudewatch` or update all server-side references to `com.edgeoftrust.remmy`.

---

### B2. CRITICAL: Private Cryptographic Key in UserDefaults
**Category:** Security
**File:** `ClaudeWatch/Services/EncryptionService.swift:155-163`
**Impact:** Curve25519 private key extractable from unencrypted plist backup

```swift
// CURRENT (INSECURE)
UserDefaults.standard.set(base64, forKey: privateKeyStorageKey)

// REQUIRED FIX
// Use Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

**Fix:** Migrate private key storage to Keychain using `SecItemAdd`/`SecItemCopyMatching`.

---

### B3. CRITICAL: Core Approval Buttons Inaccessible to VoiceOver
**Category:** Accessibility
**Files:** `ApprovalView.swift:112-151`, `ApprovalQueueView.swift:374-393, 723-741`
**Impact:** The app's primary function (approve/reject) is unusable for VoiceOver users

Icon-only approve/reject buttons in TierReviewView and CombinedActionDetailView read as "xmark" and "checkmark" — unintelligible to VoiceOver users.

**Fix:** Add `.accessibilityLabel("Approve \(action.title)")` and `.accessibilityLabel("Reject \(action.title)")` to all approve/reject buttons across all views.

---

### B4. CRITICAL: Touch Target Violation — ContextWarningView OK Button
**Category:** UI/UX + Accessibility
**File:** `ContextWarningView.swift:54`
**Impact:** 27pt button height violates Apple HIG minimum (44pt)

```swift
// CURRENT
.frame(width: 67, height: 27)  // 27pt - HIG violation

// FIX
.frame(width: 67, height: 44)  // meets minimum
```

---

## HIGH PRIORITY (Fix Before TestFlight for Polish)

### H1. Design System Typography Not Adopted (Systemic)
**Category:** UI/UX
**Impact:** 17 distinct hardcoded font sizes across views; design tokens used <10% of the time

| What Exists | What's Used Instead |
|-------------|---------------------|
| `Claude.claudeHeadline` (15pt semibold) | `.font(.system(size: 15, weight: .semibold))` |
| `Claude.claudeBody` (14pt regular) | `.font(.system(size: 14, weight: .regular))` |
| `Claude.claudeCaption` (12pt regular) | `.font(.system(size: 12))` |
| `Claude.claudeFootnote` (11pt regular) | `.font(.system(size: 11))` |

**Worst offenders:** ActionViews.swift (6 sizes), ApprovalQueueView.swift (7 sizes), StateViews.swift (6 sizes)

**Fix:** Global find-and-replace hardcoded fonts with design tokens. Add missing tokens for 9pt, 10pt used as micro-labels.

---

### H2. Three Parallel Color Systems
**Category:** UI/UX
**Impact:** "Secondary text" appears in 6+ different shades across screens

| Literal | Hex | Used In | Should Be |
|---------|-----|---------|-----------|
| `Color(red: 0.604, green: 0.604, blue: 0.624)` | #9A9A9F | ApprovalView, PausedView, etc. | New `Claude.textMuted` token |
| `Color(red: 0.431, green: 0.431, blue: 0.451)` | #6E6E73 | WorkingView, StateViews, etc. | New `Claude.textDisabled` token |
| `Color(red: 0.557, green: 0.557, blue: 0.576)` | #8E8E93 | MainView, PausedView | Already `Claude.idle` |

Plus: `ApprovalQueueView` re-defines Apple system colors as local constants instead of using `Claude.success/warning/danger`.

**Fix:** Add missing color tokens; find-and-replace all RGB literals.

---

### H3. 15+ Distinct Button Styling Patterns
**Category:** UI/UX
**Impact:** No two screens have matching button styles

Buttons vary in: shape (Capsule vs RoundedRect), padding (6-12pt), font size (9-14pt), corner radius (8-22pt), height (27-44pt).

**Fix:** Standardize to 3 button variants: `ScreenActionButton` (primary), `ScreenSecondaryButton` (secondary), `ScreenDestructiveButton` (red). Already partially exists in ScreenShell.

---

### H4. `badgeText(for:)` Defined 5 Times with Divergent Logic
**Category:** UI/UX (User-Facing Bug)
**Impact:** Same "read" action shows as "READ" on one screen, "EDIT" on another

Defined independently in: ApprovalView, TierQueueView, TierReviewView, CombinedQueueView, CombinedActionDetailView.

**Fix:** Move to `PendingAction` as a computed property. Resolve the READ vs EDIT inconsistency.

---

### H5. WatchService.swift God Object (3,139 lines, 35+ responsibilities)
**Category:** Architecture
**File:** `ClaudeWatch/Services/WatchService.swift`
**Impact:** Prevents unit testing, risks excessive view invalidation, impossible to reason about

Responsibilities include: WebSocket, cloud polling, network monitoring, action management, session management, notification scheduling, haptics, complication data, push tokens, demo mode (600+ lines), and 18 embedded data models.

**Fix (post-TestFlight):** Extract into ConnectionManager, SessionManager, ActionManager, NotificationService. Move 18 embedded data types to `/Models/`.

---

### H6. DateFormatter Allocation in View Bodies (4 occurrences)
**Category:** Performance
**Files:** `HistoryView.swift:94`, `ActivityEvent.swift:132`, `ActivityStore.swift:234`, `WatchService.swift:2943`

```swift
// CURRENT (expensive - creates new formatter every render)
var formattedTime: String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: timestamp)
}

// FIX (cache formatter as static)
private static let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.timeStyle = .short
    return f
}()
```

---

### H7. 130+ Hardcoded Font Sizes Without Dynamic Type
**Category:** Accessibility (WCAG 1.4.4 Level AA)
**Impact:** Text does not scale with accessibility settings; 7pt text invisible to many users

Only 2 views use `@ScaledMetric`. All others hardcode sizes via `.font(.system(size: N))`.

**Fix:** At minimum, increase all text to 10pt minimum. Ideally migrate to `.font(.system(size: N, relativeTo: .caption))` pattern.

---

### H8. Non-Injectable Singleton Pattern (30+ views)
**Category:** Architecture
**Impact:** Prevents SwiftUI preview and unit test isolation

Every view uses `var service = WatchService.shared` instead of `@Environment`.

**Fix (post-TestFlight):** Migrate to `@Environment(WatchService.self)` injection.

---

### H9. SwiftUI Import in Model/Service Files
**Category:** Architecture
**Files:** `ActivityEvent.swift`, `ClaudeState.swift`, `ActionTier.swift`, `WatchService.swift`, `ActivityStore.swift`

Models import SwiftUI for `Color` properties, coupling business logic to UI framework.

**Fix:** Move color/icon properties to SwiftUI extensions in DesignSystem layer.

---

### H10. ScreenShell Adoption Gap
**Category:** UI/UX
**Impact:** Only 5 of 12 screens use the layout framework, causing inconsistent spacing

| Uses ScreenShell | Does NOT |
|------------------|----------|
| WorkingView, PausedView, TaskOutcomeView, QuestionResponseView, ContextWarningView | ApprovalView, ApprovalQueueView, EmptyStateView, OfflineStateView, PairingView, StateViews |

**Fix:** Adopt ScreenShell in all remaining screens.

---

### H11. 11 Distinct White-Opacity Levels
**Category:** UI/UX
**Impact:** Inconsistent surface/fill appearance across views

Opacity values from 0.03 to 0.70 used ad-hoc. No tokens exist.

**Fix:** Add fill tokens: `Claude.fill1 = .white.opacity(0.07)`, `Claude.fill2 = .white.opacity(0.12)`, `Claude.fill3 = .white.opacity(0.15)`.

---

## MEDIUM PRIORITY (Pre-App Store Polish)

| ID | Category | Finding |
|----|----------|---------|
| M1 | Accessibility | PairingView back button reads "chevron.left" to VoiceOver |
| M2 | Accessibility | ContextWarningView has zero accessibility labels |
| M3 | Security | Empty HKDF salt in key derivation (EncryptionService.swift:73) |
| M4 | Security | APNs device token stored in UserDefaults |
| M5 | Ship-Check | Uncommitted debug logging cleanup |
| M6 | UI/UX | Two conflicting glow components (AmbientGlow vs CardGlow) |
| M7 | UI/UX | 8 dead/legacy view components cluttering codebase |
| M8 | Architecture | Collection operations in view computed properties (5 occurrences) |
| M9 | Architecture | Duplicated helper functions across views |
| M10 | Architecture | 3 breathing animation implementations (should be 1) |
| M11 | Performance | No LazyVStack usage (acceptable for current data sizes) |
| M12 | Ship-Check | Build must be verified on Mac with Xcode |

---

## PASSING ITEMS

| Check | Status |
|-------|--------|
| App Icons (all watchOS sizes) | PASS |
| Info.plist configuration | PASS |
| Entitlements (Debug/Release split) | PASS |
| Privacy Manifest (PrivacyInfo.xcprivacy) | PASS |
| No hardcoded API keys/credentials | PASS |
| No insecure HTTP endpoints | PASS |
| No sensitive data in logs | PASS |
| ATS configuration (localhost-only exception) | PASS |
| @AppStorage usage (no sensitive data) | PASS |
| Reduce motion support | PASS (well implemented) |
| No async boundary violations | PASS |
| No @State property wrapper misuse | PASS |
| Modern @Observable usage (no legacy patterns) | PASS |
| Push notification entitlements | PASS |
| Deployment target (watchOS 10.6) | PASS |
| Code signing (automatic) | PASS |
| Marketing version (1.0) | PASS |

---

## Recommended Fix Order

### Phase 1: Blockers (Day 1 — must fix)
1. **B1** — Resolve bundle ID mismatch
2. **B2** — Migrate crypto keys to Keychain
3. **B3** — Add VoiceOver labels to approve/reject buttons
4. **B4** — Fix ContextWarningView touch target

### Phase 2: Polish (Day 2-3 — before TestFlight)
5. **H1** — Adopt design system font tokens (global find-replace)
6. **H2** — Add missing color tokens and replace RGB literals
7. **H3** — Standardize button styling to 3 variants
8. **H4** — Unify `badgeText(for:)` (fix READ vs EDIT bug)
9. **H6** — Cache DateFormatters (4 files, quick fix)
10. **H10** — Adopt ScreenShell in remaining views
11. **H11** — Add fill/opacity tokens

### Phase 3: Post-TestFlight (before App Store)
12. **H5** — Decompose WatchService God object
13. **H7** — Full Dynamic Type migration
14. **H8** — Environment injection for testability
15. **H9** — Extract SwiftUI from models
16. **M1-M12** — Medium priority cleanup

---

## Key Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Design system font token adoption | ~10% | 95%+ |
| Distinct hardcoded font sizes | 17 | 5-6 |
| Distinct button patterns | 15+ | 3 |
| Distinct color literals | 6 RGB + 11 opacity | 0 (all tokens) |
| ScreenShell adoption | 5/12 screens | 12/12 |
| VoiceOver label coverage | ~60% | 100% |
| Dynamic Type support | 2 views | All views |
| WatchService.swift lines | 3,139 | ~500 (after decomposition) |
| Embedded model types | 18 in service | 0 (all in /Models/) |
| DateFormatter allocations in body | 4 | 0 |
