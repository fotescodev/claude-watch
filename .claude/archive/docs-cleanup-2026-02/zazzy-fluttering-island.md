# Claude Watch: Ship Readiness Plan

## Goal
Get Claude Watch from "working app" to "shippable product" -- TestFlight first, then App Store.

## Current State
- Functional watchOS app with WebSocket + APNs communication
- 17 SwiftUI views, full design system, complications, Siri shortcuts
- 10 test files, no CI/CD, no localization, no App Store metadata
- Privacy manifest present, entitlements configured
- 6 review skills installed (security, privacy, accessibility, App Store, comprehensive, TestFlight)

---

## Phase 1: Foundation (Code Quality + Stability)
*Must-fix issues that affect runtime correctness and maintainability.*

| Task | ID | Why First |
|------|----|-----------|
| Migrate WatchService/ActivityStore to @Observable | #1 | Fixes excessive re-renders across 14+ views; all other view work builds on this |
| Reduce view fan-out from WatchService | #9 | Blocked by #1; completes the state management fix |
| Extract shared approve/reject logic | #14 | 6 copy-pasted implementations = 6 places for bugs |
| Replace print() with os.log | #21 | Cannot debug production issues without structured logging |
| Fix ForEach identity (\.offset) | #6 | Runtime correctness for dynamic lists |
| Replace .id(refreshTrigger) pattern | #8 | Destroys/recreates view tree every 30s |

## Phase 2: API Modernization (Quick Wins)
*Mechanical replacements -- low risk, high consistency payoff.*

| Task | ID |
|------|-----|
| Replace foregroundColor() with foregroundStyle() | #2 |
| Replace Task.sleep(nanoseconds:) with Task.sleep(for:) | #3 |
| Replace DispatchQueue.main.asyncAfter | #4 |
| Replace cornerRadius() in ComplicationViews | #5 |
| Use SessionProgress.isComplete | #7 |
| Replace Timer.scheduledTimer with structured concurrency | #10 |
| Remove unused properties | #11 |
| Standardize Button syntax | #12 |
| Replace manual Task lifecycle with .task modifier | #13 |

## Phase 3: Ship Infrastructure
*Required for TestFlight submission.*

| Task | ID | Notes |
|------|----|-------|
| Add .xcconfig build configuration files | #16 | Separates Debug/Release/Beta settings |
| Add XCTest plan + expand test coverage | #17 | Gate for CI |
| Add CI/CD pipeline (GitHub Actions) | #15 | Depends on #16, #17 |
| Create App Store metadata + screenshots | #19 | Required for App Store Connect |

## Phase 4: Polish (Pre-App Store)
*Not blocking TestFlight, but required before public release.*

| Task | ID | Notes |
|------|----|-------|
| Add localization support (String Catalogs) | #18 | Infrastructure only; English strings extracted |
| Conduct formal accessibility audit | #20 | Apple reviews this; run Accessibility Inspector |

---

## Review Pipeline (Using Installed Skills)

After completing Phases 1-2, run these reviews in sequence before TestFlight:

1. `/watchos-code-review` -- watchOS-specific patterns and anti-patterns
2. `/security` -- Security audit (WebSocket auth, APNs token handling, EncryptionService)
3. `/axiom-privacy-ux` -- Privacy UX compliance (consent flow, data collection)
4. `/comprehensive-review` -- Broad code quality sweep
5. `/appstore-readiness` -- App Store submission checklist
6. `/axiom-testflight-triage` -- TestFlight pre-flight validation

## Execution Order

```
Phase 1 (#1 first, then #9, then #14,#21,#6,#8 in parallel)
    |
Phase 2 (#2-#5, #7, #10-#13 -- all independent, can parallelize)
    |
Review Pipeline (6 skill-based reviews)
    |
Phase 3 (#16 -> #17 -> #15, #19 in parallel)
    |
Phase 4 (#18, #20)
    |
/ship-check -> TestFlight -> App Store
```

## Verification
- After Phase 1: Build succeeds, all existing tests pass, no runtime regressions
- After Phase 2: Build succeeds, no deprecated API warnings
- After Reviews: All findings addressed or triaged
- After Phase 3: CI green, screenshots captured, metadata uploaded
- Final: `/ship-check` passes, TestFlight build uploads successfully
