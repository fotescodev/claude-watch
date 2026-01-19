# Documented Solutions

Quick reference for previously solved problems. **Check here before debugging.**

## By Category

### TestFlight / App Store
| Problem | File | Severity |
|---------|------|----------|
| TestFlight preparation issues and prevention | [testflight-prevention-guide.md](testflight-preparation/testflight-prevention-guide.md) | Critical |

### Integration Issues
| Problem | File | Severity |
|---------|------|----------|
| Silent push notifications not updating watch UI | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) | High |
| Multi-session progress conflicts & stale UI state | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) | Medium |

### Build Errors
_None documented yet_

### Runtime Errors
_None documented yet_

### Performance Issues
_None documented yet_

## By Component

### ClaudeWatch (watchOS App)
- [Silent push not updating UI](integration-issues/watchos-silent-push-ui-update.md) - `willPresent` vs `didReceiveRemoteNotification`
- [Multi-session conflicts](integration-issues/multi-session-progress-conflicts.md) - Session isolation, stale progress, empty states

### MCPServer (Cloudflare Worker)
_None documented yet_

## By Symptom

| Symptom | Solution |
|---------|----------|
| "All Clear" shows when it shouldn't | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| UI not updating after notification | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| `@Published` state change not reflected in view | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| Progress stuck at percentage forever | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |
| Wrong session's tasks showing on watch | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |
| Ralph's progress appearing on watch | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |

## Quick Lookups

### TestFlight Preparation
- **APNs not working in TestFlight?** → Check Release entitlements use `production` APNs environment
- **App Store rejection for privacy?** → Add `PrivacyInfo.xcprivacy` with required API declarations
- **Actions disappearing?** → Merge cloud + local state, don't replace (race condition fix)

### watchOS Notifications
- **Silent push (`content-available: 1`)** → Use `didReceiveRemoteNotification`, NOT `willPresent`
- **Visible push (with alert)** → Use `willPresent` delegate

### Multi-Session Issues
- **Ralph's progress on watch?** → Check `CLAUDE_WATCH_SESSION_ACTIVE` env var not set for Ralph
- **Progress stuck forever?** → Auto-clears after 60s; force quit to reset immediately
- **Multiple sessions fighting?** → Only one session should have `CLAUDE_WATCH_SESSION_ACTIVE=1`

### SwiftUI State
- **New `@Published` property not showing?** → Check ALL view conditions that might hide it (empty states, loading states)

---

_Add new solutions with `/workflows:compound` after fixing issues._
