# Claude Watch - Complete Data Flow Reference

> **Purpose**: Definitive reference for all API endpoints, data flows, and test coverage.
> **When debugging**: Follow the trace from source → cloud → destination. Check test coverage.

---

## System Architecture

### Current (Hooks-Based Architecture)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      CLAUDE WATCH SYSTEM (Hooks-Based)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   ┌─────────────────┐      ┌──────────────────────┐      ┌─────────────────┐   │
│   │   MAC (CLI)     │      │   CLOUD SERVER       │      │  APPLE WATCH    │   │
│   │                 │      │   (Cloudflare)       │      │                 │   │
│   │  ┌───────────┐  │      │                      │      │  ┌───────────┐  │   │
│   │  │ remmy-cli │──┼─────▶│  /pair/complete      │◀─────┼──│ Pair View │  │   │
│   │  │           │  │      │  /pair/initiate      │      │  └───────────┘  │   │
│   │  └───────────┘  │      │  /pair/status/:id    │      │                 │   │
│   │       │         │      │                      │      │  ┌───────────┐  │   │
│   │  installs hook  │      │  ┌────────────────┐  │      │  │ MainView  │  │   │
│   │       ▼         │      │  │ /approval      │──┼─APNs─┼─▶│ Actions   │  │   │
│   │  ┌───────────┐  │      │  │ /approval/:id  │◀─┼──────┼──│ List      │  │   │
│   │  │ PreToolUse│──┼─────▶│  └────────────────┘  │      │  └───────────┘  │   │
│   │  │ Hook      │  │      │                      │      │        │        │   │
│   │  └───────────┘  │      │  ┌────────────────┐  │      │        │ polls  │   │
│   │       │         │      │  │ /approval-queue│◀─┼──────┼────────┘        │   │
│   │       │ polls   │      │  │ /:pairingId    │  │      │                 │   │
│   │       ▼         │      │  └────────────────┘  │      │                 │   │
│   │  ┌───────────┐  │      │                      │      │                 │   │
│   │  │ /approval/│◀─┼──────┼──(poll for response) │      │                 │   │
│   │  │ {pid}/{id}│  │      │                      │      │  ┌───────────┐  │   │
│   │  └───────────┘  │      │  ┌────────────────┐  │      │  │ Progress  │  │   │
│   │                 │      │  │ /session-      │──┼──────┼─▶│ View      │  │   │
│   │  ┌───────────┐  │      │  │   progress     │  │      │  └───────────┘  │   │
│   │  │  claude   │  │      │  └────────────────┘  │      │                 │   │
│   │  │  (native  │  │      │                      │      │                 │   │
│   │  │   TUI)    │  │      │                      │      │                 │   │
│   │  └───────────┘  │      │                      │      │                 │   │
│   └─────────────────┘      └──────────────────────┘      └─────────────────┘   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Key Design Decisions:**
- `remmy-cli` installs hook to `~/.claude/hooks/` and registers in `~/.claude/settings.json`
- Hook talks **directly** to cloud worker (no intermediary)
- Claude runs with its **native TUI** (no `--sdk-url`, no custom UI)
- Session isolation via `CLAUDE_WATCH_SESSION_ACTIVE=1` env var
- Watch continues polling cloud worker (same endpoints, same payloads)

---

### Advanced (Bridge Architecture)

> **Status**: Battle-tested with 346+ Python tests. Available for advanced use cases
> requiring multi-option questions, exact token tracking, or real-time streaming.
> See `ARCHITECTURE.md` for bridge component details.

---

## Complete Endpoint Reference

