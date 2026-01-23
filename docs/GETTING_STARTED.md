# Getting Started with Claude Watch

Approve Claude Code changes from your Apple Watch.

---

## Quick Start

```bash
# 1. Install the CLI
npm install -g cc-watch

# 2. Run the pairing command
cc-watch

# 3. Enter the code shown on your Apple Watch
```

That's it! Claude Code will now send approval requests to your watch.

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
- Cloud server access (simulators can't use localhost)

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

#### 3. Install the App

```bash
# Build in Xcode first, then:
xcrun simctl install "Apple Watch Series 11 (46mm)" /path/to/ClaudeWatch.app
```

#### 4. Configure Cloud Mode

Simulators cannot reach localhost. You must use cloud mode:

```bash
BUNDLE_ID="com.edgeoftrust.claudewatch"

# Enable cloud mode
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool true

# Set pairing ID (get from cc-watch pairing)
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" pairingId -string "YOUR_PAIRING_ID"
```

#### 5. Launch the App

```bash
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
```

### Quick Reference Commands

```bash
# List simulators
xcrun simctl list devices | grep "Apple Watch"

# Shutdown all simulators
xcrun simctl shutdown all

# Send test notification
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch payload.json

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

Push notifications require Apple Push Notification service (APNs) credentials.

#### 1. Create APNs Key

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click "+" to create new key
3. Name it "Claude Watch APNs"
4. Check "Apple Push Notifications service (APNs)"
5. Download the `.p8` file (can only download ONCE)
6. Note your Key ID (10 characters)
7. Note your Team ID (from membership page)

#### 2. Configure Cloudflare Worker

```bash
cd claude-watch-cloud

# Set secrets (you'll be prompted for values)
npx wrangler secret put APNS_KEY_ID        # Your 10-char key ID
npx wrangler secret put APNS_TEAM_ID       # Your team ID
npx wrangler secret put APNS_PRIVATE_KEY   # Base64 of .p8 file

# Base64 encode the .p8 file:
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
```

#### 3. Deploy Worker

```bash
npx wrangler deploy
```

#### 4. Verify Setup

```bash
# Check secrets are set
npx wrangler secret list

# Test health endpoint
curl https://claude-watch.fotescodev.workers.dev/health
```

### Environment Configuration

| Environment | APNS_SANDBOX | Used For |
|-------------|--------------|----------|
| Development | `"true"` | Xcode debug builds |
| TestFlight | `"false"` | TestFlight, App Store |

To switch environments, edit `wrangler.toml`:

```toml
APNS_SANDBOX = "false"  # For TestFlight/production
```

Then redeploy: `npx wrangler deploy`

---

## Troubleshooting

### Connection Issues

#### "Invalid or expired pairing code"

- Codes expire after 30 minutes
- Generate new code: run `cc-watch` again
- Verify code is exactly 6 characters, no spaces

#### "Network unavailable"

- Check Wi-Fi/cellular connectivity on watch
- Verify cloud server: `curl https://claude-watch.fotescodev.workers.dev/health`

#### Simulator can't connect

- Simulators cannot use localhost
- Must use cloud mode (see Simulator Setup above)

### Notification Issues

#### Notifications not appearing

1. Check permissions: iPhone → Watch app → Notifications → Claude Watch
2. Verify Do Not Disturb is OFF
3. Test APNs: Check `apnsSent: true` in API response

#### `apnsSent: false` in response

- Secrets not configured: `npx wrangler secret list`
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
curl https://claude-watch.fotescodev.workers.dev/health

# Check pairing status
curl https://claude-watch.fotescodev.workers.dev/approval-queue/YOUR_PAIRING_ID

# View Cloudflare logs
npx wrangler tail
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

1. **Use Cloud Mode for production** - better reliability, supports push notifications
2. **Re-pair after environment switch** - device tokens differ between sandbox/production
3. **Keep pairing codes fresh** - use within 30 minutes
4. **Monitor connection status** - watch main screen shows current state

---

## Additional Resources

- [Architecture Guide](../.claude/ARCHITECTURE.md) - System design
- [Data Flow Reference](../.claude/DATA_FLOW.md) - API endpoints
- [Solutions Index](./solutions/INDEX.md) - Known issues and fixes

---

*Last updated: 2026-01-23*
