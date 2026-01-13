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
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│ Claude Code │──MCP──│   Server    │──5G───│ Apple Watch │
│  (on Mac)   │       │  (Bridge)   │       │  (on wrist) │
└─────────────┘       └──────┬──────┘       └─────────────┘
                             │
                             ▼
                     Push Notifications
                        via APNs
```

**Claude Watch** hooks into Claude Code via MCP. When Claude needs your approval:

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
- Network tunnel (Tailscale, ngrok, or Cloudflare)

### 1️⃣ Clone & Install

```bash
git clone https://github.com/anthropics/claude-watch.git
cd claude-watch

# Install server dependencies
cd MCPServer
pip install -r requirements.txt
```

### 2️⃣ Start the Server

```bash
python server.py --standalone --port 8787
```

### 3️⃣ Expose to Internet

```bash
# Option A: Tailscale (recommended)
tailscale serve 8787

# Option B: ngrok
ngrok http 8787

# Option C: Cloudflare
cloudflared tunnel --url http://localhost:8787
```

### 4️⃣ Build & Run Watch App

```bash
open ClaudeWatch.xcodeproj
# Select your Apple Watch target → Run (⌘R)
```

### 5️⃣ Configure & Connect

In the watch app: **Settings** → Enter your tunnel URL → **Connect**

<br/>

---

<br/>

## 🏗️ Architecture

```
claude-watch/
│
├── 📱 ClaudeWatch/              # watchOS App
│   ├── App/                     # Entry point + notification handling
│   ├── Views/                   # SwiftUI (single MainView)
│   ├── Services/                # WebSocket client
│   └── Complications/           # Watch face widgets
│
└── 🖥️ MCPServer/                # Python Server
    └── server.py                # MCP + WebSocket + APNs
```

### Communication Flow

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│   Claude Code                                                  │
│       │                                                        │
│       │ MCP Protocol                                           │
│       ▼                                                        │
│   ┌─────────┐    WebSocket     ┌─────────────┐                │
│   │ Server  │◄────────────────►│ Apple Watch │                │
│   └────┬────┘                  └─────────────┘                │
│        │                              ▲                        │
│        │ APNs Push                    │                        │
│        └──────────────────────────────┘                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### MCP Tools

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

</td>
<td>

### 🚧 In Progress
- [ ] TestFlight beta
- [ ] App Store submission
- [ ] Companion iOS app

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

### Run Server in Development

```bash
cd MCPServer
python server.py --standalone --port 8787

# Server runs on:
# - WebSocket: ws://localhost:8787
# - REST API:  http://localhost:8788
```

### Test Without Watch

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

<br/>

---

<br/>

## 🤝 Contributing

We're looking for contributors! Areas where we need help:

- 🎨 **Design** — UI/UX improvements for the watch interface
- 🍎 **iOS** — Companion app for non-cellular watches
- 🤖 **Android** — Wear OS port
- 📝 **Docs** — Tutorials, guides, videos

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

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

<p align="center">
  <a href="https://github.com/anthropics/claude-watch/stargazers">⭐ Star us on GitHub</a>
  •
  <a href="https://twitter.com/anthropaboromicclaude">🐦 Follow for updates</a>
  •
  <a href="https://discord.gg/claudecode">💬 Join Discord</a>
</p>

<br/>

<p align="center">
  <sub>Made with ❤️ and way too much ☕</sub>
</p>
