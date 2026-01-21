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

**Focus:** Critical code fixes and Xcode configuration

**Key Tasks:** (See `.claude/ralph/tasks.yaml` for detailed implementation)
- Remove deprecated WKExtension APIs
- Fix text input controllers
- Configure development team
- Add state persistence
- Wire complications to live data

**Deliverables:**
- [ ] App runs on physical Apple Watch
- [ ] WebSocket connects to your Mac
- [ ] Actions can be approved/rejected
- [ ] Complications show real data

---

## Phase 2: App Store Compliance (Week 3-4)
*"Make Apple happy"*

### 2.1 Privacy & Legal

**Requirements:**
- Privacy policy (public URL)
- Recording indicator when mic active
- AI data disclosure consent UI
- Specific privacy descriptions in Info.plist

**Privacy Policy Must Include:**
- Data collected (voice input, interactions)
- Claude API usage disclosure
- Data retention period
- User deletion rights
- GDPR/CCPA compliance

### 2.2 Accessibility

**Requirement:** All interactive elements need `.accessibilityLabel()` and `.accessibilityHint()`

**Priority Elements:**
- Settings button
- Approve/Reject buttons
- Quick action buttons
- Voice command button
- Mode switcher
- All complication elements

### 2.3 App Icons

**Status:** Only metadata exists, need actual PNG files

**Required Sizes:**
- 1024x1024 (Marketing)
- 24-33pt @2x (Notification)
- 40-54pt (Launcher)
- 86-129pt (Quick Look)

**Format:** PNG, no transparency, RGB color space

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

Replace opacity-based backgrounds with `.background(.liquidGlass)`

**Files to update:**
- MainView.swift: 10 instances
- ComplicationViews.swift: 4 instances

### 3.2 Spring Animations

Add natural spring animations to all interactive buttons:
```swift
.scaleEffect(isPressed ? 0.95 : 1.0)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
```

### 3.3 Code Structure Refactor

Split MainView.swift (526 lines) into focused components:
```
Views/
├── MainView.swift (50 lines)
├── Components/ (6 files)
└── Sheets/ (2 files)
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

| Component | Priority |
|-----------|----------|
| WatchService | CRITICAL |
| Data Models | HIGH |
| AppDelegate | HIGH |
| Widget Provider | MEDIUM |

### 4.2 UI Test Flows

- Initial connection flow
- Action approval flow
- Mode cycling
- Voice commands
- Settings management

### 4.3 Device Testing Matrix

| Device | Priority | Reason |
|--------|----------|--------|
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

**In-app prompt:**
- "How was your experience?" [Great/OK/Poor]
- On Poor: "What went wrong?"

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

| Item | Action |
|------|--------|
| App Record | Create in App Store Connect |
| Screenshots | 396x484px watchOS screenshots (5 required) |
| Description | Write compelling copy |
| Keywords | 100 chars max, optimize for search |
| Category | Productivity or Developer Tools |
| Privacy Policy URL | Add public URL |
| Age Rating | Complete questionnaire (likely 9+) |

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

## Phase 8: V2 Redesign (Post-Launch)
*"Full Claude Code Companion"*

### 8.1 Overview

Transform Claude Watch from a simple approval remote into a comprehensive Claude Code companion with support for questions, todos, sub-agents, session resume, and context management.

**Source:** `/v2/` documentation suite

### 8.2 New Flows

| Flow | Name | Priority | Description |
|------|------|----------|-------------|
| F15 | Session Resume | P0 | Resume previous sessions from watch |
| F16 | Context Warning | P1 | Proactive alerts at 75/85/95% |
| F17 | Quick Undo | P2 | Rewind to latest checkpoint |
| F18 | Question Response | P0 | Answer AskUserQuestion from wrist |
| F19 | Sub-Agent Monitor | P2 | Nested Task tool display |
| F20 | Todo Progress | P2 | Read-only TodoWrite view |
| F21 | Background Alert | P1 | Ctrl+B notification |

### 8.3 Key Features

- **Question Response (F18):** Answer Claude's questions with tap or voice
- **Session Resume (F15):** One-tap continue from watch
- **Context Warning (F16):** Proactive "/compact" suggestions
- **Todo Progress (F20):** Read-only task checklist
- **Sub-Agent Monitoring (F19):** Nested agent display
- **Quick Undo (F17):** Simplified rewind
- **Anthropic Brand Refresh:** Official colors + SF Symbols

### 8.4 Implementation Phases

| Sub-Phase | Focus | Estimate |
|-----------|-------|----------|
| 8A | Event Infrastructure | 1 week |
| 8B | Question Response (P0) | 1 week |
| 8C | Session Resume (P0) | 1 week |
| 8D | Context & Undo (P1) | 1 week |
| 8E | Todo & Sub-Agents (P2) | 1 week |
| 8F | Brand Refresh (P1) | 1 week |
| 8G | Quick Commands | 0.5 week |

### 8.5 Deliverables

- [ ] All 7 new flows functional
- [ ] 11 new event types handled
- [ ] Anthropic brand colors applied
- [ ] SF Symbols replace all emojis
- [ ] 3 new quick commands (Resume, Compact, Undo)

**See:** `.claude/plans/phase8-CONTEXT.md` for full implementation details.

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
Week 12-18: V2 Redesign (Phase 8)
```

**Total estimated time: 8-10 weeks to launch, +6 weeks for V2**

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

---

## Implementation Notes

**For detailed task implementations, see:**
- `.claude/ralph/tasks.yaml` - Complete task definitions with verification commands
- `docs/PRD.md` - Product requirements
- `plans/` - Specific feature implementation plans
