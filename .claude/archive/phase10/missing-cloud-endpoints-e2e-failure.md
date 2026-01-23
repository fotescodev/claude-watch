---
title: "E2E Tests Failing Due to Missing Cloud Endpoints and Incorrect Endpoint References"
problem_type: integration-issues
symptoms:
  - "E2E tests in test-hooks.py failing with 404 errors"
  - "test-e2e.md documentation referenced /request endpoint instead of /approval"
  - "Session control endpoints returning 404"
  - "Approval flow hangs because hook couldn't poll for status"
component: claude-watch-cloud
severity: high
tags:
  - e2e-testing
  - cloudflare-worker
  - endpoint-mismatch
  - api-documentation
  - documentation-drift
related_files:
  - claude-watch-cloud/src/index.ts
  - .claude/hooks/test-hooks.py
  - .claude/commands/test-e2e.md
  - .claude/DATA_FLOW.md
date_solved: 2026-01-21
---

# E2E Tests Failing Due to Missing Cloud Endpoints

## Problem

Claude Watch E2E tests were failing with 404 errors. The `/test-e2e` command couldn't complete because:

1. **Wrong endpoint in documentation**: `test-e2e.md` used `/request` which doesn't exist (correct: `/approval`)
2. **Missing session control endpoints**: 4 endpoints called by client code were never implemented
3. **Incomplete test coverage**: Tests weren't covering all endpoints the code depended on

## Root Cause

**Documentation-code drift**: The test documentation was written before the API was finalized. Session control features were added to WatchService.swift and watch-approval-cloud.py without implementing the corresponding cloud endpoints.

## Solution

### 1. Added 4 Missing Endpoints to Cloud Worker

**File**: `claude-watch-cloud/src/index.ts`

```typescript
// POST /session-end - Watch ends session
app.post('/session-end', async (c) => {
  const { pairingId } = await c.req.json<{ pairingId: string }>();
  // Mark session as ended, clear queues
  await c.env.MESSAGES_KV.put(`session:${pairingId}`, JSON.stringify({
    pairingId, active: false, interrupted: false, interruptAction: null,
    updatedAt: new Date().toISOString()
  }), { expirationTtl: 300 });
  await c.env.MESSAGES_KV.delete(`approval_queue:${pairingId}`);
  return c.json({ success: true });
});

// GET /session-status/:pairingId - Hook checks if session active
app.get('/session-status/:pairingId', async (c) => {
  const sessionState = await c.env.MESSAGES_KV.get(`session:${pairingId}`, 'json');
  return c.json({ sessionActive: sessionState?.active ?? true });
});

// POST /session-interrupt - Watch pauses/resumes
app.post('/session-interrupt', async (c) => {
  const { pairingId, action } = await c.req.json();
  // Update interrupt state based on action: 'stop', 'resume', 'clear'
  return c.json({ success: true, interrupted: action === 'stop' });
});

// GET /session-interrupt/:pairingId - Hook checks interrupt state
app.get('/session-interrupt/:pairingId', async (c) => {
  const sessionState = await c.env.MESSAGES_KV.get(`session:${pairingId}`, 'json');
  return c.json({ interrupted: sessionState?.interrupted ?? false });
});
```

### 2. Fixed test-e2e.md Endpoints

**Wrong**:
```bash
curl -X POST ".../request" -d '{"requestId": "..."}'
curl ".../request/$REQUEST_ID"
```

**Correct**:
```bash
# Create approval - uses 'id' field, not 'requestId'
curl -X POST ".../approval" -d '{"pairingId": "...", "id": "...", "type": "bash"}'

# Poll status - includes pairingId in path
curl ".../approval/$PAIRING_ID/$REQUEST_ID"
```

### 3. Updated test-hooks.py

Added comprehensive E2E tests:
- `test_approval_e2e_flow()`: create → queue → poll → approve → verified
- `test_session_control_e2e_flow()`: status → interrupt → resume → end

### 4. Created DATA_FLOW.md

Single source of truth documenting all 18 endpoints with their sources, purposes, and test coverage.

## Verification

```bash
python3 .claude/hooks/test-hooks.py
```

Expected: All 35 tests pass, including:
- 17 endpoint existence checks
- 4 E2E flow tests (Question, Progress, Approval, Session Control)

## Prevention

1. **Run test-hooks.py before deploying** cloud worker changes
2. **Maintain DATA_FLOW.md** as the API contract reference
3. **Add endpoints to cloud worker BEFORE** documenting them in test commands
4. **Cross-reference** endpoint names between hooks, cloud, watch, and test code

## Related Documentation

- [DATA_FLOW.md](/.claude/DATA_FLOW.md) - Complete endpoint reference
- [cc-watch-session-isolation.md](./cc-watch-session-isolation.md) - Session isolation patterns
