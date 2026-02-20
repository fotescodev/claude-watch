# Claude Watch Architecture Skeleton

> **READ THIS BEFORE PROPOSING SOLUTIONS.** Understand where your change fits.
>
> This is the source of truth for system design. For detailed API endpoints, see `DATA_FLOW.md`.

---

## System Components (Primary Architecture — Hooks-Based)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      CLAUDE WATCH SYSTEM (Hooks-Based)                          │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MAC (Developer Machine)                                                       │
│   ├── Claude Code CLI (native TUI — no modifications)                           │
│   │   ├── PreToolUse hooks → approval requests                                  │
│   │   └── CLAUDE_WATCH_SESSION_ACTIVE=1 → gates watch mode                     │
│   │                                                                             │
│   └── remmy-cli (TypeScript CLI)                                                │
│       ├── Pairing flow → POST /pair/complete                                    │
│       ├── Installs hook → ~/.claude/hooks/watch-approval-cloud.py               │
│       ├── Registers hook → ~/.claude/settings.json (PreToolUse)                 │
│       └── Spawns Claude with CLAUDE_WATCH_SESSION_ACTIVE=1                      │
│                                                                                 │
│   HOOK (watch-approval-cloud.py)                                                │
│   ├── Intercepts PreToolUse for Bash/Edit/Write/MultiEdit/NotebookEdit          │
│   ├── Checks CLAUDE_WATCH_SESSION_ACTIVE=1 (skip if not set)                   │
│   ├── Sends approval request → cloud worker                                    │
│   └── Polls for response (5-minute timeout)                                    │
│                                                                                 │
│   CLOUDFLARE WORKER (claude-watch-cloud/)                                       │
│   ├── /pair/* → Pairing handshake (watch initiates, CLI completes)              │
│   ├── /approval/* → Tool approval requests + responses                          │
│   ├── /session-progress/* → Progress updates                                    │
│   └── APNs → Push notifications to watch (instant alerts)                       │
│                                                                                 │
│   APPLE WATCH (ClaudeWatch/)                                                    │
│   ├── WatchService.swift → Polls cloud (same endpoints, same contract)          │
│   ├── Views/ → MainView, PairingView, ProgressView                             │
│   └── Complications/ → Watch face widgets                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flows (Which Code Talks to What)

| Flow | Direction | Files Involved |
|------|-----------|----------------|
| **Pairing** | Watch → Cloud → CLI | `WatchService.swift` → `index.ts` → `remmy-cli` |
| **Approval** | Hook → Cloud → Watch → Cloud → Hook → Claude | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Progress** | Hook → Cloud → Watch | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |

### Key File Locations

| Component | Path | Purpose |
|-----------|------|---------|
| **Watch App** | `ClaudeWatch/` | SwiftUI watchOS app |
| **Watch Service** | `ClaudeWatch/Services/WatchService.swift` | All cloud API calls, polling, state |
| **Hook** | `remmy-cli/hooks/watch-approval-cloud.py` | PreToolUse hook (installed to `~/.claude/hooks/`) |
| **Hook Config** | `remmy-cli/src/lib/hooks-config.ts` | Hook installation + settings.json registration |
| **Cloud Worker** | `claude-watch-cloud/src/index.ts` | Cloudflare Worker |
| **CLI** | `remmy-cli/src/commands/` | Pairing, hook setup, Claude launch |

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
| Change hook installation | `remmy-cli/src/lib/hooks-config.ts` |

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
- `CLAUDE_WATCH_SESSION_ACTIVE=1` env var gates watch mode
- Set by `remmy-cli` when spawning Claude
- Multiple Claude sessions can run; only remmy-cli sessions use watch
- Hook script exits immediately when env var is not set

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
| `CLAUDE_WATCH_SESSION_ACTIVE` | Gates watch mode | remmy-cli |
| `REMMY_DEBUG` | Verbose hook logging | User |
| `REMMY_CLOUD_URL` | Override cloud URL | User (optional) |

### Cloud Server
- **URL:** `https://claude-watch.fotescodev.workers.dev`
- **Health:** `GET /health` → `{"status":"ok"}`

### Pairing Flow (Watch-Initiated)
```
Watch: POST /pair/initiate → receives code "ABC123"
Watch: Displays code to user
CLI:   User runs `remmy-cli`, enters code
CLI:   POST /pair/complete {code: "ABC123"}
Watch: Polls /pair/status/:watchId → {paired: true, pairingId}
```

---

## Advanced Architecture (Bridge-Based)

> **Status**: Available but not the default flow. Battle-tested with 346+ Python tests.
> **Use case**: When you need richer capabilities like multi-option question handling,
> exact token tracking, or real-time streaming — the bridge provides a WebSocket-based
> intermediary between Claude CLI and the watch.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      CLAUDE WATCH SYSTEM (Bridge — Advanced)                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MAC (Developer Machine)                                                       │
│   ├── Claude Code CLI                                                           │
│   │   └── --sdk-url ws://localhost:8787/ws/cli/{session_id}                     │
│   │       Sends: NDJSON messages (system, assistant, result, control_request)    │
│   │       Receives: control_response (approve/deny with updatedInput)           │
│   │                                                                             │
│   ├── Bridge Server (MCPServer/bridge/)                                        │
│   │   ├── NDJSON WebSocket ← Claude CLI connection                              │
│   │   ├── Permission handler (can_use_tool → approve/deny)                      │
│   │   ├── Question handler (AskUserQuestion → recommended answer)               │
│   │   ├── Progress tracker (tool_progress, TodoWrite, context %)                │
│   │   └── REST API (same contract as cloud worker)                              │
│   │                                                                             │
│   └── remmy-cli (TypeScript CLI)                                                │
│       └── Launches bridge server + Claude with --sdk-url                        │
│                                                                                 │
│   CLOUDFLARE WORKER — Relay between bridge and watch                            │
│   APPLE WATCH — Polls cloud (same endpoints, zero changes)                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Bridge vs Hooks Comparison

| Capability | Hooks (Default) | Bridge (Advanced) |
|-----------|-----------------|-------------------|
| **Approval flow** | Hook → cloud → watch polls | WebSocket `can_use_tool` → bridge → cloud → watch polls |
| **Question handling** | Yes/no only (watch limitation) | Multi-option via `updatedInput` response |
| **Progress tracking** | Not yet implemented | Native `tool_progress` + TodoWrite extraction |
| **Context tracking** | Not yet implemented | `result.modelUsage` (exact token counts) |
| **Session isolation** | `CLAUDE_WATCH_SESSION_ACTIVE=1` env var | Inherent: only `--sdk-url` sessions connect |
| **Interrupt/pause** | Hook polls `/session-interrupt` | Direct `control_request { subtype: "interrupt" }` |
| **User experience** | Native Claude TUI (unchanged) | Custom TUI required (or headless) |
| **Complexity** | Minimal (1 hook script) | Full Python server + process management |

### Bridge Server Files: MCPServer/bridge/

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
| `api.py` | REST API matching cloud worker contract |
| `cloud_client.py` | Cloud worker relay client |
| `main.py` | Entrypoint wiring everything together |

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

*Last updated: 2026-02-19*
