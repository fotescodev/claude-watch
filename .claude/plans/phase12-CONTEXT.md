# Phase 12: Review Fixes + C1 Watch Verification

> **Decision date**: 2026-02-15
> **Tracker**: `.claude/plans/MIGRATION_PROGRESS.md` (single source of truth)
> **Detailed fix descriptions**: `.claude/plans/REVIEW_FINDINGS.md`

## Goal

Fix 4 critical bugs (R1-R4) then verify the watch works against the bridge (C1).

## Execution Order

Do these sequentially. Run tests after each fix. Commit atomically.

### Step 1: Bind to localhost (R4) — ~15 min

**Why first**: Smallest change, immediate security win, no dependencies.

- `ndjson_server.py`: change `host` param to `"127.0.0.1"`
- `main.py` (TCPSite): change bind to `"127.0.0.1"`
- Update existing startup tests to assert bind address

### Step 2: Double-resolution race guard (R1) — ~30 min

**Why second**: Core correctness, affects the most common user flow.

- `main.py` (`_cloud_poll_once`): before calling `approve_permission()` / `deny_permission()`, check `session.get_pending_permission(request_id)` returns non-None
- Add 2-3 E2E tests: REST resolves while cloud poll is also trying

### Step 3: Interrupt rising-edge detection (R2) — ~30 min

- `main.py` (`__init__`): add `self._last_interrupt_state: dict[str, bool] = {}`
- `main.py` (`_cloud_poll_once`): only send interrupt on `false → true` transition
- Add 2-3 tests: repeated `interrupted=true` from cloud only sends one interrupt

### Step 4: Session cleanup on stop (R3) — ~30 min

- `cloud_client.py`: add `push_session_end()` method
- `main.py` (`stop()`): call `push_session_end()` before existing cleanup
- Add 2-3 tests: unit for push_session_end, E2E for session-end on bridge stop

### Step 5: C1 — Live watch verification

**Requires physical watch.** Deploy bridge + CLI on Mac, pair with watch, verify:
- Permission approval flow works
- Question answering works
- Progress updates show on watch
- Interrupt from watch reaches CLI
- Session end cleans up on watch

## Pre-flight

Before starting R1-R4:
```bash
# Confirm green baseline (508 tests)
python -m pytest MCPServer/bridge/tests/ -q
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/
```

## Decision: Phase 2 timing

After C1, choose:
- **If C1 passes cleanly**: proceed to E1-E5 (new capabilities), do Phase 2 fixes (R5-R10) in parallel
- **If C1 surfaces issues**: fix those first, then Phase 2

## Files That Will Change

| File | Changes |
|------|---------|
| `MCPServer/bridge/ndjson_server.py` | Bind address → 127.0.0.1 |
| `MCPServer/bridge/main.py` | Bind address, race guard, interrupt tracking, session cleanup |
| `MCPServer/bridge/cloud_client.py` | Add `push_session_end()` |
| `MCPServer/bridge/tests/test_e2e_*.py` | New E2E tests for R1, R2, R3 |
| `MCPServer/bridge/tests/test_*.py` | Updated startup tests for R4 |
