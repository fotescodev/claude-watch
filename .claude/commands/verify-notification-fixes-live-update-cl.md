---
name: verify-notification-fixes-live-update-cl
description: Harvested from Ralph task BF1 - Verify notification fixes: live update + cleanup
tags: [bug-fix,notifications,verification-needed, auto-harvested]
harvested_from: BF1
harvested_at: 2026-01-18T23:02:40Z
---

# Verify notification fixes: live update + cleanup

## When to Use
This skill was automatically harvested from a successful Ralph task completion.
Use when facing similar patterns in watchOS development.

## Context
TWO FIXES IMPLEMENTED - NEED VERIFICATION:

FIX 1: Live UI update from push notifications
- Problem: Notification arrived but MainView showed "All Clear"
- Solution: Added `addPendingActionFromNotification()` in ClaudeWatchApp.swift
- Called in `willPresent` when notification arrives
- Also called when user taps notification to open app

FIX 2: Clear notifications after approve/reject
- Problem: Old notifications stayed in notification center
- Solution: Added `clearDeliveredNotification(for:)` in WatchService.swift
- Called after respondToCloudRequest, approveAction, rejectAction
- approveAll clears ALL delivered notifications

VERIFICATION STEPS (run these commands):
```bash
# 1. Build and install (simulator should be running)
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# 2. Install app
xcrun simctl install "Apple Watch Series 11 (46mm)" \
  ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/Debug-watchsimulator/ClaudeWatch.app

# 3. Launch app
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch

# 4. Send test notification
cat > /tmp/test.json << 'EOF'
{
  "aps": {"alert": {"title": "Test", "body": "Verify fix"}, "sound": "default", "category": "CLAUDE_ACTION"},
  "requestId": "verify-001", "type": "bash", "title": "Test Action", "description": "Verify notification fix"
}
EOF
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/test.json

# 5. VERIFY: MainView should show "Test Action" with approve/reject buttons
# 6. Approve the action
# 7. VERIFY: Notification should disappear from notification center
# 8. VERIFY: MainView should return to "All Clear"
```

If all verifications pass, mark this task complete and commit.

## Implementation Pattern
This skill was harvested automatically. Review the commit history for task BF1
to understand the specific implementation details.

## Files Affected
- ClaudeWatch/App/ClaudeWatchApp.swift
- ClaudeWatch/Services/WatchService.swift

## Verification
```bash
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -q "BUILD SUCCEEDED"
```
