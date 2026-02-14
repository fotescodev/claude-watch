# Session State - Claude Watch

> Last updated: 2026-02-14
> Session: Phase 11 --sdk-url Migration
> Branch: `claude/investigate-websocket-terminal-utUEt`

## Current Phase

**Phase 11: --sdk-url Migration** — Workstreams A + B + D COMPLETE

Migrating from hook-based architecture to direct WebSocket `--sdk-url` protocol. Bridge server, CLI, cloud relay, and E2E tests all built and passing.

## What Was Done

| Workstream | Status | Tests | Description |
|------------|--------|-------|-------------|
| A: Bridge Server | DONE | 249 | 8 tasks: NDJSON server, types, permissions, questions, progress, launcher, API, entrypoint |
| B1: Remmy CLI | DONE | 129 | 9 tasks: default/setup/run/status/unpair commands, config, cloud-client, bridge/claude launchers |
| B2: Cloud Relay | DONE | 46+7 | CloudClient HTTP module + bridge main.py integration + 7 E2E cloud sync tests |
| D: Integration Tests | DONE | 82 | D1-D6: approval, question, progress, interrupt, launcher, contract regression |
| **Total** | | **508** | 379 bridge + 129 CLI |

## What's Next — REVIEW FINDINGS

**Read `.claude/plans/REVIEW_FINDINGS.md` first.**

A 3-specialist review (QA, Dev, Integration) identified 18 issues. They are organized into 3 phases:

### Phase 1: Must Fix Before C1 (Watch Verification)
1. **Double-resolution race** — REST API + cloud poll can both resolve same permission
2. **Interrupt poll fires repeatedly** — no rising-edge detection, sends interrupt every 2s
3. **No session cleanup on stop** — watch shows ghost session for 5 min after bridge dies
4. **Bind to localhost** — servers bind 0.0.0.0, anyone on LAN can approve tools

### Phase 2: Fix Before Real Usage
5. Cloud KV TTL expiry (5 min) during long tool calls
6. Interrupt from two locations (REST + cloud) without coordination
7. Permission marked resolved before WS send confirmed
8. Missing cloudUrl test coverage in CLI
9. Debounce logic not tested
10. No health heartbeat to cloud

### Phase 3: Hardening
11-18. Auth, jitter, unused imports, port detection, minor items

### Then Continue:
- **C1**: Verify watch works against bridge REST API (needs physical watch)
- **E1-E5**: New capabilities (permission learning, model switch, streaming, resume, undo)
- **F1-F3**: Cleanup (remove legacy hooks, old cloud endpoints, temp files)

## Architecture

```
Claude CLI  <--NDJSON/WS (8787)-->  Bridge  <--REST (8788)-->  Cloud Worker  <--poll-->  Watch
                                    (MCPServer/bridge/)
```

## Key Files

| File | Purpose |
|------|---------|
| `.claude/plans/REVIEW_FINDINGS.md` | **START HERE** — 18 issues, 3-phase fix plan |
| `.claude/plans/MIGRATION_PROGRESS.md` | Workstream tracker with quality ratings |
| `.claude/plans/sdk-url-agent-execution-spec.md` | Full spec with acceptance criteria |
| `MCPServer/bridge/main.py` | Bridge entrypoint (~500 lines) |
| `MCPServer/bridge/cloud_client.py` | Cloud relay HTTP client (~260 lines) |
| `remmy-cli/src/cli.ts` | CLI entry point |

## Quick Commands

```bash
# Run ALL bridge tests (379 tests)
python -m pytest MCPServer/bridge/tests/ -q

# Run CLI tests (129 tests) — must split due to bun mock.module() bleed
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/

# Start bridge server
python -m MCPServer.bridge --port 8787 --pairing-id <PAIRING_ID> --cloud-url https://remmy.watch

# Check current branch
git log --oneline -5
```

## Commits (This Migration)

```
e04e805 docs: update migration progress — B2 cloud relay complete
1b10084 feat(bridge): add cloud relay sync — B2 complete, 379 tests
fc33a6d feat(bridge): add Workstream D integration tests — 82 E2E tests
ca784b8 feat(remmy-cli): implement all CLI commands with 129 tests passing
daf41b1 feat: scaffold remmy-watch CLI + bridge auto-registration fix
1c38f19 docs: session state update
```

## Key Learnings

1. `--sdk-url` is undocumented Claude CLI flag enabling NDJSON-over-WebSocket control
2. `can_use_tool` fires for ALL tool calls including `AskUserQuestion` — fixes Phase 10 stdin issue
3. `updatedInput` in control_response modifies tool inputs before execution
4. `appendSystemPrompt` in initialize injects watch-mode instructions
5. Bridge REST API matches cloud worker contract exactly — zero watch changes for MVP
6. `reuse_address=True` needed on both WS and HTTP servers to prevent test port collisions
7. Bun `mock.module()` bleeds across files — must run lib and command tests separately
