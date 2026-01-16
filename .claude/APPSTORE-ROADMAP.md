# ClaudeWatch App Store Roadmap

> **Goal:** Ship a legitimate, profitable watchOS app to the App Store

## Executive Summary

| Metric | Current | Target |
|--------|---------|--------|
| App Store Ready | NO | YES |
| Critical Blockers | 6 | 0 |
| Test Coverage | 0% | 75%+ |
| Accessibility | None | Full VoiceOver |
| Revenue Model | None | $4.99/mo subscription |
| Time to Ship | - | 8-10 weeks |

---

## Phase 1: Foundation (Week 1-2)
*"Make it work on your watch"*

### 1.1 Critical Code Fixes

| Task | File | Priority | Est. Time |
|------|------|----------|-----------|
| Remove `WKExtension.shared()` (deprecated) | ClaudeWatchApp.swift:68 | BLOCKER | 30min |
| Replace `presentTextInputController` | MainView.swift:439 | BLOCKER | 2hr |
| Set `DEVELOPMENT_TEAM` | project.pbxproj | BLOCKER | 5min |
| Add state persistence (Codable) | WatchService.swift | HIGH | 2hr |
| Fix widget data (App Groups) | ComplicationViews.swift | HIGH | 3hr |

### 1.2 Xcode Configuration

```bash
# Required changes in project.pbxproj:
DEVELOPMENT_TEAM = "YOUR_TEAM_ID"  # Currently empty
SWIFT_VERSION = 5.10               # Currently 5.0
WATCHOS_DEPLOYMENT_TARGET = 11.0   # Currently 10.0
```

### 1.3 Deliverables
- [ ] App runs on physical Apple Watch
- [ ] WebSocket connects to your Mac
- [ ] Actions can be approved/rejected
- [ ] Complications show real data

---

## Phase 2: App Store Compliance (Week 3-4)
*"Make Apple happy"*

### 2.1 Privacy & Legal

| Requirement | Status | Action |
|-------------|--------|--------|
| Privacy Policy | MISSING | Create and host publicly |
| Recording Indicator | MISSING | Add visual indicator when mic active |
| AI Data Disclosure | MISSING | Add consent UI for Claude API data sharing |
| Privacy Descriptions | Needs work | Make more specific in Info.plist |

**Privacy Policy Must Include:**
- Data collected (voice input, interactions)
- Claude API usage disclosure
- Data retention period
- User deletion rights
- GDPR/CCPA compliance

### 2.2 Accessibility (16+ items)

Every interactive element needs:
```swift
.accessibilityLabel("Approve Action")
.accessibilityHint("Approves the pending file edit")
```

**Priority Elements:**
- Settings gear button
- Approve/Reject buttons
- Quick action buttons
- Voice command button
- Mode switcher
- All complication elements

### 2.3 App Icons

Currently: Only `Contents.json` metadata exists
Required: Actual PNG files for all 16 sizes

| Size | Role | Format |
|------|------|--------|
| 1024x1024 | Marketing | PNG, no alpha |
| 24-33pt @2x | Notification | PNG, opaque |
| 40-54pt | App Launcher | PNG, opaque |
| 86-129pt | Quick Look | PNG, opaque |

### 2.4 Deliverables
- [ ] Privacy policy URL live
- [ ] Recording indicator implemented
- [ ] AI consent dialog added
- [ ] All accessibility labels added
- [ ] App icons created and added

---

## Phase 3: Polish & Liquid Glass (Week 5-6)
*"Make it beautiful"*

### 3.1 Liquid Glass Migration

Replace all opacity-based backgrounds:

```swift
// BEFORE (14 instances)
.background(Color.green.opacity(0.2))

// AFTER
.background(.liquidGlass)
```

**Files to update:**
- MainView.swift: 10 instances
- ComplicationViews.swift: 4 instances

### 3.2 Spring Animations

Add to all interactive buttons:
```swift
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
```

### 3.3 Code Structure Refactor

Split MainView.swift (526 lines) into:
```
Views/
├── MainView.swift (50 lines)
├── Components/
│   ├── StatusHeader.swift
│   ├── PendingActionsSection.swift
│   ├── ActionCard.swift
│   ├── QuickActionsBar.swift
│   ├── VoiceButton.swift
│   └── ModeSwitcher.swift
└── Sheets/
    ├── VoiceInputSheet.swift
    └── SettingsSheet.swift
```

### 3.4 Deliverables
- [ ] All backgrounds use Liquid Glass materials
- [ ] Smooth spring animations on all buttons
- [ ] MainView.swift split into focused components
- [ ] Build with Xcode 26, test Liquid Glass adoption

---

## Phase 4: Testing (Week 6-7)
*"Make it reliable"*

### 4.1 Unit Tests (75%+ coverage)

| Component | Test File | Priority |
|-----------|-----------|----------|
| WatchService | WatchServiceTests.swift | CRITICAL |
| Data Models | DataModelTests.swift | HIGH |
| AppDelegate | AppDelegateTests.swift | HIGH |
| Widget Provider | ComplicationProviderTests.swift | MEDIUM |

### 4.2 UI Tests

| Flow | Test Cases |
|------|------------|
| Initial connection | Connect → state sync → display |
| Action approval | Receive → display → approve → clear |
| Mode cycling | Normal → Auto → Plan → Normal |
| Voice command | Open sheet → input → send → close |
| Settings | Open → edit URL → save → reconnect |

### 4.3 Device Testing Matrix

