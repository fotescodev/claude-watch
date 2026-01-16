---
title: watchOS Simulator Push Notifications and PreToolUse Hook Integration - Live Test Results
slug: watch-hook-integration-live-test
category: testing-guides
component: claude-watch-mcp-server
tags:
  - watchos-simulator
  - push-notifications
  - apns
  - hook-integration
  - approval-workflow
  - xcrun-simctl
  - cloud-integration
  - pre-tool-use
  - end-to-end-testing
created: 2026-01-15
---

# watchOS Simulator Push Notifications and PreToolUse Hook Integration

## Overview

This document captures the results of a comprehensive live testing session that validated the complete Claude Watch approval workflow. The testing covered push notification delivery to watchOS simulator, cloud server integration, user approval/rejection flows, and the PreToolUse hook that orchestrates the entire approval system.

## Testing Scope

### 1. watchOS Simulator Push Notifications
- Launched Apple Watch Series 11 (46mm) simulator
- Tested native push notification delivery mechanism
- Method: Direct `xcrun simctl push` command to simulator with JSON payload
- Bundle ID: `com.edgeoftrust.claudewatch`

### 2. Cloud Server Request/Response Flow
- POST `/pair` endpoint for pairing initiation
- POST `/pair/complete` endpoint for pairing completion
- POST `/request` endpoint for creating approval requests
- GET `/request/:id` endpoint for polling request status

### 3. Watch User Approval/Rejection
- Approval path: User action triggers status change to "approved" with `respondedAt` timestamp
- Rejection path: User action triggers status change to "rejected" with `response: null`

### 4. PreToolUse Hook Integration
- Hook file: `watch-approval-cloud.py`
- Framework: Claude MCP PreToolUse hook
- Orchestrates: Request creation → Notification dispatch → Status polling → Decision return

## Test Results

### Simulator Push Notifications
**Status: PASSED ✓**

Notifications were successfully delivered to the Apple Watch Series 11 (46mm) simulator using the `xcrun simctl push` command:

```bash
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch payload.json
```

**Evidence:**
- Notifications appeared on watch simulator screen
- Multiple test notifications (3+) were successfully delivered without errors
- Payload delivery was reliable and consistent

### Cloud Server Integration - Pairing Flow
**Status: PASSED ✓**

**POST /pair:**
- Endpoint correctly returns: `{"code": "...", "pairingId": "..."}`
- Pairing code generated and pairingId assigned

**POST /pair/complete:**
- Successfully completed pairing using code and deviceToken
- Paired device registered on cloud server

### Cloud Server Integration - Request Management
**Status: PASSED ✓**

**POST /request:**
```
Body: {
  "pairingId": "...",
  "type": "...",
  "title": "...",
  "description": "..."
}
Response: {"id": "..."}
```
- Request creation successful
- Server-side request object created and stored

**GET /request/:id:**
- Returns pending status: `{"status": "pending"}`
- Returns approved status with timestamp: `{"status": "approved", "response": true}`
- Returns rejected status: `{"status": "rejected", "response": null}`

### Watch Approve/Reject Flow - Approval Path
**Status: PASSED ✓**

**Workflow:**
1. Request created on server via POST /request
2. Notification delivered to simulator via xcrun simctl push
3. User taps "Approve" action on notification
4. System registers approval action
5. GET /request/:id returns: `{"status": "approved", "response": true}`
6. `respondedAt` timestamp recorded on server

**Result:** Complete approval workflow functioning end-to-end.

### Watch Approve/Reject Flow - Rejection Path
**Status: PASSED ✓**

**Workflow:**
1. Request created on server via POST /request
2. Notification delivered to simulator via xcrun simctl push
3. User taps "Reject" action on notification
4. System registers rejection action
5. GET /request/:id returns: `{"status": "rejected", "response": null}`
6. `respondedAt` timestamp recorded on server

**Result:** Complete rejection workflow functioning end-to-end.

### PreToolUse Hook Integration
**Status: PASSED ✓**

**Hook Implementation:** `watch-approval-cloud.py`

