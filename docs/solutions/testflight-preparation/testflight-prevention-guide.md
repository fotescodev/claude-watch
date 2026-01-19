# TestFlight Preparation: Prevention Strategies and Best Practices

## Overview

This guide documents lessons learned from TestFlight preparation issues and provides checklists, best practices, and testing strategies to prevent future problems.

---

## 1. Prevention Checklist for TestFlight Submissions

### Pre-Submission Checklist

```
[ ] ENTITLEMENTS
    [ ] Separate Debug and Release entitlements files exist
    [ ] Debug uses `aps-environment: development`
    [ ] Release uses `aps-environment: production`
    [ ] Xcode project references correct entitlements per configuration
    [ ] Both entitlements have identical non-APNs keys (app groups, etc.)

[ ] PRIVACY MANIFEST (PrivacyInfo.xcprivacy)
    [ ] File exists in project and is included in target
    [ ] All accessed API types declared with reasons
    [ ] Data collection types accurately listed
    [ ] NSPrivacyTracking set correctly (false if no tracking)
    [ ] NSPrivacyTrackingDomains listed if tracking=true

[ ] BUILD CONFIGURATION
    [ ] Archive scheme uses Release configuration
    [ ] Code signing identity set for distribution
    [ ] Provisioning profile is App Store/Ad Hoc (not Development)
    [ ] Bundle identifier matches App Store Connect

[ ] PUSH NOTIFICATIONS
    [ ] APNs key uploaded to App Store Connect
    [ ] Production APNs endpoint used in server code
    [ ] Device token registration works in Release build
    [ ] Notification categories registered at app launch

[ ] APP STORE CONNECT
    [ ] App record exists with correct bundle ID
    [ ] All required metadata filled in
    [ ] Screenshots uploaded for all required sizes
    [ ] Privacy policy URL valid

[ ] RACE CONDITIONS
    [ ] Notification-added state preserved during polling
    [ ] State merging handles async updates correctly
    [ ] No data loss during concurrent updates
```

### Automated Pre-Flight Script

```bash
#!/bin/bash
# pre-testflight-check.sh

echo "=== TestFlight Pre-Flight Checks ==="

# Check entitlements
echo "Checking entitlements..."
if [ ! -f "ClaudeWatch/ClaudeWatch-Release.entitlements" ]; then
    echo "ERROR: Release entitlements missing!"
    exit 1
fi

# Verify APNs environment in Release entitlements
APS_ENV=$(plutil -extract aps-environment raw ClaudeWatch/ClaudeWatch-Release.entitlements 2>/dev/null)
if [ "$APS_ENV" != "production" ]; then
    echo "ERROR: Release entitlements must use 'production' APNs environment!"
    exit 1
fi

# Check Privacy Manifest
echo "Checking PrivacyInfo.xcprivacy..."
if [ ! -f "ClaudeWatch/PrivacyInfo.xcprivacy" ]; then
    echo "ERROR: PrivacyInfo.xcprivacy missing!"
    exit 1
fi

# Verify privacy manifest is in Xcode project
if ! grep -q "PrivacyInfo.xcprivacy" ClaudeWatch.xcodeproj/project.pbxproj; then
    echo "ERROR: PrivacyInfo.xcprivacy not referenced in project!"
    exit 1
fi

# Check Release config uses Release entitlements
if ! grep -q 'CODE_SIGN_ENTITLEMENTS.*ClaudeWatch-Release.entitlements' ClaudeWatch.xcodeproj/project.pbxproj; then
    echo "ERROR: Release config not using Release entitlements!"
    exit 1
fi

echo "=== All pre-flight checks passed ==="
```

---

## 2. Best Practices for Entitlements Management

### File Structure

```
ClaudeWatch/
├── ClaudeWatch.entitlements          # Debug/Development
└── ClaudeWatch-Release.entitlements  # Release/Production
```

### Debug Entitlements (ClaudeWatch.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.claudewatch</string>
    </array>
</dict>
</plist>
```

### Release Entitlements (ClaudeWatch-Release.entitlements)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>production</string>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.claudewatch</string>
    </array>
</dict>
</plist>
```

