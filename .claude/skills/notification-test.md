# Notification Testing

Test push notifications for Claude Watch.

## Notification Categories

Claude Watch registers one notification category:

```swift
// CLAUDE_ACTION category with actions:
- "APPROVE_ACTION" - Approve the pending action
- "REJECT_ACTION" - Reject the pending action
- "APPROVE_ALL_ACTION" - Approve all pending actions
```

## Testing Local Notifications

### 1. Create Test Payload File

Create `test-notification.apns`:
```json
{
    "aps": {
        "alert": {
            "title": "Claude Code",
            "body": "Approve file edit: MainView.swift?"
        },
        "category": "CLAUDE_ACTION",
        "sound": "default"
    },
    "actionId": "test-123",
    "actionType": "file_edit"
}
```

### 2. Send to Simulator

```bash
# Get device UDID
WATCH_UDID=$(xcrun simctl list devices | grep "Apple Watch Series 11" | grep Booted | grep -oE '[A-F0-9-]{36}')

# Send notification
xcrun simctl push $WATCH_UDID com.anthropic.claudecode test-notification.apns
```

## Testing Remote Notifications (APNs)

### Required Setup
1. Apple Developer account
2. APNs key (.p8 file)
3. Bundle ID registered for push

### Send via curl
```bash
# Generate JWT token first (see APNs documentation)
curl -v \
  --header "apns-topic: com.anthropic.claudecode" \
  --header "apns-push-type: alert" \
  --header "authorization: bearer $JWT_TOKEN" \
  --data '{"aps":{"alert":"Test","category":"CLAUDE_ACTION"}}' \
  --http2 \
  https://api.push.apple.com/3/device/$DEVICE_TOKEN
```

## Notification Flow

```
1. Server creates pending action
2. Server sends notification (local or APNs)
3. Watch receives in:
   - Foreground: UNUserNotificationCenterDelegate
   - Background: System shows banner
4. User taps action button
5. Watch sends response to server
```

## Key Files

- `ClaudeWatch/App/ClaudeWatchApp.swift` - Notification setup
- `ClaudeWatch/Services/WatchService.swift:handleNotificationResponse()` - Action handling

## Debugging

### Check Notification Permissions
```swift
UNUserNotificationCenter.current().getNotificationSettings { settings in
    print(settings.authorizationStatus)
}
```

### Common Issues

**Notifications not appearing**:
- Check `authorizationStatus` is `.authorized`
- Verify bundle ID matches in payload

**Actions not showing**:
- Ensure `CLAUDE_ACTION` category is registered
- Check `actionIdentifier` in response handler
