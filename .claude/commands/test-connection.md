---
description: Test watch-server connectivity
allowed-tools: Bash, Read, Grep
---

# Test Watch-Server Connection

Comprehensive diagnostic tool for Claude Watch connectivity and UI updates.

## Run These Tests In Order

### Step 1: Environment Check

```bash
# Check pairing ID
echo "=== Pairing ID ===" && cat ~/.claude-watch-pairing 2>/dev/null || echo "NOT SET"

# Check simulator status
echo -e "\n=== Watch Simulator ===" && xcrun simctl list devices | grep -i "watch.*booted" || echo "NOT RUNNING"

# Check cloud server health
echo -e "\n=== Cloud Server ===" && curl -s https://claude-watch.fotescodev.workers.dev/health | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('status')=='ok' else 'FAIL')" 2>/dev/null || echo "UNREACHABLE"
```

### Step 2: Pairing Status

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  echo "Checking pairing: ${PAIRING_ID:0:8}..."
  curl -s "https://claude-watch.fotescodev.workers.dev/pair/$PAIRING_ID/status" | python3 -m json.tool
else
  echo "No pairing ID found. Run pairing flow first."
fi
```

### Step 3: Test Progress Update (Most Common Issue)

Send a mock progress update and verify watch receives it:

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
echo "Sending progress update..."
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/session-progress" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\":\"$PAIRING_ID\",\"tasks\":[{\"content\":\"Test task 1\",\"status\":\"completed\",\"activeForm\":\"Testing task 1\"},{\"content\":\"Test task 2\",\"status\":\"in_progress\",\"activeForm\":\"Testing task 2\"},{\"content\":\"Test task 3\",\"status\":\"pending\",\"activeForm\":\"Testing task 3\"}],\"currentTask\":\"Test task 2\",\"currentActivity\":\"Testing task 2\",\"progress\":0.33,\"completedCount\":1,\"totalCount\":3,\"elapsedSeconds\":45}" | python3 -m json.tool
```

Then send via simctl (bypasses APNs):

```bash
cat > /tmp/progress.json << 'PAYLOAD'
{
  "aps": {"content-available": 1},
  "type": "progress",
  "tasks": [
    {"content": "Test task 1", "status": "completed", "activeForm": "Testing"},
    {"content": "Test task 2", "status": "in_progress", "activeForm": "Testing task 2"},
    {"content": "Test task 3", "status": "pending", "activeForm": "Testing"}
  ],
  "currentTask": "Test task 2",
  "currentActivity": "Testing task 2",
  "progress": 0.33,
  "completedCount": 1,
  "totalCount": 3,
  "elapsedSeconds": 45
}
PAYLOAD
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/progress.json
echo "Direct simctl push sent - check if watch UI updates"
```

### Step 4: Test Approval Request

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
echo "Sending approval request..."
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/request" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\":\"$PAIRING_ID\",\"type\":\"bash\",\"title\":\"Run: echo test\",\"description\":\"Test command execution\"}" | python3 -m json.tool
```

Also via simctl:

```bash
cat > /tmp/approval.json << 'PAYLOAD'
{
  "aps": {
    "alert": {"title": "Claude: bash", "body": "Run: echo test"},
    "sound": "default",
    "category": "CLAUDE_ACTION"
  },
  "requestId": "test-123",
  "type": "bash",
  "title": "Run: echo test",
  "description": "Test command"
}
PAYLOAD
xcrun simctl push "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch /tmp/approval.json
echo "Approval notification sent"
```

### Step 5: Test Interrupt Controls

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)

echo "=== Set STOP ==="
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/session-interrupt" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\":\"$PAIRING_ID\",\"action\":\"stop\"}" | python3 -m json.tool

echo -e "\n=== Check State ==="
curl -s "https://claude-watch.fotescodev.workers.dev/session-interrupt/$PAIRING_ID" | python3 -m json.tool

echo -e "\n=== Set RESUME ==="
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/session-interrupt" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\":\"$PAIRING_ID\",\"action\":\"resume\"}" | python3 -m json.tool
```

### Step 6: Check Pending Requests

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
curl -s "https://claude-watch.fotescodev.workers.dev/requests/$PAIRING_ID" | python3 -m json.tool
```

## Common Issues

### Watch shows "Ready" but should show progress
1. **Silent push not working on simulator** - Use simctl push directly
2. **Pairing expired** - Re-pair the watch
3. **App not in foreground** - Tap the app to bring it forward before sending
4. **sessionProgress nil** - Check if notification handler is called

### Notifications not appearing
1. Check bundle ID matches: `com.edgeoftrust.claudewatch`
2. Verify simulator is booted: `xcrun simctl list devices | grep -i watch`
3. Check notification permissions in simulator

### Hook not blocking when interrupted
1. Verify `CLAUDE_WATCH_SESSION_ACTIVE=1` is set
2. Check pairing ID matches: `cat ~/.claude-watch-pairing`
3. Test hook manually: `echo '{"tool_name":"Bash","tool_input":{"command":"test"}}' | CLAUDE_WATCH_SESSION_ACTIVE=1 python3 .claude/hooks/watch-approval-cloud.py`

## Quick Reset

```bash
# Clear all state and start fresh
rm -f ~/.claude-watch-pairing ~/.claude-watch-session /tmp/claude-watch-*
echo "State cleared. Re-pair the watch to continue."
```