### Cloud Server: `https://claude-watch.fotescodev.workers.dev`

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/health` | GET | Any | Health check | - | `{"status":"ok"}` | `test-hooks.py` |

#### Pairing Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/pair/initiate` | POST | Watch | Watch requests pairing code | `{deviceToken, publicKey?}` | `{code, watchId}` | **MISSING** |
| `/pair/status/:watchId` | GET | Watch | Poll for pairing completion | - | `{paired, pairingId?, cliPublicKey?}` | **MISSING** |
| `/pair/complete` | POST | CLI | CLI submits code from watch | `{code, deviceToken?, publicKey?}` | `{pairingId, watchPublicKey?}` | **MISSING** |
| `/api/pairing/register` | POST | CLI (legacy) | Register CLI-generated code | `{code, sessionId}` | `{success:true}` | `test-hooks.py` |
| `/api/pairing/check` | GET | CLI (legacy) | Poll for watch completion | `?sessionId=...` | `{paired, pairingId?}` | `test-hooks.py` |
| `/api/pairing/cleanup` | POST | CLI | Cleanup expired session | `{sessionId}` | `{success:true}` | **MISSING** |

#### Approval Flow Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/approval` | POST | Hook | Create approval request | `{pairingId, id, type, title, description?, filePath?, command?}` | `{success:true, requestId}` | `test-hooks.py` |
| `/approval/:requestId` | POST | Watch | Submit approval decision | `{pairingId, approved}` | `{success:true}` | `test-hooks.py` |
| `/approval/:pairingId/:requestId` | GET | Hook | Poll for approval status | - | `{status: 'pending'|'approved'|'rejected'}` | **MISSING** |
| `/approval-queue/:pairingId` | GET | Watch | Get pending approvals | - | `{requests:[], totalCount}` | `test-hooks.py` |
| `/approval-queue/:pairingId` | DELETE | Watch | Clear approval queue | - | `{success:true}` | **MISSING** |

#### Question Flow Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/question` | POST | Hook | Create question | `{pairingId, question, header?, options[], multiSelect}` | `{questionId}` | `test-hooks.py` |
| `/question/:questionId` | GET | Hook | Poll for answer | - | `{status, selectedIndices?}` | `test-hooks.py` |
| `/question/:questionId/answer` | POST | Watch | Submit answer | `{selectedIndices?[], skipped?}` | `{success:true}` | `test-hooks.py` |
| `/questions/:pairingId` | GET | Watch | Get pending questions | - | `{questions:[]}` | `test-hooks.py` |

#### Session Progress Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/session-progress` | POST | Hook | Post progress update | `{pairingId, currentTask?, progress, completedCount, totalCount, tasks[]}` | `{success:true}` | `test-hooks.py` |
| `/session-progress/:pairingId` | GET | Watch | Get progress | - | `{progress:{...}}` | `test-hooks.py` |

#### Session Control Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/session-end` | POST | Watch | End session | `{pairingId}` | `{success:true}` | **MISSING** |
| `/session-status/:pairingId` | GET | Hook | Check if session active | - | `{sessionActive:boolean}` | **MISSING** |
| `/session-interrupt` | POST | Watch | Pause/resume session | `{pairingId, action:'stop'|'resume'|'clear'}` | `{interrupted:boolean}` | **MISSING** |
| `/session-interrupt/:pairingId` | GET | Hook | Check interrupt state | - | `{interrupted:boolean, action?}` | **MISSING** |

#### Legacy/Message Endpoints

| Endpoint | Method | Source | Purpose | Request Body | Response | Tests |
|----------|--------|--------|---------|--------------|----------|-------|
| `/api/message` | POST | MCP | Send message to watch | `{pairingId, type, payload}` | `{success:true}` | **MISSING** |
| `/api/messages` | GET | Watch/MCP | Poll messages | `?pairingId=...&direction=to_watch|to_server` | `{messages:[]}` | **MISSING** |
| `/respond/:requestId` | POST | Watch | Legacy approval response | `{approved, pairingId}` | `{success:true}` | **MISSING** |
| `/requests/:pairingId` | GET | Watch | Legacy get pending | - | `{requests:[]}` | **MISSING** |

---

## Data Flow Traces

