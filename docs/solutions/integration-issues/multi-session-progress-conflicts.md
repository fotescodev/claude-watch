---
title: "Multi-Session Progress Tracking Conflicts and Stale Watch UI State"
category: integration-issues
severity: medium
platform: watchOS
symptoms:
  - Watch shows wrong session's progress (Ralph's tasks instead of user's)
  - Progress bar stuck at percentage forever (e.g., "45%")
  - SessionProgress never clears after session ends
  - Empty state shows "All Clear" with useless "Try Demo" button
components:
  - WatchService
  - ClaudeWatchApp
  - StateViews
  - progress-tracker hook
tags:
  - watchOS
  - SwiftUI
  - session-isolation
  - stale-state
  - progress-tracking
  - multi-session
---

# Multi-Session Progress Conflicts and Stale UI State

## Problem

Three interconnected issues when using Claude Watch with multiple Claude Code sessions:

### 1. Session Isolation
When running Ralph (autonomous task runner) inside a Claude Code session with watch hooks enabled, Ralph's `TodoWrite` calls send progress updates to the watch, overwriting the user's interactive session progress.

### 2. Stale Progress Data
Progress displays (e.g., "Refactoring auth mod... 45%") persist indefinitely because `sessionProgress` only clears when a notification with `totalCount: 0` arrives. If a session terminates abnormally, the watch shows stale data forever.

### 3. Useless Empty State
The "All Clear" view showed only a tray icon and "Try Demo" button - no useful information when paired and waiting for approvals.

## Root Cause

1. **Session Isolation**: Hooks execute in ANY Claude Code session with a pairing ID configured, not just the designated watch session.

2. **No Staleness Timeout**: `sessionProgress` had no automatic cleanup mechanism - it depended entirely on receiving a "completion" notification.

3. **Single Empty State**: `EmptyStateView` didn't differentiate between "not paired" and "paired but idle" states.

## Solution

### Fix 1: Session Isolation via Environment Variable

Hooks check for `CLAUDE_WATCH_SESSION_ACTIVE=1` env var and exit immediately if not set:

```python
# .claude/hooks/watch-approval-cloud.py (and progress-tracker.py)
def main():
    # Session isolation: Only run if this session was started with cc-watch
    if not os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE"):
        sys.exit(0)
    # ... rest of hook logic
```

**Usage**: Only `npx cc-watch` sets this env var when starting a session. Other sessions (including Ralph) exit hooks immediately.

### Fix 2: Stale Progress Timeout (60 seconds)

Track when progress was last updated and clear if stale:

```swift
// WatchService.swift
@Published var sessionProgress: SessionProgress?
var lastProgressUpdate: Date?
private let progressStaleThreshold: TimeInterval = 60

// In fetchPendingRequests() polling loop:
if let lastUpdate = lastProgressUpdate,
   Date().timeIntervalSince(lastUpdate) > progressStaleThreshold {
    sessionProgress = nil
    lastProgressUpdate = nil
}
```

Set timestamp when progress notification received:
```swift
// ClaudeWatchApp.swift - handleProgressNotificationBackground()
service.sessionProgress = SessionProgress(...)
service.lastProgressUpdate = Date()
```

### Fix 3: Contextual Empty State

Separate views for paired vs unpaired states:

```swift
// StateViews.swift
var body: some View {
    if service.isPaired {
        pairedEmptyState  // Shows: connection status, "Ready", "Approvals will appear here"
    } else {
        unpairedEmptyState  // Shows: "Not Paired", pairing button, demo button
    }
}
```

**Paired empty state shows:**
- Connection status dot (green/yellow/red)
- "Ready" with checkmark icon
- "Approvals will appear here" subtitle
- Pairing ID (8 chars) for debugging

## Prevention

### Session Isolation
- **Always** use `CLAUDE_WATCH_SESSION_ACTIVE=1` only for ONE designated session
- Never run Ralph or automated tools in the same environment as an active watch session
- Consider adding session identifiers to notifications for validation

### Stale State
- Always implement timeout-based cleanup for external-dependent state
- Never trust that "completion" notifications will arrive
- Include TTL (time-to-live) with every state update

### Empty States
- Empty states must show: **status + context + expectation**
- Remove "demo" buttons once user is paired
- Show last activity time to indicate system health

## Files Modified

| File | Change |
|------|--------|
| `ClaudeWatch/Services/WatchService.swift` | Added `lastProgressUpdate`, `progressStaleThreshold`, staleness check |
| `ClaudeWatch/App/ClaudeWatchApp.swift` | Set `lastProgressUpdate` in notification handler |
| `ClaudeWatch/Views/StateViews.swift` | Redesigned `EmptyStateView` with paired/unpaired states |
| `.claude/hooks/watch-approval-cloud.py` | Added session isolation check |
| `.claude/hooks/progress-tracker.py` | Added session isolation check |

## Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Wrong progress showing | Multiple sessions sending to watch | Check `CLAUDE_WATCH_SESSION_ACTIVE` env var |
| Progress stuck forever | No staleness timeout | Auto-clears after 60s (already fixed) |
| "All Clear" when paired | Single empty state design | Force quit app, shows "Ready" now |

## Related

- [watchos-silent-push-ui-update.md](watchos-silent-push-ui-update.md) - Silent push notification handling
