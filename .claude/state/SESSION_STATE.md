# Session State - Claude Watch

> Last updated: 2026-02-15
> Session: Phase 12 — Review Fixes + C1 Watch Verification
>
> **Branches:**
> - Migration code: `claude/investigate-websocket-terminal-utUEt`
> - Docs cleanup: `restructuring` (merged docs restructuring on 2026-02-15)

## Single Source of Truth

**`.claude/plans/MIGRATION_PROGRESS.md`** — all workstream tracking, test counts, review fixes, timeline.

## Current Phase

**Phase 12: Review Fixes (R1-R4) + C1 Watch Verification**

Next session execution plan: `.claude/plans/phase12-CONTEXT.md`

## Where We Are

```
[x] A: Bridge Server       (249 tests)
[x] B: CLI + Cloud Relay    (175 tests)
[x] D: Integration Tests    (82 tests)
                             ─── 508 tests passing ───
[ ] R1-R4: Critical fixes   ← START HERE
[ ] C1: Watch verification   ← then this
[ ] R5-R10: Usage fixes      (after C1)
[ ] E1-E5: New capabilities  (week 5)
[ ] F1-F3 + R11-R18: Polish  (week 6)
```

## Quick Start

```bash
# 0. Checkout the migration branch
git checkout claude/investigate-websocket-terminal-utUEt

# 1. Confirm green baseline (expect 379 bridge + 129 CLI = 508 total)
python -m pytest MCPServer/bridge/tests/ -q          # expect 379 passed
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/  # expect 129 passed

# 2. Read the execution plan
# .claude/plans/phase12-CONTEXT.md

# 3. Fix R4 → R1 → R2 → R3 (in order, test after each)

# 4. C1: live watch verification (requires physical watch)
```

## Architecture

```
Claude CLI  <--NDJSON/WS (8787)-->  Bridge  <--REST (8788)-->  Cloud Worker  <--poll-->  Watch
                                    (MCPServer/bridge/)
```

## Key Learnings

1. `--sdk-url` is undocumented Claude CLI flag enabling NDJSON-over-WebSocket control
2. `can_use_tool` fires for ALL tool calls including `AskUserQuestion`
3. `updatedInput` in control_response modifies tool inputs before execution
4. `appendSystemPrompt` in initialize injects watch-mode instructions
5. Bridge REST API matches cloud worker contract exactly — zero watch changes for MVP
6. `reuse_address=True` needed on WS and HTTP servers to prevent test port collisions
7. Bun `mock.module()` bleeds across files — must run lib and command tests separately
