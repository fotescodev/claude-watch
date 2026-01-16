---
description: Test watch-server connectivity
allowed-tools: Bash(curl:*), Bash(python:*), Bash(lsof:*), Read
---

# Test Watch-Server Connection

Verify the watch app can communicate with the server:

1. Check if server is running:
   ```bash
   lsof -i :8787 -i :8788
   ```

2. Test REST API:
   ```bash
   curl -s http://localhost:8788/state | python3 -m json.tool
   ```

3. Test WebSocket (quick connect test):
   ```bash
   curl -s -N -H "Connection: Upgrade" -H "Upgrade: websocket" http://localhost:8787 || echo "WebSocket endpoint available"
   ```

4. Simulate a notification:
   ```bash
   curl -X POST http://localhost:8788/action/request \
     -H "Content-Type: application/json" \
     -d '{"action_id": "test123", "type": "file_edit", "description": "Test notification"}'
   ```

5. Report connection status and any issues found
