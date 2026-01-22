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
| COMP5 question proxy architectural failure (codex-review) | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) | Critical |
| Question flow bugs - pairing mismatch, wrong function, missing proxy | [question-flow-prevention-strategies.md](integration-issues/question-flow-prevention-strategies.md) | High |
| E2E tests failing - missing cloud endpoints & wrong API references | [missing-cloud-endpoints-e2e-failure.md](integration-issues/missing-cloud-endpoints-e2e-failure.md) | High |
| Silent push notifications not updating watch UI | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) | High |
| Multi-session progress conflicts & stale UI state | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) | Medium |
| COMP5 question proxy failure (codex-review branch) | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) | Critical |

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
- [Missing cloud endpoints](integration-issues/missing-cloud-endpoints-e2e-failure.md) - Session control endpoints not implemented
- [DATA_FLOW.md](/.claude/DATA_FLOW.md) - Complete API endpoint reference

## By Symptom

| Symptom | Solution |
|---------|----------|
| Questions not showing on watch | [question-flow-prevention-strategies.md](integration-issues/question-flow-prevention-strategies.md) |
| Answers not returning to terminal | [question-flow-prevention-strategies.md](integration-issues/question-flow-prevention-strategies.md) |
| Pairing ID mismatch between simulator/device | [question-flow-prevention-strategies.md](integration-issues/question-flow-prevention-strategies.md) |
| API contract mismatch (CLI vs Cloud) | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |
| CLI hangs forever waiting for answer | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |
| stdin listener conflicts | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |
| E2E test returns 404 | [missing-cloud-endpoints-e2e-failure.md](integration-issues/missing-cloud-endpoints-e2e-failure.md) |
| `/request` endpoint not found | [missing-cloud-endpoints-e2e-failure.md](integration-issues/missing-cloud-endpoints-e2e-failure.md) - Use `/approval` instead |
| Session control endpoints missing | [missing-cloud-endpoints-e2e-failure.md](integration-issues/missing-cloud-endpoints-e2e-failure.md) |
| "All Clear" shows when it shouldn't | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| UI not updating after notification | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| `@Published` state change not reflected in view | [watchos-silent-push-ui-update.md](integration-issues/watchos-silent-push-ui-update.md) |
| Progress stuck at percentage forever | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |
| Wrong session's tasks showing on watch | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |
| Ralph's progress appearing on watch | [multi-session-progress-conflicts.md](integration-issues/multi-session-progress-conflicts.md) |
| Question never reaches watch | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |
| CLI hangs waiting for question answer | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |
| Question ID mismatch between components | [comp5-question-proxy-failure-analysis.md](integration-issues/comp5-question-proxy-failure-analysis.md) |

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

### Question Flow Issues
- **Questions not showing on watch?** → Run via `npx cc-watch`, not `claude` directly
- **Pairing ID mismatch?** → Run: `jq -r '.pairingId' ~/.claude-watch/config.json > ~/.claude-watch-pairing`
- **Wrong function used?** → `handle_question()` for answers, `send_question_notification_only()` for info only
- **Answers not returning?** → Check `CLAUDE_WATCH_PROXY_MODE=1` and stdin-proxy poll loop

### SwiftUI State
- **New `@Published` property not showing?** → Check ALL view conditions that might hide it (empty states, loading states)

### Cloud API / E2E Testing
- **E2E test returns 404?** → Check endpoint names match [DATA_FLOW.md](/.claude/DATA_FLOW.md)
- **Using `/request` endpoint?** → Wrong! Use `/approval` instead
- **Session control not working?** → Endpoints added 2026-01-21, redeploy cloud worker
- **Approval flow hangs?** → Hook polls `GET /approval/:pairingId/:requestId`, verify it exists

### COMP5 / Phase 10 Architecture (Lessons Learned)
- **API contract mismatch?** → Define shared contract FIRST, all components implement to same spec
- **Question ID mismatch?** → CLI generates ID, cloud stores as-is (don't generate new one)
- **CLI hangs forever?** → Add timeouts to ALL promises; never use `new Promise(() => {})`
- **stdin duplicated?** → Single listener with router pattern, not multiple listeners
- **Wrong option selected?** → Use escape sequences (Arrow down + Enter), not text input
- **Full plan?** → See `.claude/plans/phase10-CONTEXT.md`

---

_Add new solutions with `/workflows:compound` after fixing issues._
