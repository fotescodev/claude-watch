# Session State - Claude Watch

> Last updated: 2026-02-12
> Session: Phase 11 --sdk-url Migration
> Branch: `claude/investigate-websocket-terminal-utUEt`

## Current Phase

**Phase 11: --sdk-url Migration** - Workstream A COMPLETE

Migrating from hook-based architecture (PreToolUse hooks -> Cloud Worker -> Watch polling) to a direct WebSocket `--sdk-url` protocol. The new architecture uses a Python bridge server that speaks NDJSON-over-WebSocket to the Claude CLI, replacing all hooks with a single real-time control channel.

## Workstream A: COMPLETE (8/8 tasks, 249 tests, ~6,900 lines)

The entire bridge server is built and tested. It can be launched with:
```bash
python -m MCPServer.bridge --port 8787 --pairing-id PAIR-123 --launch --cwd /path/to/project
```

### Bridge Architecture (Built)

```
Claude CLI  <--NDJSON/WebSocket-->  Bridge Server  <--REST HTTP-->  Cloud Worker  <--polling-->  Watch
                                    (MCPServer/bridge/)
                                    Port 8787 (WS)
                                    Port 8788 (HTTP)
```

### Files Created

| File | Lines | Tests | Purpose |
|------|-------|-------|---------|
| `MCPServer/bridge/types.py` | 317 | 57 | Message dataclasses for all 13 NDJSON message types |
| `MCPServer/bridge/session.py` | 266 | (in types) | Per-session state: permissions, todos, progress, context % |
| `MCPServer/bridge/ndjson_server.py` | 229 | 11 | Async WebSocket server, NDJSON line splitting, message dispatch |
| `MCPServer/bridge/permissions.py` | 177 | 21 | `can_use_tool` handling, approve/deny/approve_all, auto-accept |
| `MCPServer/bridge/questions.py` | 175 | 20 | AskUserQuestion: recommendation extraction, `updatedInput.answers` |
| `MCPServer/bridge/progress.py` | 280 | 43 | TodoWrite parsing, context %, compaction, tool activity strings |
| `MCPServer/bridge/launcher.py` | 245 | 29 | CLI process lifecycle: launch, relaunch (--resume), kill |
| `MCPServer/bridge/api.py` | 466 | 34 | REST API matching current cloud worker contract (zero watch changes) |
| `MCPServer/bridge/main.py` | 391 | 34 | Bridge entrypoint: wires NDJSON + API + Launcher + message routing |
| `MCPServer/bridge/__main__.py` | 5 | — | `python -m MCPServer.bridge` support |

### Quality Ratings

| Task | Rating | Key Win |
|------|--------|---------|
| A1: NDJSON Server | 9/10 | Proper path validation, keep_alive filtering |
| A2: Types & Session | 8/10 | All message types, camelCase conversion |
| A3: Permissions | 9/10 | updatedInput passthrough, auto-accept mode |
| A4: Questions | 9/10 | **Phase 10 fix** — AskUserQuestion via WebSocket |
| A5: Progress | 8/10 | TodoWrite extraction, context % from modelUsage |
| A6: CLI Launcher | 8/10 | --resume, SIGTERM->SIGKILL, immediate-exit detection |
| A7: Watch REST API | 9/10 | Full cloud worker contract match |
| A8: Bridge Entrypoint | 9/10 | Watch-mode system prompt injection via initialize |

**Average rating: 8.6/10**

## What's Next (Priority Order)

### Workstream D: Integration Tests (RECOMMENDED NEXT)
- D1: End-to-End Approval Flow
- D2: End-to-End Question Flow (validates Phase 10 fix)
- D3: End-to-End Progress Flow
- D4: End-to-End Interrupt Flow
- D5: CLI Launcher Integration
- D6: Regression Test Against Current Watch API Contract

### Workstream B: cc-watch CLI
- B1: Launch Bridge + CLI from `npx cc-watch`
- B2: Cloud Worker Relay (bridge -> cloud -> watch)

### Workstream C: Watch App
- C1: Zero Changes for MVP (verify watch works against new bridge API)
- C2: Direct WebSocket (Post-MVP, bypass cloud relay entirely)

### Workstream E: New Capabilities (unlocked by --sdk-url)
- E1: Permission Learning ("Always Allow" button)
- E2: Model Switching from Watch
- E3: Real-Time Token Streaming
- E4: Session Resume on Crash
- E5: File Undo from Watch

### Workstream F: Cleanup
- F1: Remove Legacy Hooks
- F2: Remove Cloud Worker Approval Endpoints
- F3: Remove Temp Files & Config

## Commits This Session

```
2198da5 research: analyze --sdk-url WebSocket protocol from reverse-engineered Claude Code CLI
8183c66 plan: comprehensive --sdk-url migration with 1:1 feature parity matrix
d6d354d spec: agent-executable --sdk-url migration with acceptance criteria and tests
970ab13 feat(bridge): implement A1-A5 — NDJSON server, types, permissions, questions, progress
fc687c7 feat(bridge): implement A6-A8 — CLI launcher, REST API, bridge entrypoint
```

## Key Documents

| Document | Purpose |
|----------|---------|
| `.claude/plans/sdk-url-migration-plan.md` | Full migration plan with 28-feature parity matrix |
| `.claude/plans/sdk-url-agent-execution-spec.md` | Agent-executable spec (25 tasks, 6 workstreams, ~50 tests) |
| `.claude/plans/MIGRATION_PROGRESS.md` | Live workstream progress tracker with quality ratings |
| `.claude/inbox/sdk-url-websocket-analysis.md` | Original reverse-engineering analysis |

## Key Learnings

1. `--sdk-url` is an undocumented Claude CLI flag (`.hideHelp()` in Commander) that enables NDJSON-over-WebSocket control
2. Reverse-engineered from [fotescodev/remmy-websocket](https://github.com/fotescodev/remmy-websocket) (The Vibe Companion)
3. Protocol provides `can_use_tool` for ALL tool calls including `AskUserQuestion` — this fixes the Phase 10 stdin-proxy failure
4. `updatedInput` in `control_response` allows modifying tool inputs before execution (command sanitization, answer injection)
5. Bridge REST API must match current cloud worker contract exactly so watch app needs zero changes for MVP
6. `appendSystemPrompt` in `initialize` control_request injects watch-mode instructions (y/n only questions)
7. Agent parallelization at scale works well — we ran 7 agents simultaneously for Wave 1, 3 for Wave 2
8. Quality review/rating cycle (1-10) helps catch integration gaps early

## Previous Phase Summary

**Phase 10: V2 Redesign** - ~95% complete (as of 2026-01-23)
- All core watch features working (approvals, questions, context warnings, progress)
- View transitions verified (F16/F18)
- Remaining items: device testing (Control Center, Siri, Double Tap), service refactoring
- See commits `870054f`, `ecd5d06`, `44d5c5d` for Phase 10 work

## Quick Commands

```bash
# Run bridge tests (249 tests, ~7s)
python -m pytest MCPServer/bridge/tests/ -q

# Start bridge server
python -m MCPServer.bridge --port 8787 --pairing-id <PAIRING_ID> --launch --cwd <PROJECT_DIR>

# Build watch app for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Check current branch
git log --oneline -5
```
