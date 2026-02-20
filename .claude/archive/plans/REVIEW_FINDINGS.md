# SDK-URL Migration — Review Findings & Fix Plan

> **Date**: 2026-02-14
> **Scope**: Workstreams A (Bridge), B (CLI + Cloud Relay), D (E2E Tests)
> **Tests**: 508 total (379 bridge + 129 CLI)
> **Branch**: `claude/investigate-websocket-terminal-utUEt`

## Summary

Three-specialist review (QA, Dev, Integration) of all completed work.
18 findings across 4 severity levels. Fixes organized into 3 phases.

---

## Phase 1: Must Fix Before C1 (Watch Verification)

These are correctness bugs that will cause problems during live watch testing.

### 1. Double-Resolution Race Condition — CRITICAL

**File**: `MCPServer/bridge/main.py` (`_cloud_poll_once` + `api.py` REST endpoints)

**Problem**: Both the REST API (local watch via HTTP) and the cloud poll loop can resolve the same permission simultaneously. If the watch approves locally AND the cloud poll fires at the same time, `approve_permission()` is called twice — the second call sends a duplicate `control_response` to the CLI.

**Fix**: Add a check-before-resolve guard in `_cloud_poll_once`. Before calling `approve_permission()` or `deny_permission()`, verify the permission is still pending:
```python
perm = session.get_pending_permission(request_id)
if perm is None:
    continue  # Already resolved by REST API
```

**Tests to add**: E2E test where REST API resolves permission while cloud poll is also trying.

### 2. Interrupt Poll Fires Repeatedly — CRITICAL

**File**: `MCPServer/bridge/main.py` (`_cloud_poll_once`)

**Problem**: The cloud poll checks `poll_interrupt_state()` every 2 seconds. If the cloud returns `{"interrupted": true}`, the bridge sends an interrupt `control_request` to the CLI every 2 seconds indefinitely. There's no state tracking for "already sent this interrupt."

**Fix**: Track last-seen interrupt state per session. Only send interrupt on rising edge (false → true):
```python
# In Bridge.__init__:
self._last_interrupt_state: dict[str, bool] = {}

# In _cloud_poll_once:
state = await self._cloud_client.poll_interrupt_state()
was_interrupted = self._last_interrupt_state.get(session_id, False)
if state["interrupted"] and not was_interrupted:
    # Send interrupt to CLI
    ...
self._last_interrupt_state[session_id] = state["interrupted"]
```

**Tests to add**: E2E test verifying only one interrupt is sent even when cloud keeps returning `interrupted=true`.

### 3. Session Cleanup on Bridge Stop — CRITICAL

**File**: `MCPServer/bridge/main.py` (`stop()`)

**Problem**: When the bridge shuts down (SIGTERM, crash, user Ctrl+C), it doesn't notify the cloud. The watch keeps showing "Session Active" until the cloud KV entry expires (5 minutes). The user gets a ghost session.

**Fix**: In `stop()`, push a session-end event to cloud before closing:
```python
async def stop(self):
    if self._cloud_client and self._cloud_client.is_enabled:
        await self._cloud_client.push_session_end()
    # ... existing cleanup
```

Add `push_session_end()` to `CloudClient`:
```python
async def push_session_end(self) -> bool:
    return await self._post("/session-end", {"pairingId": self.pairing_id})
```

**Tests to add**: Unit test for `push_session_end()`, E2E test verifying cloud receives session-end on bridge stop.

### 4. Bind to Localhost — CRITICAL

**File**: `MCPServer/bridge/ndjson_server.py` + `MCPServer/bridge/main.py`

**Problem**: Both WebSocket and HTTP servers bind to `0.0.0.0` by default. Anyone on the local network can connect and approve/reject tool calls without authentication.

**Fix**: Change bind address to `127.0.0.1` (localhost only):
```python
# ndjson_server.py
self._server = await websockets.serve(..., host="127.0.0.1", ...)

# main.py (TCPSite)
site = web.TCPSite(runner, "127.0.0.1", self._http_port, ...)
```

**Tests to add**: Verify servers bind to localhost in existing startup tests.

---

## Phase 2: Fix Before Real Usage

These won't block C1 testing but should be fixed before anyone actually uses this.

### 5. Cloud KV TTL Can Expire Mid-Session — HIGH

**Problem**: Cloud worker stores data with 300s (5 min) TTL. Long tool calls (e.g., a 10-minute build) can cause the approval request to expire on cloud before the watch even sees it.

**Fix**: Bridge should periodically refresh cloud state. Add a TTL-refresh push in the poll loop — every ~60s re-push active approvals and progress.

### 6. Interrupt State From Two Locations — HIGH

**File**: `MCPServer/bridge/api.py` (REST `/interrupt`) + `MCPServer/bridge/main.py` (cloud poll)

**Problem**: Interrupt can arrive from both local REST API and cloud poll. No coordination between the two paths.

**Fix**: Centralize interrupt handling in a single method on Bridge that both paths call. Add a "last interrupt sent" timestamp to debounce.

### 7. Permission Resolved Before WS Send Confirmed — HIGH

**File**: `MCPServer/bridge/permissions.py` + `main.py`