### Xcode Build Settings Configuration

In `project.pbxproj`, ensure configuration-specific entitlements:

```
/* Debug */
CODE_SIGN_ENTITLEMENTS = ClaudeWatch/ClaudeWatch.entitlements;

/* Release */
CODE_SIGN_ENTITLEMENTS = "ClaudeWatch/ClaudeWatch-Release.entitlements";
```

### Key Principles

1. **Never edit entitlements files directly** - Use Xcode's Signing & Capabilities UI when possible
2. **Keep non-APNs keys synchronized** - App groups, keychain sharing, etc. must match
3. **Version control both files** - Track changes to detect accidental modifications
4. **Document each entitlement** - Comment why each capability is needed

### Entitlement Diff Check Script

```bash
#!/bin/bash
# check-entitlements-sync.sh
# Verifies Debug and Release entitlements differ ONLY in aps-environment

DEBUG_ENT="ClaudeWatch/ClaudeWatch.entitlements"
RELEASE_ENT="ClaudeWatch/ClaudeWatch-Release.entitlements"

# Extract all keys except aps-environment and compare
debug_keys=$(plutil -convert json -o - "$DEBUG_ENT" | jq -S 'del(.["aps-environment"])')
release_keys=$(plutil -convert json -o - "$RELEASE_ENT" | jq -S 'del(.["aps-environment"])')

if [ "$debug_keys" != "$release_keys" ]; then
    echo "WARNING: Entitlements differ in more than just aps-environment!"
    echo "Debug (non-APS):"
    echo "$debug_keys"
    echo "Release (non-APS):"
    echo "$release_keys"
    exit 1
fi

echo "Entitlements are properly synchronized"
```

---

## 3. Testing Strategies Before TestFlight Upload

### Tier 1: Local Testing

| Test | How | Expected Result |
|------|-----|-----------------|
| Debug build on simulator | `xcodebuild -configuration Debug -destination 'platform=watchOS Simulator'` | Builds successfully |
| Release build on simulator | `xcodebuild -configuration Release -destination 'platform=watchOS Simulator'` | Builds successfully |
| Unit tests pass | `xcodebuild test -scheme ClaudeWatch` | All tests green |

### Tier 2: Device Testing

| Test | How | Expected Result |
|------|-----|-----------------|
| Debug on physical watch | Run from Xcode with Development provisioning | App installs and runs |
| Release on physical watch | Archive and Ad Hoc distribute | App installs and runs |
| Push notifications (Dev) | Send test push via APNs sandbox | Notification appears |
| Push notifications (Prod) | Send test push via APNs production | Notification appears |

### Tier 3: Integration Testing

```swift
// NotificationIntegrationTests.swift

/// Test that notification-added actions survive cloud polling
func testNotificationActionsNotOverwrittenByPolling() async {
    // 1. Simulate notification adding an action
    let notificationAction = PendingAction(id: "notif-123", ...)
    watchService.state.pendingActions.append(notificationAction)

    // 2. Simulate cloud polling returning different actions
    let cloudResponse = [
        ["id": "cloud-456", ...]
    ]
    await watchService.processCloudResponse(cloudResponse)

    // 3. Verify notification action is preserved
    XCTAssertTrue(watchService.state.pendingActions.contains { $0.id == "notif-123" })
    XCTAssertTrue(watchService.state.pendingActions.contains { $0.id == "cloud-456" })
}
```

### Tier 4: Archive Validation

```bash
# Build archive
xcodebuild archive \
    -project ClaudeWatch.xcodeproj \
    -scheme ClaudeWatch \
    -archivePath build/ClaudeWatch.xcarchive \
    -configuration Release

# Validate archive (without uploading)
xcodebuild -exportArchive \
    -archivePath build/ClaudeWatch.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist ExportOptions.plist \
    -dry-run
```

### Tier 5: TestFlight Validation

1. Upload to App Store Connect
2. Wait for processing (check for email about issues)
3. Install via TestFlight on test device
4. Verify all features work with production APNs

### Pre-Upload Validation Checklist