### Flow 1: Pairing (Watch-Initiated - Current)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PAIRING FLOW (Watch initiates, CLI completes)                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   WATCH                           CLOUD                           CLI           │
│     │                               │                              │            │
│  1. │──POST /pair/initiate─────────▶│                              │            │
│     │  {deviceToken, publicKey}     │                              │            │
│     │◀─{code:"123456", watchId}─────│                              │            │
│     │                               │                              │            │
│  2. │ [Display code "123456"]       │                              │            │
│     │                               │                              │            │
│  3. │──GET /pair/status/:watchId───▶│                              │            │
│     │◀─{paired:false}───────────────│                              │            │
│     │         (polling)             │                              │            │
│     │                               │                              │            │
│     │                               │◀─POST /pair/complete─────────│ 4.         │
│     │                               │  {code:"123456", publicKey}  │            │
│     │                               │─{pairingId, watchPublicKey}─▶│            │
│     │                               │                              │            │
│  5. │──GET /pair/status/:watchId───▶│                              │            │
│     │◀─{paired:true, pairingId,────-│                              │            │
│     │   cliPublicKey}               │                              │            │
│     │                               │                              │            │
│  6. │ [Store pairingId, start       │                              │            │
│     │  polling for requests]        │                              │            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

TEST COVERAGE: NONE - No E2E test exists for this flow!
FILE LOCATIONS:
  - Watch: WatchService.swift:843-925 (initiatePairing, checkPairingStatus)
  - Cloud: index.ts:158-262 (/pair/initiate, /pair/status, /pair/complete)
  - CLI (legacy): cc-watch.ts:159-218 (runPairing → POST /pair/complete)
  - CLI (current): remmy-cli/src/commands/setup.ts (pairing flow)
```

### Flow 2a: Tool Approval (Hook-Based — Current)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ APPROVAL FLOW (Hook-Based — Current)                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   HOOK                            CLOUD                           WATCH         │
│     │                               │                              │            │
│  1. │──POST /approval──────────────▶│                              │            │
│     │  {pairingId, id, type,        │                              │            │
│     │   title, description}         │                              │            │
│     │◀─{success:true, requestId}────│                              │            │
│     │                               │                              │            │
│  2. │ [Send simctl push to sim]     │                              │            │
│     │ (xcrun simctl push...)        │──────[APNs push]────────────▶│ (real)     │
│     │                               │                              │            │
│     │                               │◀─GET /approval-queue/:pid────│ 3.         │
│     │                               │─{requests:[...]}────────────▶│            │
│     │                               │                              │            │
│  4. │──GET /approval/:pid/:rid─────▶│                              │            │
│     │◀─{status:"pending"}───────────│                              │            │
│     │         (polling)             │                              │            │
│     │                               │                              │            │
│     │                               │◀─POST /approval/:rid─────────│ 5.         │
│     │                               │  {pairingId, approved:true}  │            │
│     │                               │─{success:true}──────────────▶│            │
│     │                               │                              │            │
│  6. │──GET /approval/:pid/:rid─────▶│                              │            │
│     │◀─{status:"approved"}──────────│                              │            │
│     │                               │                              │            │
│  7. │ [Return allow to Claude]      │                              │            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

TEST COVERAGE:
  - test-hooks.py: Validates POST /approval, POST /approval/:id endpoints exist
  - test_watch_approval.py: Unit tests for hook logic (map_tool_type, build_title, etc.)
  - MISSING: GET /approval/:pid/:rid (hook polling endpoint)
  - MISSING: E2E test with actual watch interaction

FILE LOCATIONS:
  - Hook: watch-approval-cloud.py:622-642 (create_request → POST /approval)
  - Hook: watch-approval-cloud.py:754-800 (wait_for_response → GET /approval/:pid/:rid)
  - Cloud: index.ts:345-381 (POST /approval)
  - Cloud: index.ts:396-423 (POST /approval/:requestId)
  - Cloud: index.ts:384-393 (GET /approval-queue/:pairingId)
  - Watch: WatchService.swift:1174-1256 (fetchPendingRequests)
  - Watch: WatchService.swift:986-1015 (respondToCloudRequest)
```

### Flow 3a: Question (Hook-Based — Current)

