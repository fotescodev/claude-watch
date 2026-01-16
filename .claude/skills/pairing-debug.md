# Pairing Code Debugging

Debug the 6-character pairing flow for Claude Watch cloud mode.

## Pairing Flow Overview

```
1. Claude Code CLI calls POST /pair
2. Server generates code (ABC-123) + pairingId
3. User enters code on Watch
4. Watch calls POST /pair/complete with code + deviceToken
5. Server validates, stores device token
6. Pairing complete - Watch can receive requests
```

## Code Format

```
ABC-123
└─┬─┘└┬┘
  │   └── 3 digits (0-9)
  └────── 3 uppercase letters (A-Z, excluding I/O)
```

Generated in server.py:
```python
letters = ''.join(random.choices('ABCDEFGHJKLMNPQRSTUVWXYZ', k=3))
numbers = ''.join(random.choices('0123456789', k=3))
code = f"{letters}-{numbers}"
```

## Testing Pairing

### 1. Generate Pairing Code
```bash
# Local server
curl -X POST http://localhost:8788/pair

# Cloud relay
curl -X POST https://your-worker.workers.dev/pair
```

Response:
```json
{
    "pairingId": "uuid-here",
    "code": "ABC-123",
    "expiresIn": 600
}
```

### 2. Complete Pairing
```bash
curl -X POST http://localhost:8788/pair/complete \
  -H "Content-Type: application/json" \
  -d '{"code": "ABC-123", "deviceToken": "test-token"}'
```

### 3. Check Pairing Status
```bash
curl http://localhost:8788/pair/{pairingId}/status
```

## Common Issues

### "Invalid Code"
**Cause**: Code doesn't exist or expired (10 min TTL)
**Fix**: Generate new code, enter quickly

### "Pairing Already Complete"
**Cause**: Code was already used
**Fix**: Generate new code

### "Device Token Missing"
**Cause**: Watch didn't register for notifications
**Fix**: Check notification permissions

## Key Files

- `ClaudeWatch/Views/PairingView.swift` - Code entry UI
- `ClaudeWatch/Services/WatchService.swift:completePairing()` - API call
- `MCPServer/server.py` - Server-side pairing logic
- `MCPServer/worker/src/index.js` - Cloud relay pairing

## Cloudflare KV Storage

Pairing data stored in KV:
```
PAIRINGS namespace:
  key: code (ABC-123)
  value: { pairingId, deviceToken?, createdAt }
  TTL: 600 seconds
```

## Debugging Commands

### List Active Pairings (Local)
```bash
curl http://localhost:8788/debug/pairings
```

### Clear Expired Pairings
Handled automatically by KV TTL in cloud mode.

### Watch Logs for Pairing
```bash
xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "pairing"'
```
