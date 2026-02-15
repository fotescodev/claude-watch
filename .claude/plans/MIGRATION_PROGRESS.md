# SDK-URL Migration Progress

> **Branch**: `claude/investigate-websocket-terminal-utUEt`
> **Spec**: `.claude/plans/sdk-url-agent-execution-spec.md`
> **Plan**: `.claude/plans/sdk-url-migration-plan.md`
> **Last updated**: 2026-02-15

## Status Overview

| Workstream | Status | Tests |
|------------|--------|-------|
| A: Bridge Server (A1-A8) | DONE | 249 |
| B: Remmy CLI + Cloud Relay (B1-B2) | DONE | 129+46 |
| D: Integration Tests (D1-D6) | DONE | 82 |
| **R: Review Fixes (R1-R4)** | **UP NEXT** | ~10 planned |
| C: Watch App (C1-C2) | BLOCKED on R | — |
| E: New Capabilities (E1-E5) | PENDING | — |
| F: Cleanup (F1-F3) | PENDING | — |
| **Total passing** | | **508** |

---

## Workstream A: Bridge Server — DONE

- [x] A1: NDJSON WebSocket Server (229 lines, 11 tests)
- [x] A2: Message Types & Session State (317+266 lines, 57 tests)
- [x] A3: Permission Handler (177 lines, 21 tests)
- [x] A4: AskUserQuestion Handler (175 lines, 20 tests)
- [x] A5: Progress Tracker (280 lines, 43 tests)
- [x] A6: CLI Launcher (245 lines, 29 tests)
- [x] A7: Watch-Facing REST API (466 lines, 34 tests)
- [x] A8: Bridge Entrypoint (391 lines, 34 tests)

## Workstream B: Remmy CLI — DONE

- [x] B1: Launch Bridge + CLI (9 tasks, 129 tests, ~4,600 lines)
- [x] B2: Cloud Worker Relay (cloud_client.py + main.py integration, 46 tests)

## Workstream D: Integration Tests — DONE

- [x] D1: End-to-End Approval Flow (11 tests)
- [x] D2: End-to-End Question Flow (5 tests)
- [x] D3: End-to-End Progress Flow (4 tests)
- [x] D4: End-to-End Interrupt Flow (6 tests)
- [x] D5: CLI Launcher Integration (15 tests)
- [x] D6: Regression Test Against Current Watch API Contract (41 tests)

---

## Workstream R: Review Fixes — UP NEXT

> 3-specialist review (QA, Dev, Integration) on 2026-02-14 identified 18 findings.
> Detailed fix descriptions with code snippets: `.claude/plans/REVIEW_FINDINGS.md`

### Phase 1: Must Fix Before C1 — CRITICAL

These are correctness and security bugs. Gate for C1 watch verification.

- [ ] **R1: Double-resolution race condition** — CRITICAL
  - Files: `main.py` (`_cloud_poll_once`), `api.py`
  - Both REST API and cloud poll can resolve same permission simultaneously
  - Fix: check-before-resolve guard in `_cloud_poll_once`
  - Tests: E2E test for concurrent resolution

- [ ] **R2: Interrupt poll fires repeatedly** — CRITICAL
  - File: `main.py` (`_cloud_poll_once`)
  - No rising-edge detection; sends interrupt every 2s indefinitely
  - Fix: track `_last_interrupt_state` per session, fire only on false→true
  - Tests: E2E verifying single interrupt even when cloud keeps returning true

- [ ] **R3: No session cleanup on bridge stop** — CRITICAL
  - File: `main.py` (`stop()`), `cloud_client.py`
  - Watch shows ghost session for ~5 min after bridge dies
  - Fix: add `push_session_end()` to CloudClient, call from `stop()`
  - Tests: unit test for push_session_end, E2E for session-end on stop

- [ ] **R4: Servers bind to 0.0.0.0** — CRITICAL
  - Files: `ndjson_server.py`, `main.py`
  - Anyone on LAN can connect and approve/reject tool calls
  - Fix: bind to `127.0.0.1` (localhost only)
  - Tests: update existing startup tests to verify bind address

### Phase 2: Fix Before Real Usage — HIGH/MEDIUM

Won't block C1 but must be fixed before anyone relies on this.

- [ ] R5: Cloud KV TTL expires mid-session (5 min TTL, long tool calls) — HIGH
- [ ] R6: Interrupt from REST + cloud without coordination — HIGH
- [ ] R7: Permission marked resolved before WS send confirmed — HIGH
- [ ] R8: Missing `cloudUrl` test coverage in CLI — MEDIUM
- [ ] R9: Debounce logic (`_cloud_push_progress_debounced`) not tested — MEDIUM
- [ ] R10: No health heartbeat to cloud — MEDIUM

### Phase 3: Hardening — LOW

Pre-production polish.

- [ ] R11: No auth on REST API — LOW for MVP
- [ ] R12: No auth on WebSocket — LOW for MVP
- [ ] R13: Missing retry backoff jitter in cloud_client.py — LOW
- [ ] R14: Unused imports in main.py (`json`, `sys`) — LOW
- [ ] R15: Port detection uses HTTP fetch instead of TCP — LOW
- [ ] R16: CLI SIGINT handler registered twice — LOW
- [ ] R17: No connectivity retry on initial pairing — LOW
- [ ] R18: Interrupt state not persisted across restart — LOW

