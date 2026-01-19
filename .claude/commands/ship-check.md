---
description: Pre-submission validation checklist for TestFlight/App Store
allowed-tools: Read, Glob, Grep, Bash(xcodebuild:*), Bash(plutil:*), Bash(ls:*), Bash(cat:*)
---

# /ship-check - Pre-Submission Validation

**Purpose**: Comprehensive checklist before uploading to TestFlight or App Store. Catches common rejection reasons.

## Instructions

Run through each validation category and report status.

### 1. Entitlements Check

```bash
# Check Release entitlements exist
ls -la ClaudeWatch/ClaudeWatch-Release.entitlements 2>/dev/null || echo "MISSING: Release entitlements"

# Verify production APNs
plutil -extract aps-environment raw ClaudeWatch/ClaudeWatch-Release.entitlements 2>/dev/null || echo "MISSING: aps-environment"

# Check Debug entitlements (should be development)
plutil -extract aps-environment raw ClaudeWatch/ClaudeWatch.entitlements 2>/dev/null
```

**Expected**:
- `ClaudeWatch-Release.entitlements` exists
- Release has `aps-environment: production`
- Debug has `aps-environment: development`

### 2. Privacy Manifest Check

```bash
# Check PrivacyInfo.xcprivacy exists
ls -la ClaudeWatch/PrivacyInfo.xcprivacy 2>/dev/null || echo "MISSING: Privacy manifest"

# Verify it's in Xcode project
grep -r "PrivacyInfo.xcprivacy" ClaudeWatch.xcodeproj/project.pbxproj || echo "NOT IN PROJECT"
```

**Expected**:
- `PrivacyInfo.xcprivacy` exists
- File is referenced in Xcode project

### 3. Build Validation

```bash
# Archive build test (dry run)
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -configuration Release \
  -destination 'generic/platform=watchOS' \
  -archivePath /tmp/ClaudeWatch-test.xcarchive \
  archive 2>&1 | tail -20
```

**Expected**:
- Archive succeeds without errors
- No signing issues

### 4. Info.plist Check

```bash
# Required keys
grep -E "CFBundleDisplayName|CFBundleShortVersionString|CFBundleVersion|UIDeviceFamily" ClaudeWatch/Info.plist
```

**Expected**:
- Display name set
- Version numbers present
- Device family includes watch (4)

### 5. App Icons Check

```bash
# Check icon assets exist
ls ClaudeWatch/Assets.xcassets/AppIcon.appiconset/*.png 2>/dev/null | wc -l
```

**Expected**:
- All required icon sizes present (6+ PNG files)

### 6. Accessibility Check

```bash
# Quick scan for accessibility labels
grep -r "accessibilityLabel\|accessibilityHint" ClaudeWatch/Views/ | wc -l
```

**Expected**:
- At least 10+ accessibility labels
- All interactive elements labeled

### 7. Code Signing Check

```bash
# Check signing configuration
grep -A5 "CODE_SIGN_IDENTITY" ClaudeWatch.xcodeproj/project.pbxproj | head -10
```

**Expected**:
- Release uses "Apple Distribution" or "iPhone Distribution"
- Provisioning profile set for App Store

## Output Format

```
## Ship Check Results

### Critical (Must Fix)
- [ ] FAIL: [Issue description]
- [x] PASS: [Check name]

### High (Should Fix)
- [ ] WARN: [Issue description]
- [x] PASS: [Check name]

### Checklist Status
| Category | Status | Notes |
|----------|--------|-------|
| Entitlements | PASS/FAIL | ... |
| Privacy Manifest | PASS/FAIL | ... |
| Build | PASS/FAIL | ... |
| Info.plist | PASS/FAIL | ... |
| App Icons | PASS/FAIL | ... |
| Accessibility | PASS/FAIL | ... |
| Code Signing | PASS/FAIL | ... |

### Ready to Ship?
[YES - All checks pass / NO - Fix issues above]

### Next Steps
1. [First thing to fix]
2. [Second thing to fix]
```

## When to Use

- **Before TestFlight upload**: Catch issues early
- **Before App Store submission**: Final validation
- **After major changes**: Verify nothing broke

## Common Fixes

### Missing Release Entitlements
```bash
cp ClaudeWatch/ClaudeWatch.entitlements ClaudeWatch/ClaudeWatch-Release.entitlements
# Then edit to change aps-environment to "production"
```

### Missing Privacy Manifest
```bash
# Create basic privacy manifest
cat > ClaudeWatch/PrivacyInfo.xcprivacy << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF
```

### Missing Accessibility Labels
```swift
Button("Approve") { ... }
    .accessibilityLabel("Approve action")
    .accessibilityHint("Double tap to approve this code change")
```
