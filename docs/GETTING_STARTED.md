# Getting Started with Remmy

Approve Claude Code changes from your Apple Watch.

---

## Quick Start

```bash
# 1. Build and install the CLI
cd remmy-cli && bun install && bun run build && npm link

# 2. Run the pairing command
remmy

# 3. Enter the 6-digit code shown on your Apple Watch
```

That's it. Claude Code will now send approval requests to your watch.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Simulator Setup](#simulator-setup)
3. [Physical Device Setup](#physical-device-setup)
4. [Troubleshooting](#troubleshooting)

---

## Simulator Setup

For development and testing without a physical Apple Watch.

### Prerequisites

- Xcode Command Line Tools: `xcode-select --install`
- watchOS SDK (included with Xcode)
- Cloud server access (simulators can't reach localhost directly)

### Setup Steps

#### 1. Boot the Simulator

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
```

#### 2. Get Device UUID

```bash
DEVICE_ID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep -oE '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)
echo $DEVICE_ID
```

#### 3. Build and Install the App

```bash
# Build in Xcode
open ClaudeWatch.xcodeproj
# Or from command line:
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'

# Install to simulator
xcrun simctl install "Apple Watch Series 11 (46mm)" \
  $(find ~/Library/Developer/Xcode/DerivedData -name "ClaudeWatch.app" -path "*watchsimulator*" | head -1)
```

#### 4. Configure Cloud Mode

Simulators cannot reach localhost. You must use cloud mode:

```bash
BUNDLE_ID="com.edgeoftrust.remmy"

# Enable cloud mode
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool true

# Set pairing ID (get from remmy setup)
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" pairingId -string "YOUR_PAIRING_ID"
```

#### 5. Launch the App

```bash
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.remmy
```

### Quick Reference Commands

```bash
# List simulators
xcrun simctl list devices | grep "Apple Watch"

# Shutdown all simulators
xcrun simctl shutdown all

# Send test notification
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.remmy payload.json

# View logs
log stream --predicate 'process == "ClaudeWatch"' --level debug
```

---

## Physical Device Setup

For real Apple Watch with push notifications.

### Prerequisites

- Apple Developer Account ($99/year)
- Cloudflare Account (free tier works)
- Physical Apple Watch paired with iPhone

### APNs Configuration

Push notifications require Apple Push Notification service (APNs) credentials. See [APNs Setup Guide](APNS_SETUP_GUIDE.md) for the full walkthrough.

#### Quick Version

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Create new key with "Apple Push Notifications service (APNs)" enabled
3. Download the `.p8` file (can only download ONCE)
4. Note your Key ID (10 characters) and Team ID

```bash
cd claude-watch-cloud

# Set secrets
npx wrangler secret put APNS_KEY_ID        # Your 10-char key ID
npx wrangler secret put APNS_TEAM_ID       # Your team ID
npx wrangler secret put APNS_PRIVATE_KEY   # Base64 of .p8 file

# Base64 encode the .p8 file:
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy

# Deploy
npx wrangler deploy
```

### Environment Configuration

| Environment | APNS_SANDBOX | Used For |
|-------------|--------------|----------|
| Development | `"true"` | Xcode debug builds |
| TestFlight | `"false"` | TestFlight, App Store |

To switch environments, edit `wrangler.toml` in `claude-watch-cloud/`:

```toml
APNS_SANDBOX = "false"  # For TestFlight/production
```

Then redeploy: `npx wrangler deploy`

---

## Troubleshooting

### Connection Issues

#### "Invalid or expired pairing code"

- Pairing codes expire after 5 minutes
- Generate a new code: tap "Pair" again on the watch, then run `remmy`
- Code is 6 digits

#### "Network unavailable"

- Check Wi-Fi/cellular connectivity on watch
- Verify cloud server: `curl https://remmy.watch/health`

#### Simulator can't connect

- Simulators cannot reach localhost directly
- Must use cloud mode (see Simulator Setup above)

### Notification Issues

#### Notifications not appearing

1. Check permissions: iPhone > Watch app > Notifications > Remmy
2. Verify Do Not Disturb is OFF
3. Test APNs: Check `apnsSent: true` in API response

#### `apnsSent: false` in response

- Secrets not configured: `npx wrangler secret list` (in `claude-watch-cloud/`)
- Redeploy after setting secrets: `npx wrangler deploy`

#### Wrong APNs environment

| Build Type | Required Setting |
|------------|------------------|
| Xcode Debug | `APNS_SANDBOX = "true"` |
| TestFlight | `APNS_SANDBOX = "false"` |
| App Store | `APNS_SANDBOX = "false"` |

### Quick Diagnostic

```bash
# Check cloud server
curl https://remmy.watch/health

# Check pairing status
curl https://remmy.watch/approval-queue/YOUR_PAIRING_ID

# View Cloudflare logs
cd claude-watch-cloud && npx wrangler tail
```

### Error Quick Reference

| Error | Cause | Solution |
|-------|-------|----------|
| "Connection timeout" | Server unreachable | Check URL, firewall |
| "Max reconnection attempts" | Persistent failure | Reset app, check config |
| "BadDeviceToken" | Invalid APNs token | Re-pair watch |
| "InvalidProviderToken" | Wrong Key/Team ID | Verify APNs credentials |

---

## Best Practices

1. **Re-pair after environment switch** -- device tokens differ between sandbox/production
2. **Keep pairing codes fresh** -- they expire after 5 minutes
3. **Monitor connection status** -- watch main screen shows current state

---

## Additional Resources

- [Architecture Guide](../.claude/ARCHITECTURE.md) -- System design and data flows
- [Data Flow Reference](../.claude/DATA_FLOW.md) -- API endpoint details
- [Solutions Index](./solutions/INDEX.md) -- Previously solved problems by symptom
- [Contributing](../CONTRIBUTING.md) -- How to contribute

---

*Last updated: 2026-03-04*