> Watch can only approve/reject, so questions are handled as yes/no via CLAUDE.md constraints.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ QUESTION FLOW (Hook-Based — Current)                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   HOOK                            CLOUD                           WATCH         │
│     │                               │                              │            │
│  1. │──POST /question──────────────▶│                              │            │
│     │  {pairingId, question, header,│                              │            │
│     │   options[], multiSelect}     │                              │            │
│     │◀─{questionId}─────────────────│                              │            │
│     │                               │                              │            │
│  2. │ [Send simctl push]            │                              │            │
│     │                               │                              │            │
│     │                               │◀─GET /questions/:pid─────────│ 3.         │
│     │                               │─{questions:[...]}───────────▶│            │
│     │                               │                              │            │
│  4. │──GET /question/:qid──────────▶│                              │            │
│     │◀─{status:"pending"}───────────│                              │            │
│     │         (polling)             │                              │            │
│     │                               │                              │            │
│     │                               │◀─POST /question/:qid/answer──│ 5.         │
│     │                               │  {selectedIndices:[0]}       │            │
│     │                               │─{success:true}──────────────▶│            │
│     │                               │                              │            │
│  6. │──GET /question/:qid──────────▶│                              │            │
│     │◀─{status:"answered",          │                              │            │
│     │   selectedIndices:[0]}────────│                              │            │
│     │                               │                              │            │
│  7. │ [Return answer to Claude]     │                              │            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

TEST COVERAGE:
  - test-hooks.py: E2E flow test (create → poll → answer → verify)
  - MISSING: stdin-proxy question parsing integration test

FILE LOCATIONS:
  - Hook: watch-approval-cloud.py:195-319 (handle_question)
  - Hook: watch-approval-cloud.py:322-333 (create_question_request)
  - Hook: watch-approval-cloud.py:374-411 (wait_for_question_response)
  - Cloud: index.ts:467-505 (POST /question)
  - Cloud: index.ts:508-521 (GET /question/:id)
  - Cloud: index.ts:524-549 (POST /question/:id/answer)
  - Cloud: index.ts:552-558 (GET /questions/:pairingId)
  - Watch: WatchService.swift:1393-1434 (fetchPendingQuestions)
  - Watch: WatchService.swift:1440-1461 (answerQuestion)
```

### Flow 4a: Session Progress (Hook-Based — Current)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ PROGRESS FLOW (Hook-Based — Current)                                            │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   HOOK                            CLOUD                           WATCH         │
│     │                               │                              │            │
│  1. │──POST /session-progress──────▶│                              │            │
│     │  {pairingId, currentTask,     │                              │            │
│     │   progress, tasks[]}          │                              │            │
│     │◀─{success:true}───────────────│                              │            │
│     │                               │                              │            │
│     │                               │◀─GET /session-progress/:pid──│ 2.         │
│     │                               │─{progress:{...}}────────────▶│            │
│     │                               │         (polling)            │            │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

TEST COVERAGE:
  - test-hooks.py: E2E flow test (post → retrieve)

FILE LOCATIONS:
  - Hook: progress-tracker.py (PostToolUse → POST /session-progress)
  - Cloud: index.ts:565-576 (POST /session-progress)
  - Cloud: index.ts:579-589 (GET /session-progress/:pairingId)
  - Watch: WatchService.swift:1259-1321 (fetchSessionProgress)
```

---

## Critical Gap Analysis

### Missing Endpoints (In Cloud but NOT tested)

| Endpoint | Used By | Risk | Priority |
|----------|---------|------|----------|
| `GET /approval/:pairingId/:requestId` | Hook polling | **HIGH** - Hook won't know approval status | P0 |
| `POST /session-end` | Watch | MEDIUM - Session won't cleanly terminate | P1 |
| `GET /session-status/:pairingId` | Hook | MEDIUM - Hook can't detect ended sessions | P1 |
| `POST /session-interrupt` | Watch | MEDIUM - Pause/resume won't work | P1 |
| `GET /session-interrupt/:pairingId` | Hook | MEDIUM - Hook won't detect paused state | P1 |
| `DELETE /approval-queue/:pairingId` | Watch | LOW - Stale approvals may linger | P2 |

