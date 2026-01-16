<p align="center">
  <img src="https://img.shields.io/badge/watchOS-10.0+-FF6B35?style=for-the-badge&logo=apple&logoColor=white" alt="watchOS 10.0+"/>
  <img src="https://img.shields.io/badge/Swift-5.9+-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.9+"/>
  <img src="https://img.shields.io/badge/MCP-Protocol-8B5CF6?style=for-the-badge" alt="MCP Protocol"/>
  <img src="https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge" alt="MIT License"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Coming%20Soon-FF3366?style=flat-square" alt="Coming Soon"/>
  <img src="https://img.shields.io/badge/Beta-Testers%20Wanted-8B5CF6?style=flat-square" alt="Beta Testers Wanted"/>
</p>

<br/>

<h1 align="center">
  <br/>
  ⌚ Claude Watch
  <br/>
</h1>

<h3 align="center">
  <em>The first wearable interface for AI-assisted coding.</em>
  <br/>
  <strong>Approve code changes from your wrist. No phone. No laptop. Just tap.</strong>
</h3>

<br/>

<p align="center">
  <a href="#-the-problem">Problem</a> •
  <a href="#-the-solution">Solution</a> •
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-roadmap">Roadmap</a>
</p>

<br/>

---

<br/>

## 🎬 See It In Action

```
                    ┌─────────────────────────────────┐
   *buzz* *buzz*    │ 🔧 Claude: File Edit            │
                    │                                 │
  You look down     │ src/auth/login.py               │
  at your watch     │ "Add rate limiting to           │
        ↓           │  prevent brute force..."        │
                    │                                 │
                    │  [Approve]  [Reject]  [Open]    │
                    └─────────────────────────────────┘
                                   │
                              tap Approve
                                   │
                                   ▼
                      ✓ Claude continues coding
                        You continue walking
```

**Your AI pair programmer, now on your wrist.**

<br/>

---

<br/>

## 😤 The Problem

You're using Claude Code. It's incredible. But...

- 🚶 You step away from your desk for coffee
- 💻 Claude needs approval for a file edit
- ⏳ Your AI sits there. Waiting. Blocked.
- 😫 You come back 10 minutes later to find... nothing happened

**Every context switch kills your AI's momentum.**

<br/>

## 💡 The Solution

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│ Claude Code │──HTTP──►│ Cloudflare Worker│◄──HTTP──│ Apple Watch │
│  (on Mac)   │         │  (Cloud Relay)   │         │  (on wrist) │
└─────────────┘         └────────┬─────────┘         └─────────────┘
       ▲                         │                          │
       │                         ▼                          │
       │                   APNs (optional)                  │
       │                         │                          │
       └─────────polling─────────┴──────────polling─────────┘
```

**Claude Watch** uses a cloud relay. When Claude needs your approval:

1. 📱 Your watch buzzes
2. 👀 You glance at your wrist
3. 👆 Tap **Approve**
4. ✅ Claude continues — you never broke stride

**No phone. No laptop. No app to open. Just tap the notification.**

<br/>

---

<br/>

## ✨ Features

<table>
<tr>
<td width="50%">

### 🔔 Actionable Notifications
Approve or reject directly from the notification banner. The app doesn't even need to open.

### 🎯 Single-Screen UI
Everything you need, nothing you don't. Status, pending actions, voice input — one glance.

### 🎤 Voice Commands
*"Run the tests"*
*"Fix the errors"*
*"Commit with message auth hotfix"*

</td>
<td width="50%">

### 🔄 Mode Cycling
Just like Claude Code's `Shift+Tab`:
- **Normal** → Approve each action
- **Auto** → YOLO mode, approve all
- **Plan** → Read-only research

### ⌚ Complications
See progress right on your watch face. No app launch needed.

### 📳 Haptic Feedback
Different vibration patterns for different events. You'll *feel* when something needs attention.

</td>
</tr>
</table>

<br/>

---

<br/>

## 🖼️ Screenshots

<p align="center">
  <em>Coming soon — currently in active development</em>
</p>

<p align="center">
  <code>┌─────────────────────────┐</code><br/>
  <code>│ ● REFACTORING      73%  │</code><br/>
  <code>│ ▓▓▓▓▓▓▓░░░              │</code><br/>
  <code>│ RUNNING            AUTO │</code><br/>
  <code>├─────────────────────────┤</code><br/>
  <code>│ ✏️ Edit login.py         │</code><br/>
  <code>│ [Approve] [Reject]      │</code><br/>
  <code>├─────────────────────────┤</code><br/>
  <code>│ 🎤 Voice Command         │</code><br/>
  <code>├─────────────────────────┤</code><br/>
  <code>│ ⚡ AUTO        → PLAN    │</code><br/>
  <code>└─────────────────────────┘</code>
</p>

<br/>

---

<br/>

## 🚀 Quick Start

### Prerequisites

- Apple Watch Series 6+ with watchOS 10+
- Mac with Claude Code CLI installed
- Xcode 15+ (for building)

### Option A: Cloud Mode (Recommended)

Works anywhere with internet — walk your dog, go to a coffee shop, etc.

**1️⃣ Generate Pairing Code**

```bash
curl -X POST https://claude-watch.fotescodev.workers.dev/pair
# Returns: {"code": "ABC-123", "pairingId": "...", "expiresIn": 600}
```

**2️⃣ Enter Code on Watch**

Open the watch app → Settings (gear icon) → **Pair with Code** → Enter code

**3️⃣ Send Approval Requests**

```bash
# From Claude Code or any script:
curl -X POST https://claude-watch.fotescodev.workers.dev/request \
  -H "Content-Type: application/json" \
  -d '{"pairingId": "YOUR_PAIRING_ID", "type": "bash", "title": "npm test"}'
