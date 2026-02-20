# PRD: Cloud Pairing Backend & watchOS Integration

> **Status:** Draft
> **Date:** 2026-01-17
> **Scope:** Cloud relay backend, watchOS pairing UX
> **Priority:** High
> **Related:** claude-watch-npm package

---

## Executive Summary

Complete the end-to-end pairing flow between the `claude-watch` npm package and the watchOS app via a cloud relay backend. The npm package generates a 6-digit code, user enters it on watch, and they're paired.

### Current State

- **npm package** (`claude-watch-npm/`): Creates 6-digit code, waits for watch to pair
- **watchOS app** (`ClaudeWatch/`): Has code entry UI, calls `/pair/complete` endpoint
- **Cloud backend**: Needs to be implemented

---

## Part 1: Cloud Relay Backend (Cloudflare Worker)

### Purpose

Stateless relay that bridges the npm package and watchOS app. Uses KV storage for short-lived pairing sessions.

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/pairing/register` | POST | npm registers pairing code |
| `/api/pairing/check` | GET | npm polls for pairing completion |
| `/api/pairing/cleanup` | POST | npm cleans up expired session |
| `/pair/complete` | POST | watch completes pairing with code |
| `/api/message` | POST | Send message (either direction) |
| `/api/messages` | GET | Poll for messages |
| `/respond/:requestId` | POST | Watch responds to approval request |
| `/health` | GET | Health check |

### Data Structures

**Pairing Session** (KV, TTL: 5 minutes)
```json
{
  "code": "472913",
  "sessionId": "uuid",
  "createdAt": "2026-01-17T00:00:00Z",
  "pairingId": null,
  "paired": false
}
```

**Paired Connection** (KV, TTL: 24 hours)
```json
{
  "pairingId": "uuid",
  "deviceToken": "apns-token",
  "createdAt": "2026-01-17T00:00:00Z",
  "lastSeen": "2026-01-17T00:00:00Z"
}
```

**Message Queue** (KV, TTL: 5 minutes)
```json
{
  "messages": [
    {
      "id": "uuid",
      "type": "action_requested",
      "payload": {},
      "timestamp": "2026-01-17T00:00:00Z"
    }
  ]
}
```

### Implementation

**File:** `claude-watch-cloud/src/index.ts`

```typescript
import { Hono } from 'hono';

interface Env {
  PAIRING_KV: KVNamespace;
  CONNECTIONS_KV: KVNamespace;
  MESSAGES_KV: KVNamespace;
}

const app = new Hono<{ Bindings: Env }>();

// Register pairing code (from npm package)
app.post('/api/pairing/register', async (c) => {
  const { code, sessionId } = await c.req.json();

  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify({
    code,
    sessionId,
    createdAt: new Date().toISOString(),
    paired: false,
    pairingId: null,
  }), { expirationTtl: 300 }); // 5 minutes

  return c.json({ success: true });
});

// Check if pairing completed (polled by npm package)
app.get('/api/pairing/check', async (c) => {
  const sessionId = c.req.query('sessionId');

  // Find session by iterating (or use sessionId as key)
  const session = await c.env.PAIRING_KV.get(`session:${sessionId}`, 'json');

  if (!session) {
    return c.json({ paired: false });
  }

  return c.json({
    paired: session.paired,
    pairingId: session.pairingId,
  });
});

// Complete pairing (from watch)
app.post('/pair/complete', async (c) => {
  const { code, deviceToken } = await c.req.json();

  // Find pairing session by code
  const session = await c.env.PAIRING_KV.get(`code:${code}`, 'json');

  if (!session) {
    return c.json({ error: 'Invalid or expired code' }, 404);
  }

  // Generate pairing ID
  const pairingId = crypto.randomUUID();

  // Update session as paired
  session.paired = true;
  session.pairingId = pairingId;
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), { expirationTtl: 60 });
  await c.env.PAIRING_KV.put(`session:${session.sessionId}`, JSON.stringify(session), { expirationTtl: 60 });

  // Store connection
  await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify({
    pairingId,
    deviceToken,
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  }), { expirationTtl: 86400 }); // 24 hours

  return c.json({ pairingId });
});

