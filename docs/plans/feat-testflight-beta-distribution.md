# feat: TestFlight Beta Distribution

## Overview

Distribute Claude Watch to beta testers via TestFlight. This enables external testing of the watch approval flow before App Store submission.

## Critical Discovery: APNs Environment

**TestFlight uses PRODUCTION APNs, not sandbox.**

| Distribution Method | APNs Environment |
|--------------------|------------------|
| Xcode Debug Build | `api.sandbox.push.apple.com` |
| **TestFlight** | `api.push.apple.com` (production) |
| App Store | `api.push.apple.com` (production) |

**Action Required**: Switch cloud server from sandbox to production APNs before TestFlight distribution.

---

## Blockers (Must Fix First)

### 1. Missing App Icons (CRITICAL)

**Location**: `ClaudeWatch/Assets.xcassets/AppIcon.appiconset/`

Only `Contents.json` exists - **no PNG files**. All 17 required icon sizes are missing.

**Required Sizes**:
- 24x24 @2x (48px) - Notification Center
- 27.5x27.5 @2x (55px) - Notification Center 42mm
- 29x29 @2x, @3x (58px, 87px) - Settings
- 40x40 @2x (80px) - Home Screen 38mm
- 44x44 @2x (88px) - Home Screen 42mm
- 50x50 @2x (100px) - Home Screen Ultra
- 86x86 @2x (172px) - Short Look 38mm
- 98x98 @2x (196px) - Short Look 42mm
- 108x108 @2x (216px) - Short Look Ultra
- 1024x1024 @1x - App Store

**Fix**: Create 1024x1024 source icon, use icon generator tool.

### 2. Switch APNs to Production

**File**: `MCPServer/worker/wrangler.toml`

```toml
# Change from:
APNS_SANDBOX = "true"

# To:
APNS_SANDBOX = "false"
```

Then redeploy: `cd MCPServer/worker && npx wrangler deploy`

### 3. Privacy Policy URL

**Required for**: External TestFlight testing and App Store

**Options**:
- Host on GitHub Pages (quick)
- Add to existing website
- Use privacy policy generator service

**Content must include**:
- Data collected (device token, approval history)
- How data is used (push notifications, approval workflow)
- Data retention policy
- Third-party services (Cloudflare Workers)

---

## TestFlight Setup Steps

### Phase 1: Prepare Build

- [ ] Create app icons (all 17 sizes)
- [ ] Set version to `1.0` build `1` (already done)
- [ ] Add `ITSAppUsesNonExemptEncryption = false` to Info.plist (uses standard HTTPS only)
- [ ] Verify push notification entitlement is present
- [ ] Archive build: Product > Archive

### Phase 2: App Store Connect Setup

- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Create new app (+ button > New App)
  - Platform: iOS (for watch-only apps too)
  - Bundle ID: `com.edgeoftrust.claudewatch`
  - Name: "Claude Watch"
  - Primary Language: English
- [ ] Fill in required metadata:
  - App description
  - Privacy Policy URL
  - Support URL
  - App category: Developer Tools or Utilities

### Phase 3: Upload Build

- [ ] In Xcode Organizer, select archive
- [ ] Distribute App > App Store Connect > Upload
- [ ] Wait for processing (15-30 min, first build can take longer)
- [ ] Build appears in TestFlight tab when ready

### Phase 4: Configure TestFlight

- [ ] Navigate to TestFlight tab in App Store Connect
- [ ] Fill in Test Information:
  - Beta App Description: "Approve Claude Code actions from your Apple Watch"
  - What to Test: "Test the approval flow for file edits and bash commands"
  - Feedback Email: your-email@example.com
- [ ] Answer Export Compliance (No encryption beyond HTTPS)
- [ ] Create test group: "Beta Testers"

### Phase 5: Switch to Production APNs

- [ ] Update `wrangler.toml`: `APNS_SANDBOX = "false"`
- [ ] Deploy: `npx wrangler deploy`
- [ ] **Important**: Device tokens from TestFlight are different from development tokens
- [ ] Testers must re-pair when switching from dev to TestFlight build

### Phase 6: Invite Testers

**Internal Testing** (no review required):
- [ ] Add testers via App Store Connect Users
- [ ] Testers install via TestFlight app on iPhone
- [ ] Toggle "Show App on Apple Watch" in TestFlight

**External Testing** (requires Beta App Review):
- [ ] Submit build for Beta App Review
- [ ] Wait for approval (usually < 24 hours)
- [ ] Add external testers by email or public link

---

## Testing Checklist for Beta Testers

Provide this to testers:

```markdown
## Claude Watch Beta Testing Guide

### Setup
1. Install TestFlight on your iPhone
2. Accept beta invite
3. In TestFlight, toggle "Show App on Apple Watch"
4. Open Claude Watch on your watch
5. Tap "Pair with Claude Code"
6. Enter the pairing code shown in Claude Code

### Test Cases
- [ ] Receive push notification for file edit
- [ ] Approve a file edit from notification
- [ ] Reject a bash command from notification
- [ ] Open app and approve pending request
- [ ] Test with watch screen off (should wake on notification)

### Report Issues
Email: your-email@example.com
Include: Watch model, watchOS version, steps to reproduce
```

---

## Screenshot Requirements

For App Store (not required for TestFlight internal):

| Watch Model | Dimensions |
|-------------|------------|
| Series 11/10 | 416 x 496 |
| Ultra 3 | 422 x 514 |

Capture:
1. Main approval screen with pending request
2. Approved confirmation
3. Settings/pairing screen

---

## Acceptance Criteria

- [ ] App icon visible in TestFlight and on watch
- [ ] Build uploads and processes without errors
- [ ] Internal testers can install on Apple Watch
- [ ] Push notifications arrive on tester watches
- [ ] Approve/Reject flow works end-to-end
- [ ] Privacy policy accessible via URL

---

## References

- [TestFlight Overview - Apple Developer](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Submit watchOS apps - Apple Developer](https://developer.apple.com/watchos/submit/)
- [APNs Environment for TestFlight](https://developer.apple.com/forums/thread/40725)
- Repo research: `ClaudeWatch.xcodeproj/project.pbxproj:PRODUCT_BUNDLE_IDENTIFIER`
- Repo research: `ClaudeWatch/ClaudeWatch.entitlements:aps-environment`
