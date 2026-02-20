# Architecture & Progress Tracker

> **Branch**: `restructuring`
> **Primary architecture**: Hooks-based (remmy-cli + cloud worker)
> **Secondary**: Bridge-based (MCPServer/bridge/, advanced use cases)
> **Last updated**: 2026-02-20

## Architecture Pivot (2026-02-19)

**FROM**: Bridge-based (`remmy` → bridge → `claude --sdk-url`) with custom Ink TUI
**TO**: Hooks-based (`remmy` → install hook → `claude` with native TUI)

The bridge was over-engineered for MVP. The hook-based approach (proven in `claude-watch-npm`) is simpler: hook talks directly to cloud worker, watch polls cloud worker directly.

## Status Overview

| Workstream | Status | Tests |
|------------|--------|-------|
| A: Bridge Server (A1-A8) | DONE | 249 |
| B: Remmy CLI + Cloud Relay (B1-B2) | DONE | 143+46 |
| D: Integration Tests (D1-D6) | DONE | 82 |
| R: Review Fixes (R1-R4) | DONE | — |
| **T: TUI (Ink)** | **CANCELLED** (hooks pivot) | — |
| **H: Hooks Pivot** | **DONE** | 14 new |
| C: Watch App (C1) | **DONE** | — |
| E: New Capabilities (E1-E5) | PENDING | — |
| F: Cleanup (F1-F3) | **DONE** | — |
| **Total passing** | | **~503** |

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

## Workstream R: Review Fixes — DONE (hooks-relevant items)

> 3-specialist review (QA, Dev, Integration) on 2026-02-14 identified 18 findings.
> Detailed findings archived: `.claude/archive/plans/REVIEW_FINDINGS.md`

### Phase 1: Must Fix Before C1 — DONE

- [x] **R1: Double-resolution race condition** — commit `4470c7d`
- [x] **R2: Interrupt poll fires repeatedly** — commit `0ad5c1e`
- [x] **R3: No session cleanup on bridge stop** — commit `2c1df00`
- [x] **R4: Servers bind to 0.0.0.0** — commit `4a5c8d2`

### Phase 2: Fix Before Real Usage

- [x] **R5: Cloud KV TTL expires mid-session** — fixed: 5min → 1hr, commit `e48b8f4`
- [ ] R6: Interrupt from REST + cloud without coordination — *bridge-only, not hooks-relevant*
- [ ] R7: Permission marked resolved before WS send confirmed — *bridge-only, not hooks-relevant*
- [ ] R8: Missing `cloudUrl` test coverage in CLI — MEDIUM
- [ ] R9: Debounce logic (`_cloud_push_progress_debounced`) not tested — *bridge-only*
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

## Workstream T: TUI (Ink Terminal Interface) — CANCELLED

> **Cancelled 2026-02-19**: Hooks pivot eliminates the need for a custom TUI.
> Claude Code's native TUI is used directly. All TUI code deleted (~1,754 LOC).

---

## Workstream H: Hooks Pivot — DONE

> **Plan**: `.claude/plans/lucky-questing-balloon.md`
> **Branch**: `restructuring`
> **Completed**: 2026-02-19

- [x] **H1: Hook management** — `remmy-cli/src/lib/hooks-config.ts` (14 tests)
- [x] **H2: Hook script** — `remmy-cli/hooks/watch-approval-cloud.py` (ported from claude-watch-npm)
- [x] **H3: Simplify CLI launch** — Remove `--sdk-url`, add `CLAUDE_WATCH_SESSION_ACTIVE=1`
- [x] **H4: Remove TUI code** — Deleted `remmy-cli/src/tui/` (17 files), 6 npm deps
- [x] **H5: Bridge TUI cleanup** — Removed TUI WS endpoint, `tui_clients`, `broadcast_to_tui`
- [x] **H6: Update tests** — 143 CLI tests passing (up from 129), 346 bridge tests passing
- [x] **H7: Settings cleanup** — Removed disabled PreToolUse entry from project settings
- [x] **H8: Documentation** — Updated ARCHITECTURE.md, DATA_FLOW.md, SESSION_STATE.md

---

## Workstream C: Watch App — C1 DONE

- [x] **C1: Watch approval flow verified live** — approvals + questions route through cloud worker, tested in real Claude session (2026-02-20)
- [ ] C2: Direct WebSocket (Post-MVP, bridge path only)

## Workstream E: New Capabilities — PENDING

- [ ] E1: Permission Learning ("Always Allow" Button)
- [ ] E2: Model Switching from Watch
- [ ] E3: Real-Time Streaming
- [ ] E4: Session Resume on Crash
- [ ] E5: File Undo from Watch

## Workstream F: Cleanup — DONE (2026-02-20)

- [x] F1: Remove legacy hooks from `.claude/hooks/` (17 files deleted)
- [x] F2: Remove legacy cloud worker endpoints (6 dead endpoints removed, deployed)
- [x] F3: Remove stale MCP server config, archive SDK-URL docs

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

WEEK 4: Review Fixes + Hooks Pivot (DONE)
  R1-R4 (Phase 1 critical fixes)
  H1-H8 (Hooks pivot — hooks primary, bridge advanced)
  TUI cancelled (not needed with hooks approach)

WEEK 5: Watch Verification + Fixes (DONE)
  C1 (watch approval + questions verified live via hooks)
  R5 (KV TTL fixed: 5min → 1hr)
  F1-F3 (legacy cleanup: hooks, cloud endpoints, config, docs)

WEEK 6: New Capabilities + Hardening (NEXT)
  E1-E5 (permission learning, model switch, streaming, resume, undo)
  R8, R10-R18 (remaining review fixes + hardening)
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
# CLI tests (147) — must split due to bun mock.module() bleed
cd remmy-cli && bun test src/ui/ src/lib/config.test.ts src/lib/cloud-client.test.ts src/lib/claude-launcher.test.ts src/lib/bridge-launcher.test.ts src/cli.test.ts && bun test src/lib/hooks-config.test.ts && bun test src/commands/

# Bridge tests (346)
python -m pytest MCPServer/bridge/tests/ -q

# Bridge unit only
python -m pytest MCPServer/bridge/tests/ -q --ignore=MCPServer/bridge/tests/test_e2e_*

# Bridge E2E only
python -m pytest MCPServer/bridge/tests/test_e2e_* -q
```

## Key Learnings

1. `--sdk-url` is undocumented Claude CLI flag enabling NDJSON-over-WebSocket control
2. `can_use_tool` fires for ALL tool calls including `AskUserQuestion` — fixes Phase 10 stdin issue
3. `updatedInput` in control_response modifies tool inputs before execution
4. `appendSystemPrompt` in initialize injects watch-mode instructions
5. Bridge REST API matches cloud worker contract exactly — zero watch changes for MVP
6. `reuse_address=True` needed on both WS and HTTP servers to prevent test port collisions
7. Bun `mock.module()` bleeds across files — must run lib and command tests separately
