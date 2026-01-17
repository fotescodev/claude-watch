# Claude Watch Connection Troubleshooting Guide

A comprehensive guide for diagnosing and resolving connection issues in Claude Watch, covering both Cloud Mode (polling) and WebSocket Mode (direct connection).

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Connection Modes](#connection-modes)
4. [Quick Diagnostic Checklist](#quick-diagnostic-checklist)
5. [Common Issues & Solutions](#common-issues--solutions)
6. [Best Practices](#best-practices)
7. [Advanced Troubleshooting](#advanced-troubleshooting)
8. [Related Documentation](#related-documentation)

---

## Overview

Claude Watch supports two connection modes:

- **Cloud Mode (Default)**: Polling-based connection via Cloudflare Workers relay
- **WebSocket Mode**: Direct local connection with ping/pong heartbeat

Connection issues can manifest as:
- Failed pairing attempts
- Disconnections during use
- Missing or delayed notifications
- "Network unavailable" errors
- Timeout errors

This guide provides step-by-step troubleshooting for all connection scenarios.

---

## Prerequisites

Before troubleshooting, verify you have:

### For Cloud Mode
- Valid pairing code from Claude Code instance
- Internet connectivity on Apple Watch
- Cloudflare Workers server accessible: `https://claude-watch.fotescodev.workers.dev`
- APNs (Apple Push Notification service) enabled

### For WebSocket Mode
- Local MCP server running (default port: 8787)
- Apple Watch and server on same network
- Server IP address accessible from watch
- Firewall rules allow WebSocket connections

### General Requirements
- watchOS 10.0+ installed
- Claude Watch app installed and running
- Network connectivity (Wi-Fi or cellular)
- Notification permissions granted

### Verify Prerequisites

```bash
# Check if MCP server is running (WebSocket mode)
curl http://192.168.1.165:8787/state

# Check if cloud server is accessible (Cloud mode)
curl https://claude-watch.fotescodev.workers.dev/health

# Check network connectivity
ping -c 3 8.8.8.8
```

---

## Connection Modes

### Cloud Mode (Polling-Based)

**Default connection mode** - Uses Cloudflare Workers as relay between watch and Claude Code.

**How it works:**
- Watch polls cloud server every 2 seconds for pending requests
- Claude Code pushes requests to cloud server
- APNs delivers notifications for immediate action
- Polling continues in foreground, pauses in background

**Configuration:**
```swift
// Automatically enabled by default
useCloudMode = true  // Set via @AppStorage

// Pairing ID stored after successful pairing
pairingId = "ABC123"  // 6-character code
```

**Advantages:**
- Works across networks (no local network required)
- Reliable with automatic retry
- Supports push notifications
- Better battery life (no persistent connection)

**Best for:**
- Remote development (different networks)
- Simulator testing
- Production use
- Mobile/cellular connections

### WebSocket Mode (Direct Connection)

**Local connection mode** - Direct WebSocket connection to MCP server on same network.

**How it works:**
- Watch establishes WebSocket connection to local server
- Persistent bidirectional communication
- Ping/pong heartbeat every 15 seconds
- Exponential backoff reconnection (1s → 60s max)

**Configuration:**
```swift
useCloudMode = false  // Disable cloud mode
serverURL = "ws://192.168.1.165:8787"  // Local server URL
```

**Advantages:**
- Lower latency (no relay)
- Real-time updates
- No cloud dependency
- Privacy (local only)

**Best for:**
- Same network development
- Low-latency requirements
- Offline/local-only setups
- Privacy-sensitive workflows

### Switching Between Modes

To switch from Cloud to WebSocket:
1. Open Settings on watch
2. Toggle "Use Cloud Mode" to OFF
3. Enter local server URL
4. Tap "Connect"

To switch from WebSocket to Cloud:
1. Open Settings on watch
2. Toggle "Use Cloud Mode" to ON
3. Enter pairing code from Claude Code
4. Tap "Pair"

---

## Quick Diagnostic Checklist

Use this checklist for rapid diagnosis:

### Connection Status Indicators

| Status | Meaning | Action |
|--------|---------|--------|
| **OFFLINE** | Disconnected | Check network, verify server running |
| **CONNECTING** | Initial connection attempt | Wait 5-10 seconds |
| **CONNECTED** | Active connection | Normal operation |
| **RETRY N** | Reconnecting (attempt N) | Check network, wait for backoff |

### 30-Second Diagnosis

1. **Check connection status** on watch main screen
2. **Verify network connectivity** (Wi-Fi icon visible)
3. **Confirm server is running** (Cloud or local MCP)
4. **Check lastError message** (if any)
5. **Try manual reconnect** (Settings → Reconnect)

### Error Message Quick Reference

| Error Message | Mode | Issue | Solution |
|---------------|------|-------|----------|
| "Invalid or expired pairing code" | Cloud | Bad code entry | Re-enter code, verify case |
| "Connection timeout" | WebSocket | Handshake failed | Check server URL, firewall |
| "Server not responding" | WebSocket | Pong timeout | Verify server running |
| "Network unavailable" | Both | No connectivity | Check Wi-Fi/cellular |
| "Invalid server URL" | WebSocket | Malformed URL | Fix URL format |
| "Max reconnection attempts exceeded" | WebSocket | Persistent failure | Check server, reset app |
| "Server error: 404" | Cloud | Pairing ID not found | Re-pair with new code |
| "Request timed out" | Cloud | Cloud server slow | Retry, check internet |

---

## Common Issues & Solutions

### Issue 1: Pairing Fails with "Invalid or expired pairing code"

**Symptom:** Entering pairing code shows error immediately or after a few seconds

**Causes:**
- Incorrect code entry (case mismatch)
- Code expired (30-minute timeout)
- Code already used
- Server unreachable

**Solutions:**

#### Solution 1.1: Verify Code Case Sensitivity

Pairing codes are **case-insensitive** but must be entered exactly (no spaces):

```bash
# Correct examples:
ABC123
abc123
AbC123

# Incorrect examples:
ABC 123  # Contains space
ABC12    # Too short
ABCD123  # Too long
```

**Steps:**
1. Copy pairing code directly from Claude Code terminal
2. Paste into watch (or type carefully)
3. Verify code is exactly 6 characters
4. Tap "Pair"

#### Solution 1.2: Check Code Expiration

Pairing codes expire after **30 minutes**.

**Steps:**
1. In Claude Code terminal, check code timestamp
2. If older than 30 minutes, generate new code:
   ```bash
   # In Claude Code, trigger new pairing
   /pair
   ```
3. Use new code immediately (within 30 minutes)

#### Solution 1.3: Verify Cloud Server Accessibility

**Steps:**
```bash
# Test cloud server health endpoint
curl https://claude-watch.fotescodev.workers.dev/health

# Expected response:
{"status": "ok"}

# If no response, check internet connectivity:
ping -c 3 claude-watch.fotescodev.workers.dev
```

#### Solution 1.4: Check Server Logs

**Steps:**
1. In Claude Code terminal, check for pairing attempt logs
2. Look for errors like:
   - "Code not found in KV storage"
   - "Code expired"
   - "Invalid code format"
3. If no logs appear, watch request never reached server

**Related:** See [pairing-code-case-sensitivity-CloudflareWorker-20260116.md](./solutions/integration-issues/pairing-code-case-sensitivity-CloudflareWorker-20260116.md) for case sensitivity fix details.

---

### Issue 2: "Connection timeout" in WebSocket Mode

**Symptom:** Watch shows "CONNECTING" then transitions to "Connection timeout"

**Causes:**
- Handshake timeout (no response within 10 seconds)
- Server not running
- Incorrect server URL
- Firewall blocking connection
- Network changed

**Solutions:**

#### Solution 2.1: Verify Server is Running

**Steps:**
```bash
# Check if MCP server is running
ps aux | grep "python.*server.py"

# Test server HTTP endpoint
curl http://192.168.1.165:8787/state

# Expected response:
{"status": "idle", "pending_actions": []}

# If server not running, start it:
cd MCPServer
python server.py --standalone --port 8787
```

#### Solution 2.2: Verify Server URL Format

**Correct format:**
```
ws://192.168.1.165:8787
```

**Common mistakes:**
```
# Missing protocol
192.168.1.165:8787  # ❌ Missing ws://

# Wrong protocol
http://192.168.1.165:8787  # ❌ Use ws:// not http://

# Missing port
ws://192.168.1.165  # ❌ Include :8787

# Trailing slash
ws://192.168.1.165:8787/  # ⚠️ Works but unnecessary
```

**Steps:**
1. Open Settings on watch
2. Verify server URL follows format: `ws://IP:PORT`
3. Update if needed
4. Tap "Connect"

#### Solution 2.3: Check Firewall Rules

**Steps:**
```bash
# On server machine, check if port 8787 is listening
sudo lsof -i :8787

# Expected output:
# COMMAND  PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
# Python   1234 user   3u  IPv4  12345      0t0  TCP *:8787 (LISTEN)

# Test from another device on same network
curl http://SERVER_IP:8787/state

# If connection refused, allow port in firewall:
# macOS:
sudo pfctl -d  # Disable firewall temporarily for testing
# Or add rule to allow port 8787

# Linux:
sudo ufw allow 8787/tcp
```

#### Solution 2.4: Network Troubleshooting

**Steps:**
```bash
# Verify watch and server on same network
# On server:
ifconfig | grep "inet "

# Note server IP (e.g., 192.168.1.165)
# On watch, check if same subnet (e.g., 192.168.1.x)

# Test connectivity from watch network:
ping 192.168.1.165

# If no response:
# - Verify both on same Wi-Fi network
# - Check router allows device-to-device communication
# - Disable AP isolation on router
```

---

### Issue 3: "Server not responding" (Pong Timeout)

**Symptom:** Connection works initially, then shows "Server not responding" after 15-30 seconds

**Causes:**
- Server stopped responding to ping
- Server crashed
- Network congestion
- Server overloaded

**Solutions:**

#### Solution 3.1: Verify Server Health

**Steps:**
```bash
# Check server logs for errors
tail -f /path/to/server.log

# Look for:
# - Unhandled exceptions
# - Memory errors
# - Timeout errors

# Restart server:
pkill -f "python.*server.py"
cd MCPServer
python server.py --standalone --port 8787
```

#### Solution 3.2: Check Network Quality

**Steps:**
```bash
# Test network latency
ping -c 10 192.168.1.165

# Look for:
# - Packet loss (should be 0%)
# - High latency (should be < 100ms)
# - Jitter (variance in latency)

# If poor quality:
# - Move closer to Wi-Fi router
# - Switch to 5GHz Wi-Fi band
# - Reduce network congestion
```

#### Solution 3.3: Increase Timeout Values (Advanced)

If network is consistently slow but stable:

**Note:** Requires code modification in `WatchService.swift`:
```swift
// Default values:
private let pingInterval: TimeInterval = 15.0  // Send ping every 15s
private let pongTimeout: TimeInterval = 10.0   // Expect pong within 10s

// For slow networks, increase:
private let pingInterval: TimeInterval = 30.0  // Send ping every 30s
private let pongTimeout: TimeInterval = 20.0   // Expect pong within 20s
```

---

### Issue 4: "Network unavailable"

**Symptom:** Connection fails immediately with "Network unavailable"

**Causes:**
- No Wi-Fi or cellular connectivity
- Airplane mode enabled
- Network restrictions
- DNS failure

**Solutions:**

#### Solution 4.1: Verify Network Connectivity

**Steps:**
1. Check watch displays Wi-Fi or cellular icon
2. If missing:
   - Swipe up for Control Center
   - Verify Airplane Mode is OFF
   - Verify Wi-Fi is ON (or cellular if available)
3. Test connectivity:
   - Open Messages or Mail app
   - Send test message
   - If fails, network issue is system-wide

#### Solution 4.2: Reconnect to Wi-Fi

**Steps:**
1. On iPhone (for paired watch):
   - Open Watch app
   - Go to Wi-Fi settings
   - Forget current network
   - Reconnect
2. On Apple Watch:
   - Settings → Wi-Fi
   - Select network
   - Enter password

#### Solution 4.3: Reset Network Settings

**Steps (iPhone):**
1. Settings → General → Transfer or Reset iPhone
2. Reset → Reset Network Settings
3. Re-pair watch
4. Reconnect to Wi-Fi

**Note:** This resets all network settings including Wi-Fi passwords.

---

### Issue 5: "Max reconnection attempts exceeded"

**Symptom:** After multiple retry attempts, connection gives up with this error

**Causes:**
- Server persistently unreachable
- Invalid configuration
- Network completely down
- Server IP changed

**Solutions:**

#### Solution 5.1: Reset Connection State

**Steps:**
1. Open Claude Watch Settings
2. Toggle "Use Cloud Mode" OFF then ON (or vice versa)
3. Wait 5 seconds
4. Attempt reconnection

This resets:
- Reconnection attempt counter (back to 0)
- Exponential backoff timer
- Connection state machine

#### Solution 5.2: Verify Configuration

**Steps:**
```bash
# Check server configuration is correct
# For WebSocket mode:
serverURL = "ws://192.168.1.165:8787"  # ✅ Correct format

# For Cloud mode:
useCloudMode = true
pairingId = "ABC123"  # ✅ Valid pairing ID

# Verify server is reachable:
# WebSocket:
curl http://192.168.1.165:8787/state

# Cloud:
curl https://claude-watch.fotescodev.workers.dev/health
```

#### Solution 5.3: Force Reset App State

**Steps:**
1. Force quit Claude Watch:
   - Press Digital Crown + Side Button
   - Swipe left on Claude Watch
   - Tap X to close
2. Wait 10 seconds
3. Relaunch app
4. Connection state is reset

---

### Issue 6: Cloud Polling Stopped

**Symptom:** In Cloud Mode, no updates received even though connected

**Causes:**
- App entered background (polling paused)
- Pairing ID expired or invalidated
- Cloud server stopped returning requests
- Network switched (new IP)

**Solutions:**

#### Solution 6.1: Bring App to Foreground

**Steps:**
1. Raise wrist to wake watch
2. Open Claude Watch app (tap icon or complication)
3. Verify status shows "CONNECTED"
4. Polling resumes automatically

**Background behavior:**
- Polling **pauses** when app enters background
- Polling **resumes** when app becomes active
- Push notifications deliver urgent requests in background

#### Solution 6.2: Verify Pairing Status

**Steps:**
```bash
# Check pairing status via cloud API
curl https://claude-watch.fotescodev.workers.dev/requests/YOUR_PAIRING_ID

# Expected response:
{"requests": [...]}

# If 404 error:
# Pairing ID expired or invalid - re-pair required

# If empty requests:
# Polling working, no pending actions
```

#### Solution 6.3: Check Polling Configuration

**Steps:**
1. Verify in `WatchService.swift`:
   ```swift
   private let pollingInterval: TimeInterval = 2.0  // Poll every 2 seconds
   ```
2. Logs should show polling activity:
   ```
   [Polling] Fetching requests for pairing ID: ABC123
   [Polling] Received 0 pending requests
   ```
3. If no logs, polling task cancelled or never started

---

### Issue 7: Notifications Not Appearing

**Symptom:** Connection shows "CONNECTED" but no notifications for pending actions

**Causes:**
- Notification permissions denied
- Do Not Disturb enabled
- Notification settings misconfigured
- APNs token not registered

**Solutions:**

#### Solution 7.1: Verify Notification Permissions

**Steps:**
1. On iPhone → Watch app
2. Notifications → Claude Watch
3. Verify "Allow Notifications" is ON
4. Verify notification style is set (e.g., "Banners")

#### Solution 7.2: Check Do Not Disturb

**Steps:**
1. On Apple Watch:
   - Swipe up for Control Center
   - Verify Do Not Disturb is OFF (moon icon)
   - Verify Theater Mode is OFF
2. On iPhone:
   - Settings → Focus
   - Verify Do Not Disturb is OFF
   - Or add Claude Watch to allowed apps

#### Solution 7.3: Re-register APNs Token

**Steps:**
1. Force quit Claude Watch
2. Restart Apple Watch:
   - Press and hold Side Button
   - Drag "Power Off" slider
   - Wait 30 seconds
   - Press Side Button to restart
3. Launch Claude Watch
4. Accept notification permission prompt (if shown)
5. APNs token re-registered automatically

#### Solution 7.4: Test Notification Delivery

**Steps:**
```bash
# Trigger test notification from MCP server:
# In server console or via API:
curl -X POST http://192.168.1.165:8787/notify \
  -H "Content-Type: application/json" \
  -d '{"title": "Test", "message": "Notification test"}'

# Watch should display notification within 1-2 seconds
# If not, APNs configuration issue
```

---

### Issue 8: Connection Drops During Network Transitions

**Symptom:** Connection works on Wi-Fi, fails when switching to cellular or vice versa

**Causes:**
- Network path monitor detects change
- Reconnection triggered but fails
- Server unreachable on new network
- Pairing mode mismatch

**Solutions:**

#### Solution 8.1: Use Cloud Mode for Network Mobility

**Recommended for mobile scenarios:**

Cloud Mode handles network transitions gracefully because:
- Polling resumes after network change
- No persistent connection to maintain
- Works across different networks

**Steps:**
1. Open Settings
2. Enable "Use Cloud Mode"
3. Enter pairing code
4. Network transitions handled automatically

#### Solution 8.2: Network Monitor Behavior

**WebSocket Mode behavior:**
```swift
// When network becomes unavailable:
connectionStatus = .disconnected
lastError = "Network unavailable"

// When network becomes available:
reconnectAttempt = 0  // Reset backoff
connect()  // Immediate reconnection attempt
```

**Expected sequence:**
1. Network changes (Wi-Fi → Cellular)
2. Watch detects network unavailable (brief moment)
3. Watch detects network available (new network)
4. Reconnection triggered with reset backoff
5. Connection re-established

**If connection fails:**
- Verify server reachable on new network
- Check server URL is accessible from cellular/new Wi-Fi
- Cloud Mode recommended for network mobility

---

### Issue 9: App Disconnects in Background

**Symptom:** Connection drops after watch screen turns off or app minimized

**Causes:**
- Normal behavior for WebSocket mode (system suspends connections)
- Polling paused in Cloud mode (also normal)
- Background refresh disabled

**Solutions:**

#### Solution 9.1: Understand Background Behavior

**WebSocket Mode:**
- System may suspend WebSocket connections in background
- Reconnection happens when app becomes active
- This is **expected behavior** for watchOS

**Cloud Mode:**
- Polling pauses when app enters background
- Push notifications deliver urgent requests
- Polling resumes when app becomes active

**Both modes:**
- Full functionality restored when app active
- Not a bug - OS battery optimization

#### Solution 9.2: Use Complications for Quick Access

**Steps:**
1. Add Claude Watch complication to watch face
2. Tap complication to launch app instantly
3. Connection resumes immediately

**Recommended complications:**
- Circular: Shows pending count
- Rectangular: Shows task name + status
- Inline: Shows connection status

#### Solution 9.3: Enable Background App Refresh (Limited Effect)

**Steps:**
1. iPhone → Watch app
2. General → Background App Refresh
3. Enable for Claude Watch

**Note:** watchOS still suspends apps aggressively. This provides minimal benefit but worth enabling.

---

### Issue 10: Simulator Cannot Connect to Localhost

**Symptom:** Running in watchOS simulator, connection fails to `ws://localhost:8787`

**Cause:**
- watchOS simulator network sandbox restrictions
- Cannot reach host machine's localhost
- Must use Cloud Mode or bridge server

**Solution:**

**Option 1: Use Cloud Mode (Recommended)**

See [SIMULATOR_SETUP_GUIDE.md](./SIMULATOR_SETUP_GUIDE.md) for complete setup instructions.

**Steps:**
```bash
# Boot simulator
xcrun simctl boot "Apple Watch Series 11 (46mm)"

# Enable cloud mode
DEVICE_ID="YOUR_DEVICE_UUID"
BUNDLE_ID="com.edgeoftrust.claudewatch"

xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool true

# Set pairing ID from cloud server
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" pairingId -string "ABC123"

# Launch app
xcrun simctl launch "Apple Watch Series 11 (46mm)" "$BUNDLE_ID"
```

**Option 2: Use Host Machine IP**

If you must use WebSocket mode in simulator:

```bash
# Find host machine IP on local network
ifconfig | grep "inet " | grep -v 127.0.0.1

# Example: inet 192.168.1.100

# Configure simulator to use this IP:
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" useCloudMode -bool false
xcrun simctl spawn "$DEVICE_ID" defaults write "$BUNDLE_ID" serverURL -string "ws://192.168.1.100:8787"
```

**Related:** See [SIMULATOR_SETUP_GUIDE.md](./SIMULATOR_SETUP_GUIDE.md) for detailed simulator troubleshooting.

---

## Best Practices

### Connection Reliability

1. **Use Cloud Mode for production**
   - Better reliability across networks
   - Handles network transitions
   - Lower battery usage
   - Push notification support

2. **Use WebSocket Mode for development**
   - Lower latency
   - No cloud dependency
   - Real-time debugging
   - Privacy (local only)

3. **Monitor connection status**
   - Check status indicator on main screen
   - Review lastError messages
   - Watch for "RETRY N" status (indicates issues)

4. **Graceful degradation**
   - App queues messages when disconnected
   - High-priority messages (approve/reject) queued first
   - Automatic retry with exponential backoff
   - Manual retry available in Settings

### Pairing Best Practices

1. **Use pairing codes immediately**
   - 30-minute expiration
   - Generate new code if expired
   - Copy/paste to avoid typos

2. **Verify code entry**
   - Exactly 6 characters
   - Case-insensitive but no spaces
   - Check for extra whitespace

3. **Test pairing before production use**
   - Send test approval request
   - Verify notification received
   - Confirm response reaches Claude Code

### Network Best Practices

1. **Wi-Fi recommendations**
   - Use 5GHz band when available (lower latency)
   - Stay within router range
   - Reduce network congestion
   - Disable AP isolation on router

2. **Cellular recommendations**
   - Cloud Mode required (WebSocket won't work)
   - Monitor data usage
   - Verify cellular plan allows data

3. **Network transitions**
   - Cloud Mode recommended for mobile scenarios
   - WebSocket Mode best for stationary development
   - Test both scenarios if using WebSocket

### Battery Optimization

1. **Minimize reconnection attempts**
   - Fix configuration issues promptly
   - Don't let app retry indefinitely
   - Force quit if max retries reached

2. **Background behavior**
   - Accept that polling pauses in background
   - Rely on push notifications for urgent requests
   - Don't fight the system - it's designed this way

3. **Polling interval**
   - Default 2 seconds is optimized
   - Longer intervals save battery but delay updates
   - Shorter intervals drain battery faster

---

## Advanced Troubleshooting

### Enable Diagnostic Logging

**Steps:**

1. **Xcode Console Logging** (for development):
   ```bash
   # Connect watch to Mac via USB
   # Open Xcode → Devices and Simulators
   # Select your watch
   # View console output
   ```

2. **System Logs** (for debugging):
   ```bash
   # Stream logs for Claude Watch process
   log stream --predicate 'process == "ClaudeWatch"' --level debug
   ```

3. **Network Traffic Inspection**:
   ```bash
   # Use Charles Proxy or Wireshark
   # Configure watch to use proxy
   # Inspect WebSocket/HTTP traffic
   ```

### Connection State Machine

Understanding the connection state flow:

```
[disconnected]
    ↓ connect()
[connecting] → handshake timeout → [reconnecting] → max retries → [disconnected]
    ↓ handshake success
[connected] → pong timeout → [reconnecting]
    ↓ network unavailable
[disconnected]
```

**State transitions:**
- `disconnected` → `connecting`: Manual or automatic connection attempt
- `connecting` → `connected`: Successful handshake (first message received)
- `connecting` → `reconnecting`: Handshake timeout (10s)
- `connected` → `reconnecting`: Pong timeout (10s after ping)
- `reconnecting` → `connected`: Successful reconnection
- `reconnecting` → `disconnected`: Max retries exceeded (10 attempts)
- Any → `disconnected`: Network unavailable

### Manual State Reset

**Force reset connection state:**

```swift
// Option 1: Via Settings UI
Settings → Toggle mode → Wait → Toggle back

// Option 2: Via UserDefaults (simulator)
xcrun simctl spawn "$DEVICE_ID" defaults delete "$BUNDLE_ID" serverURL
xcrun simctl spawn "$DEVICE_ID" defaults delete "$BUNDLE_ID" pairingId

// Option 3: Force quit app
Digital Crown + Side Button → Swipe left → X
```

### Debugging Reconnection Logic

**Exponential backoff formula:**

```swift
func delay(forAttempt attempt: Int) -> TimeInterval {
    let baseDelay = min(1.0 * pow(2.0, Double(attempt)), 60.0)
    let jitter = baseDelay * 0.2 * Double.random(in: -1...1)
    return max(0.1, baseDelay + jitter)
}
```

**Expected delays:**
- Attempt 0: 1.0s ± 0.2s
- Attempt 1: 2.0s ± 0.4s
- Attempt 2: 4.0s ± 0.8s
- Attempt 3: 8.0s ± 1.6s
- Attempt 4: 16.0s ± 3.2s
- Attempt 5: 32.0s ± 6.4s
- Attempt 6+: 60.0s ± 12.0s (max)

**Max retries:** 10 attempts before giving up

### Server-Side Debugging

**Check MCP server logs:**

```bash
# Start server with verbose logging
cd MCPServer
python server.py --standalone --port 8787 --log-level DEBUG

# Expected logs:
# [INFO] WebSocket connection established
# [DEBUG] Received ping from client
# [DEBUG] Sent pong to client
# [INFO] State sync sent to client
```

**Common server errors:**

```bash
# Port already in use:
OSError: [Errno 48] Address already in use
# Solution: pkill -f "python.*server.py" or use different port

# Permission denied:
OSError: [Errno 13] Permission denied
# Solution: sudo or use port > 1024

# Import error:
ImportError: No module named 'websockets'
# Solution: pip install websockets
```

### Cloud Server Debugging

**Check Cloudflare Workers logs:**

```bash
# Via wrangler CLI:
wrangler tail

# Via Cloudflare Dashboard:
# Workers & Pages → claude-watch → Logs
```

**Common cloud errors:**

```bash
# Pairing code not found:
# Response: {"error": "Invalid or expired code"}
# Cause: Code expired (>30min) or never created
# Solution: Generate new code

# KV read error:
# Response: {"error": "KV storage unavailable"}
# Cause: Cloudflare KV issue
# Solution: Check KV binding, verify KV namespace exists

# Rate limiting:
# Response: 429 Too Many Requests
# Cause: Exceeded free tier limits
# Solution: Wait or upgrade plan
```

---

## Related Documentation

### Getting Started
- [README.md](../README.md) - Project overview and quick start guide
- [SIMULATOR_SETUP_GUIDE.md](./SIMULATOR_SETUP_GUIDE.md) - Complete simulator testing and troubleshooting guide

### Connection & Pairing
- [SEAMLESS_PAIRING_SPEC.md](./specs/SEAMLESS_PAIRING_SPEC.md) - Pairing flow specification and design
- `ClaudeWatch/Services/WatchService.swift` - Connection implementation and state management
- [pairing-code-case-sensitivity-CloudflareWorker-20260116.md](./solutions/integration-issues/pairing-code-case-sensitivity-CloudflareWorker-20260116.md) - Pairing code case sensitivity fix
- [pairing-flow-loading-spinner-PairingView-20260116.md](./solutions/ui-bugs/pairing-flow-loading-spinner-PairingView-20260116.md) - Pairing UI improvements

### WebSocket & Cloud Mode
- [unnecessary-websocket-cloud-mode-WatchService-20260116.md](./solutions/runtime-errors/unnecessary-websocket-cloud-mode-WatchService-20260116.md) - WebSocket connection optimization
- `MCPServer/server.py` - Local MCP server WebSocket API
- `MCPServer/worker/src/index.js` - Cloudflare Workers cloud relay API

### Testing Guides
- [simulator-live-testing-guide.md](./solutions/testing-guides/simulator-live-testing-guide.md) - Live testing on simulator
- [watch-hook-integration-live-test.md](./solutions/testing-guides/watch-hook-integration-live-test.md) - Watch hook integration testing

### Additional Solutions
- [watchos-demo-mode-stuck-no-exit.md](./solutions/ui-bugs/watchos-demo-mode-stuck-no-exit.md) - Demo mode exit issues
- [test-target-deployment-mismatch-20260116.md](./solutions/build-errors/test-target-deployment-mismatch-20260116.md) - Build configuration issues
- [watchos26-deprecation-warnings-20260115.md](./solutions/build-errors/watchos26-deprecation-warnings-20260115.md) - Deprecation warnings

### Project Planning
- [PRD.md](./PRD.md) - Product requirements and architecture
- [APPSTORE-ROADMAP.md](./APPSTORE-ROADMAP.md) - App Store release roadmap

---

## Getting Help

If issues persist after following this guide:

1. **Check existing issues** in project repository
2. **Review server logs** for error messages
3. **Test with Demo Mode** to isolate app vs. connection issues:
   ```swift
   // Enable demo mode in Settings
   isDemoMode = true
   // If demo mode works, issue is with connection, not app
   ```
4. **File a bug report** with:
   - Connection mode (Cloud or WebSocket)
   - Error message (from lastError)
   - Steps to reproduce
   - Server logs (if available)
   - watchOS version

---

**Last Updated:** 2026-01-17
**Applies to:** Claude Watch v1.0+, watchOS 10.0+
