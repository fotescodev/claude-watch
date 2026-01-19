# watchOS Notification Handling Prevention Strategies

This document captures prevention strategies for avoiding issues with watchOS notification handling and SwiftUI state management, based on a real bug where silent push notifications failed to update the UI.

## Issue Summary

**Problem:** Silent push notifications (`content-available: 1`) were not updating the UI because:
1. Wrong delegate method used for silent notifications
2. View logic did not account for the new `@Published` state variable (`sessionProgress`)

---

## Prevention Strategies

### 1. Notification Type Awareness

**Always identify which notification type you are handling before implementation:**

| Notification Type | Payload Characteristic | Delegate Method | Use Case |
|-------------------|----------------------|-----------------|----------|
| **Alert (visible)** | `aps.alert` present | `userNotificationCenter(_:willPresent:)` | User-facing notifications |
| **Silent (background)** | `content-available: 1`, no alert | `didReceiveRemoteNotification(_:fetchCompletionHandler:)` | Background data updates |
| **Action response** | User tapped action | `userNotificationCenter(_:didReceive:)` | Approve/reject buttons |

**Key Insight:** Silent notifications with `content-available: 1` are delivered to `WKApplicationDelegate.didReceiveRemoteNotification()`, NOT to `UNUserNotificationCenterDelegate.willPresent()`.

### 2. Dual-Path Handling Pattern

For notifications that may arrive both in foreground and background, implement BOTH handlers:

```swift
// In WKApplicationDelegate
/// Handle silent/background push notifications (content-available: 1)
func didReceiveRemoteNotification(
    _ userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void
) {
    let notificationType = userInfo["type"] as? String

    if notificationType == "progress" {
        // Handle progress update
        handleProgressNotification(userInfo: userInfo)
        completionHandler(.newData)
    } else {
        completionHandler(.noData)
    }
}

// In UNUserNotificationCenterDelegate
/// Handle foreground notifications (willPresent is called for foreground delivery)
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    let userInfo = notification.request.content.userInfo
    let notificationType = userInfo["type"] as? String

    if notificationType == "progress" {
        handleProgressNotification(userInfo: userInfo)
        completionHandler([])  // Don't show banner for progress updates
    } else {
        handleActionNotification(userInfo: userInfo)
        completionHandler([.banner, .sound])
    }
}
```

### 3. Centralized Handler Functions

Extract notification handling logic into reusable functions to ensure consistent behavior across delegate methods:

```swift
/// Centralized progress notification handler
private func handleProgressNotification(userInfo: [AnyHashable: Any]) {
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
}
```

---

## Checklist: Adding New @Published State to SwiftUI Views

When adding a new `@Published` property that should trigger UI updates:

### Service Layer Checklist

- [ ] **1. Declare the property with `@Published`**
  ```swift
  @Published var sessionProgress: SessionProgress?
  ```

- [ ] **2. Ensure the property is set on `@MainActor`**
  ```swift
  Task { @MainActor in
      service.sessionProgress = newValue
  }
  ```

- [ ] **3. Consider ALL code paths that set this property**
  - Initialization
  - WebSocket messages
  - REST API responses
  - Push notification handlers (BOTH delegate methods)
  - User actions

### View Layer Checklist

- [ ] **4. Verify the view observes the service**
  ```swift
  @ObservedObject private var service = WatchService.shared
  ```

- [ ] **5. Update view logic to handle the new state**
  - Check if existing conditional logic needs updating
  - Example: If a view shows "empty state" when `pendingActions.isEmpty`, also check `sessionProgress == nil`

- [ ] **6. Add explicit UI for the new state (if applicable)**
  ```swift
  if let progress = service.sessionProgress {
      sessionProgressView(progress)
  }
  ```

- [ ] **7. Test all view state combinations**
  - New state is nil
  - New state has value
  - New state combined with other states (pending actions, errors, etc.)

### Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| View doesn't update | Ensure property is `@Published` and set on main thread |
| Conditional logic ignores new state | Review ALL `if/else` branches in view that determine what to show |
| State only set in one handler | Check both `willPresent` and `didReceiveRemoteNotification` |
| Forgetting to clear state | Add cleanup logic (e.g., set to `nil` when appropriate) |

---

## Testing Strategy for Notification-Driven UI Updates

### 1. Unit Tests for Notification Parsing

```swift
func testProgressNotificationParsing() {
    let userInfo: [AnyHashable: Any] = [
        "type": "progress",
        "currentTask": "Running tests",
        "progress": 0.66,
        "completedCount": 2,
        "totalCount": 3
    ]

    // Verify parsing produces expected SessionProgress
    let progress = SessionProgress(from: userInfo)
    XCTAssertEqual(progress?.currentTask, "Running tests")
    XCTAssertEqual(progress?.progress, 0.66)
    XCTAssertEqual(progress?.completedCount, 2)
    XCTAssertEqual(progress?.totalCount, 3)
}
```

### 2. Integration Tests for State Updates

```swift
func testProgressNotificationUpdatesServiceState() async {
    let service = WatchService.shared

    // Simulate notification handling
    let userInfo: [AnyHashable: Any] = [
        "type": "progress",
        "currentTask": "Test task",
        "progress": 0.5,
        "completedCount": 1,
        "totalCount": 2
    ]

    await MainActor.run {
        service.handleProgressNotification(userInfo: userInfo)
    }

    // Verify state was updated
    await MainActor.run {
        XCTAssertNotNil(service.sessionProgress)
        XCTAssertEqual(service.sessionProgress?.currentTask, "Test task")
    }
}
```