# Returns: {"requestId": "abc123"}
```

**4️⃣ Poll for Response**

```bash
curl https://claude-watch.fotescodev.workers.dev/request/abc123
# Returns: {"status": "approved"} or {"status": "rejected"} or {"status": "pending"}
```

### Option B: Local WebSocket Mode

For local development or when you don't want cloud dependency.

```bash
# 1. Start server
cd MCPServer && python server.py --standalone --port 8787

# 2. Expose via tunnel (Tailscale/ngrok/Cloudflare)
tailscale serve 8787

# 3. In watch app: Settings → Enter ws://your-url:8787 → Connect
```

<br/>

---

<br/>

## 🏗️ Architecture

```
claude-watch/
│
├── 📱 ClaudeWatch/              # watchOS App (Swift/SwiftUI)
│   ├── App/                     # Entry point + notification handling
│   │   └── ClaudeWatchApp.swift # AppDelegate, notification categories
│   ├── Views/                   # SwiftUI views
│   │   ├── MainView.swift       # Main UI with action queue
│   │   └── PairingView.swift    # Pairing code entry
│   ├── Services/                # Business logic
│   │   └── WatchService.swift   # Cloud polling, WebSocket, state
│   └── Complications/           # Watch face widgets
│
├── 🌐 MCPServer/worker/         # Cloudflare Worker (JavaScript)
│   ├── src/index.js             # Cloud relay API
│   ├── wrangler.toml            # Cloudflare config
│   └── package.json             # Dependencies
│
└── 🖥️ MCPServer/                # Local Python Server (optional)
    └── server.py                # MCP + WebSocket + APNs
```

### Cloud Mode Flow (Production)

```
┌───────────────────────────────────────────────────────────────────────────┐
│                                                                           │
│  1. PAIRING                                                               │
│  ───────────────────────────────────────────────────────────────────────  │
│  Claude Code                    Cloudflare                   Watch        │
│       │                              │                          │         │
│       │─── POST /pair ──────────────►│                          │         │
│       │◄── {code: "ABC-123"} ───────│                          │          │
│       │                              │                          │         │
│       │         User shows code      │◄── POST /pair/complete ──│         │
│       │         on terminal          │    {code, deviceToken}   │         │
│       │                              │                          │         │
│                                                                           │
│  2. REQUEST/RESPONSE                                                      │
│  ───────────────────────────────────────────────────────────────────────  │
│  Claude Code                    Cloudflare                   Watch        │
│       │                              │                          │         │
│       │─── POST /request ───────────►│                          │         │
│       │    {pairingId, type, title}  │─── APNs push (optional) ─►│        │
│       │                              │                          │         │
│       │                              │◄── GET /requests/{id} ────│ (poll) │
│       │                              │    returns pending list   │ every  │
│       │                              │                          │ 2 sec   │ 
│       │                              │◄── POST /respond/{id} ────│        │
│       │                              │    {approved: true}       │        │
│       │                              │                           │        │
│       │◄── GET /request/{id} ─────── │                           │        │
│       │    {status: "approved"}      │                           │        │
│       │                              │                           │        │
└───────────────────────────────────────────────────────────────────────────┘
```

### Cloud Relay API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/pair` | POST | Generate 6-char pairing code (expires 10 min) |
| `/pair/complete` | POST | Watch completes pairing with code + device token |
| `/pair/:id/status` | GET | Check if pairing is complete |
| `/request` | POST | Send approval request (returns requestId) |
| `/request/:id` | GET | Poll for response status |
| `/requests/:pairingId` | GET | List pending requests (for watch polling) |
| `/respond/:id` | POST | Watch sends approve/reject |
| `/health` | GET | Health check |

