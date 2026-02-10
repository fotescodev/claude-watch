# Analysis: Claude Code `--sdk-url` WebSocket Protocol

> **Source**: [fotescodev/remmy-websocket](https://github.com/fotescodev/remmy-websocket) (aka "The Vibe Companion")
> **Date**: 2026-02-10
> **Status**: Research / Inbox

## Summary

The Vibe Companion reverse-engineered a hidden `--sdk-url` flag in Claude Code CLI (v2.1.37). When set, the CLI acts as a WebSocket client connecting to YOUR server using NDJSON protocol. This is the same protocol used by Claude Code's web UI.

## Key Discovery

```bash
claude --sdk-url ws://localhost:8765 \
       --print \
       --output-format stream-json \
       --input-format stream-json \
       --verbose \
       -p ""
```

The CLI connects TO your server (not the other way around). Messages are NDJSON — one JSON object per `\n`-terminated line.

## Why This Matters for Claude Watch

### Problems It Solves

| Current Problem | `--sdk-url` Solution |
|----------------|---------------------|
| Hook can't intercept `AskUserQuestion` | ALL tool calls arrive as `can_use_tool` requests |
| stdin injection failed (Phase 10) | Responses go back over WebSocket |
| Pairing ID mismatch | Single WebSocket connection |
| Polling latency (2-5s) | Real-time WebSocket push |
| Question pipeline breaks | Direct: CLI → WS → bridge → watch → bridge → WS → CLI |
| Watch can only approve/reject | `updatedInput` can modify tool args before allowing |

### The Multiple Questions Fix

With `--sdk-url`, `AskUserQuestion` arrives as a `can_use_tool` control request with full question/options payload. The bridge can:
1. Inspect the input (see question text + options)
2. Transform for watch (extract recommended option)
3. Respond with `updatedInput` containing the selected answer

This completely bypasses the stdin injection problem.

## Protocol Overview

### Message Types (CLI → Server)
- `system/init` — Session initialization (tools, model, capabilities)
- `assistant` — Full LLM response
- `stream_event` — Token-by-token streaming (if `--verbose`)
- `result` — Query complete (success/error)
- `control_request` — Permission requests (`can_use_tool`)
- `tool_progress` — Heartbeat during tool execution
- `keep_alive` — Keepalive

### Message Types (Server → CLI)
- `user` — Send prompts
- `control_response` — Allow/deny tool use
- `control_request` — Interrupt, set_model, set_permission_mode

### Permission Flow
```
CLI: { type: "control_request", request_id: "uuid", request: { subtype: "can_use_tool", tool_name: "Bash", input: {...} } }
Server: { type: "control_response", response: { subtype: "success", request_id: "uuid", response: { behavior: "allow", updatedInput: {...} } } }
```

### Initialize (before first user message)
The `initialize` control request can register hooks, MCP servers, system prompts, and custom agents before the CLI starts. This could replace our `CLAUDE_WATCH_SESSION_ACTIVE=1` approach.

## Reusable Components

### From Their Codebase
1. **Message types** (`session-types.ts`) — Full TypeScript type defs for all CLI messages
2. **Permission flow** (`ws-bridge.ts`) — Clean request → pending map → response pattern
3. **CLI launcher** (`cli-launcher.ts`) — Process lifecycle, --resume support
4. **Session persistence** — Disk-backed store, reconnection replay
5. **Protocol doc** (`WEBSOCKET_PROTOCOL_REVERSED.md`) — 1356 lines, fully typed

### Edge Cases They Handle
- Session persistence across server restarts
- CLI process death + auto-relaunch with `--resume`
- Message queuing when CLI isn't connected yet
- Permission cancellation on CLI disconnect
- Context compaction notifications
- Multiple concurrent tool calls (Map-based pending permissions)

## Proposed Integration Path

1. **Phase 1**: Port bridge server to Python (extend `server.py`) or run as sidecar
2. **Phase 2**: Modify `cc-watch` to launch `claude --sdk-url ws://bridge:port`
3. **Phase 3**: Connect bridge to cloud relay (or direct WebSocket to watch)
4. **Phase 4**: Handle `AskUserQuestion` via `updatedInput`

## Architecture Comparison

```
CURRENT:
  Claude Code → PreToolUse Hook → Cloud Worker → Watch (polls) → Cloud → Hook → Claude
                     ↓ (broken for AskUserQuestion)
                  stdin-proxy → failed (Phase 10)

PROPOSED:
  claude --sdk-url ws://bridge → Bridge Server → Cloud/Watch (push)
                               ←               ← Watch approve/deny
```

## References
- Full protocol: `WEBSOCKET_PROTOCOL_REVERSED.md` (cloned to /tmp/remmy-websocket/)
- Their bridge: `web/server/ws-bridge.ts` (730 lines)
- Their launcher: `web/server/cli-launcher.ts` (492 lines)
- Their types: `web/server/session-types.ts` (239 lines)
