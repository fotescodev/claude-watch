# Claude Watch

Control Claude Code from your Apple Watch. Approve actions, track progress, and receive notifications.

## Quick Start

```bash
npx cc-watch
```

Enter the pairing code shown on your Apple Watch to connect.

## Commands

| Command | Description |
|---------|-------------|
| `npx cc-watch` | Interactive setup wizard |
| `npx cc-watch status` | Check connection status |
| `npx cc-watch serve` | Start MCP server (called by Claude Code) |
| `npx cc-watch unpair` | Remove configuration |

## How It Works

1. **Pair** - Run `npx cc-watch` and enter the code on your watch
2. **Configure** - Claude Code's MCP config is updated automatically
3. **Use** - Claude will send approval requests to your watch

## MCP Tools

When paired, Claude Code gets access to these tools:

- `watch_notify` - Send notifications to your watch
- `watch_request_approval` - Request approval for actions
- `watch_update_progress` - Update task progress
- `watch_set_task` - Set current task name
- `watch_complete_task` - Mark task complete
- `watch_get_state` - Get session state

## Requirements

- Node.js 18+
- Apple Watch with Claude Watch app
- Claude Code CLI

## License

MIT
