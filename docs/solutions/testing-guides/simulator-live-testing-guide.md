---
title: Claude Watch Simulator Live Testing - End-to-End Approval Flow
slug: simulator-live-testing-guide
category: testing-guides
component: claude-watch-integration
tags:
  - watchos-simulator
  - push-notifications
  - cloud-server
  - pretooluse-hook
  - approval-workflow
  - xcrun-simctl
  - end-to-end-testing
created: 2026-01-15
---

# Claude Watch Simulator Live Testing Guide

Complete guide for testing the Claude Watch approval flow on the watchOS simulator, including push notifications, cloud server integration, and PreToolUse hook.

## What We Tested

| Component | Status | Notes |
|-----------|--------|-------|
| Simulator Push Notifications | ✅ PASS | via `xcrun simctl push` |
| Cloud Server Pairing | ✅ PASS | POST /pair, POST /pair/complete |
| Request Creation | ✅ PASS | POST /request with pairingId |
| Watch Approve | ✅ PASS | Returns `{"status": "approved"}` |
| Watch Reject | ✅ PASS | Returns `{"status": "rejected"}` |
| PreToolUse Hook | ✅ PASS | Returns `{"permissionDecision": "allow"}` |

## Prerequisites

```bash
# Verify Xcode command line tools
xcode-select -p

# List available watch simulators
xcrun simctl list devices | grep -i watch
```

## Setup Steps

### 1. Boot the Simulator

```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
open -a Simulator
```

### 2. Get Device ID

```bash
DEVICE_ID=$(xcrun simctl list devices | grep "Apple Watch Series 11 (46mm)" | grep -oE "[0-9A-F-]{36}")
echo $DEVICE_ID
```

### 3. Install the App

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClaudeWatch.app" -path "*watchsimulator*" | head -1)
xcrun simctl install "Apple Watch Series 11 (46mm)" "$APP_PATH"
```

### 4. Configure Cloud Mode

```bash
# Enable cloud mode (required - simulator can't use localhost WebSocket)
xcrun simctl spawn "$DEVICE_ID" defaults write com.edgeoftrust.claudewatch useCloudMode -bool true

# Set pairing ID (get from cloud server first)
xcrun simctl spawn "$DEVICE_ID" defaults write com.edgeoftrust.claudewatch pairingId -string "YOUR_PAIRING_ID"
```

### 5. Create Pairing on Cloud Server

```bash
# Generate pairing code
curl -s -X POST https://claude-watch.fotescodev.workers.dev/pair | jq .
# Returns: {"code": "XXX-XXX", "pairingId": "uuid", "expiresIn": 600}

# Complete pairing (use the code from above)
curl -s -X POST https://claude-watch.fotescodev.workers.dev/pair/complete \
  -H "Content-Type: application/json" \
  -d '{"code": "XXX-XXX", "deviceToken": "simulator-token"}'
```

### 6. Launch App

```bash
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
```

## Testing Procedure

### Test 1: Push Notification Delivery

```bash
# Create notification payload
cat > /tmp/test-notif.json << 'EOF'
{
  "aps": {
    "alert": {
      "title": "Claude: file edit",
      "body": "Edit example.swift",
      "subtitle": "Test notification"
    },
    "sound": "default",
    "category": "CLAUDE_ACTION"
  },
  "requestId": "test-001",
  "type": "file_edit"
}
EOF

# Send to simulator
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/test-notif.json
```

**Expected**: Notification appears on watch simulator.

### Test 2: Cloud Server Approval Flow

```bash
# Create request
PAIRING_ID="your-pairing-id"
curl -s -X POST https://claude-watch.fotescodev.workers.dev/request \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"type\": \"file_edit\",
    \"title\": \"Edit MainView.swift\",
    \"description\": \"Test request\"
  }"
# Returns: {"requestId": "xxxxxxxx", "apnsSent": false}

# Send notification for this request
REQUEST_ID="xxxxxxxx"  # from above
cat > /tmp/approval-test.json << EOF
{
  "aps": {"alert": {"title": "Claude: file edit", "body": "Edit MainView.swift"}, "sound": "default"},
  "requestId": "$REQUEST_ID"
}
EOF
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/approval-test.json

# Poll for response (after approving on watch)
curl -s https://claude-watch.fotescodev.workers.dev/request/$REQUEST_ID | jq .
```

**Expected on Approve**:
```json
{"id": "xxxxxxxx", "status": "approved", "response": true, "respondedAt": 1234567890}
```

**Expected on Reject**:
```json
{"id": "xxxxxxxx", "status": "rejected", "response": null, "respondedAt": 1234567890}
```

### Test 3: PreToolUse Hook Integration

```bash
# Test hook directly
echo '{"tool_name": "Bash", "tool_input": {"command": "echo test"}}' | \
  python3 .claude/hooks/watch-approval-cloud.py
```

**Expected on Approve**:
```json
{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
```

**Expected on Reject**: Exit code 2

## Troubleshooting

### Simulator Can't Connect to WebSocket

**Problem**: Watch app can't connect to `ws://localhost:8787`

**Solution**: Use cloud mode. The watchOS simulator has network limitations and cannot reliably connect to the host machine's localhost.

```bash
xcrun simctl spawn "$DEVICE_ID" defaults write com.edgeoftrust.claudewatch useCloudMode -bool true
```

### Notifications Not Appearing

**Checklist**:
1. Bundle ID matches: `com.edgeoftrust.claudewatch`
2. App is installed on simulator
3. JSON payload is valid
4. Simulator is booted

```bash
# Verify app is installed
xcrun simctl listapps "Apple Watch Series 11 (46mm)" | grep claudewatch
```

### App Not Polling for Requests

**Checklist**:
1. `useCloudMode` is `true`
2. `pairingId` is set correctly
3. App was relaunched after config change

```bash
# Check current settings
xcrun simctl spawn "$DEVICE_ID" defaults read com.edgeoftrust.claudewatch

# Force restart
xcrun simctl terminate "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
```

## Quick Reference Commands

| Action | Command |
|--------|---------|
| Boot simulator | `xcrun simctl boot "Apple Watch Series 11 (46mm)"` |
| Shutdown | `xcrun simctl shutdown "Apple Watch Series 11 (46mm)"` |
| Install app | `xcrun simctl install [device] [path]` |
| Launch app | `xcrun simctl launch [device] [bundle-id]` |
| Terminate app | `xcrun simctl terminate [device] [bundle-id]` |
| Send push | `xcrun simctl push [device] [bundle-id] [payload.json]` |
| Set default | `xcrun simctl spawn [id] defaults write [bundle] [key] -[type] [value]` |
| Read defaults | `xcrun simctl spawn [id] defaults read [bundle]` |

## Hook Configuration

The PreToolUse hook is configured in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/watch-approval-cloud.py"
          }
        ]
      }
    ]
  }
}
```

**Note**: Hooks load at session start. Restart Claude Code to pick up changes.

## Results Summary

Live testing on 2026-01-15 confirmed:

1. **Push notifications work** - `xcrun simctl push` successfully delivers to watch simulator
2. **Cloud pairing works** - Full pair → complete flow operational
3. **Approve/Reject works** - Watch responses correctly recorded on cloud server
4. **Hook integration works** - PreToolUse hook successfully orchestrates the full flow

The Claude Watch approval system is **fully functional** for simulator testing.

## Related Files

- `.claude/hooks/watch-approval-cloud.py` - PreToolUse hook for cloud mode
- `MCPServer/worker/src/index.js` - Cloudflare Worker endpoints
- `ClaudeWatch/Services/WatchService.swift` - Watch app cloud integration
