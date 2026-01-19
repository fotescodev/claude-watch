# Phase 5 Context: TestFlight Beta Distribution

> **Decisions captured**: 2026-01-19
> **Status**: DRAFT - Needs user confirmation

---

## Key Decisions

### 1. Entitlements Strategy

**Choice**: Separate Debug/Release entitlements files

**Rationale**:
- Cleanest separation between development and production APNs
- Avoids build-time variable substitution complexity
- Follows Apple's recommended practice

**Implementation**:
```
ClaudeWatch/ClaudeWatch.entitlements         → aps-environment: development
ClaudeWatch/ClaudeWatch-Release.entitlements → aps-environment: production
```

Xcode build settings:
- Debug: `CODE_SIGN_ENTITLEMENTS = ClaudeWatch/ClaudeWatch.entitlements`
- Release: `CODE_SIGN_ENTITLEMENTS = ClaudeWatch/ClaudeWatch-Release.entitlements`

---

### 2. Privacy Manifest

**Choice**: Minimal manifest declaring only used APIs

**APIs Used**:
| API | Reason Code | Justification |
|-----|-------------|---------------|
| UserDefaults | CA92.1 | App preferences (pairing ID, permission mode) |

**Not Used** (no declaration needed):
- File timestamp APIs
- System boot time APIs
- Disk space APIs
- Active keyboard APIs

---

### 3. Beta Testing Strategy

**Choice**: Phased rollout

| Phase | Testers | Duration | Goal |
|-------|---------|----------|------|
| Alpha | 5-10 internal | 1 week | Crash detection |
| Closed Beta | 25-50 invited | 2 weeks | Real usage patterns |
| Open Beta | 100-500 public | 2 weeks | Scale testing |

**Go/No-Go Criteria**:
- 99.5%+ crash-free rate
- 0 critical bugs
- <3 high-priority bugs

---

### 4. App Store Metadata

**App Name**: Claude Watch

**Subtitle**: AI Code Approvals on Your Wrist

**Category**: Developer Tools

**Keywords** (100 chars max):
```
claude,ai,code,approval,developer,programming,automation,watchos,coding,assistant
```

**Description** (draft):
```
Claude Watch brings AI pair programming to your wrist.

Approve code changes, send voice commands, and monitor Claude Code
progress—all without leaving your meeting or breaking your flow.

FEATURES
• Real-time action approval from your watch
• Voice commands via dictation
• Three modes: Normal, Auto-approve, Plan
• Watch face complications
• Push notifications for urgent actions

REQUIREMENTS
• Requires Claude Code CLI on your Mac
• watchOS 10.0 or later
• Apple Watch Series 4 or later
```

---

### 5. Privacy Policy

**Choice**: GitHub Pages hosted

**URL**: `https://fotescodev.github.io/claude-watch/privacy`

**Content Requirements**:
- Data collected: Device token (for push notifications), pairing ID
- Data not collected: Code content, file contents, personal information
- Third parties: Cloudflare (relay server), Apple (APNs)
- Contact info for privacy questions

---

### 6. Screenshots

**Required**: 5 screenshots at 396x484px (Apple Watch Series 4+)

| Screenshot | Content |
|------------|---------|
| 1. Main View | Action approval screen with Approve/Reject buttons |
| 2. Progress | Session progress with task list |
| 3. Modes | Mode toggle showing Normal/Auto/Plan |
| 4. Notifications | Actionable notification example |
| 5. Complications | Watch face with Claude Watch complication |

---

## Implementation Notes

- Test archive build BEFORE uploading to avoid App Store Connect processing errors
- Use Xcode Organizer for upload (not `altool` or Transporter)
- Have App Store Connect app record created before first upload
- Privacy policy must be publicly accessible URL before submission

---

## Out of Scope (Phase 5)

- Stop/Play interrupt controls (deferred to Phase 6)
- Multi-session support
- Android Wear OS port
- Diff preview on watch

---

## Verification Criteria

- [ ] Archive builds without error
- [ ] Upload to TestFlight succeeds
- [ ] Push notifications work with production APNs
- [ ] 10+ alpha testers complete approval flow
- [ ] Crash-free rate >99.5%
- [ ] All App Store metadata complete
- [ ] Privacy policy URL accessible

---

## Questions for User

> **Please confirm or adjust these decisions**:

1. **Entitlements**: Separate files OK? Or prefer single file with build variables?
2. **Beta scope**: Start with 5-10 alpha, expand to 50 closed beta?
3. **Privacy policy**: GitHub Pages, or different hosting?
4. **App name**: "Claude Watch" or different name?

---

*This context file guides Phase 5 implementation. Update as decisions change.*
