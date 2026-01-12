# Claude Watch

A WatchOS companion app for Claude Code - control your AI coding sessions from your wrist using Claude's web sessions feature.

![WatchOS](https://img.shields.io/badge/watchOS-10.0+-orange)
![Swift](https://img.shields.io/badge/Swift-5.9+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## How It Works

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│ Apple Watch │ ──5G──▶ │  Bridge Server   │ ──────▶ │  Claude Code    │
│  (cellular) │         │  (your machine)  │         │  Web Sessions   │
└─────────────┘         └──────────────────┘         └─────────────────┘
                               │
                               ▼
                        Exposed via:
                        • Tailscale
                        • ngrok
                        • Cloudflare Tunnel
```

The watch connects to a lightweight bridge server running on your dev machine. The bridge server uses Claude Code's `& "prompt"` syntax to spawn web sessions that run on Anthropic's infrastructure - no need to keep your laptop open!

## Features

### 🎛️ Control Deck Interface
- **OLED-style status display** showing task name, progress, model, and connection status
- **Action buttons**: Accept, Approve, Discard, Retry - all with haptic feedback
- **YOLO Mode toggle**: Auto-approve all actions with one tap
- **Digital Crown model switching**: Rotate to switch between Opus, Sonnet, and Haiku

### 📋 Actions Management
- View all pending actions in a scrollable list
- Swipe to accept or discard individual actions
- Approve all pending actions at once
- Real-time updates via polling

### 🎤 Voice Input
- Dictate prompts directly from your watch
- Quick prompt suggestions for common actions
- Recent prompts history

### ⌚ Watch Face Complications
- **Circular**: Progress ring with pending action count
- **Rectangular**: Full status with task name, progress bar, and model
- **Corner**: Compact progress gauge
- **Inline**: Text-based status for modular faces

### 📳 Haptic Feedback
- Distinct haptic patterns for different actions
- Celebration pattern when tasks complete
- Alert pattern for pending actions requiring attention

## Quick Start

### 1. Start the Bridge Server

```bash
cd BridgeServer
pip install -r requirements.txt
python server.py
```

### 2. Expose to Internet

Choose one:

**Tailscale (recommended for security):**
```bash
tailscale serve 8787
```

**ngrok (quick setup):**
```bash
ngrok http 8787
```

**Cloudflare Tunnel:**
```bash
cloudflared tunnel --url http://localhost:8787
```

### 3. Configure Watch App

1. Open Claude Watch on your Apple Watch
2. Go to Settings → Bridge Server
3. Enter your tunnel URL (e.g., `https://abc123.ngrok.io`)
4. Tap Connect

### 4. Start Coding!

Send prompts from your watch. They'll spawn as web sessions that:
- Run on Claude's infrastructure
- Continue even if your laptop sleeps
- Can be teleported back with `/teleport` when you're at your desk

## Architecture

```
ClaudeWatch/
├── App/
│   └── ClaudeWatchApp.swift       # App entry point
├── Models/
│   ├── SessionState.swift          # Data models
│   └── SessionManager.swift        # State management (uses bridge)
├── Views/
│   ├── ContentView.swift           # Main tab navigation
│   ├── ControlDeckView.swift       # Main control interface
│   ├── ActionsListView.swift       # Pending actions list
│   ├── QuickPromptsView.swift      # Prompt suggestions
│   ├── VoiceInputView.swift        # Voice dictation
│   ├── ModelPickerView.swift       # Model selection
│   └── SettingsView.swift          # Server URL config
├── Services/
│   ├── ClaudeBridgeService.swift   # HTTP API client
│   └── HapticService.swift         # Haptic feedback
├── Complications/
│   └── ComplicationViews.swift     # WidgetKit widgets
└── Assets.xcassets/

BridgeServer/
├── server.py                       # FastAPI bridge server
└── requirements.txt                # Python dependencies
```

## Bridge Server API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/status` | GET | Server health check |
| `/session` | POST | Create new web session |
| `/session/:id` | GET | Get session status |
| `/sessions` | GET | List all sessions |
| `/session/:id/approve` | POST | Approve pending action |
| `/session/:id/approveAll` | POST | Approve all actions |
| `/session/:id/discard` | POST | Discard pending action |
| `/session/:id/cancel` | POST | Cancel session |

### Example: Create Session

```bash
curl -X POST http://localhost:8787/session \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Fix the authentication bug in login.py"}'
```

Response:
```json
{
  "id": "a1b2c3d4",
  "prompt": "Fix the authentication bug in login.py",
  "status": "starting",
  "progress": 0.0,
  "task_name": "FIX THE AUTHENTICATION",
  "pending_actions": [],
  "created_at": "2024-01-15T10:30:00Z"
}
```

## UI Preview

### Control Deck (Main Screen)
```
┌─────────────────────────┐
│ TASK: FIX AUTH BUG  45% │
│ ▓▓▓▓▓▓░░░░░░░░         │
│ MODEL: OPUS 4.5  SUB:85%│
│ ● CONNECTED        YOLO │
├─────────────────────────┤
│ [✓ ACCEPT] [👍 APPROVE] │
│ [✗ DISCARD] [↻ RETRY]   │
├─────────────────────────┤
│ ⚡ YOLO MODE         OFF │
└─────────────────────────┘
```

## Workflow Example

1. **At your desk**: Start working on a feature in Claude Code
2. **Need to step away**: Send current task to web with `& "continue working on the auth feature"`
3. **On the go**: Monitor from your watch, approve file edits
4. **Back at desk**: Run `/teleport` to pull the session back to your terminal

## Requirements

### Watch App
- Xcode 15.0+
- watchOS 10.0+
- Apple Watch with cellular (for 5G connectivity)

### Bridge Server
- Python 3.8+
- Claude Code CLI installed
- Network tunnel (Tailscale/ngrok/Cloudflare)

## Security Notes

- The bridge server should only be exposed via authenticated tunnels
- Tailscale is recommended as it uses your private network
- Never expose the bridge server directly to the public internet
- The watch app stores the server URL securely in UserDefaults

## Contributing

Contributions welcome! Please read our contributing guidelines before submitting PRs.

## License

MIT License - see LICENSE file for details.

---

*Inspired by the vibecoding community's hardware control deck concept.*
