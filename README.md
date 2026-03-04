<p align="center">
  <img src="https://img.shields.io/badge/watchOS-10.0+-FF6B35?style=for-the-badge&logo=apple&logoColor=white" alt="watchOS 10.0+"/>
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9+"/>
  <img src="https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge" alt="MIT License"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Beta-8B5CF6?style=flat-square" alt="Beta"/>
  <img src="https://img.shields.io/badge/TestFlight-Coming%20Soon-FF3366?style=flat-square" alt="TestFlight Coming Soon"/>
</p>

<br/>

<h1 align="center">
  <br/>
  Remmy
  <br/>
</h1>

<h3 align="center">
  <em>Approve Claude Code changes from your Apple Watch.</em>
  <br/>
  <strong>No phone. No laptop. Just tap.</strong>
</h3>

<br/>

```bash
# Install and pair in 30 seconds
cd remmy-cli && bun run build && npm link
remmy
# Enter the 6-digit code shown on your Apple Watch
```

<br/>

<p align="center">
  <a href="#the-problem">Problem</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#for-developers">For Developers</a>
</p>

<br/>

---

<br/>

## See It In Action

```
                    +------------------------------------+
   *buzz* *buzz*    |  Edit: src/auth/login.py           |
                    |                                    |
  You look down     |  "Add rate limiting to             |
  at your watch     |   prevent brute force..."          |
        |           |                                    |
        v           |   [Approve]     [Reject]           |
                    +------------------------------------+
                                   |
                              tap Approve
                                   |
                                   v
                      Claude continues coding.
                        You continue walking.
```

**Your AI pair programmer, now on your wrist.**

<br/>

---

<br/>

## The Problem

You're using Claude Code. It's incredible. But...

- You step away from your desk for coffee
- Claude needs approval for a file edit
- Your AI sits there. Waiting. Blocked.
- You come back 10 minutes later to find... nothing happened

**Every context switch kills your AI's momentum.**

<br/>

## How It Works

