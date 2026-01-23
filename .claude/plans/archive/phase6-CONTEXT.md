# Phase 6 Context: App Store Submission

> Decisions captured: 2026-01-21
> Participants: dfotesco

## Key Decisions

### App Identity (from Phase 5)
- **App Name**: CC Watch
- **Category**: Developer Tools
- **Age Rating**: 9+
- **Privacy Policy**: `https://fotescodev.github.io/claude-watch/privacy`

### App Description Style
**Choice**: Consumer-friendly
**Rationale**: Broader appeal, simpler language for App Store browsing
**Tone**: Focus on convenience and ease of use, avoid jargon

### Keywords Strategy
**Choice**: AI + Dev Tools focus
**Keywords** (100 char max):
```
claude,ai,code,developer,approve,watch,programming,assistant
```
**Rationale**: Target developers searching for AI coding tools

### Support URL
**Choice**: GitHub repo issues
**URL**: `https://github.com/fotescodev/claude-watch/issues`
**Rationale**: Centralized, public, easy to track

### Screenshots
**Choice**: All 5 scenarios from roadmap
**Device**: Apple Watch Series 10 46mm (416x496px)
**Scenarios**:
1. Main view with pending action
2. Action approval flow (tap to approve)
3. Mode switcher (Normal/Auto/Plan)
4. Watch face complications
5. Voice input sheet

### Promotional Text
**Choice**: Feature highlight (170 char limit)
```
Approve Claude Code changes from your wrist. No phone needed.
```

### Launch Strategy
**Choice**: Coordinated launch across all channels
**Channels**:
- Hacker News (Show HN)
- Reddit (r/ClaudeAI, r/programming, r/apple)
- Twitter/X
- LinkedIn
- ProductHunt (later, after initial feedback)

**Timeline**:
1. TestFlight validation complete
2. Prepare marketing assets (screenshots, description)
3. Draft launch posts for each channel
4. Submit to App Store review
5. Schedule posts for launch day
6. Monitor and respond to feedback

## App Store Metadata

### App Description (Consumer-friendly)
```
Approve AI code changes right from your Apple Watch.

CC Watch connects to Claude Code on your Mac, letting you review and approve code changes without pulling out your phone or returning to your desk.

Perfect for:
• Approving quick fixes while in meetings
• Staying in flow during deep work
• Monitoring Claude's progress on the go

Features:
• One-tap approve or reject
• Real-time push notifications
• Three modes: Normal, Auto-approve, and Plan
• Watch face complications for quick status
• Voice commands via dictation
• End-to-end encrypted - your code stays private

How it works:
1. Run Claude Code on your Mac
2. Pair your Apple Watch with a simple code
3. Get notified when Claude needs approval
4. Tap to approve - Claude continues working

Requires Claude Code running on your Mac.
```

### What's New (Version 1.0)
```
Initial release:
• Real-time approval notifications
• Three operating modes
• Watch face complications
• Voice command support
• End-to-end encryption
```

### Keywords (96/100 chars)
```
claude,ai,code,developer,approve,watch,programming,assistant
```

## Screenshot Capture Plan

| # | Scenario | Setup Required | Notes |
|---|----------|----------------|-------|
| 1 | Main view with pending action | Trigger a tool request | Show tool name + approve/reject buttons |
| 2 | Approval flow | Mid-approval | Show confirmation or success state |
| 3 | Mode switcher | Settings screen | Show all three modes |
| 4 | Complications | Watch face | Use Modular or Infograph face |
| 5 | Voice input | Dictation sheet | Show voice waveform |

**Screenshot dimensions**: 416x496px (Series 10 46mm)

## Launch Day Checklist

### Pre-Launch (T-1 week)
- [ ] Screenshots captured and uploaded
- [ ] Description finalized
- [ ] Keywords optimized
- [ ] Promotional text set
- [ ] Draft posts for HN, Reddit, Twitter, LinkedIn
- [ ] Identify best posting times for each platform

### Launch Day
- [ ] App Store approval received
- [ ] Release to App Store
- [ ] Post to Hacker News (Show HN)
- [ ] Post to r/ClaudeAI
- [ ] Post to r/programming
- [ ] Tweet announcement
- [ ] LinkedIn post
- [ ] Monitor comments and respond

### Post-Launch (T+1 week)
- [ ] Respond to App Store reviews
- [ ] Address any reported issues
- [ ] Consider ProductHunt launch
- [ ] Gather feedback for v1.1

## Out of Scope (Phase 6)

- In-app purchases / subscriptions (Phase 7)
- Analytics integration
- A/B testing screenshots
- Localization (English only for v1.0)
- Press kit / media outreach

## Verification Criteria

- [ ] All 5 screenshots uploaded to App Store Connect
- [ ] Description approved by App Store review
- [ ] Keywords indexed and searchable
- [ ] Privacy policy URL accessible
- [ ] App approved and live on App Store
- [ ] Launch posts published on all channels

---

*Created by /discuss-phase skill*