**Workflow:**
1. Hook receives tool use request from Claude MCP
2. Creates approval request on cloud server (POST /request)
3. Sends push notification to watch simulator (xcrun simctl push)
4. Polls GET /request/:id with exponential backoff
5. Returns decision based on user response

**Hook Return Behavior:**

**On Approval:**
```json
{
  "hookSpecificOutput": {
    "permissionDecision": "allow"
  }
}
```
- Tool execution proceeds
- User approval logged with timestamp

**On Rejection:**
```
Exit code: 2
```
- Tool execution blocked
- User rejection logged with timestamp

**Testing Evidence:**
- Hook successfully created requests on cloud server
- Notifications properly dispatched to simulator
- Status polling worked with appropriate retry logic
- Correct return values for both approval and rejection paths

## Key Components Tested

### Server-Side Components
- **PendingAction class** (`MCPServer/server.py` lines 82-103): Action state management
- **ActionStatus enum** (`MCPServer/server.py` lines 68-72): Status tracking (pending/approved/rejected)
- **WatchConnectionManager** (`MCPServer/server.py` lines 132-269): WebSocket connection handling
- **APNsSender class** (`MCPServer/server.py` lines 273-353): Push notification delivery

### Client-Side Components
- **ClaudeWatchApp.swift** (`ClaudeWatch/App/`): Notification registration and handling
- **WatchService.swift** (`ClaudeWatch/Services/`): WebSocket client and approval actions
- **MainView.swift** (`ClaudeWatch/Views/`): UI for displaying pending approvals

### Integration Points
- Cloud server: Python Flask/async endpoints
- Simulator: xcrun simctl push for notification delivery
- Watch app: UNNotificationAction handling for approve/reject
- MCP framework: PreToolUse hook integration

## Technical Details

### Simulator Push Notification Payload
```json
{
  "aps": {
    "alert": {
      "title": "Approval Request",
      "body": "Approve or reject this action"
    },
    "sound": "default",
    "category": "APPROVAL_CATEGORY"
  },
  "requestId": "..."
}
```

### Request Lifecycle on Cloud Server
```
Created → Pending → (User responds) → Approved/Rejected → respondedAt timestamp
```

### Hook Polling Strategy
- Initial poll immediately after notification send
- Exponential backoff: 0.5s, 1s, 2s, 4s, 8s, etc.
- Timeout: 300 seconds (5 minutes)
- Retry on network errors, stop on explicit user decision

## Validation Checklist

- [x] Notifications delivered to watch simulator
- [x] Multiple notifications sent and received
- [x] Cloud pairing flow functional
- [x] Request creation and polling operational
- [x] Approval action registered and reflected in GET /request/:id
- [x] Rejection action registered and reflected in GET /request/:id
- [x] Hook creates requests on cloud server
- [x] Hook sends notifications to simulator
- [x] Hook polls for completion correctly
- [x] Hook returns {"permissionDecision": "allow"} on approval
- [x] Hook exits with code 2 on rejection
- [x] End-to-end workflow from tool use to decision functional

## Related Documentation

- `MCPServer/TESTING_SESSION.md` - Detailed testing procedures and commands
- `MCPServer/server.py` - Python MCP server implementation (classes: PendingAction, WatchConnectionManager, APNsSender)
- `ClaudeWatch/Services/WatchService.swift` - Watch client implementation
- `ClaudeWatch/App/ClaudeWatchApp.swift` - Notification registration and handling
- `docs/PRD.md` - Product requirements and feature specifications

## Future Testing Considerations

1. **Real Device Testing**: Validate on actual watchOS devices with real APNs certificates
2. **Network Latency**: Test with simulated network delays
3. **Concurrent Requests**: Test multiple simultaneous approval requests
4. **Long Polling**: Extend timeout scenarios
5. **Error Recovery**: Test network disconnection and reconnection scenarios
6. **Hook Timeout**: Test behavior when user doesn't respond within 5 minutes

## Conclusion

The live testing session successfully validated the complete Claude Watch approval workflow. All core functionality—push notification delivery, cloud server integration, user actions, and MCP hook integration—is operational and ready for integration with Claude Code's PreToolUse hook system. The workflow enables developers to approve or reject code changes directly from their Apple Watch while using Claude Code.
