---
description: Clean, build, and install the app on a physical Apple Watch
allowed-tools: Bash(xcodebuild:*), Bash(xcrun:*), Bash(rm:*), Read
---

# Deploy to Physical Apple Watch

Build and install ClaudeWatch on the user's physical Apple Watch for end-to-end testing.

## Prerequisites Check

First verify the watch is available:
```bash
xcrun devicectl list devices 2>&1
```

**Device states:**
- `available (paired)` - Ready for deployment
- `connecting` - Wait or wake watch (raise wrist, unlock)
- `unavailable` - Enable Developer Mode on watch: Settings > Privacy & Security > Developer Mode

## Workflow

### 1. Check Device Status
```bash
xcrun devicectl list devices 2>&1 | grep -i watch
```

If status is NOT "available", inform user:
- **connecting**: "Wake your Apple Watch (raise wrist, tap screen, unlock)"
- **unavailable**: "Enable Developer Mode: Watch Settings > Privacy & Security > Developer Mode > ON, then restart watch"

### 2. Clean Build (optional but recommended)
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*
```

### 3. Build for Device
```bash
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'generic/platform=watchOS' \
  -allowProvisioningUpdates \
  build 2>&1 | tail -50
```

Check for `** BUILD SUCCEEDED **` at the end.

### 4. Get App Path
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/Debug-watchos -name "ClaudeWatch.app" -type d 2>/dev/null | head -1)
echo "App path: $APP_PATH"
```

### 5. Install on Watch
Get the watch's CoreDevice identifier first:
```bash
WATCH_ID=$(xcrun devicectl list devices 2>&1 | grep -i watch | grep available | awk '{print $3}')
echo "Watch ID: $WATCH_ID"
```

Then install:
```bash
xcrun devicectl device install app --device "$WATCH_ID" "$APP_PATH"
```

### 6. Launch App (optional)
```bash
xcrun devicectl device process launch --device "$WATCH_ID" com.edgeoftrust.claudewatch
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Device is busy (Connecting)" | Wake watch, wait 30s, retry |
| "Unable to find destination" | Watch not paired or Developer Mode off |
| Signing errors | Open Xcode, let it fix provisioning |
| "No such device" | Check `xcrun devicectl list devices` |

## Quick Full Deploy
```bash
# All-in-one (after confirming watch is available):
rm -rf ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-* && \
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'generic/platform=watchOS' -allowProvisioningUpdates build 2>&1 | tail -20 && \
WATCH_ID=$(xcrun devicectl list devices 2>&1 | grep -i watch | grep available | awk '{print $3}') && \
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/Debug-watchos -name "ClaudeWatch.app" -type d | head -1) && \
xcrun devicectl device install app --device "$WATCH_ID" "$APP_PATH"
```
