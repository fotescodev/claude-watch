# WebSocket Connection Debugging

Debug WebSocket connectivity issues in Claude Watch.

## Architecture Overview

```
Watch App (WatchService.swift)
    ↓ WebSocket
Local Server (MCPServer/server.py:8787)
    OR
    ↓ HTTP Polling
Cloud Relay (Cloudflare Worker)
```

## Connection Status States

```swift
enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, nextRetryIn: TimeInterval)
}
```

## Debugging Steps

### 1. Check Server is Running
```bash
# Local server
curl http://localhost:8788/state

# Cloud relay
curl https://your-worker.workers.dev/health
```

### 2. Test WebSocket Connection
```bash
# Using websocat (brew install websocat)
websocat ws://localhost:8787
```

### 3. Monitor Watch Logs
```bash
# Stream watch simulator logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.anthropic.claudecode"'
```

### 4. Check Network Monitor State

In WatchService.swift, the `NWPathMonitor` tracks network availability:
- `.satisfied` = network available
- `.unsatisfied` = no network

### 5. Reconnection Logic

The service uses exponential backoff with jitter:
- Initial delay: 1 second
- Max delay: 60 seconds
- Max retries: 10
- Jitter: +/- 20%

## Common Issues

### "Handshake Timeout"
**Cause**: Server didn't respond within 10 seconds
**Fix**: Ensure server sends first message after connection

### "Pong Timeout"
**Cause**: No pong received within 10 seconds of ping
**Fix**: Check server implements ping/pong correctly

### "Network Unavailable"
**Cause**: Watch has no connectivity
**Fix**: Check WiFi/Bluetooth connectivity on simulator

### "Invalid URL"
**Cause**: Malformed WebSocket URL
**Fix**: Ensure URL starts with `ws://` or `wss://`

## Key Files

- `ClaudeWatch/Services/WatchService.swift:connect()` - Connection logic
- `ClaudeWatch/Services/WatchService.swift:handleWebSocketReceive()` - Message handling
- `MCPServer/server.py` - Local WebSocket server
