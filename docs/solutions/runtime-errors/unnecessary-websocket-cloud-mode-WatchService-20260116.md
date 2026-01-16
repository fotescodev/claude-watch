---
module: ClaudeWatch
date: 2026-01-16
problem_type: runtime_error
component: service_object
symptoms:
  - "App tried connecting to local WebSocket (192.168.x.x) in cloud mode"
  - "Network errors in console when cloud mode enabled"
  - "Connection attempts to unavailable local server"
root_cause: logic_error
resolution_type: code_fix
severity: medium
tags: [websocket, cloud-mode, connection-guard, network-errors, watchos]
---

# Troubleshooting: Unnecessary WebSocket Connection Attempts in Cloud Mode

## Problem
When the app was configured to use cloud mode (communicating via Cloudflare Worker), it still attempted to establish a WebSocket connection to a local IP address (192.168.x.x). This caused network errors and unnecessary connection attempts to an unavailable server.

## Environment
- Module: ClaudeWatch
- Platform: watchOS
- Affected Component: ClaudeWatch/Services/WatchService.swift
- Date: 2026-01-16

## Symptoms
- App tried connecting to local WebSocket (192.168.x.x) even when using cloud mode
- Network errors appearing in console when cloud mode was enabled
- Connection timeout errors to local addresses that don't exist
- Battery drain from repeated failed connection attempts

## What Didn't Work

**Direct solution:** The problem was identified and fixed on the first attempt after reviewing the connect() function logic.

## Solution

The `connect()` function had no guard to check if cloud mode was enabled before attempting WebSocket connection.

**Code changes**:
```swift
// Before (broken):
func connect() {
    // Started WebSocket connection regardless of mode
    let url = URL(string: "ws://\(localIP):8080/ws")!
    webSocketTask = URLSession.shared.webSocketTask(with: url)
    webSocketTask?.resume()
    receiveMessage()
}

// After (fixed):
func connect() {
    // Guard: Don't connect to local WebSocket in cloud mode
    if useCloudMode {
        return
    }

    let url = URL(string: "ws://\(localIP):8080/ws")!
    webSocketTask = URLSession.shared.webSocketTask(with: url)
    webSocketTask?.resume()
    receiveMessage()
}
```

## Why This Works

1. **ROOT CAUSE**: The `connect()` function was designed for local WebSocket communication but was being called regardless of the user's configured connection mode. When cloud mode was enabled, the app should communicate via HTTP to the Cloudflare Worker, not via WebSocket to a local server.

2. **The solution** adds an early return guard that:
   - Checks `useCloudMode` flag at the start of `connect()`
   - Returns immediately if cloud mode is enabled, skipping WebSocket setup
   - Allows the rest of the app to use cloud-based HTTP communication

3. **Underlying issue**: Missing mode check at the entry point of the local connection code path. The two communication modes (local WebSocket vs. cloud HTTP) were not properly isolated.

## Prevention

- Use protocol-based abstraction for connection modes:
  ```swift
  protocol ConnectionService {
      func send(message: Message) async throws
  }
  class WebSocketConnectionService: ConnectionService { }
  class CloudConnectionService: ConnectionService { }
  ```
- Initialize only the appropriate service based on configuration
- Add assertions or logging when mode-specific code is called in wrong mode
- Consider using Swift's type system to make invalid states unrepresentable

## Related Issues

- See also: [pairing-flow-loading-spinner-PairingView-20260116.md](../ui-bugs/pairing-flow-loading-spinner-PairingView-20260116.md) - Related watch app issue
- See also: [pairing-code-case-sensitivity-CloudflareWorker-20260116.md](../integration-issues/pairing-code-case-sensitivity-CloudflareWorker-20260116.md) - Related cloud mode issue