### Previously Missing Endpoints (Now Implemented - 2026-01-21)

All previously missing endpoints have been added to the cloud worker:

| Endpoint | Status | Tests |
|----------|--------|-------|
| `GET /approval/:pairingId/:requestId` | Implemented | `test-hooks.py` E2E |
| `GET /session-status/:pairingId` | Implemented | `test-hooks.py` E2E |
| `GET /session-interrupt/:pairingId` | Implemented | `test-hooks.py` E2E |
| `POST /session-end` | Implemented | `test-hooks.py` E2E |
| `POST /session-interrupt` | Implemented | `test-hooks.py` E2E |

### Test Coverage Matrix

| Component | Unit Tests | Integration Tests | E2E Tests |
|-----------|------------|-------------------|-----------|
| Hook (watch-approval-cloud.py) | `test_watch_approval.py` | - | `test-hooks.py` |
| Cloud (index.ts) | - | `test-hooks.py` | `test-hooks.py` |
| Watch (WatchService.swift) | - | - | Manual via `/test-e2e` |
| CLI (remmy-cli) | `src/lib/*.test.ts` | - | `src/commands/*.test.ts` |
| Hook config (hooks-config.ts) | `hooks-config.test.ts` (14 tests) | - | - |
| Bridge (advanced) | `bridge/tests/` (346 tests) | E2E tests | `test_e2e_*.py` |

**E2E Tests in `test-hooks.py`:**
- Question flow (create → pending → answer → answered)
- Progress flow (post → retrieve)
- Approval flow (create → queue → poll → approve → verified)
- Session control (status → interrupt → resume → end)

---

## Quick Diagnosis Checklist

### "Approval request not appearing on watch"

1. Check hook is receiving tool call:
   ```bash
   tail -f /tmp/claude-watch-hook-debug.log
   ```

2. Check cloud server is receiving request:
   ```bash
   PAIRING_ID=$(cat ~/.claude-watch-pairing)
   curl -s "https://claude-watch.fotescodev.workers.dev/approval-queue/$PAIRING_ID"
   ```

3. Check watch is polling (watch logs):
   - Watch should call `GET /approval-queue/:pairingId` every 2 seconds

### "Approval granted but Claude still waiting"

1. Check the polling endpoint exists:
   ```bash
   PAIRING_ID=$(cat ~/.claude-watch-pairing)
   REQUEST_ID="your-request-id"
   curl -s "https://claude-watch.fotescodev.workers.dev/approval/$PAIRING_ID/$REQUEST_ID"
   ```
   **If 404**: The endpoint doesn't exist! This is the bug.

2. Check hook is polling correct endpoint:
   - Hook calls: `GET /approval/:pairingId/:requestId`
   - But cloud only has: `POST /approval/:requestId`

### "Question not appearing on watch"

1. Check question was created:
   ```bash
   PAIRING_ID=$(cat ~/.claude-watch-pairing)
   curl -s "https://claude-watch.fotescodev.workers.dev/questions/$PAIRING_ID"
   ```

2. Check watch is rendering questions:
   - Watch should display `QuestionView` when `pendingQuestion != nil`

### "Session end not working"

1. Check endpoint exists:
   ```bash
   curl -s -X POST "https://claude-watch.fotescodev.workers.dev/session-end" \
     -H "Content-Type: application/json" \
     -d '{"pairingId":"test"}'
   ```
   **If 404**: Endpoint not implemented in cloud worker.

---

## File Reference

### Current (Hooks-Based Architecture)

