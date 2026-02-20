# Phase 5 Context: TestFlight Beta Distribution

> Decisions captured: 2026-01-21 (final)
> Participants: dfotesco

## Key Decisions

### Entitlements Strategy ✅ DONE
**Choice**: Separate entitlements files for Debug and Release
**Rationale**: Cleaner separation, no build variable complexity, easier to audit
**Implementation**:
- `ClaudeWatch/ClaudeWatch.entitlements` (debug, development APNs)
- `ClaudeWatch/ClaudeWatch-Release.entitlements` (release, production APNs)
- Configured in Xcode build settings per configuration

### Beta Testing Scope (Updated)
**Choice**: Solo testing (1 person) initially
**Rationale**: Test alone first before expanding to others
**Implementation**:
- Start with just dfotesco as internal tester
- Expand to 3-5 trusted developers after initial validation
- Can grow to 5-10 for broader internal testing later

### Privacy Policy Hosting
**Choice**: GitHub Pages
**URL**: `https://fotescodev.github.io/claude-watch/privacy`
**Rationale**: Free, version controlled, easy to update
**Implementation**:
- Create `docs/privacy.md` in this repo
- Enable GitHub Pages on repo (Settings → Pages → Deploy from main/docs)
- Add URL to App Store Connect

### Privacy Contact Method
**Choice**: GitHub Issues
**Rationale**: Transparent, public, easy to manage
**Implementation**:
- Link to repo issues page in privacy policy
- URL: `https://github.com/fotescodev/claude-watch/issues`

### Privacy Policy Content
**Choice**: Minimal data disclosure + US-only compliance
**Rationale**: Matches zero-knowledge E2E encryption model; keep simple initially
**Data Collected**:
- Device ID (for push notifications)
- Pairing code (temporary, for device linking)
- Push token (for APNs)
- NO code, commands, or session content stored on server (E2E encrypted)
**Data Retention**: Ephemeral (24 hours max)
**Compliance**: US privacy laws only (no GDPR/CCPA sections needed initially)

### App Store Connect Setup
**Choice**: Individual Developer Account ($99/year)
**App Name**: CC Watch (avoids potential Anthropic trademark issues)
**Category**: Developer Tools
**Age Rating**: 9+ (app shows user-generated code content)

### TestFlight Review Strategy
**Choice**: Record video demo
**Rationale**: Easiest for Apple reviewers to understand the paired device flow
**Implementation**:
- Record screen capture showing: pairing flow → tool request → watch approval
- Upload to App Store Connect review notes
- Explain that app requires paired Mac running Claude Code

### Pre-TestFlight Features ✅ DONE
**Choice**: Include SessionStart hook (COMP1) AND E2E encryption (COMP3)
**Implementation Complete**:
- ✅ COMP1: SessionStart hook (session tracking)
- ✅ COMP3: E2E encryption (CLI: TweetNaCl, Watch: CryptoKit)

## Implementation Checklist

### Critical Path (Blocking TestFlight)
- [x] Create Release entitlements file with `aps-environment: production`
- [x] Create `PrivacyInfo.xcprivacy` manifest (App Store requirement)
- [ ] Create and deploy privacy policy to GitHub Pages
- [x] Test archive build: `xcodebuild archive`
- [ ] Add accessibility labels to interactive elements (deferred - not blocking)

### Feature Work (Before TestFlight) ✅ ALL DONE
- [x] COMP1: SessionStart hook for session tracking
- [x] COMP3A: E2E encryption - CLI side (tweetnacl-js)
- [x] COMP3B: E2E encryption - Worker side (key exchange)
- [x] COMP3C: E2E encryption - Watch side (CryptoKit)

### TestFlight Submission
- [ ] Create App Store Connect app record
- [ ] Upload archive to App Store Connect
- [ ] Add internal tester (dfotesco only initially)
- [ ] Submit for TestFlight review

## Out of Scope (Phase 5)