// Send message (from npm MCP server to watch)
app.post('/api/message', async (c) => {
  const { pairingId, type, payload } = await c.req.json();

  // Get existing messages
  const existing = await c.env.MESSAGES_KV.get(`to_watch:${pairingId}`, 'json') || { messages: [] };

  existing.messages.push({
    id: crypto.randomUUID(),
    type,
    payload,
    timestamp: new Date().toISOString(),
  });

  // Keep last 50 messages
  if (existing.messages.length > 50) {
    existing.messages = existing.messages.slice(-50);
  }

  await c.env.MESSAGES_KV.put(`to_watch:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Poll messages (from watch)
app.get('/api/messages', async (c) => {
  const pairingId = c.req.query('pairingId');
  const direction = c.req.query('direction') || 'to_watch';

  const key = `${direction}:${pairingId}`;
  const data = await c.env.MESSAGES_KV.get(key, 'json') || { messages: [] };

  // Clear messages after reading
  await c.env.MESSAGES_KV.delete(key);

  return c.json(data);
});

// Respond to approval (from watch)
app.post('/respond/:requestId', async (c) => {
  const requestId = c.req.param('requestId');
  const { approved, pairingId } = await c.req.json();

  // Store response for MCP server to poll
  const existing = await c.env.MESSAGES_KV.get(`to_server:${pairingId}`, 'json') || { messages: [] };

  existing.messages.push({
    id: crypto.randomUUID(),
    type: 'action_response',
    payload: { action_id: requestId, approved },
    timestamp: new Date().toISOString(),
  });

  await c.env.MESSAGES_KV.put(`to_server:${pairingId}`, JSON.stringify(existing), { expirationTtl: 300 });

  return c.json({ success: true });
});

// Health check
app.get('/health', (c) => c.json({ status: 'ok' }));

export default app;
```

### Deployment

```bash
# Create wrangler.toml
cd claude-watch-cloud
wrangler init

# Create KV namespaces
wrangler kv:namespace create PAIRING_KV
wrangler kv:namespace create CONNECTIONS_KV
wrangler kv:namespace create MESSAGES_KV

# Deploy
wrangler deploy
```

---

## Part 2: npm Package Updates

### Required Changes

1. **Update cloud URL** in `src/config/pairing-store.ts`:
   ```typescript
   const DEFAULT_CLOUD_URL = "https://claude-watch.<your-account>.workers.dev";
   ```

2. **Update pairing registration** in `src/cloud/pairing.ts`:
   - Register both by code AND by sessionId for lookup

3. **Add message polling** in `src/cloud/client.ts`:
   - Poll `/api/messages?direction=to_server` for watch responses

---

## Part 3: watchOS Updates

### 3.1 Update Cloud URL

**File:** `ClaudeWatch/Services/WatchService.swift`

Update the default cloud URL to match the deployed worker:

```swift
@AppStorage("cloudServerURL") var cloudServerURL = "https://claude-watch.<account>.workers.dev"
```

### 3.2 Improve Error Messages

**File:** `ClaudeWatch/Services/WatchService.swift`

Add better error descriptions:

```swift
enum CloudError: LocalizedError {
    case invalidCode
    case invalidResponse
    case serverError(Int)
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid or expired code. Try again."
        case .invalidResponse:
            return "Unexpected server response."
        case .serverError(let code):
            return "Server error (\(code)). Try again."
        case .networkUnavailable:
            return "No network connection."
        case .timeout:
            return "Connection timed out."
        }
    }
}
```

### 3.3 Add Connection Retry UI

**File:** `ClaudeWatch/Views/PairingView.swift`

Add retry button on error:

```swift
// In PairingCodeEntryView
if let error = errorMessage {
    VStack(spacing: Claude.Spacing.xs) {
        Text(error)
            .font(.claudeFootnote)
            .foregroundStyle(Claude.danger)

        Button("Try Again") {
            errorMessage = nil
            code = ""
        }
        .font(.claudeFootnote)
        .foregroundStyle(Claude.orange)
    }
}
```

### 3.4 Persist Connection State

Ensure connection survives app restart:

```swift
// In WatchService.init()
if useCloudMode && isPaired {
    // Resume connection on launch
    startPolling()
}
```

### 3.5 Add Settings View for Unpairing

**File:** `ClaudeWatch/Views/SettingsView.swift` (new)

```swift
struct SettingsView: View {
    @ObservedObject var service: WatchService
    @State private var showUnpairConfirm = false

    var body: some View {
        List {
            Section("Connection") {
                if service.isPaired {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(service.connectionStatus.description)
                            .foregroundStyle(Claude.textSecondary)
                    }

                    Button("Unpair") {
                        showUnpairConfirm = true
                    }
                    .foregroundStyle(Claude.danger)
                }
            }
        }
        .alert("Unpair?", isPresented: $showUnpairConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Unpair", role: .destructive) {
                service.unpair()
            }
        } message: {
            Text("You'll need to pair again with a new code.")
        }
    }
}
```

Add `unpair()` method to WatchService:

```swift
func unpair() {
    stopPolling()
    pairingId = ""
    connectionStatus = .disconnected
    state = WatchState()
}
```

---

## Part 4: End-to-End Flow

### Happy Path

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   npm package   │     │  Cloud Worker   │     │   watchOS app   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │ POST /api/pairing/register                    │
         │ { code: "472913", sessionId: "..." }          │
         │──────────────────────>│                       │
         │                       │ Store in KV           │
         │<──────────────────────│                       │
         │ { success: true }     │                       │
         │                       │                       │
         │ Display code to user  │                       │
         │                       │                       │
         │                       │  User enters code     │
         │                       │<──────────────────────│
         │                       │ POST /pair/complete   │
         │                       │ { code: "472913" }    │
         │                       │                       │
         │                       │ Generate pairingId    │
         │                       │ Store connection      │
         │                       │──────────────────────>│
         │                       │ { pairingId: "..." }  │
         │                       │                       │
         │ GET /api/pairing/check                        │
         │──────────────────────>│                       │
         │<──────────────────────│                       │
         │ { paired: true, pairingId: "..." }            │
         │                       │                       │
         │ Store pairingId       │                       │
         │ Configure MCP         │                       │
         │                       │                       │
         ▼                       ▼                       ▼
      PAIRED                  READY                   PAIRED
```

### Approval Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  MCP Server     │     │  Cloud Worker   │     │   watchOS app   │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │ POST /api/message     │                       │
         │ { type: "action_requested", ... }             │
         │──────────────────────>│                       │
         │                       │ Queue message         │
         │                       │                       │
         │                       │ GET /api/messages     │
         │                       │<──────────────────────│
         │                       │──────────────────────>│
         │                       │ { messages: [...] }   │
         │                       │                       │
         │                       │  User approves        │
         │                       │                       │
         │                       │ POST /respond/:id     │
         │                       │<──────────────────────│
         │                       │ Queue response        │
         │                       │                       │
         │ GET /api/messages     │                       │
         │ ?direction=to_server  │                       │
         │──────────────────────>│                       │
         │<──────────────────────│                       │
         │ { messages: [{ type: "action_response", approved: true }] }
         │                       │                       │
         ▼                       ▼                       ▼
    CONTINUE                  RELAY                   DONE
```

---

## Implementation Phases

### Phase 1: Cloud Backend (1 day)

1. [ ] Create `claude-watch-cloud/` directory
2. [ ] Initialize Cloudflare Worker with Hono
3. [ ] Implement pairing endpoints
4. [ ] Implement message relay endpoints
5. [ ] Create KV namespaces
6. [ ] Deploy to Cloudflare

### Phase 2: npm Package Integration (0.5 day)

1. [ ] Update DEFAULT_CLOUD_URL in pairing-store.ts
2. [ ] Update pairing.ts to store by both code and sessionId
3. [ ] Test pairing flow locally

### Phase 3: watchOS Updates (0.5 day)

1. [ ] Update cloudServerURL default
2. [ ] Improve CloudError descriptions
3. [ ] Add retry UI on error
4. [ ] Add Settings view with unpair option
5. [ ] Test end-to-end flow

### Phase 4: Testing & Polish (0.5 day)

1. [ ] Test on real device
2. [ ] Test network interruption recovery
3. [ ] Test expired code handling
4. [ ] Add haptic feedback for all states

---

## Files to Create/Modify

### New Files

```
claude-watch-cloud/
├── package.json
├── wrangler.toml
├── tsconfig.json
└── src/
    └── index.ts
```

### Modified Files

```
claude-watch-npm/
└── src/
    └── config/
        └── pairing-store.ts  # Update DEFAULT_CLOUD_URL

ClaudeWatch/
├── Services/
│   └── WatchService.swift    # Update cloudServerURL, add unpair()
└── Views/
    ├── PairingView.swift     # Add retry UI
    └── SettingsView.swift    # New - unpair option
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Pairing success rate | >95% |
| Time to pair | <30 seconds |
| Message relay latency | <2 seconds |
| Battery impact from polling | <5% per hour |

---

## Testing Plan

### Unit Tests

```bash
# npm package
cd claude-watch-npm && npm test

# Cloud worker
cd claude-watch-cloud && npm test
```

### Integration Tests

1. Run `npx claude-watch` - should show pairing code
2. Enter code on watch simulator
3. Verify connection established
4. Send test notification from MCP
5. Verify watch receives notification

### End-to-End Test

1. Start fresh (no prior pairing)
2. Run `npx claude-watch` on Mac
3. Enter code on real Apple Watch
4. Start Claude Code, run test prompt
5. Receive approval request on watch
6. Approve from watch
7. Verify Claude Code continues

---

## References

- `claude-watch-npm/` - npm package implementation
- `ClaudeWatch/Services/WatchService.swift` - existing cloud mode code
- `ClaudeWatch/Views/PairingView.swift` - existing pairing UI
- Cloudflare Workers KV documentation

---

**END OF PRD**
