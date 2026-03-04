# Agent Guide — Reading Order by Task Type

> Referenced by CLAUDE.md. Maps task types to the docs you need.
> Last updated: 2026-03-04

## Quick Orientation (Every Session)

1. `.claude/state/SESSION_STATE.md` — what happened last, what's next
2. `.claude/plans/MIGRATION_PROGRESS.md` — workstream status & test counts

## New Session Checklist

If you're a new agent or starting a fresh session, do this:

```bash
# 1. You're reading this — good. Now read SESSION_STATE for context:
#    .claude/state/SESSION_STATE.md

# 2. Checkout the correct branch for your task
git checkout <branch>

# 3. Verify green baseline (expect 346+ bridge + CLI tests)
python -m pytest MCPServer/bridge/tests/ -q
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/

# 4. Check MIGRATION_PROGRESS.md for current task (look for "UP NEXT")

# 5. Read the relevant spec for your task (see "Specs & Plans" below)

# 6. Start working. Commit atomically per task.
```

---

## By Task Type

### Watch UI / SwiftUI
1. `.claude/LAYOUT_STANDARDS.md` — spacing, typography tokens
2. `.claude/ARCHITECTURE.md` — Watch app section
3. `docs/specs/SWIFTUI_DESIGN_SYSTEM.md` — component library (colors, fonts, semantic tokens)
4. Check existing Views in `ClaudeWatch/Views/` for patterns

### Bridge / Server (Python)
1. `.claude/ARCHITECTURE.md` — bridge architecture section (Phase 11)
2. `.claude/plans/sdk-url-agent-execution-spec.md` — full bridge spec (workstreams A1-A8)
3. `.claude/DATA_FLOW.md` — API endpoints & message types
4. `MCPServer/bridge/` — implementation reference

### CLI (TypeScript)
1. `.claude/ARCHITECTURE.md` — CLI section
2. `.claude/plans/remmy-watch-cli-spec.md` — CLI spec (commands, flow, structure)
3. `remmy-cli/src/` — implementation reference

### Bug Fix
1. `docs/solutions/INDEX.md` — **check if already solved!**
2. `.claude/ARCHITECTURE.md` — trace the data flow
3. `.claude/DATA_FLOW.md` — verify endpoint behavior
4. Check test files for relevant test cases

### New Feature
1. `.claude/ARCHITECTURE.md` — where does it fit?
2. `.claude/plans/MIGRATION_PROGRESS.md` — current status & blockers
3. `.claude/state/SESSION_STATE.md` — context from last session
4. Relevant spec file (see "Specs & Plans" section)

### TestFlight / Shipping
1. `.claude/TESTFLIGHT_READINESS.md` — blockers & audit results
2. `.claude/plans/MIGRATION_PROGRESS.md` — what's done, what's left
3. `docs/solutions/testflight-preparation/testflight-prevention-guide.md`

---

## Don't Waste Tokens

**DO:**
- Read SESSION_STATE.md first for instant orientation
- Check `docs/solutions/INDEX.md` before debugging (it may already be solved)
- Read ARCHITECTURE.md before proposing solutions
- Use Grep and Glob to locate specific files/code

**DON'T:**
- Explore random directories looking for context
- Read files in `.claude/archive/` — that's completed/obsolete work
- Search the entire codebase to "understand the project"
- Read old session logs (`.jsonl` files)

---

## Key Architecture (Current)

**Primary: Hooks-based** — `remmy` CLI installs a PreToolUse hook that routes approvals through the cloud worker.

```
Claude CLI  --hook-->  Cloud Worker (claude-watch-cloud/)  <--poll-->  Watch
```

**Advanced: Bridge-based** — Optional Python bridge for richer capabilities (multi-option questions, token tracking).

```
Claude CLI  <--NDJSON/WS-->  Bridge (MCPServer/bridge/)  <--REST-->  Cloud  <--poll-->  Watch
```

### Data Flow Overview (Hooks — Primary)

| Flow | Direction | Key Files |
|------|-----------|-----------|
| **Approval** | Hook → Cloud → Watch → Cloud → Hook → Claude | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Question** | Hook → Cloud → Watch → Cloud → Hook → Claude | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Progress** | Hook → Cloud → Watch | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Pairing** | Watch → Cloud → CLI | `WatchService.swift` → `index.ts` → `remmy-cli/src/commands/setup.ts` |

---

## Test Commands

```bash
# Bridge tests (expect 346+)
python -m pytest MCPServer/bridge/tests/ -q

# Bridge unit only
python -m pytest MCPServer/bridge/tests/ -q --ignore=MCPServer/bridge/tests/test_e2e_*

# Bridge E2E only
python -m pytest MCPServer/bridge/tests/test_e2e_* -q

# CLI tests (must split due to bun mock.module() bleed)
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/
```

---

## Specs & Plans

| Spec | Purpose |
|------|---------|
| `.claude/plans/sdk-url-agent-execution-spec.md` | Bridge server implementation (workstreams A-F) |
| `.claude/plans/remmy-watch-cli-spec.md` | CLI command structure and behavior |
| `.claude/archive/plans/REVIEW_FINDINGS.md` | 18 findings from 3-specialist review (R1-R18) |
| `docs/specs/SWIFTUI_DESIGN_SYSTEM.md` | Watch UI design tokens and patterns |

---

## Key Patterns

### Bridge REST API Contract

The bridge exposes a REST API on port 8788 that **exactly matches** the cloud worker contract. This means zero watch changes for MVP.

Endpoints:
- `GET /state` — current session state
- `GET /permissions` — pending permission requests
- `POST /permissions/{id}/resolve` — approve/reject a permission
- `GET /questions` — pending questions
- `POST /questions/{id}/resolve` — answer a question
- `POST /interrupt` — send interrupt signal
- `GET /progress` — current task progress

### Watch Input Constraints

- Watch can **ONLY** tap approve/reject buttons
- Watch **CANNOT** select from numbered options
- Watch **CANNOT** type text input
- Watch **CANNOT** see multi-line question context

**Implication:** Claude must ask yes/no questions when using watch approval.

### Session Isolation

In the hooks-based architecture (primary), `CLAUDE_WATCH_SESSION_ACTIVE=1` env var gates watch mode — set by `remmy` CLI when spawning Claude. The hook script exits immediately when the env var is not set, so other Claude sessions are unaffected.

In the bridge architecture (advanced), session isolation is inherent — only `--sdk-url` sessions connect to the bridge.

---

## Common Gotchas

1. **Port conflicts in tests**: Bridge tests need `reuse_address=True` on both WebSocket (8787) and HTTP (8788) servers
2. **Bun mock bleed**: `mock.module()` bleeds across files — run lib and command tests separately
3. **Context overflow**: Bridge session stores full message history — watch for token bloat in long sessions
4. **Double-resolution race**: Bridge's cloud poll + REST API can resolve same permission twice (R1 blocker)
5. **Interrupt poll spam**: No rising-edge detection — sends interrupt every 2s (R2 blocker)

---

## Review Findings (R1-R18)

**Phase 1: Must Fix Before C1** (watch verification blockers)
- R1: Double-resolution race condition
- R2: Interrupt poll fires repeatedly
- R3: No session cleanup on bridge stop
- R4: Servers bind to 0.0.0.0 (security risk)

See `.claude/archive/plans/REVIEW_FINDINGS.md` for full details and fix specs.

---

*This guide is a living document. Update it when patterns change.*