- Open/public beta testing (defer to Phase 5.5)
- COMP2: Thinking state indicator (nice-to-have, not blocking)
- COMP4: Activity batching (performance optimization, can ship without)
- In-app feedback collection (can use TestFlight's built-in)
- Marketing screenshots (Phase 6)
- Full accessibility audit (defer to Phase 6)

## Verification Criteria

- [x] Archive builds successfully with Release configuration
- [ ] APNs work in production mode (TestFlight build)
- [ ] Privacy policy accessible at public URL
- [x] E2E encryption verified (CLI ↔ Worker ↔ Watch)
- [x] SessionStart hook captures session IDs
- [ ] No crashes during internal testing

## Technical Notes

### Entitlements File Structure ✅ IMPLEMENTED
```xml
<!-- ClaudeWatch-Release.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>production</string>
</dict>
</plist>
```

### Privacy Manifest ✅ IMPLEMENTED
`PrivacyInfo.xcprivacy` declares:
- NSPrivacyTracking: false
- NSPrivacyTrackingDomains: []
- NSPrivacyAccessedAPITypes: UserDefaults, Device ID

### E2E Encryption Architecture ✅ IMPLEMENTED
```
CLI (tweetnacl-js)          Worker (passthrough)        Watch (CryptoKit)
     │                           │                           │
     ├─── Generate keypair ──────┼─── Store public keys ─────┼─── Generate keypair
     │    during pairing         │    during pairing         │    during pairing
     │                           │                           │
     ├─── Encrypt request ───────┼─── Forward encrypted ─────┼─── Decrypt on device
     │    (x25519 + XSalsa20)    │    blob only              │    (Curve25519 + ChaChaPoly)
     │                           │                           │
     └─── Keys exchanged via ────┼─── /pair/initiate ────────┼─── Watch sends pubKey
          /pair/complete         │    /pair/complete         │    CLI sends pubKey
```

### Privacy Policy Template
```markdown
# CC Watch Privacy Policy

Last updated: [date]

## Information We Collect

CC Watch collects minimal information required for the app to function:

- **Device Identifier**: A unique identifier for delivering push notifications
- **Push Token**: Apple Push Notification service token
- **Pairing Code**: Temporary code used to link your watch with your computer

## End-to-End Encryption

All session content (code, commands, approval requests) is encrypted end-to-end.
Our servers CANNOT read your code or session data. Only your devices have the
decryption keys.

## Data Retention

- Pairing data: Deleted when you unpair devices
- Approval requests: Deleted within 24 hours
- Session content: Never stored on our servers (encrypted)

## Contact

For privacy questions, please open an issue:
https://github.com/fotescodev/claude-watch/issues
```

## Remaining Tasks

1. **Create privacy policy** → `docs/privacy.md`
2. **Enable GitHub Pages** → Settings → Pages → Deploy from main/docs
3. **Record demo video** → Screen capture of full pairing + approval flow
4. **Create App Store Connect record** → developer.apple.com
   - App name: "CC Watch"
   - Category: Developer Tools
   - Age rating: 9+
5. **Upload archive** → Xcode Organizer or altool
6. **Add self as tester** → TestFlight → Internal Testing
7. **Submit for review** → App Store Connect (include demo video)

## Video Demo Script

Record the following flow for Apple reviewers:

1. **Mac side**: Show Claude Code terminal, start cc-watch CLI
2. **Watch side**: Show app launch, tap "Pair", display pairing code
3. **Mac side**: Enter pairing code, show "Paired successfully"
4. **Mac side**: Claude Code executes a tool (e.g., file edit)
5. **Watch side**: Notification appears, tap to view details
6. **Watch side**: Tap "Approve" button
7. **Mac side**: Show tool execution proceeds
8. **Narration**: "CC Watch enables developers to approve Claude Code actions from their Apple Watch"

---

*Created by /discuss-phase skill*
