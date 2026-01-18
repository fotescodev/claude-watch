# Production-Ready Claude Watch: Comprehensive Plan

## Problem Statement

The user wants to use Claude Watch on their **physical Apple Watch outdoors** while Claude Code runs on their laptop. The current implementation has critical gaps that prevent this workflow.

## Current State Assessment

| Component | Status | Works? |
|-----------|--------|--------|
| Pairing Flow | Watch displays code, CLI enters | YES (DONE) |
| Cloud Relay | Messages queue in KV, polling works | YES |
| Watch Receives Requests | Only if app is foregrounded | PARTIAL |
| Push Notifications (APNs) | **NOT IMPLEMENTED** | NO |
| Claude Code Integration | MCP tools are opt-in, not automatic | NO |
| Session Persistence | 24h TTL, no refresh | NO |
| Post-Reboot Polling | Doesn't auto-start | NO |

## Critical Finding

**The fundamental issue**: Claude Code's native permission prompts (terminal Y/n) don't automatically route through the watch. The MCP tools (`watch_request_approval`) exist and work, but Claude must be **explicitly told** to use them. There's no hook into Claude Code's native approval flow.

---

## Phase 1: Make Polling Reliable (Quick Wins)

**Goal**: Fix reliability issues so paired watches work correctly with app open.

### 1.1 Auto-Start Polling on App Launch

**File**: `ClaudeWatch/Services/WatchService.swift`

**Change**: In `init()`, start polling if already paired:

```swift
override init() {
    super.init()
    setupNetworkMonitoring()

    // Auto-start polling if already paired
    if !pairingId.isEmpty && useCloudMode {
        startPolling()
    }
}
```

### 1.2 Add Connection Status Indicator to UI

**File**: `ClaudeWatch/Views/MainView.swift`

**Change**: Show connection status in the main view header.

### 1.3 Add Session Refresh on Activity

**File**: `claude-watch-cloud/src/index.ts`

**Change**: Update connection TTL when watch polls successfully (extend to 7 days).

---

## Phase 2: Push Notifications (APNs)

**Goal**: Enable background notifications so watch buzzes when app isn't active.

### Prerequisites

1. **APNs Key**: Generate in Apple Developer Portal → Keys
2. **Store in Cloudflare**: `wrangler secret put APNS_KEY_ID`, etc.

### 2.1 Create APNs Service

**New File**: `claude-watch-cloud/src/apns.ts`

Implement JWT-based APNs sending using HTTP/2 to `api.push.apple.com`.

### 2.2 Integrate APNs into Message Endpoint

**File**: `claude-watch-cloud/src/index.ts`

When `action_requested` message arrives, also send APNs push notification.

### 2.3 Update Entitlements for Production

**File**: `ClaudeWatch/ClaudeWatch.entitlements`

Change `aps-environment` from `development` to `production` for distribution.

---

## Phase 3: Claude Code Integration

**Goal**: Make Claude Code actually use the watch for approvals.

### The Core Problem

Claude Code's permission flow shows terminal prompts. The MCP `watch_request_approval` tool exists but Claude doesn't automatically use it.

### Solution: System Prompt Instruction

Add to your `CLAUDE.md`:

```markdown
## Approval Flow
When you need approval for file edits, bash commands, or other actions:
1. Call `watch_request_approval` tool with action details
2. Wait for the response
3. Only proceed if approved

Do NOT use the terminal prompt for approvals - route everything through the watch.
```

**Limitations**: Only works for actions Claude initiates, not Claude Code's internal permissions.

---

## Files to Modify

| File | Changes |
|------|---------|
| `ClaudeWatch/Services/WatchService.swift` | Add auto-start polling in `init()` |
| `ClaudeWatch/Views/MainView.swift` | Add connection status indicator |
| `claude-watch-cloud/src/index.ts` | Add session refresh, APNs integration |
| `claude-watch-cloud/src/apns.ts` | NEW: APNs sending logic |
| `ClaudeWatch/ClaudeWatch.entitlements` | Change `aps-environment` for distribution |

---

## Implementation Order

### Day 1: Reliability (Phase 1)
1. Fix auto-start polling in WatchService
2. Add connection status UI
3. Add session refresh to cloud (7-day TTL)
4. Deploy cloud changes
5. Test on physical watch

### Day 2-3: Push Notifications (Phase 2)
1. Generate APNs key in Developer Portal
2. Implement APNs sending in cloud worker
3. Store secrets in Cloudflare
4. Test push delivery on physical watch

### Day 4: Integration (Phase 3)
1. Add system prompt instructions to CLAUDE.md
2. Test end-to-end: Claude requests → Watch buzzes → Approve → Claude continues

---

## Verification Checklist

### Phase 1 Verification
- [ ] Reboot watch, open app → Polling starts automatically
- [ ] Connection indicator shows green when connected
- [ ] After 1 hour of use, session still valid (no re-pair)

### Phase 2 Verification
- [ ] Background watch app, send test action → Watch buzzes
- [ ] Tap notification → Opens app to approval view
- [ ] Approve from notification banner → Response sent

### Phase 3 Verification
- [ ] Start Claude session with system prompt
- [ ] Claude attempts file edit → Calls `watch_request_approval`
- [ ] Watch receives notification
- [ ] Approve on watch → Claude proceeds

### End-to-End Outdoor Test
1. Pair watch with CLI
2. Walk outside with watch (laptop stays home)
3. Trigger Claude action remotely
4. Watch buzzes
5. Approve from wrist
6. Verify action completed

---

## Summary

| Gap | Solution | Effort |
|-----|----------|--------|
| Polling doesn't auto-start | Add to `init()` | 10 min |
| No connection indicator | Add UI element | 15 min |
| 24h session expiry | Add TTL refresh (7 days) | 20 min |
| No push notifications | Implement APNs | 2-3 hours |
| Claude doesn't use watch | System prompt instruction | 10 min |

**Total Effort**: ~4-5 hours for full production readiness

**After Implementation**: You can walk outside, watch buzzes when Claude needs approval, tap to approve, Claude continues - all without touching your laptop.
