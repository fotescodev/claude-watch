# Claude Watch

Control Claude Code from your wrist. Get tapped when approval is needed, tap to approve — no phone required.

```
┌────────────────────────────────────────┐
│  🔧 Claude: File Edit                  │
│  Update auth/login.py                  │
│  "Add rate limiting to prevent..."     │
│                                        │
│  [Approve]  [Reject]  [Open App]       │
└────────────────────────────────────────┘
          ↓ tap Approve
     Claude continues working
```

## How It Works

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│ Claude Code │ ──MCP──▶│   Server    │──WebSocket──▶│ Apple Watch │
│   (CLI)     │         │ (your Mac)  │◀─────────────│   (5G)     │
└─────────────┘         └──────┬──────┘         └─────────────┘
                               │
                               ▼
                         Push via APNs
                        (optional but best)
```

1. **MCP Server** runs alongside Claude Code, hooking into tool execution
2. When Claude needs approval, server sends **push notification** to your watch
3. You tap **Approve** or **Reject** right from the notification
4. Response flows back through WebSocket
5. Claude continues (or stops)

**No polling. No iPhone needed. Just a tap.**

## Features

### Actionable Notifications
The killer feature. When Claude wants to edit a file or run a command:

```
┌─────────────────────────────────┐
│ 🔧 Claude: File Edit            │
│ src/auth/login.py               │
│ "Add rate limiting..."          │
│                                 │
│ [Approve] [Reject] [Approve All]│
└─────────────────────────────────┘
```

Tap directly from notification — app doesn't even need to open.

### Single-Screen UI
When you do open the app, everything is on one screen:

```
┌─────────────────────────┐
│ ● REFACTORING      73%  │  ← Status
│ ▓▓▓▓▓▓▓░░░              │
│ RUNNING            YOLO │
├─────────────────────────┤
│ ┌─────────────────────┐ │
│ │ ✏️ Edit login.py     │ │  ← Pending action
│ │ [Approve] [Reject]  │ │
│ └─────────────────────┘ │
├─────────────────────────┤
│ [→][✓][🐛][■]          │  ← Quick prompts
├─────────────────────────┤
│ 🎤 Voice Command        │  ← Dictation
├─────────────────────────┤
│ ⚡ YOLO            OFF   │  ← Auto-approve
└─────────────────────────┘
```

### Voice Commands
Hold the mic button and speak:
- "Continue"
- "Run the tests"
- "Fix the errors"
- "Stop and explain what you're doing"
- "Commit with message fixed login bug"

### Watch Face Complications
Glance at your watch face to see:
- **Circular**: Progress ring + pending count
- **Rectangular**: Task name, progress bar, status
- **Inline**: "REFACTOR 73% • 2"

### YOLO Mode
Toggle on to auto-approve everything. Live dangerously.

## Quick Start

### 1. Install the MCP Server

```bash
cd MCPServer
pip install -r requirements.txt
```

### 2. Add to Claude Code Settings

Edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "watch": {
      "command": "python",
      "args": ["/path/to/claude-watch/MCPServer/server.py", "--standalone", "--port", "8787"]
    }
  }
}
```

Or run standalone for testing:

```bash
python server.py --standalone --port 8787
```

### 3. Expose to Internet

Your watch needs to reach the server. Pick one:

**Tailscale (recommended)**
```bash
tailscale serve 8787
# Your URL: https://your-machine.tailnet-name.ts.net
```

**ngrok**
```bash
ngrok http 8787
# Your URL: https://abc123.ngrok.io
```

**Cloudflare Tunnel**
```bash
cloudflared tunnel --url http://localhost:8787
```

### 4. Configure Watch App

1. Open Claude Watch on Apple Watch
2. Tap gear icon (settings)
3. Enter your server URL: `wss://your-server-url`
4. Connection indicator turns green

### 5. Done!

Claude Code will now send notifications to your watch when it needs approval.

## Architecture

```
claude-watch/
├── MCPServer/
│   ├── server.py           # MCP + WebSocket + REST server
│   └── requirements.txt
│
└── ClaudeWatch/
    ├── App/
    │   └── ClaudeWatchApp.swift    # Entry point + notifications
    ├── Views/
    │   └── MainView.swift          # Single-screen UI
    ├── Services/
    │   └── WatchService.swift      # WebSocket client
    └── Complications/
        └── ComplicationViews.swift # Watch face widgets
```

### MCP Server Tools

The server exposes these tools to Claude Code:

| Tool | Description |
|------|-------------|
| `watch_request_approval` | Block until watch approves/rejects |
| `watch_notify` | Send notification to watch |
| `watch_update_progress` | Update progress bar |
| `watch_set_task` | Set current task name |
| `watch_complete_task` | Mark task complete |

### WebSocket Protocol

**Server → Watch:**
```json
{"type": "action_requested", "action": {...}}
{"type": "progress_update", "progress": 0.73}
{"type": "state_sync", "state": {...}}
```

**Watch → Server:**
```json
{"type": "action_response", "action_id": "abc", "approved": true}
{"type": "prompt", "text": "run the tests"}
{"type": "toggle_yolo", "enabled": true}
```

### Push Notifications (APNs)

For true push (no open connection needed):

1. Create APNs key in Apple Developer Portal
2. Run server with APNs config:
```bash
python server.py --standalone \
  --apns-key /path/to/key.p8 \
  --apns-key-id KEYID123 \
  --apns-team-id TEAMID \
  --bundle-id com.yourcompany.claudewatch
```

## Development

### Watch App

1. Open in Xcode 15+
2. Select Apple Watch target
3. Build and run

### Server Testing

```bash
# Run server
python server.py --standalone --port 8787

# Test endpoints (REST API on port 8788)
curl http://localhost:8788/state
curl -X POST http://localhost:8788/action/respond \
  -d '{"action_id": "abc", "approved": true}'
```

## Requirements

**Watch App**
- watchOS 10.0+
- Apple Watch with cellular (recommended)

**Server**
- Python 3.8+
- Claude Code CLI
- Tailscale/ngrok/Cloudflare for tunneling

## FAQ

**Do I need my iPhone nearby?**
No. Cellular Apple Watch connects directly to server.

**Does my Mac need to stay on?**
Yes, MCP server runs on your Mac. For untethered: run server in cloud or use web sessions.

**What if I miss a notification?**
Pending actions show in app. They timeout after 5 minutes.

**Battery impact?**
Minimal. WebSocket is efficient, push uses APNs (not polling).

---

*Inspired by the vibecoding hardware control deck.*