### Local WebSocket Mode (Development)

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│   Claude Code                                                  │
│       │                                                        │
│       │ MCP Protocol                                           │
│       ▼                                                        │
│   ┌─────────┐    WebSocket     ┌─────────────┐                 │
│   │ Server  │◄────────────────►│ Apple Watch │                 │
│   └────┬────┘                  └─────────────┘                 │
│        │                              ▲                        │
│        │ APNs Push                    │                        │
│        └──────────────────────────────┘                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### MCP Tools (Local Mode)

| Tool | Description |
|------|-------------|
| `watch_request_approval` | Block until watch approves/rejects |
| `watch_notify` | Send notification to watch |
| `watch_update_progress` | Update progress indicator |
| `watch_set_task` | Set current task name |
| `watch_complete_task` | Mark task as done |

<br/>

---

<br/>

## 🗺️ Roadmap

<table>
<tr>
<td>

### ✅ Done
- [x] WebSocket real-time sync
- [x] Actionable push notifications
- [x] Mode cycling (Normal/Auto/Plan)
- [x] Voice commands
- [x] Watch face complications
- [x] Haptic feedback patterns
- [x] **Cloud relay (Cloudflare Worker)**
- [x] **Pairing flow with 6-char codes**
- [x] **Remote approval via polling**

</td>
<td>

### 🚧 In Progress
- [ ] APNs push notifications
- [ ] TestFlight beta
- [ ] App Store submission

</td>
<td>

### 🔮 Future
- [ ] Multi-session support
- [ ] Diff preview on watch
- [ ] Siri integration
- [ ] Android Wear OS port

</td>
</tr>
</table>

<br/>

---

<br/>

## 🧑‍💻 For Developers

### Deploy Your Own Cloud Relay

```bash
cd MCPServer/worker

# Install wrangler
npm install

# Login to Cloudflare
npx wrangler login

# Create KV namespaces
npx wrangler kv:namespace create PAIRINGS
npx wrangler kv:namespace create REQUESTS

# Update wrangler.toml with your namespace IDs

# Deploy
npx wrangler deploy
# → https://your-worker.your-subdomain.workers.dev
```

### Test Cloud Relay API

```bash
# 1. Create pairing
curl -X POST https://claude-watch.fotescodev.workers.dev/pair
# → {"code":"ABC-123","pairingId":"...","expiresIn":600}

# 2. Complete pairing (simulating watch)
curl -X POST https://claude-watch.fotescodev.workers.dev/pair/complete \
  -H "Content-Type: application/json" \
  -d '{"code":"ABC-123","deviceToken":"test"}'

# 3. Send request
curl -X POST https://claude-watch.fotescodev.workers.dev/request \
  -H "Content-Type: application/json" \
  -d '{"pairingId":"YOUR_ID","type":"bash","title":"npm test"}'
# → {"requestId":"abc123"}

# 4. Respond (simulating watch)
curl -X POST https://claude-watch.fotescodev.workers.dev/respond/abc123 \
  -H "Content-Type: application/json" \
  -d '{"approved":true}'

# 5. Check status
curl https://claude-watch.fotescodev.workers.dev/request/abc123
# → {"status":"approved"}
```

### Run Local WebSocket Server

```bash
cd MCPServer
python server.py --standalone --port 8787

# Server runs on:
# - WebSocket: ws://localhost:8787
# - REST API:  http://localhost:8788
```

### Test Local Server Without Watch

```bash
# Get current state
curl http://localhost:8788/state

# Simulate approval
curl -X POST http://localhost:8788/action/respond \
  -H "Content-Type: application/json" \
  -d '{"action_id": "test123", "approved": true}'
```

### Add to Claude Code (MCP)

```json
// ~/.claude/settings.json
{
  "mcpServers": {
    "watch": {
      "command": "python",
      "args": ["/path/to/MCPServer/server.py"]
    }
  }
}
```

### Key Files

| File | Description |
|------|-------------|
| `MCPServer/worker/src/index.js` | Cloudflare Worker - all API endpoints |
| `MCPServer/worker/wrangler.toml` | Cloudflare config, KV namespace bindings |
| `ClaudeWatch/Services/WatchService.swift` | Watch app service - polling, state, API calls |
| `ClaudeWatch/Views/MainView.swift` | Main UI - action queue, approve/reject buttons |
| `ClaudeWatch/Views/PairingView.swift` | Pairing code entry UI |
| `ClaudeWatch/App/ClaudeWatchApp.swift` | App entry, notification handling |

<br/>

---

<br/>

## 📜 License

MIT License — see [LICENSE](LICENSE) for details.

<br/>

---

<br/>

<p align="center">
  <strong>Built for developers who code on the move.</strong>
  <br/>
  <em>Inspired by the <a href="https://reddit.com/r/vibecoding">vibecoding</a> hardware control deck.</em>
</p>

<br/>

<p align="center">
  <sub>Made with ❤️ and way too much ☕</sub>
</p>
