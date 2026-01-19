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

### Build Errors
_None documented yet_

### Runtime Errors
_None documented yet_

### Performance Issues
_None documented yet_

## By Component

### ClaudeWatch (watchOS App)
- [Silent push not updating UI](integration-issues/watchos-silent-push-ui-update.md) - `willPresent` vs `didReceiveRemoteNotification`

### MCPServer (Cloudflare Worker)
_None documented yet_

## By Symptom

| Symptom | Solution |
|---------|----------|
| "All Clear" shows when it shouldn't | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| UI not updating after notification | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| `@Published` state change not reflected in view | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |

## Quick Lookups

### TestFlight Preparation
- **APNs not working in TestFlight?** → Check Release entitlements use `production` APNs environment
- **App Store rejection for privacy?** → Add `PrivacyInfo.xcprivacy` with required API declarations
- **Actions disappearing?** → Merge cloud + local state, don't replace (race condition fix)

### watchOS Notifications
- **Silent push (`content-available: 1`)** → Use `didReceiveRemoteNotification`, NOT `willPresent`
- **Visible push (with alert)** → Use `willPresent` delegate

### SwiftUI State
- **New `@Published` property not showing?** → Check ALL view conditions that might hide it (empty states, loading states)

---

_Add new solutions with `/workflows:compound` after fixing issues._
