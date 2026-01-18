# cc-watch

Control Claude Code from your Apple Watch. Approve code changes, track progress, and receive notifications—all from your wrist.

[![npm version](https://img.shields.io/npm/v/cc-watch.svg)](https://www.npmjs.com/package/cc-watch)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Approve/Reject Actions** - Review and approve file edits, bash commands, and tool usage directly from your watch
- **Progress Tracking** - See real-time task progress with visual indicators
- **Push Notifications** - Get notified when Claude needs your attention
- **Voice Commands** - Approve or reject with Siri
- **Watch Complications** - Quick status glances from any watch face

## Quick Start

```bash
npx cc-watch
```

This launches the interactive setup wizard. Enter the pairing code displayed on your Apple Watch to connect.

## Installation

```bash
# Use directly with npx (recommended)
npx cc-watch

# Or install globally
npm install -g cc-watch
```

## Requirements

- Node.js 18+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- Apple Watch with watchOS 10+ running the Claude Watch app

## Commands

| Command | Description |
|---------|-------------|
| `npx cc-watch` | Interactive setup wizard |
| `npx cc-watch status` | Check connection status |
| `npx cc-watch serve` | Start MCP server (used by Claude Code) |
| `npx cc-watch unpair` | Remove configuration |
| `npx cc-watch help` | Show help message |

## How It Works

### 1. Pair Your Watch

Run `npx cc-watch` and enter the 6-digit code shown on your Apple Watch.

```
$ npx cc-watch

  Claude Watch Setup

  Enter the pairing code shown on your Apple Watch:
  > 123456

  ✓ Paired successfully!
  ✓ MCP configuration updated
```

### 2. Claude Code Integration

The setup wizard automatically adds cc-watch to your Claude Code MCP configuration at `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "claude-watch": {
      "command": "npx",
      "args": ["cc-watch", "serve"]
    }
  }
}
```

### 3. Use With Claude Code

When Claude performs actions that require approval, you'll receive a notification on your watch:

```
Claude wants to:
Edit src/index.ts
[Approve] [Reject]
```

Tap to approve or reject, or use voice commands: "Hey Siri, approve" or "Hey Siri, reject".

## MCP Tools

When paired, Claude Code gains access to these tools:

### `watch_notify`
Send a notification to your watch.

```typescript
{
  title: string,   // Notification title
  message: string  // Notification body
}
```

### `watch_request_approval`
Request approval for an action. Blocks until the user approves or rejects.

```typescript
{
  action_type: "file_edit" | "file_create" | "file_delete" | "bash" | "tool_use",
  title: string,        // Short action title
  description: string,  // Detailed description
  file_path?: string,   // File path (if applicable)
  command?: string      // Command (if bash action)
}
// Returns: { approved: boolean, timestamp: string }
```

### `watch_update_progress`
Update the progress indicator on the watch.

```typescript
{
  progress: number,    // 0.0 to 1.0
  task_name?: string   // Optional task name
}
```

### `watch_set_task`
Set the current task being worked on.

```typescript
{
  name: string,         // Task name
  description?: string  // Task description
}
```

### `watch_complete_task`
Mark the current task as complete.

```typescript
{
  success?: boolean  // Default: true
}
```

### `watch_get_state`
Get the current session state.

```typescript
// Returns: { connected: boolean, task: string | null, progress: number }
```

## Architecture

```
┌─────────────┐     WebSocket      ┌──────────────────┐
│ Apple Watch │◄──────────────────►│ Cloudflare Worker│
└─────────────┘                    └────────┬─────────┘
                                            │
                                            │ HTTP/SSE
                                            ▼
┌─────────────┐      MCP/stdio     ┌──────────────────┐
│ Claude Code │◄──────────────────►│   cc-watch CLI   │
└─────────────┘                    └──────────────────┘
```

The cc-watch CLI acts as an MCP server that Claude Code communicates with via stdio. It relays messages to your Apple Watch through a Cloudflare Worker that maintains WebSocket connections.

## Troubleshooting

### "Watch not connected"

1. Ensure your Apple Watch has the Claude Watch app open
2. Check that your watch has an internet connection
3. Try re-pairing: `npx cc-watch unpair && npx cc-watch`

### "MCP server not responding"

1. Restart Claude Code
2. Check the MCP configuration: `cat ~/.claude/claude_desktop_config.json`
3. Verify the cc-watch entry exists in `mcpServers`

### Check Status

```bash
npx cc-watch status
```

This shows your current pairing status and connection state.

## Privacy

- Pairing codes expire after 5 minutes
- Session data is stored only on the Cloudflare Worker edge (KV storage)
- No data is logged or stored permanently
- All communication is encrypted (HTTPS/WSS)

## Development

```bash
# Clone the repository
git clone https://github.com/fotescodev/claude-watch.git
cd claude-watch/claude-watch-npm

# Install dependencies
npm install

# Run in development mode
npm run dev

# Build
npm run build
```

## License

MIT

## Links

- [GitHub Repository](https://github.com/fotescodev/claude-watch)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [MCP Specification](https://modelcontextprotocol.io)