**Problem**: `approve_permission()` marks the permission as resolved in session state, then sends the `control_response` to the CLI over WebSocket. If the WebSocket send fails, the permission is "resolved" but the CLI never got the response.

**Fix**: Only mark resolved after confirmed WebSocket send. Or add a retry mechanism for failed sends.

### 8. Missing `cloudUrl` Test Coverage — MEDIUM

**File**: `remmy-cli/src/commands/default.ts`, `run.ts`

**Problem**: The `cloudUrl` passthrough to `launchBridge()` is not tested in the CLI test suite. If `getCloudUrl()` returns undefined, it silently launches without cloud sync.

**Fix**: Add tests for `default` and `run` commands verifying cloudUrl is passed to launchBridge.

### 9. Debounce Logic Not Tested — MEDIUM

**File**: `MCPServer/bridge/main.py` (`_cloud_push_progress_debounced`)

**Problem**: The 5-second debounce on tool_progress pushes is implemented but not directly tested.

**Fix**: Add a test that sends multiple tool_progress events rapidly and verifies only one cloud push happens.

### 10. No Health/Heartbeat to Cloud — MEDIUM

**Problem**: Bridge has no heartbeat to cloud. If the bridge crashes silently, the cloud and watch don't know until the next poll fails or KV expires.

**Fix**: Add periodic heartbeat push to cloud (every 30s). Cloud worker could expose a `/heartbeat` endpoint that refreshes session TTL.

---

## Phase 3: Hardening (Pre-Production)

### 11. No Authentication on REST API — LOW for MVP

**Problem**: Anyone who discovers the pairing ID can approve/reject tools via REST.

**Fix**: Add a shared secret (generated during pairing) that must be sent as `Authorization: Bearer <token>` on all REST and WebSocket connections.

### 12. No Authentication on WebSocket — LOW for MVP

**Problem**: Any process can connect to the WebSocket with any session_id.

**Fix**: Same shared secret approach as #11. Or use a one-time token generated by the bridge at startup.

### 13. Missing Retry Backoff Jitter — LOW

**File**: `MCPServer/bridge/cloud_client.py`

**Problem**: Retry delay is `retry_delay * (attempt + 1)` — linear backoff without jitter. Multiple clients failing simultaneously will thundering-herd.

**Fix**: Add random jitter: `delay * (attempt + 1) + random.uniform(0, delay)`.

### 14. Unused Imports in main.py — LOW

**File**: `MCPServer/bridge/main.py`

**Problem**: `import json` and `import sys` are imported but unused.

**Fix**: Remove them.

### 15. Port Detection Fragile — LOW

**File**: `remmy-cli/src/lib/bridge-launcher.ts` (`isPortBusy`)

**Problem**: Port check uses HTTP fetch which only detects HTTP services. A non-HTTP service on the port would be missed.

**Fix**: Use TCP socket connect instead of HTTP fetch for port detection.

### 16-18. Minor Items

- **CLI SIGINT handler registered twice** (`default.ts` + `run.ts` both register)
- **No connectivity retry on initial pairing** (CLI `completePairing` doesn't retry on network failure)
- **Interrupt state not persisted** (bridge restart loses interrupt tracking)

---

## Execution Order

```
PHASE 1 (Before C1 — watch verification):
  #1  Double-resolution guard         ~30 min, 2-3 tests
  #2  Interrupt state tracking         ~30 min, 2-3 tests
  #3  Session cleanup on stop          ~30 min, 2-3 tests
  #4  Bind to localhost                ~15 min, update existing tests

PHASE 2 (Before real usage):
  #5  KV TTL refresh                   ~1 hr, 3-4 tests
  #6  Centralize interrupt handling    ~45 min, 2-3 tests
  #7  Permission send confirmation     ~1 hr, 3-4 tests
  #8  cloudUrl test coverage           ~30 min, 4-6 tests
  #9  Debounce test                    ~15 min, 1-2 tests
  #10 Health heartbeat                 ~1 hr, 3-4 tests

PHASE 3 (Pre-production):
  #11-12 API/WS auth                  ~2 hr, 6-8 tests
  #13-18 Minor fixes                  ~1 hr, misc tests
```

## Current Test Counts (Reference)

| Suite | Tests | Command |
|-------|-------|---------|
| Bridge unit (A1-A8 + B2) | 297 | `python -m pytest MCPServer/bridge/tests/ -q --ignore=MCPServer/bridge/tests/test_e2e_*` |
| Bridge E2E (D1-D6 + cloud sync) | 82 | `python -m pytest MCPServer/bridge/tests/test_e2e_* -q` |
| **Bridge total** | **379** | `python -m pytest MCPServer/bridge/tests/ -q` |
| Remmy CLI | 129 | `cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/` |
| **Grand total** | **508** | |

## Commits (This Migration)

| Commit | Description |
|--------|-------------|
| `e04e805` | docs: update migration progress — B2 cloud relay complete |
| `1b10084` | feat(bridge): add cloud relay sync — B2 complete, 379 tests |
| `fc33a6d` | feat(bridge): add Workstream D integration tests — 82 E2E tests |
| `ca784b8` | feat(remmy-cli): implement all CLI commands with 129 tests passing |
| `daf41b1` | feat: scaffold remmy-watch CLI + bridge auto-registration fix |
| `1c38f19` | docs: session state update |
