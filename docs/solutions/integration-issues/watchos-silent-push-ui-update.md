---
title: "Silent Push Notifications Not Updating Watch UI for Real-Time Task Progress"
category: integration-issues
tags:
  - watchOS
  - SwiftUI
  - APNs
  - silent-push-notifications
  - UNUserNotificationCenter
  - real-time-updates
  - content-available
severity: high
component: ClaudeWatch
date_documented: 2026-01-18
symptoms:
  - "Progress notifications sent from server but watch UI shows 'All Clear'"
  - "Silent push received but @Published state not triggering view refresh"
  - "Background notification handler not updating visible UI"
technologies:
  - watchOS 10.0+
  - Swift 5.9+
  - SwiftUI
  - APNs
related_files:
  - ClaudeWatch/App/ClaudeWatchApp.swift
  - ClaudeWatch/Views/MainView.swift
  - ClaudeWatch/Services/WatchService.swift
---

# Silent Push Notifications Not Updating Watch UI

## Problem

Progress notifications sent from the Cloudflare worker were being received by the watch but the UI continued showing "All Clear" instead of displaying the task progress.

**Expected:** Watch displays "Working on: [task name]" with progress bar
**Actual:** Watch shows "All Clear" empty state

## Root Cause Analysis

### Root Cause 1: Wrong Delegate Method for Silent Push

Silent push notifications (those with `content-available: 1` but no `alert` payload) are delivered differently than regular notifications on watchOS:

| Notification Type | Delegate Method |
|-------------------|-----------------|
| Regular (with alert) | `userNotificationCenter:willPresent:` |
| Silent (`content-available: 1`) | `didReceiveRemoteNotification:fetchCompletionHandler:` |

The original implementation only had `willPresent`, so silent progress pushes were received by the system but never processed by the app.

### Root Cause 2: View Logic Missing New State Check

The `MainView` displayed `EmptyStateView` based on:

```swift
// BROKEN: Missing sessionProgress check
if service.state.pendingActions.isEmpty && service.state.status == .idle {
    EmptyStateView()
}
```

Even when `sessionProgress` was set, the view showed "All Clear" because:
1. No pending approval actions existed
2. Status was `.idle` (progress updates don't change status)

## Solution

### Step 1: Add Silent Push Handler

Add `didReceiveRemoteNotification` to `AppDelegate`:

```swift
func didReceiveRemoteNotification(
    _ userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void
) {
    let notificationType = userInfo["type"] as? String

    if notificationType == "progress" {
        let currentTask = userInfo["currentTask"] as? String
        let progress = userInfo["progress"] as? Double ?? 0
        let completedCount = userInfo["completedCount"] as? Int ?? 0
        let totalCount = userInfo["totalCount"] as? Int ?? 0

        Task { @MainActor in
            let service = WatchService.shared
            if totalCount > 0 {
                service.sessionProgress = SessionProgress(
                    currentTask: currentTask,
                    progress: progress,
                    completedCount: completedCount,
                    totalCount: totalCount
                )
            } else {
                service.sessionProgress = nil
            }
        }
        completionHandler(.newData)
    } else {
        completionHandler(.noData)
    }
}
```

### Step 2: Update willPresent for Hybrid Notifications

Handle progress notifications that include an alert payload:

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    let userInfo = notification.request.content.userInfo
    let notificationType = userInfo["type"] as? String

    if notificationType == "progress" {
        handleProgressNotification(userInfo: userInfo)
        completionHandler([])  // Don't show banner
    } else {
        addPendingActionFromNotification(userInfo: userInfo)
        completionHandler([.banner, .sound])
    }
}
```

### Step 3: Fix MainView Empty State Condition

```swift
// FIXED: Check sessionProgress before showing empty state
} else if service.state.pendingActions.isEmpty
        && service.state.status == .idle
        && service.sessionProgress == nil {
    EmptyStateView()
} else {
    mainContentView
}
```

## Testing

### Simulator Push Test

```bash
# Create test payload
cat > /tmp/progress-test.json << 'EOF'
{
  "aps": {
    "alert": {"title": "Progress", "body": "Update"},
    "sound": "default"
  },
  "type": "progress",
  "currentTask": "Running tests",
  "progress": 0.66,
  "completedCount": 4,
  "totalCount": 6
}
EOF

# Send to simulator
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/progress-test.json
```

**Note:** For simulator testing, use notifications with an `alert` payload. Pure silent notifications (`content-available` only) may not be delivered reliably in the simulator.

## Prevention Strategies

### 1. Notification Type Awareness

Always implement both handlers when supporting different notification types:
- `willPresent` for foreground visible notifications
- `didReceiveRemoteNotification` for background/silent notifications

### 2. Checklist for New @Published State

When adding new `@Published` properties to a service:

- [ ] Update ALL view conditions that might hide the new state
- [ ] Check empty state / loading state logic
- [ ] Check animation state tracking
- [ ] Test all state combinations

### 3. Centralized Handler Pattern

Extract notification handling into reusable functions:

```swift
private func handleProgressNotification(userInfo: [AnyHashable: Any]) {
    // Single implementation, called from multiple handlers
}
```

## Related

- [Apple: Pushing Background Updates](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app)
- [UNUserNotificationCenterDelegate](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
- [WKApplicationDelegate](https://developer.apple.com/documentation/watchkit/wkapplicationdelegate)