Remmy uses a [Claude Code hook](https://docs.anthropic.com/en/docs/claude-code/hooks) to intercept tool approval requests and route them to your Apple Watch through a Cloudflare Worker relay.

```
                                              +-------------------+
+-------------+   hook    +------------------+|                   |
| Claude Code | --------> | Cloudflare Worker|| <--- Apple Watch  |
|   (CLI)     |           | (cloud relay)    ||      (polls)      |
+-------------+           +------------------+|                   |
                                              +-------------------+
                               |
                               v
                          APNs (optional)
                      instant push notification
```

When Claude needs your approval:

1. Your watch buzzes
2. You glance at your wrist
3. Tap **Approve** or **Reject**
4. Claude continues -- you never broke stride

<br/>

---

<br/>

## Features

<table>
<tr>
<td width="50%">

### Actionable Notifications
Approve or reject directly from the notification banner. The app doesn't even need to open.

### Single-Screen UI
Status, pending actions, voice input -- one glance.

### Voice Commands
*"Run the tests"*
*"Fix the errors"*
*"Commit with message auth hotfix"*

</td>
<td width="50%">

### Mode Cycling
Just like Claude Code's `Shift+Tab`:
- **Normal** -- Approve each action
- **Auto** -- Approve all
- **Plan** -- Read-only research

### Watch Face Complications
See Claude's progress right on your watch face.

### Haptic Feedback
Different vibration patterns for different events. You'll *feel* when something needs attention.

</td>
</tr>
</table>

<br/>

---

<br/>

## Quick Start

### Prerequisites

- Apple Watch Series 6+ with watchOS 10+
- Mac with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [Bun](https://bun.sh) runtime (for building the CLI)
- Xcode 15+ (for building the watch app)

### 1. Build and install the CLI

```bash
cd remmy-cli
bun install
bun run build
npm link    # makes `remmy` available globally
```

### 2. Build and install the watch app

```bash
# Open in Xcode
open ClaudeWatch.xcodeproj

# Or build from command line
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

### 3. Pair and start coding

```bash
remmy
# 1. The watch app shows a 6-digit pairing code
# 2. Enter it in the CLI
# 3. Claude launches with watch approvals enabled
```

That's it. Claude Code now routes approval requests to your watch.

### CLI Commands

| Command | Description |
|---------|-------------|
| `remmy` | Pair (if needed) + install hook + launch Claude |
| `remmy run` | Launch Claude with watch approvals (must be paired) |
| `remmy setup` | Pair with watch only (no Claude launch) |
| `remmy status` | Show pairing and connectivity info |
| `remmy unpair` | Remove pairing and clean up |

<br/>

---

<br/>

## Architecture

Remmy has four components:

```
remmy/
|
+-- ClaudeWatch/                    # watchOS App (Swift/SwiftUI)
|   +-- App/                        # Entry point + AppDelegate
|   +-- Views/                      # SwiftUI views (16 files)
|   +-- Services/                   # WatchService, Encryption, Keychain
|   +-- Complications/              # Watch face widgets
|
+-- remmy-cli/                      # TypeScript CLI
|   +-- src/commands/               # default, run, setup, status, unpair
|   +-- src/lib/                    # cloud-client, config, hooks
|   +-- hooks/                      # watch-approval-cloud.py (bundled)
|
+-- claude-watch-cloud/             # Cloudflare Worker (TypeScript/Hono)
|   +-- src/index.ts                # Cloud relay API
|   +-- wrangler.toml               # Cloudflare config
|
+-- MCPServer/                      # Legacy/Advanced servers
    +-- bridge/                     # Bridge server (Python, 346+ tests)
    +-- worker/                     # Legacy Cloudflare Worker (JS)
    +-- server.py                   # Legacy standalone MCP server
```

### Primary Flow (Hooks-Based)

This is the default architecture. The CLI installs a [PreToolUse hook](https://docs.anthropic.com/en/docs/claude-code/hooks) that intercepts tool calls and routes them through the cloud.

```
1. PAIRING
   Watch                    Cloud                    CLI (remmy)
     |                        |                        |
     |-- POST /pair/initiate ->|                        |
     |<- {code: "123456"} ----|                        |
     |                        |                        |
     |   (user enters code)   |                        |
     |                        |<-- POST /pair/complete --|
     |-- GET /pair/status --->|                        |
     |<- {paired: true} ------|                        |

2. APPROVAL
   Claude CLI           Hook Script              Cloud              Watch
     |                      |                      |                   |
     |-- PreToolUse ------->|                      |                   |
     |                      |-- POST /approval --->|                   |
     |                      |                      |-- APNs push ----->|
     |                      |                      |<-- POST approve --|
     |                      |<-- GET /approval ----|                   |
     |<-- approve/deny -----|                      |                   |
```

### Cloud Relay API

The Cloudflare Worker (`claude-watch-cloud/`) provides these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/pair/initiate` | POST | Watch generates pairing code |
| `/pair/complete` | POST | CLI completes pairing with code |
| `/pair/status/:watchId` | GET | Watch polls for pairing completion |
| `/approval` | POST | Hook sends approval request |
| `/approval/:pairingId/:requestId` | GET | Hook polls for watch response |
| `/approval-queue/:pairingId` | GET | Watch lists pending approvals |
| `/approval/:requestId` | POST | Watch sends approve/reject |
| `/question` | POST | Hook sends question to watch |
| `/question/:id/answer` | POST | Watch answers question |
| `/session-progress` | POST | Hook sends progress update |
| `/session-progress/:pairingId` | GET | Watch polls progress |
| `/health` | GET | Health check |

### Advanced: Bridge Architecture

For richer capabilities (multi-option questions, token tracking, real-time streaming), an optional bridge server sits between Claude CLI and the cloud:

```
Claude CLI  <--NDJSON/WS-->  Bridge (Python)  <--REST-->  Cloud  <--poll-->  Watch
```

See [Architecture docs](.claude/ARCHITECTURE.md) for details. The bridge has 346+ tests and supports features not yet available in the hooks-based flow.

<br/>

---

<br/>

## For Developers

### Documentation

| Doc | Audience | Purpose |
|-----|----------|---------|
| **[Getting Started](docs/GETTING_STARTED.md)** | Users | Setup guide (simulator, device, troubleshooting) |
| **[Architecture](.claude/ARCHITECTURE.md)** | Developers | System design, data flows, component map |
| **[Data Flow](.claude/DATA_FLOW.md)** | Developers | API endpoint reference and flow traces |
| **[Agent Guide](.claude/AGENT_GUIDE.md)** | AI Agents | Task-based reading order for Claude sessions |
| **[APNs Setup](docs/APNS_SETUP_GUIDE.md)** | Developers | Push notification configuration |
| **[Simulator Setup](docs/SIMULATOR_SETUP_GUIDE.md)** | Developers | watchOS Simulator testing |
| **[E2E Testing](docs/E2E_TESTING.md)** | Developers | End-to-end test procedures |
| **[Solutions Index](docs/solutions/INDEX.md)** | Debugging | Previously solved problems by symptom |

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, coding standards, and how to run tests.

### Key Files

| File | Description |
|------|-------------|
| `ClaudeWatch/App/ClaudeWatchApp.swift` | App entry, notification handling |
| `ClaudeWatch/Views/MainView.swift` | Primary UI -- action queue, approve/reject |
| `ClaudeWatch/Services/WatchService.swift` | Cloud polling, state management |
| `remmy-cli/src/commands/default.ts` | CLI main flow -- pair + hook + launch |
| `remmy-cli/hooks/watch-approval-cloud.py` | PreToolUse hook (installed to `~/.claude/hooks/`) |
| `claude-watch-cloud/src/index.ts` | Cloudflare Worker -- cloud relay API |

### Environment Variables

| Variable | Purpose | Set By |
|----------|---------|--------|
| `CLAUDE_WATCH_SESSION_ACTIVE` | Gates watch approval mode | `remmy` CLI |
| `REMMY_CLOUD_URL` | Override cloud relay URL | User (optional) |
| `REMMY_DEBUG` | Enable verbose hook logging | User (optional) |

### Running Tests

```bash
# Bridge server tests (Python) -- expect 346+
python -m pytest MCPServer/bridge/tests/ -q

# CLI tests (TypeScript) -- must split due to bun mock isolation
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/

# Build watch app for simulator
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

### Deploy Your Own Cloud Relay

```bash
cd claude-watch-cloud

# Install dependencies
npm install

# Login to Cloudflare
npx wrangler login

# Deploy
npx wrangler deploy
# -> https://your-worker.your-subdomain.workers.dev
```

<br/>

---

<br/>

## License

MIT License -- see [LICENSE](LICENSE) for details.

<br/>

---

<br/>

<p align="center">
  <strong>Built for developers who code on the move.</strong>
</p>

<p align="center">
  <sub>Made with care and way too much coffee</sub>
</p>
