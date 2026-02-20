# Remmy Watch CLI — Agent Execution Spec (v2 — post eng-lead review)

> **Package**: `remmy-watch` (npm)
> **Binary**: `remmy`
> **Runtime**: Bun (dev/test), Node-compatible build output
> **Domain**: remmy.watch
> **Directory**: `remmy-cli/`
> **Branch**: `claude/investigate-websocket-terminal-utUEt`

## Eng Lead Review Changes (v1 → v2)

| Finding | Severity | Resolution |
|---------|----------|------------|
| C1: `--print` flags contradict `stdio: inherit` | CRITICAL | **Fixed R6.1**: Claude spawned with only `--sdk-url` flag, NO `--print/--output-format/--input-format/-p`. User gets normal interactive TUI. |
| C2: Session registration breaks without `--launch` | CRITICAL | **Fixed in bridge**: Auto-registration added to `_on_cli_connect` when `pairing_id` is set. 2 new tests (36/36 passing). |
| C3: Python bridge distribution unaddressed | CRITICAL | **Fixed R5**: Bridge Python files bundled into npm package under `bridge/`. `PYTHONPATH` set before spawn. |
| C4: No port collision handling | CRITICAL | **Fixed R5.9**: Added port scanning with auto-increment on EADDRINUSE. |
| I1: `--` separator is UX regression | IMPORTANT | **Fixed R8.4**: Args after `run` pass through directly, no `--` needed. |
| I2: Unpair doesn't clean legacy cc-watch | IMPORTANT | **Fixed R8.9**: Checks for and removes legacy hooks + MCP entries. |
| I3: Cloud failure when paired blocks launch | IMPORTANT | **Fixed R7.2**: Cloud check is informational when paired (prints status, doesn't block). |
| I4: Encryption is non-functional dead weight | IMPORTANT | **Fixed**: Dropped tweetnacl/tweetnacl-util. Zero runtime deps. Encryption deferred to future task. |
| I5: Status bridge health semantics undefined | IMPORTANT | **Fixed R8.5**: Status shows pairing info, cloud connectivity, config path, bridge port probe. |
| I6: Missing createdAt/watchId in status | IMPORTANT | **Fixed R8.5**: Added createdAt and watchId to display. |
| M1: Bare `version` not routed | MINOR | **Fixed R9.1**: Added `"version"` to routes. |
| M2: readline prompts need edge cases | MINOR | **Fixed**: Added `src/ui/prompt.ts` to R2 for text + confirm prompts. |
| M3: Migration should move not copy | MINOR | **Fixed R3.8**: Move (copy + delete source), with fallback. |
| M6: `--verbose` not in CLI flags | MINOR | **Fixed R9.1**: Added `--verbose` flag. |
| S2: Drop `--resume` from v1 | SUGGESTION | **Accepted**: Removed R6.7, R6.T7. |

## Architecture

```
User runs `bunx remmy-watch` (or `npx remmy-watch`)
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  remmy CLI (TypeScript / Bun)                       │
│                                                     │
│  1. Check pairing (~/.remmy/config.json)            │
│  2. If unpaired → cloud pairing flow (6-digit code) │
│  3. Launch Python bridge server in background       │
│  4. Launch Claude CLI with --sdk-url pointing at    │
│     the bridge server (interactive TUI preserved)   │
│  5. Bridge handles all approvals via WebSocket      │
│  6. Watch polls bridge REST API for approvals       │
└─────────────────────────────────────────────────────┘
```

**IMPORTANT: Claude runs in interactive TUI mode.** The `--sdk-url` flag is the ONLY
extra flag passed to Claude. No `--print`, no `--output-format`, no `-p ""`.
The user gets the normal Claude Code experience; the bridge operates out-of-band
via the WebSocket control channel.

## Happy Path Parity (cc-watch → remmy)

| cc-watch Command | remmy Equivalent | Behavior |
|------------------|------------------|----------|
| `npx cc-watch` | `bunx remmy-watch` | Pair (if needed) → launch bridge + Claude |
| `npx cc-watch setup` | `remmy setup` | Pair only, don't launch |
| `npx cc-watch run` | `remmy run` | Launch bridge + Claude (must be paired) |
| `npx cc-watch run --model opus` | `remmy run --model opus` | Extra args pass through to Claude directly |
| `npx cc-watch status` | `remmy status` | Check pairing + cloud + bridge probe |
| `npx cc-watch unpair` | `remmy unpair` | Remove ~/.remmy + legacy cc-watch artifacts |
| `npx cc-watch serve` | *(removed)* | Bridge replaces MCP server |
| `npx cc-watch help` | `remmy help` | Show help |
| `npx cc-watch --version` | `remmy --version` | Show version |

### Default Command Happy Path (1:1 parity)

**cc-watch flow:**
1. Show header
2. Check if paired → if not, show "Not paired" message
3. Verify cloud connectivity (latency check) — **informational when paired**
4. If unpaired: prompt for 6-digit code from watch → POST to cloud → save config
5. Install PreToolUse hook
6. Spawn `claude` with `CLAUDE_WATCH_SESSION_ACTIVE=1`
7. Wait for claude to exit

**remmy flow (NEW):**
1. Show header ("remmy" in cyan)
2. Check if paired → if not, show "Not paired" message
3. Verify cloud connectivity — **informational when paired** (prints status, does NOT block launch)
4. If unpaired: check cloud → prompt for 6-digit code → POST to cloud → save config
5. ~~Install hook~~ → Launch bridge server (`python -m MCPServer.bridge`)
6. Spawn `claude --sdk-url ws://localhost:{port}/ws/cli/{session_id}` (interactive TUI)
7. Wait for claude to exit
8. Stop bridge server on exit

## Project Structure

```
remmy-cli/
├── src/
│   ├── cli.ts                  # CLI entry point + command router
│   ├── commands/
│   │   ├── default.ts          # Default: pair + launch
│   │   ├── setup.ts            # Pair only
│   │   ├── run.ts              # Launch (must be paired)
│   │   ├── status.ts           # Check status
│   │   └── unpair.ts           # Remove config + legacy cleanup
│   ├── lib/
│   │   ├── bridge-launcher.ts  # Spawn Python bridge server
│   │   ├── claude-launcher.ts  # Spawn Claude CLI with --sdk-url
│   │   ├── cloud-client.ts     # Cloud relay HTTP client
│   │   └── config.ts           # ~/.remmy/config.json persistence
│   ├── ui/
│   │   ├── colors.ts           # ANSI color helpers (zero deps)
│   │   ├── spinner.ts          # CLI spinner (zero deps)
│   │   ├── prompt.ts           # readline-based text + confirm prompts
│   │   └── header.ts           # Remmy banner/header
│   ├── types.ts                # Type definitions
│   └── test/
│       └── setup.ts            # Test setup/globals
├── bridge/                     # Python bridge files (bundled for distribution)
│   └── (symlink or copy of MCPServer/bridge/)
├── scripts/
│   └── build.ts                # Build script (bun build --target node)
├── package.json
├── tsconfig.json
└── .gitignore
```

## Dependencies Strategy

**ZERO runtime deps.** cc-watch had 6:
- `chalk` → **Replace with 20-line ANSI helper** (`src/ui/colors.ts`)
- `ora` → **Replace with 30-line spinner** (`src/ui/spinner.ts`)
- `prompts` → **Replace with readline wrapper** (`src/ui/prompt.ts`)
- `tweetnacl` + `tweetnacl-util` → **Dropped** (encryption non-functional in cc-watch, deferred)
- `zod` → **Dropped** (TypeScript types + runtime checks)
- `@modelcontextprotocol/sdk` → **Dropped** (MCP server gone)

**Result: 0 runtime deps** vs 6 before.

**Dev deps:**
- `@types/bun` — Bun type definitions
- `typescript` — Type checking only (bun transpiles)

---

## Task Breakdown

### R1: Project Scaffold + Build Pipeline
**Files:** `package.json`, `tsconfig.json`, `scripts/build.ts`, `.gitignore`

**Acceptance Criteria:**
- R1.1: `bun install` succeeds with zero errors
- R1.2: `bun run build` produces `dist/cli.mjs` with `#!/usr/bin/env node` shebang
- R1.3: `dist/cli.mjs` is executable and runs on Node 20+
- R1.4: `bun run src/cli.ts --help` prints help text
- R1.5: `bun run src/cli.ts --version` prints version from package.json
- R1.6: `bun test` runs with zero config
- R1.7: package.json `bin` field: `{"remmy": "./dist/cli.mjs"}`

**Tests:**
```
R1.T1: build.test.ts — verify build script creates dist/cli.mjs with shebang
R1.T2: cli.test.ts — --help prints usage, --version prints semver
```

---

### R2: UI Utilities (Colors, Spinner, Prompt, Header)
**Files:** `src/ui/colors.ts`, `src/ui/spinner.ts`, `src/ui/prompt.ts`, `src/ui/header.ts`

**Acceptance Criteria:**
- R2.1: `colors.ts` exports: `red()`, `green()`, `yellow()`, `cyan()`, `dim()`, `bold()`, `white()`
- R2.2: Colors disabled when `NO_COLOR` env var is set or stdout is not a TTY
- R2.3: `spinner.ts` exports: `Spinner` class with `start(msg)`, `succeed(msg)`, `fail(msg)`, `stop()`
- R2.4: Spinner hides cursor on start, shows cursor on stop
- R2.5: `header.ts` exports: `showHeader()` printing "remmy" in cyan with version
- R2.6: `prompt.ts` exports: `askText(question, validate?)` → string, `askConfirm(question, defaultVal?)` → bool
- R2.7: Prompts handle Ctrl+C gracefully (return null or throw)
- R2.8: Prompts handle empty input with default values

**Tests:**
```
R2.T1: colors.test.ts — each color fn wraps text in correct ANSI codes
R2.T2: colors.test.ts — NO_COLOR disables formatting
R2.T3: spinner.test.ts — start/succeed/fail produce expected output patterns
R2.T4: header.test.ts — showHeader() output contains "remmy"
R2.T5: prompt.test.ts — askText returns user input
R2.T6: prompt.test.ts — askConfirm defaults to provided default
```

---

### R3: Config Persistence (~/.remmy/)
**Files:** `src/lib/config.ts`, `src/types.ts`

Carry forward from `cc-watch/src/config/pairing-store.ts` — rebrand + simplify (no encryption keys).

**Acceptance Criteria:**
- R3.1: Config dir is `~/.remmy/`, config file is `~/.remmy/config.json`
- R3.2: `readConfig()` returns `RemmyConfig | null`
- R3.3: `saveConfig(config)` writes atomically (write to .tmp, rename)
- R3.4: `deleteConfig()` removes config file and dir if empty
- R3.5: `isPaired()` returns true iff config exists and has pairingId
- R3.6: `createConfig(cloudUrl)` returns config with pairingId placeholder
- R3.7: Config stores: `pairingId`, `cloudUrl`, `createdAt`, `watchId` (optional)
- R3.8: Legacy migration: if `~/.claude-watch/config.json` exists, MOVE to `~/.remmy/` (copy + delete source)
- R3.9: `getConfigPath()` returns the config file path (for status display)

**Tests:**
```
R3.T1: config.test.ts — save/read roundtrip preserves all fields
R3.T2: config.test.ts — isPaired() true when config has pairingId
R3.T3: config.test.ts — isPaired() false when no config
R3.T4: config.test.ts — deleteConfig() removes file
R3.T5: config.test.ts — createConfig() returns valid structure with createdAt
R3.T6: config.test.ts — atomic write (writes .tmp then renames)
R3.T7: config.test.ts — legacy migration moves file
R3.T8: config.test.ts — getConfigPath() returns correct path
```

---

### R4: Cloud Client
**File:** `src/lib/cloud-client.ts`

Carry forward from `cc-watch/src/cloud/client.ts` — rebrand + simplify.

**Acceptance Criteria:**
- R4.1: `checkConnectivity(cloudUrl)` → `{connected: bool, latency?: number, error?: string}`
- R4.2: Timeout after 5s for connectivity check
- R4.3: `completePairing(cloudUrl, code)` → POST to `/pair/complete` → returns pairingId
- R4.4: Handles 404 (invalid/expired code) with user-friendly error
- R4.5: Default cloud URL constant is `https://remmy.watch`
- R4.6: Overridable via `REMMY_CLOUD_URL` env var

**Tests:**
```
R4.T1: cloud-client.test.ts — checkConnectivity returns connected=true on 200
R4.T2: cloud-client.test.ts — checkConnectivity returns connected=false on network error
R4.T3: cloud-client.test.ts — checkConnectivity times out after 5s
R4.T4: cloud-client.test.ts — completePairing returns pairingId on success
R4.T5: cloud-client.test.ts — completePairing handles 404 (expired code)
R4.T6: cloud-client.test.ts — default URL is https://remmy.watch
R4.T7: cloud-client.test.ts — REMMY_CLOUD_URL env var overrides default
```

---

### R5: Bridge Launcher
**File:** `src/lib/bridge-launcher.ts`

**NEW** — spawns the Python bridge server as a child process.

**Acceptance Criteria:**
- R5.1: `launchBridge(opts)` spawns `python -m MCPServer.bridge --port {port} --pairing-id {id}`
- R5.2: Returns `BridgeProcess` with `{process, port, pairingId}`
- R5.3: Waits for bridge to be healthy (polls `/health` on port+1) with 10s timeout
- R5.4: `stopBridge(bp)` sends SIGTERM, waits 3s, then SIGKILL
- R5.5: Detects if Python 3 is available, shows helpful error if not
- R5.6: Sets `PYTHONPATH` to locate the `MCPServer.bridge` package
- R5.7: Passes `--verbose` flag through when opts.verbose is true
- R5.8: Captures stderr for error reporting (logged on failure)
- R5.9: If default port is busy, tries next 5 ports (8787→8791)

**Tests:**
```
R5.T1: bridge-launcher.test.ts — constructs correct spawn args
R5.T2: bridge-launcher.test.ts — health check polling with mock fetch
R5.T3: bridge-launcher.test.ts — times out after 10s if bridge never healthy
R5.T4: bridge-launcher.test.ts — stopBridge sends SIGTERM then SIGKILL
R5.T5: bridge-launcher.test.ts — detects missing Python
R5.T6: bridge-launcher.test.ts — passes --verbose flag
R5.T7: bridge-launcher.test.ts — sets PYTHONPATH correctly
R5.T8: bridge-launcher.test.ts — port fallback on EADDRINUSE
```

---

### R6: Claude Launcher
**File:** `src/lib/claude-launcher.ts`

Spawns Claude CLI with `--sdk-url` pointing at the bridge. Interactive TUI mode.

**Acceptance Criteria:**
- R6.1: `launchClaude(opts)` spawns `claude --sdk-url ws://localhost:{port}/ws/cli/{sid}` — NO `--print`, NO `--output-format`, NO `-p ""`
- R6.2: Inherits stdio (`{stdio: "inherit"}`) so user gets normal Claude TUI
- R6.3: Returns a Promise that resolves with the exit code
- R6.4: Does NOT set `CLAUDE_WATCH_SESSION_ACTIVE=1` env var
- R6.5: Passes through extra args from user directly (e.g., `remmy run --model opus`)
- R6.6: Detects if `claude` binary is available, shows helpful error if not

**Tests:**
```
R6.T1: claude-launcher.test.ts — constructs args: only --sdk-url, no --print
R6.T2: claude-launcher.test.ts — inherits stdio
R6.T3: claude-launcher.test.ts — returns exit code
R6.T4: claude-launcher.test.ts — env does NOT contain CLAUDE_WATCH_SESSION_ACTIVE
R6.T5: claude-launcher.test.ts — passes extra args (--model opus)
R6.T6: claude-launcher.test.ts — detects missing claude binary
```

---

### R7: Command — Default (`bunx remmy-watch`)
**File:** `src/commands/default.ts`

Main happy path. 1:1 with cc-watch default command.

**Acceptance Criteria:**
- R7.1: Shows "remmy" header
- R7.2: If paired: shows pairing ID (truncated), verifies cloud (INFORMATIONAL — does NOT block launch), launches bridge + Claude
- R7.3: If unpaired: checks cloud (BLOCKING) → prompts for 6-digit code → pairs → saves config → launches
- R7.4: Pairing prompt validates 6-digit numeric input
- R7.5: Shows spinner during pairing ("Completing pairing...")
- R7.6: Shows "Launching Claude with watch approvals..." before spawn
- R7.7: Shows helpful messages: "Other `claude` sessions run normally."
- R7.8: On Claude exit, stops bridge and exits with same code
- R7.9: On Ctrl+C (SIGINT), stops bridge gracefully before exit
- R7.10: If bridge launch fails (no Python, port busy), shows helpful error and exits

**Tests:**
```
R7.T1: default.test.ts — paired flow: skips pairing, launches bridge + claude
R7.T2: default.test.ts — unpaired flow: prompts code, pairs, saves, launches
R7.T3: default.test.ts — validates 6-digit code input
R7.T4: default.test.ts — handles pairing failure gracefully
R7.T5: default.test.ts — stops bridge on claude exit
R7.T6: default.test.ts — handles Ctrl+C (SIGINT)
R7.T7: default.test.ts — cloud failure when paired is informational, launch continues
```

---

### R8: Commands — Setup, Run, Status, Unpair
**Files:** `src/commands/setup.ts`, `src/commands/run.ts`, `src/commands/status.ts`, `src/commands/unpair.ts`

1:1 parity with cc-watch equivalents (minus hook/MCP, plus legacy cleanup).

**Acceptance Criteria:**
- R8.1: `setup` — pair flow only, no launch. Shows "Run `remmy run` to start."
- R8.2: `setup` — if already paired, offers to reconfigure (confirm prompt)
- R8.3: `run` — guard: must be paired. Launches bridge + Claude
- R8.4: `run` — passes extra args directly to Claude (no `--` separator needed)
- R8.5: `status` — shows: pairing (ID, cloud URL, createdAt, watchId), cloud connectivity (latency), config path, bridge port probe (optional)
- R8.6: `status` — shows "Not paired" + "Run `remmy` to set up" when unconfigured
- R8.7: `unpair` — shows what will be deleted, confirms, deletes ~/.remmy/config.json
- R8.8: `unpair` — shows "Run `remmy` to set up again."
- R8.9: `unpair` — also checks for and removes legacy cc-watch artifacts:
  - `~/.claude/hooks/watch-approval-cloud.py`
  - PreToolUse hook entry in `~/.claude/settings.json`
  - `claude-watch` server entry in `~/.claude/.mcp.json`

**Tests:**
```
R8.T1: setup.test.ts — runs pairing, saves config, does not launch
R8.T2: setup.test.ts — offers reconfigure when already paired
R8.T3: run.test.ts — rejects if not paired
R8.T4: run.test.ts — launches bridge + claude when paired
R8.T5: run.test.ts — passes extra args directly (no -- needed)
R8.T6: status.test.ts — shows pairing info, cloud connectivity, config path
R8.T7: status.test.ts — shows "not paired" when unconfigured
R8.T8: unpair.test.ts — deletes config after confirmation
R8.T9: unpair.test.ts — cancellation preserves config
R8.T10: unpair.test.ts — removes legacy cc-watch hooks and MCP config
```

---

### R9: CLI Entry Point + Command Router
**File:** `src/cli.ts`

**Acceptance Criteria:**
- R9.1: Routes: `""` → default, `"setup"`, `"run"`, `"status"`, `"unpair"`, `"help"`, `"--help"`, `"-h"`, `"version"`, `"--version"`, `"-v"`
- R9.2: Supports global flags: `--verbose`
- R9.3: Unknown command prints error + help text, exits code 1
- R9.4: `--help` / `help` prints full usage with all commands listed
- R9.5: `--version` / `version` reads version from package.json
- R9.6: Shebang is `#!/usr/bin/env node` (for npm compat)
- R9.7: Top-level error handler catches unhandled rejections

**Tests:**
```
R9.T1: cli.test.ts — routes "setup" to setup handler
R9.T2: cli.test.ts — routes "" to default handler
R9.T3: cli.test.ts — unknown command exits with code 1
R9.T4: cli.test.ts — --help prints usage text with all commands
R9.T5: cli.test.ts — --version prints semver
R9.T6: cli.test.ts — bare "version" also prints version
```

---

## What's NOT Included (out of scope)

- MCP server (`serve` command) — bridge replaces this
- Hook installation — bridge replaces hooks
- MCP config management — not needed
- `CLAUDE_WATCH_SESSION_ACTIVE` env var — bridge uses `--sdk-url` instead
- E2E encryption (tweetnacl) — non-functional in cc-watch, deferred
- Compiled binary distribution — future work
- `--resume` session recovery — deferred (bridge handles internally)

---

## Build & Test Commands

```bash
# Development
bun run src/cli.ts                  # Run from source
bun run src/cli.ts --help           # Help text
bun test                            # Run all tests
bun test --watch                    # Watch mode

# Build for npm
bun run build                       # → dist/cli.mjs

# Type check
bun run typecheck                   # tsc --noEmit

# Publish
bun publish --dry-run               # Verify
bun publish                         # Ship it
```

---

## Task Dependency Graph

```
R1 (scaffold) ──┬──→ R2 (UI: colors, spinner, prompt, header)
                │
                ├──→ R3 (config ~/.remmy/)
                │
                ├──→ R4 (cloud client)
                │
                ├──→ R5 (bridge launcher)
                │
                └──→ R6 (claude launcher)

R2 + R3 + R4 + R5 + R6 ──→ R7 (default command)
                            R8 (setup/run/status/unpair)
                            R9 (CLI router)
```

**Wave 1 (parallel):** R1, R2, R3, R4, R5, R6 — all independent
**Wave 2 (parallel after wave 1):** R7, R8, R9 — depend on wave 1

---

## Quality Criteria

Each task rated 1-10 by eng lead on:
- **Correctness**: Does it meet all acceptance criteria?
- **Tests**: Do tests cover the ACs? Are they meaningful?
- **Code quality**: Clean, minimal, well-typed, zero unnecessary deps?
- **Parity**: Does the user-facing behavior match cc-watch 1:1?
