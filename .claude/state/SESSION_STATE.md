# Session State - Claude Watch

> Last updated: 2026-02-11
> Session: Phase 11 --sdk-url Migration
> Branch: `claude/investigate-websocket-terminal-utUEt`

## Current Phase

**Phase 11: --sdk-url Migration** - In Progress

Migrating from hook-based architecture (PreToolUse hooks -> Cloud Worker -> Watch polling) to a direct WebSocket `--sdk-url` protocol. The new architecture uses a Python bridge server that speaks NDJSON-over-WebSocket to the Claude CLI, replacing all hooks with a single real-time control channel.

## Key Documents

| Document | Purpose |
|----------|---------|
| `.claude/plans/sdk-url-migration-plan.md` | Full migration plan with feature parity matrix |
| `.claude/plans/sdk-url-agent-execution-spec.md` | Agent-executable spec with acceptance criteria and tests |
| `.claude/plans/MIGRATION_PROGRESS.md` | Workstream-level progress tracker |
| `.claude/inbox/sdk-url-websocket-analysis.md` | Original reverse-engineering analysis |

## What's Being Built

The bridge server (`MCPServer/bridge/`) sits between the Claude CLI and the watch:

```
Claude CLI  <--NDJSON/WebSocket-->  Bridge Server  <--REST/APNs-->  Cloud Worker  <--polling-->  Watch
                                    (MCPServer/bridge/)
```

The bridge replaces hooks for:
- **Approval flow**: `can_use_tool` control requests replace `watch-approval-cloud.py` hook
- **Question handling**: `AskUserQuestion` via `updatedInput` replaces broken stdin-proxy (Phase 10)
- **Progress tracking**: Native `tool_progress` + `assistant` message parsing replace `progress-tracker.py` hook
- **Context warnings**: `result.modelUsage` provides exact token counts, replacing estimated `context-warning.py` hook

What stays the same:
- Cloud pairing flow (watch initiates, CLI completes)
- Watch UI (views, complications, notification categories)
- APNs push notifications (sender changes from cloud to bridge)
- E2E encryption (for cloud relay leg)

## Progress

### Workstream A: Bridge Server (Python) - IN PROGRESS

| Task | Status | File(s) |
|------|--------|---------|
| A1: NDJSON WebSocket Server | In Progress | `MCPServer/bridge/ndjson_server.py` (not yet created) |
| A2: Message Types & Session State | In Progress | `MCPServer/bridge/types.py`, `MCPServer/bridge/session.py` (created) |
| A3: Permission Handler | Pending | `MCPServer/bridge/permissions.py` |
| A4: AskUserQuestion Handler | Pending | `MCPServer/bridge/questions.py` |
| A5: Progress Tracker | Pending | `MCPServer/bridge/progress.py` |
| A6: CLI Launcher | Pending | `MCPServer/bridge/launcher.py` |
| A7: Watch-Facing REST API | Pending | `MCPServer/bridge/api.py` |
| A8: Bridge Entrypoint | Pending | `MCPServer/bridge/main.py` |

### Workstreams B-F: Not Started

See `.claude/plans/MIGRATION_PROGRESS.md` for full workstream breakdown.

## Key Files Being Created

| File | Purpose |
|------|---------|
| `MCPServer/bridge/__init__.py` | Package init (exists) |
| `MCPServer/bridge/types.py` | Message dataclasses for all NDJSON types (exists) |
| `MCPServer/bridge/session.py` | Per-session state management (exists) |
| `MCPServer/bridge/ndjson_server.py` | WebSocket server accepting CLI connections |
| `MCPServer/bridge/permissions.py` | `can_use_tool` handler + `control_response` construction |
| `MCPServer/bridge/questions.py` | `AskUserQuestion` parsing + recommendation extraction |
| `MCPServer/bridge/progress.py` | TodoWrite + tool_progress + context % tracking |
| `MCPServer/bridge/launcher.py` | CLI process spawning with `--sdk-url` |
| `MCPServer/bridge/api.py` | REST API matching current cloud worker contract |
| `MCPServer/bridge/main.py` | Entrypoint wiring everything together |

## Commits This Session

```
2198da5 research: analyze --sdk-url WebSocket protocol from reverse-engineered Claude Code CLI
8183c66 plan: comprehensive --sdk-url migration with 1:1 feature parity matrix
d6d354d spec: agent-executable --sdk-url migration with acceptance criteria and tests
```

## Previous Phase Summary

**Phase 10: V2 Redesign** - ~95% complete (as of 2026-01-23)
- All core watch features working (approvals, questions, context warnings, progress)
- View transitions verified (F16/F18)
- Remaining items: device testing (Control Center, Siri, Double Tap), service refactoring
- See commits `870054f`, `ecd5d06`, `44d5c5d` for Phase 10 work

## Quick Commands

```bash
# Build watch app for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Run bridge server (once built)
python -m MCPServer.bridge --port 8787 --pairing-id <PAIRING_ID>

# Run bridge tests (once built)
python -m pytest MCPServer/bridge/tests/

# Check current branch
git log --oneline -5
```

## Key Learnings (Carried Forward)

1. `--sdk-url` is an undocumented Claude CLI flag that enables NDJSON-over-WebSocket control
2. Reverse-engineered from [fotescodev/remmy-websocket](https://github.com/fotescodev/remmy-websocket) (The Vibe Companion)
3. Protocol provides `can_use_tool` for ALL tool calls including `AskUserQuestion` -- this fixes the Phase 10 stdin-proxy failure
4. `updatedInput` in `control_response` allows modifying tool inputs before execution (command sanitization, answer injection)
5. Bridge REST API must match current cloud worker contract exactly so watch app needs zero changes for MVP