---

## Workstream C: Watch App — BLOCKED on R Phase 1

- [ ] C1: Zero Changes for MVP — verify watch works against bridge REST API
- [ ] C2: Direct WebSocket (Post-MVP)

## Workstream E: New Capabilities — PENDING

- [ ] E1: Permission Learning ("Always Allow" Button)
- [ ] E2: Model Switching from Watch
- [ ] E3: Real-Time Streaming
- [ ] E4: Session Resume on Crash
- [ ] E5: File Undo from Watch

## Workstream F: Cleanup — PENDING

- [ ] F1: Remove Legacy Hooks
- [ ] F2: Remove Cloud Worker Approval Endpoints
- [ ] F3: Remove Temp Files & Config

---

## Quality Reviews (A1-A8)

| Task | Rating | Tests | Notes |
|------|--------|-------|-------|
| A1: NDJSON Server | 9/10 | 11/11 | Clean async server, proper error handling, keep_alive filtering |
| A2: Types & Session | 8/10 | 57/57 | All message types covered, camelCase conversion works |
| A3: Permissions | 9/10 | 21/21 | Approve/deny/approve_all correct, updatedInput passthrough |
| A4: Questions | 9/10 | 20/20 | Recommendation extraction, multi-question support |
| A5: Progress | 8/10 | 43/43 | TodoWrite extraction, context %, compaction lifecycle |
| A6: CLI Launcher | 8/10 | 29/29 | Async subprocess, SIGTERM->SIGKILL escalation, --resume |
| A7: Watch REST API | 9/10 | 34/34 | Full cloud worker contract match |
| A8: Bridge Entrypoint | 9/10 | 34/34 | Clean wiring, initialize control_request, auto-accept routing |

## Execution Timeline

```
WEEK 1: Foundation (DONE)
  A1-A5 (NDJSON server + types + permissions + questions + progress)

WEEK 2: Integration (DONE)
  A6-A8 (CLI launcher + REST API + entrypoint)
  D6 (API compatibility regression)

WEEK 3: CLI + E2E (DONE)
  B1 (remmy-cli launches bridge)
  B2 (cloud relay sync)
  D1-D5 (E2E integration tests)
  3-specialist review → 18 findings

WEEK 4: Review Fixes + Watch Verification (CURRENT)
  R1-R4 (Phase 1 critical fixes — gate for C1)
  C1 (verify watch works with zero changes)
  R5-R10 (Phase 2 fixes if time allows)

WEEK 5: New Capabilities
  E1-E5 (permission learning, model switch, streaming, resume, undo)

WEEK 6: Cleanup + Hardening
  R11-R18 (Phase 3 hardening)
  F1-F3 (remove hooks, cloud endpoints, temp files)
  C2 (optional: direct WebSocket from watch)
```

## Commits

| Commit | Description | Tasks |
|--------|-------------|-------|
| `2198da5` | research: analyze --sdk-url WebSocket protocol | Research |
| `8183c66` | plan: comprehensive migration with feature parity matrix | Planning |
| `d6d354d` | spec: agent-executable migration with AC and tests | Spec |
| `970ab13` | feat(bridge): implement A1-A5 | A1-A5 |
| `fc687c7` | feat(bridge): implement A6-A8 | A6-A8 |
| `daf41b1` | feat: scaffold remmy-watch CLI + bridge auto-registration fix | B1 scaffold |
| `ca784b8` | feat(remmy-cli): implement all CLI commands with 129 tests | B1 |
| `fc33a6d` | feat(bridge): add Workstream D integration tests — 82 E2E | D1-D6 |
| `1b10084` | feat(bridge): add cloud relay sync — B2 complete, 379 tests | B2 |
| `e04e805` | docs: update migration progress — B2 cloud relay complete | Docs |
| `1aa3491` | docs: add review findings and fix plan | Review |

## Test Commands

```bash
# Bridge tests (379)
python -m pytest MCPServer/bridge/tests/ -q

# Bridge unit only (297)
python -m pytest MCPServer/bridge/tests/ -q --ignore=MCPServer/bridge/tests/test_e2e_*

# Bridge E2E only (82)
python -m pytest MCPServer/bridge/tests/test_e2e_* -q

# CLI tests (129) — must split due to bun mock.module() bleed
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/
```

## Key Learnings

1. `--sdk-url` is undocumented Claude CLI flag enabling NDJSON-over-WebSocket control
2. `can_use_tool` fires for ALL tool calls including `AskUserQuestion` — fixes Phase 10 stdin issue
3. `updatedInput` in control_response modifies tool inputs before execution
4. `appendSystemPrompt` in initialize injects watch-mode instructions
5. Bridge REST API matches cloud worker contract exactly — zero watch changes for MVP
6. `reuse_address=True` needed on both WS and HTTP servers to prevent test port collisions
7. Bun `mock.module()` bleeds across files — must run lib and command tests separately