| Device | Priority | Notes |
|--------|----------|-------|
| Series 6 (40mm) | HIGH | Oldest supported, smallest |
| Series 9 (41mm) | HIGH | Latest watchOS |
| Ultra 2 (49mm) | HIGH | Largest display |
| SE 2nd Gen | MEDIUM | Budget validation |

### 4.4 Deliverables
- [ ] 75%+ unit test coverage
- [ ] All UI flows tested
- [ ] Tested on 3+ device sizes
- [ ] No crashes in 1000+ sessions

---

## Phase 5: Beta Testing (Week 7-9)
*"Make it real-world ready"*

### 5.1 TestFlight Phases

| Phase | Testers | Duration | Focus |
|-------|---------|----------|-------|
| Alpha | 5-10 | 1 week | Crashes, core function |
| Closed Beta | 25-50 | 2 weeks | Real usage patterns |
| Open Beta | 100-500 | 2 weeks | Scale, edge cases |

### 5.2 Feedback Collection

**In-app prompt after each session:**
- "How was your experience?" [Great/OK/Poor]
- On Poor: "What went wrong?" (multiple choice + text)

**Weekly survey:**
- Usage frequency
- Most used feature
- Crash reports
- Missing features
- NPS score (0-10)

### 5.3 Go/No-Go Criteria

| Metric | Required |
|--------|----------|
| Crash-free sessions | > 99.5% |
| User satisfaction | > 4.0/5.0 |
| Critical bugs | 0 |
| High-priority bugs | < 3 |

### 5.4 Deliverables
- [ ] TestFlight build submitted
- [ ] 100+ beta testers recruited
- [ ] Feedback system implemented
- [ ] All critical bugs fixed

---

## Phase 6: App Store Submission (Week 9-10)
*"Ship it"*

### 6.1 App Store Connect Setup

| Item | Status | Action |
|------|--------|--------|
| App Record | TODO | Create in App Store Connect |
| Screenshots | TODO | 396x484px watchOS screenshots |
| Description | TODO | Write compelling copy |
| Keywords | TODO | 100 chars max |
| Category | TODO | Productivity or Developer Tools |
| Privacy Policy URL | TODO | Add public URL |
| Age Rating | TODO | Complete questionnaire (likely 9+) |

### 6.2 Marketing Assets

**Screenshots needed:**
1. Main view with pending action
2. Action approval flow
3. Mode switcher (YOLO mode)
4. Complications on watch face
5. Voice input sheet

**App Description draft:**
```
ClaudeWatch brings AI pair programming to your wrist.

Approve code changes, send voice commands, and monitor Claude Code
progress—all without leaving your meeting or breaking your flow.

Features:
• Real-time action approval from your watch
• Voice commands via dictation
• Three modes: Normal, Auto-approve, Plan
• Watch face complications
• Push notifications for urgent actions

Requires Claude Code running on your Mac with the MCP server.
```

### 6.3 Submission Checklist

- [ ] All screenshots uploaded
- [ ] Description finalized
- [ ] Keywords optimized
- [ ] Privacy policy URL verified
- [ ] Age rating completed
- [ ] Build uploaded and processed
- [ ] Submit for review

---

## Phase 7: Monetization (Post-Launch)
*"Make it profitable"*

### 7.1 Recommended Pricing Model

**Freemium + Subscription:**

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | 50 approvals/week, Normal mode only |
| Premium | $4.99/mo | Unlimited approvals, all modes, voice commands |
| Pro | $9.99/mo | + Multi-watch, analytics dashboard |
| Annual | $39.99/yr | Premium features, 33% savings |

### 7.2 Revenue Projections (Conservative)

| Year | Users | Paid % | Annual Revenue |
|------|-------|--------|----------------|
| Y1 | 7,500 | 30% | $1.08M |
| Y2 | 22,500 | 40% | $4.32M |
| Y3 | 50,000 | 50% | $11.97M |

### 7.3 Growth Strategy

**Phase 1 (Months 1-3):** Organic
- ProductHunt launch
- Hacker News post
- Claude Code Discord promotion

**Phase 2 (Months 3-6):** Partnerships
- Approach Anthropic for official recognition
- Apple Developer Relations (WWDC feature)
- Developer conference sponsorships

**Phase 3 (Year 2):** Expansion
- Android Wear OS port
- Companion iOS app
- Team/Enterprise licensing

---

## Timeline Summary

```
Week 1-2:   Foundation (code fixes, configuration)
Week 3-4:   Compliance (privacy, accessibility, icons)
Week 5-6:   Polish (Liquid Glass, animations, refactor)
Week 6-7:   Testing (unit tests, UI tests, devices)
Week 7-9:   Beta (TestFlight, feedback, bug fixes)
Week 9-10:  Submission (App Store Connect, review)
Week 10+:   Launch & monetization
```

**Total estimated time: 8-10 weeks**

---

## Success Metrics

### Launch Criteria
- [ ] 0 critical bugs
- [ ] 99.5%+ crash-free rate
- [ ] Full VoiceOver support
- [ ] All App Store requirements met
- [ ] 100+ beta testers validated

### 90-Day Goals
- [ ] 1,000+ downloads
- [ ] 4.5+ star rating
- [ ] 100+ paid subscribers
- [ ] Featured in Apple newsletter (stretch)

### Year 1 Goals
- [ ] 7,500+ users
- [ ] $1M+ ARR
- [ ] Anthropic partnership
- [ ] Android Wear OS port started