### 3. Simulator Push Notification Testing

Use `xcrun simctl push` to test real notifications:

```bash
# Create test payload for silent notification
cat > /tmp/progress.json << 'EOF'
{
  "aps": {"content-available": 1},
  "type": "progress",
  "currentTask": "Running tests",
  "progress": 0.66,
  "completedCount": 2,
  "totalCount": 3
}
EOF

# Send to simulator
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/progress.json
```

```bash
# Create test payload for visible notification with actions
cat > /tmp/action.json << 'EOF'
{
  "aps": {
    "alert": {"title": "Approval Needed", "body": "Edit file.swift"},
    "sound": "default",
    "category": "CLAUDE_ACTION"
  },
  "requestId": "test-001",
  "type": "file_edit",
  "title": "Edit file.swift",
  "description": "Modify authentication logic"
}
EOF

# Send to simulator
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/action.json
```

### 4. UI Test Assertions

```swift
func testProgressNotificationUpdatesUI() throws {
    app.launchArguments.append("--skip-consent")
    app.launchArguments.append("--demo-mode")
    app.launch()

    // Trigger progress notification (via test hook or manual)
    // ...

    // Verify UI shows progress
    let progressText = app.staticTexts["Working on:"]
    XCTAssertTrue(progressText.waitForExistence(timeout: 5))

    let taskText = app.staticTexts["Running tests"]
    XCTAssertTrue(taskText.waitForExistence(timeout: 5))
}
```

### 5. Manual Verification Checklist

| Scenario | Expected Behavior | Verified |
|----------|-------------------|----------|
| App in foreground, silent notification | UI updates immediately | [ ] |
| App in background, silent notification | State ready when app opens | [ ] |
| App in foreground, visible notification | Banner shown + UI updates | [ ] |
| User taps notification | App opens with correct state | [ ] |
| Approve action from notification | Notification cleared + UI updates | [ ] |
| Reject action from notification | Notification cleared + UI updates | [ ] |
| Multiple notifications in sequence | All processed correctly | [ ] |
| Clear all notifications (approveAll) | All notifications removed | [ ] |

---

## Best Practices for watchOS Notifications

### 1. Notification Categories

Register categories at app launch for actionable notifications:

```swift
private func registerNotificationCategories() {
    let approveAction = UNNotificationAction(
        identifier: "APPROVE_ACTION",
        title: "Approve",
        options: [.foreground]
    )

    let rejectAction = UNNotificationAction(
        identifier: "REJECT_ACTION",
        title: "Reject",
        options: [.destructive]
    )

    let category = UNNotificationCategory(
        identifier: "CLAUDE_ACTION",
        actions: [approveAction, rejectAction],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )

    UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

### 2. APNs Payload Design

**For visible notifications with actions:**
```json
{
  "aps": {
    "alert": {"title": "Approval Needed", "body": "Description"},
    "sound": "default",
    "category": "CLAUDE_ACTION"
  },
  "requestId": "unique-id",
  "type": "notification_type",
  "title": "Action Title",
  "description": "Action details"
}
```

**For silent background updates:**
```json
{
  "aps": {
    "content-available": 1
  },
  "type": "progress",
  "currentTask": "Task name",
  "progress": 0.5,
  "completedCount": 1,
  "totalCount": 2
}
```

### 3. Thread Safety

Always dispatch UI updates to the main thread:

```swift
Task { @MainActor in
    WatchService.shared.sessionProgress = newProgress
}
```

### 4. Completion Handler Discipline

Always call completion handlers:

```swift
func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {

    // ALWAYS call completionHandler, even in error cases
    defer { completionHandler(result) }

    var result: WKBackgroundFetchResult = .noData

    // Process notification...
    if processedSuccessfully {
        result = .newData
    }
}
```

### 5. Notification Cleanup

Clear delivered notifications after user action:

```swift
private func clearDeliveredNotification(for requestId: String) {
    let center = UNUserNotificationCenter.current()

    center.getDeliveredNotifications { notifications in
        let idsToRemove = notifications.compactMap { notification -> String? in
            let userInfo = notification.request.content.userInfo
            let notificationRequestId = userInfo["requestId"] as? String
            if notificationRequestId == requestId {
                return notification.request.identifier
            }
            return nil
        }

        if !idsToRemove.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }
}
```

---

## Quick Reference: Delegate Method Selection

```
                    ┌──────────────────────────────┐
                    │   Push Notification Arrives   │
                    └──────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │                              │
              Has aps.alert?               content-available: 1?
                    │                              │
                   YES                            YES
                    │                              │
                    ▼                              ▼
        ┌─────────────────────┐      ┌─────────────────────────────┐
        │ UNUserNotification  │      │ WKApplicationDelegate       │
        │ CenterDelegate      │      │ .didReceiveRemoteNotification│
        │ .willPresent()      │      │ (fetchCompletionHandler:)    │
        └─────────────────────┘      └─────────────────────────────┘
                    │
         User taps notification?
                    │
                   YES
                    │
                    ▼
        ┌─────────────────────┐
        │ UNUserNotification  │
        │ CenterDelegate      │
        │ .didReceive()       │
        └─────────────────────┘
```

---

## Files Referenced

- `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/App/ClaudeWatchApp.swift` - AppDelegate with notification handling
- `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Services/WatchService.swift` - Service with `@Published` state
- `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Views/MainView.swift` - Main view observing service state