```
[ ] Archive builds without warnings (treat warnings as errors)
[ ] Archive validation passes locally
[ ] Entitlements in archive match expected Release values
[ ] PrivacyInfo.xcprivacy included in archive
[ ] No development/debug code paths active
[ ] No hardcoded development URLs
[ ] Version and build numbers incremented
```

---

## 4. Common Pitfalls to Avoid

### Pitfall 1: Wrong APNs Environment

**Symptom**: Push notifications work in development but fail in TestFlight/production.

**Cause**: Using `development` APNs environment in Release entitlements.

**Prevention**:
- Always have separate entitlements files
- Automate verification in CI/CD
- Test with production APNs before uploading

### Pitfall 2: Missing Privacy Manifest

**Symptom**: App Store Connect rejects upload or warns about missing privacy declarations.

**Cause**: Apple requires `PrivacyInfo.xcprivacy` since Spring 2024 for apps using certain APIs.

**Prevention**:
- Add PrivacyInfo.xcprivacy to project template
- Audit all API usage against Apple's required reasons list
- Update manifest when adding new dependencies

**APIs Requiring Declaration** (non-exhaustive):
- UserDefaults (CA92.1 - app functionality)
- File timestamp APIs
- System boot time APIs
- Disk space APIs
- Active keyboard APIs

### Pitfall 3: Race Conditions in State Management

**Symptom**: Actions from notifications disappear or are overwritten.

**Cause**: Cloud polling response replaces local state without merging.

**Prevention**:
```swift
// WRONG: Replace all
state.pendingActions = cloudActions

// RIGHT: Merge preserving local-only
let cloudIds = Set(cloudActions.map { $0.id })
let localOnly = state.pendingActions.filter { !cloudIds.contains($0.id) }
state.pendingActions = cloudActions + localOnly
```

### Pitfall 4: Forgetting to Increment Build Number

**Symptom**: Upload rejected because build already exists.

**Prevention**:
- Use automatic build numbering (CI timestamp)
- Script to auto-increment before archive

```bash
# Auto-increment build number
BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" ClaudeWatch/Info.plist)
NEW_BUILD=$((BUILD_NUM + 1))
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $NEW_BUILD" ClaudeWatch/Info.plist
```

### Pitfall 5: Development URLs in Production

**Symptom**: App works locally but fails in TestFlight.

**Cause**: Hardcoded localhost or development server URLs.

**Prevention**:
```swift
#if DEBUG
let baseURL = "http://localhost:8787"
#else
let baseURL = "https://api.claudewatch.app"
#endif
```

### Pitfall 6: Missing Notification Categories

**Symptom**: Actionable notifications appear without action buttons.

**Cause**: Notification categories not registered at app launch.

**Prevention**:
```swift
// Register categories EARLY in app lifecycle
func application(_ application: WKApplication, didFinishLaunchingWithOptions ...) {
    registerNotificationCategories() // MUST be called here
}
```

### Pitfall 7: Entitlements Drift

**Symptom**: Debug works, Release crashes or features missing.

**Cause**: Adding capability to Debug but forgetting Release entitlements.

**Prevention**:
- Always add capabilities via Xcode UI (updates both)
- Run entitlements sync check before release
- Add to pre-commit hook

---

## Quick Reference Card

```
TESTFLIGHT PREPARATION QUICK CHECKLIST

Entitlements:
  Debug   → ClaudeWatch.entitlements      → aps-environment: development
  Release → ClaudeWatch-Release.entitlements → aps-environment: production

Privacy Manifest:
  File: ClaudeWatch/PrivacyInfo.xcprivacy
  Required since: Spring 2024

Race Condition Prevention:
  MERGE cloud + local state, don't REPLACE

Build Numbers:
  Always increment before archive

APNs Testing:
  Test PRODUCTION APNs before TestFlight upload
```

---

## Related Documentation

- [watchOS Silent Push UI Update](../integration-issues/watchos-silent-push-ui-update.md)
- [Apple Privacy Manifest Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [APNs Environment Configuration](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server)

---

*Last updated: 2026-01-19*
*Created from lessons learned during Claude Watch TestFlight preparation*