| File | Purpose | Key Functions/Endpoints |
|------|---------|------------------------|
| `remmy-cli/hooks/watch-approval-cloud.py` | PreToolUse hook (bundled, installed to ~/.claude/hooks/) | `create_request()`, `wait_for_response()` |
| `remmy-cli/src/lib/hooks-config.ts` | Hook installation + registration | `setupHook()`, `installHookScript()`, `registerHook()` |
| `remmy-cli/src/lib/claude-launcher.ts` | Claude launcher | Spawn Claude with `CLAUDE_WATCH_SESSION_ACTIVE=1` |
| `remmy-cli/src/cli.ts` | CLI entry point | Command router, help, version |
| `remmy-cli/src/commands/default.ts` | Default command | Pair + install hook + launch Claude |
| `remmy-cli/src/commands/run.ts` | Run command | Install hook + launch Claude (requires pairing) |
| `remmy-cli/src/commands/setup.ts` | Setup command | Pairing flow only |
| `ClaudeWatch/Services/WatchService.swift` | Watch service | All cloud API calls, polling |
| `claude-watch-cloud/src/index.ts` | Cloud worker | Pairing, approval relay, progress storage |

### Advanced (Bridge Architecture)

| File | Purpose | Key Functions/Endpoints |
|------|---------|------------------------|
| `MCPServer/bridge/main.py` | Bridge entrypoint | Server startup, session initialization, cleanup |
| `MCPServer/bridge/ndjson_server.py` | WebSocket server | Accept CLI connections, parse NDJSON, dispatch messages |
| `MCPServer/bridge/permissions.py` | Permission handler | `can_use_tool` processing, approve/deny logic |
| `MCPServer/bridge/questions.py` | Question handler | `AskUserQuestion` parsing, recommendation extraction |
| `MCPServer/bridge/progress.py` | Progress tracker | TodoWrite extraction, context %, tool_progress |
| `MCPServer/bridge/api.py` | REST API | `/state`, `/permissions`, `/questions`, `/progress`, `/interrupt` |
| `MCPServer/bridge/cloud_client.py` | Cloud relay | Push data to cloud worker, poll for interrupt |
| `MCPServer/bridge/launcher.py` | CLI launcher | Spawn Claude with `--sdk-url`, lifecycle management |

---

## Test Files

| File | Tests |
|------|-------|
| `.claude/hooks/test-hooks.py` | Cloud endpoint validation, E2E flows |
| `.claude/hooks/test_watch_approval.py` | Hook unit tests |
| `remmy-cli/src/lib/hooks-config.test.ts` | Hook installation + registration (14 tests) |
| `remmy-cli/src/lib/claude-launcher.test.ts` | Claude launcher (env var, args) |
| `remmy-cli/src/commands/*.test.ts` | CLI command tests (20 tests) |
| `MCPServer/bridge/tests/` | Bridge server tests (346 tests) |

---

## Adding New Endpoints Checklist

When adding a new endpoint:

1. [ ] Add route to `claude-watch-cloud/src/index.ts`
2. [ ] Add test to `.claude/hooks/test-hooks.py`
3. [ ] Update this document (`DATA_FLOW.md`)
4. [ ] If hook calls it: Update `watch-approval-cloud.py`
5. [ ] If watch calls it: Update `WatchService.swift`
6. [ ] If CLI calls it: Update relevant `remmy-cli/src/` file

---

## Architecture Status

**Current State (2026-02-19):**
- ✅ **Hooks-based flow is PRIMARY** — `remmy` installs hook, spawns Claude with native TUI
- ✅ Bridge server available as advanced option (346 Python tests passing)
- ✅ CLI implemented (remmy-cli: 143 tests passing)
- ✅ Hook management (install, register, unregister, status check)

**Architecture Pivot (2026-02-19):**
- **FROM**: Bridge-based (`remmy` → bridge → `claude --sdk-url`) with custom TUI
- **TO**: Hooks-based (`remmy` → install hook → `claude` with native TUI)
- **Reason**: Claude Code's native TUI is excellent; the watch only needs a transparent background notification layer via hooks. No intermediary needed.

**What Stayed the Same:**
- Watch UI (MainView, PairingView, ProgressView — zero changes)
- Cloud worker endpoints (hook talks to same endpoints)
- APNs push notifications (delivery mechanism unchanged)
- Pairing flow (watch initiates with code, CLI completes)

---

## Version

Last updated: 2026-02-19
Document version: 3.0 (hooks-based architecture is now primary)
