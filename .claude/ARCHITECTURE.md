# Claude Watch Architecture Skeleton

> **READ THIS BEFORE PROPOSING SOLUTIONS.** Understand where your change fits.
>
> This is the source of truth for system design. For detailed API endpoints, see `DATA_FLOW.md`.

---

## System Components

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CLAUDE WATCH SYSTEM                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MAC (Developer Machine)                                                       │
│   ├── Claude Code (agent runtime)                                               │
│   │   ├── PreToolUse hooks → approval requests                                  │
│   │   ├── PostToolUse hooks → progress updates + mobile validation              │
│   │   ├── SessionStart hooks → context injection                                │
│   │   └── Mobile-MCP tools → iOS Simulator automation                           │
│   │                                                                             │
│   └── cc-watch CLI (claude-watch-npm/)                                          │
│       ├── Pairing flow → POST /pair/complete                                    │
│       └── Spawns Claude with CLAUDE_WATCH_SESSION_ACTIVE=1                      │
│                                                                                 │
│   CLOUDFLARE WORKER (claude-watch-cloud/)                                       │
│   ├── /pair/* → Pairing handshake (watch initiates, CLI completes)              │
│   ├── /approval/* → Tool approval requests + responses                          │
│   ├── /session-progress/* → Progress updates from TodoWrite hook                │
│   └── APNs → Push notifications to watch (instant alerts)                       │
│                                                                                 │
│   APPLE WATCH (ClaudeWatch/)                                                    │
│   ├── WatchService.swift → Polls cloud, sends responses, manages state          │
│   ├── Views/ → MainView (approvals), PairingView (setup), ProgressView          │
│   └── Complications/ → Watch face widgets for quick access                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flows (Which Code Talks to What)

| Flow | Direction | Files Involved |
|------|-----------|----------------|
| **Pairing** | Watch → Cloud → CLI | `WatchService.swift` → `index.ts` → `cc-watch.ts` |
| **Approval** | Hook → Cloud → Watch → Cloud → Hook | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Progress** | Hook → Cloud → Watch | `progress-tracker.py` → `index.ts` → `WatchService.swift` |
| **Mobile Test** | Agent → Simulator → Validator | `mobile_*` tools → iOS Simulator → `screen_state_validator.py` |

### Key File Locations

| Component | Path | Purpose |
|-----------|------|---------|
| **Watch App** | `ClaudeWatch/` | SwiftUI watchOS app |
| **Watch Service** | `ClaudeWatch/Services/WatchService.swift` | All cloud API calls, polling, state |
| **Cloud Worker** | `claude-watch-cloud/src/index.ts` | Cloudflare Worker (message router) |
| **CLI** | `claude-watch-npm/src/cli/cc-watch.ts` | Pairing + Claude launcher |
| **Approval Hook** | `.claude/hooks/watch-approval-cloud.py` | PreToolUse → sends approvals |
| **Progress Hook** | `.claude/hooks/progress-tracker.py` | PostToolUse → sends progress |
| **Mobile Validator** | `.claude/hooks/validators/mobile/screen_state_validator.py` | PostToolUse → validates UI state |

---

## Before You Change Code

Answer these questions FIRST:

1. **Which component?** (Hook / Cloud / Watch / CLI)
2. **Which flow?** (Pairing / Approval / Progress)
3. **What calls what?** Check `DATA_FLOW.md` for endpoint details
4. **Does it need changes in multiple places?** Most features touch 2-3 components

### Common Patterns

| Task | Components to Modify |
|------|---------------------|
| Add new approval type | Hook + Cloud + Watch |
| Change notification content | Hook + Cloud (APNs payload) |
| Add new UI element | Watch only |
| Change polling interval | Watch only (WatchService) |
| Add new API endpoint | Cloud + caller (Hook or Watch) |
| Add mobile test automation | Mobile-MCP tools + validator hook |
| Add UI validation assertion | `screen_state_validator.py` |

---

## Critical Constraints

### Watch Input Limitations
- Watch can **ONLY** tap approve/reject buttons
- Watch **CANNOT** select from numbered options
- Watch **CANNOT** type text input
- Watch **CANNOT** see multi-line question context

**Implication:** Claude must ask yes/no questions when `CLAUDE_WATCH_SESSION_ACTIVE=1`

### Communication Architecture
- **All communication goes through cloud** (no direct hook↔watch)
- Hooks check `CLAUDE_WATCH_SESSION_ACTIVE=1` before activating
- Cloud uses APNs for instant notifications, polling as fallback
- Watch polls every 2 seconds when app is in foreground

### Session Isolation
- `CLAUDE_WATCH_SESSION_ACTIVE=1` gates watch mode
- Set by `cc-watch` when spawning Claude
- Hooks exit early (code 0) if not set
- Multiple Claude sessions can run, only cc-watch sessions use watch

---

## Debugging Checklist

When something doesn't work:

1. **Check which component failed**
   - Hook logs: `/tmp/claude-watch-hook-debug.log`
   - Cloud logs: `wrangler tail` (Cloudflare dashboard)
   - Watch logs: Xcode console or `log stream`

2. **Trace the flow**
   - See `DATA_FLOW.md` for exact endpoint sequence
   - Each flow has a numbered step diagram

3. **Check known solutions**
   - `docs/solutions/INDEX.md` - categorized by symptom
   - Search for similar error messages

---

## Quick Reference

### Environment Variables
| Variable | Purpose | Set By |
|----------|---------|--------|
| `CLAUDE_WATCH_SESSION_ACTIVE` | Gates watch mode | cc-watch |
| `CLAUDE_WATCH_PAIRING_ID` | Current pairing | cc-watch or ~/.claude-watch-pairing |
| `CLAUDE_WATCH_DEBUG` | Verbose logging | User |

### Cloud Server
- **URL:** `https://claude-watch.fotescodev.workers.dev`
- **Health:** `GET /health` → `{"status":"ok"}`

### Pairing Flow (Watch-Initiated)
```
Watch: POST /pair/initiate → receives code "ABC123"
Watch: Displays code to user
CLI:   User runs `npx cc-watch`, enters code
CLI:   POST /pair/complete {code: "ABC123"}
Watch: Polls /pair/status/:watchId → {paired: true, pairingId}
```

---

## Phase 11: --sdk-url Migration (In Progress)

> **Status**: In Progress (started 2026-02-11)
> **Branch**: `claude/investigate-websocket-terminal-utUEt`
> **Spec**: `.claude/plans/sdk-url-agent-execution-spec.md`

### New Architecture

The `--sdk-url` migration replaces the hook-based data channel with a direct NDJSON-over-WebSocket connection between the Claude CLI and a local Python bridge server. The bridge replaces all four hooks (approval, question, progress, context) with a single real-time control channel.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CLAUDE WATCH SYSTEM (Phase 11)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MAC (Developer Machine)                                                       │
│   ├── Claude Code CLI                                                           │
│   │   └── --sdk-url ws://localhost:8787/ws/cli/{session_id}                     │
│   │       Sends: NDJSON messages (system, assistant, result, control_request)    │
│   │       Receives: control_response (approve/deny with updatedInput)           │
│   │                                                                             │
│   ├── Bridge Server (MCPServer/bridge/) ← NEW                                  │
│   │   ├── NDJSON WebSocket ← Claude CLI connection                              │
│   │   ├── Permission handler (can_use_tool → approve/deny)                      │
│   │   ├── Question handler (AskUserQuestion → recommended answer)               │
│   │   ├── Progress tracker (tool_progress, TodoWrite, context %)                │
│   │   ├── CLI launcher (spawns claude --sdk-url, manages lifecycle)             │
│   │   └── REST API (same contract as current cloud worker)                      │
│   │                                                                             │
│   └── cc-watch CLI (claude-watch-npm/)                                          │
│       ├── Pairing flow → POST /pair/complete (unchanged)                        │
│       └── Launches bridge server (replaces env var spawning)                    │
│                                                                                 │
│   CLOUDFLARE WORKER (claude-watch-cloud/) — REDUCED ROLE                        │
│   ├── /pair/* → Pairing handshake (unchanged)                                   │
│   └── Relay: Bridge → Cloud → Watch (approval/progress/question data)           │
│       (Cloud worker becomes a thin relay; bridge is the source of truth)        │
│                                                                                 │
│   APPLE WATCH (ClaudeWatch/) — UNCHANGED FOR MVP                                │
│   ├── WatchService.swift → Polls cloud (same endpoints, same contract)          │
│   ├── Views/ → MainView, PairingView, ProgressView (no changes)                │
│   └── Complications/ → Watch face widgets (no changes)                          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### What Changes

| Component | Before (Hooks) | After (--sdk-url) |
|-----------|----------------|-------------------|
| **Approval flow** | `watch-approval-cloud.py` hook -> cloud -> watch polls | `can_use_tool` WebSocket msg -> bridge -> cloud -> watch polls |
| **Question handling** | `question-handler.py` hook (broken for multi-option) | `AskUserQuestion` via `can_use_tool` + `updatedInput` response |
| **Progress tracking** | `progress-tracker.py` PostToolUse hook | Native `tool_progress` + `assistant` message parsing |
| **Context warnings** | `context-warning.py` hook (estimated) | `result.modelUsage` (exact token counts) |
| **Session isolation** | `CLAUDE_WATCH_SESSION_ACTIVE=1` env var | Inherent: only `--sdk-url` sessions connect to bridge |
| **Interrupt/pause** | Hook polls `/session-interrupt` endpoint | Direct `control_request { subtype: "interrupt" }` |

### What Stays the Same

- Cloud pairing flow (watch initiates with code, CLI completes)
- Watch UI (views, complications, notification categories)
- APNs push notifications (delivery mechanism unchanged)
- E2E encryption (for cloud relay leg)
- Watch input constraints (approve/reject only)

### New Files: MCPServer/bridge/

| File | Purpose |
|------|---------|
| `__init__.py` | Package init |
| `types.py` | Dataclasses for all NDJSON message types |
| `session.py` | Per-session state (model, tools, cost, pending permissions, todos) |
| `ndjson_server.py` | WebSocket server accepting CLI connections |
| `permissions.py` | `can_use_tool` handler + `control_response` construction |
| `questions.py` | `AskUserQuestion` parsing + recommendation extraction |
| `progress.py` | TodoWrite + tool_progress + context % tracking |
| `launcher.py` | CLI process spawning with `--sdk-url`, lifecycle management |
| `api.py` | REST API matching current cloud worker contract (zero watch changes) |
| `main.py` | Entrypoint wiring everything together |

### Data Flow Changes

| Flow | New Direction | Files Involved |
|------|--------------|----------------|
| **Approval** | CLI -> Bridge (WebSocket) -> Cloud -> Watch -> Cloud -> Bridge -> CLI | `bridge/permissions.py` -> `index.ts` -> `WatchService.swift` |
| **Question** | CLI -> Bridge (parse + recommend) -> Cloud -> Watch -> Cloud -> Bridge (updatedInput) -> CLI | `bridge/questions.py` -> `index.ts` -> `WatchService.swift` |
| **Progress** | CLI -> Bridge (native messages) -> Cloud -> Watch | `bridge/progress.py` -> `index.ts` -> `WatchService.swift` |
| **Interrupt** | Watch -> Cloud -> Bridge -> CLI (instant) | `WatchService.swift` -> `index.ts` -> `bridge/permissions.py` |

For full details, see `.claude/plans/sdk-url-agent-execution-spec.md`.

---

## Learnings Log

> Undocumented patterns discovered during development. Add new entries with date.

### 2026-01-23: Initial architecture documentation
- Created from existing DATA_FLOW.md and codebase analysis
- Key insight: Most features require changes in 2-3 components (hook + cloud + watch)

### 2026-01-21: E2E encryption key exchange
- Keys exchanged during pairing: watch in /pair/initiate, CLI in /pair/complete
- Watch receives cliPublicKey from /pair/status response
- Uses x25519 key agreement + XSalsa20-Poly1305 (CLI) / ChaChaPoly (Watch)

### 2026-01-22: Question handling simplified
- COMP5 complex stdout interception abandoned
- Solution: Constrain Claude to yes/no questions via CLAUDE.md
- Watch's existing approve/reject UI handles this perfectly

### 2026-01-23: Documentation architecture for agent retention
- Agents lose context each session; hooks inject mandatory architecture checklist
- Validators (Python scripts) enforce doc structure deterministically
- Learnings Log compounds knowledge; `/compound` captures session insights

### 2026-01-23: Mobile-MCP integration with Ralph Loop
- Mobile-MCP tools enable iOS Simulator automation for testing Claude Watch
- Destructive tools (`mobile_install_app`, `mobile_uninstall_app`) require watch approval
- PostToolUse validator (`screen_state_validator.py`) implements self-healing loop
- Pattern: Code > Vibes (deterministic validation beats probabilistic verification)
- `mobile_list_elements_on_screen` provides "visual sense" without computer vision

---

*Last updated: 2026-02-11*
