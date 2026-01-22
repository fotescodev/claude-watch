# API Contract Audit Report

> **Date**: 2026-01-22
> **Status**: Critical issues found - must fix before V2
> **Priority**: P0 for next phase

---

## Executive Summary

The API contracts between CLI ↔ Cloud ↔ Watch have **critical mismatches** that cause the polling-based action flow to fail. The system currently works only because APNs push notifications bypass the broken polling endpoint.

---

## Critical Issues

### 1. `/requests` Endpoint Filter is Broken (CRITICAL)

**Location**: `claude-watch-cloud/src/index.ts` line 291

```typescript
// CURRENT (BROKEN):
const requests = data.messages.filter(m => m.type === 'action_requested');

// Messages are stored with:
{
  type: "to_watch",           // ← This is what's stored
  payload: {
    type: "action_requested", // ← This is what filter looks for
    action: {...}
  }
}

// Filter NEVER matches because m.type === "to_watch", not "action_requested"
```

**Result**: Watch always receives empty array from `/requests/:pairingId`

**Fix**:
```typescript
const requests = data.messages.filter(m => m.payload?.type === 'action_requested');
```

---

### 2. Nested Structure Mismatch (CRITICAL)

**Cloud returns**:
```json
{
  "requests": [
    {
      "id": "uuid",
      "type": "to_watch",
      "payload": {
        "type": "action_requested",
        "action": {
          "id": "abc123",
          "title": "Edit file",
          "description": "...",
          "file_path": "/src/main.ts"
        }
      }
    }
  ]
}
```

**Watch expects** (`WatchService.swift` lines 1147-1181):
```json
{
  "requests": [
    {
      "id": "abc123",
      "type": "action_requested",
      "title": "Edit file",
      "description": "...",
      "filePath": "/src/main.ts"
    }
  ]
}
```

**Result**: Watch `guard let` statements fail, all requests silently dropped

**Fix** (in Cloud):
```typescript
const flatRequests = requests.map(msg => ({
  id: msg.payload?.action?.id || msg.id,
  type: msg.payload?.type,
  title: msg.payload?.action?.title,
  description: msg.payload?.action?.description,
  filePath: msg.payload?.action?.file_path,  // Convert to camelCase
  command: msg.payload?.action?.command
}));
return c.json({ requests: flatRequests });
```

---

### 3. Field Case Inconsistency (HIGH)

| Component | Field Name | Case Style |
|-----------|------------|------------|
| CLI (TypeScript) | `file_path` | snake_case |
| Cloud (TypeScript) | `file_path` | snake_case |
| Watch (Swift) | `filePath` | camelCase |

**Affected locations**:
- `WatchService.swift` line 1166: `filePath`
- `ClaudeWatchApp.swift` line 200: `filePath` in notification handler
- `claude-watch-npm/src/types/index.ts` line 50: `file_path`

**Result**: File path information lost when Watch parses requests/notifications

**Fix options**:
1. Cloud converts snake_case → camelCase before sending to Watch
2. Watch accepts both cases with fallback
3. Standardize on one case everywhere

---

## Flow Analysis

### Working Flows ✅

| Flow | Why It Works |
|------|--------------|
| Pairing (Watch → Cloud → CLI) | Direct endpoint calls, no message queue |
| APNs push notifications | Bypasses `/requests` polling entirely |
| Approval response (Watch → Cloud → CLI) | Payload extraction fixes nesting |

### Broken Flows ❌

| Flow | Why It's Broken |
|------|-----------------|
| CLI → Cloud → Watch action requests (polling) | Filter mismatch + nested structure |
| Watch polling for pending actions | Returns empty array always |

---

## Why Testing Passed

The dog walk test and other E2E tests passed because:

1. **APNs is the primary path**: Push notifications deliver actions directly to Watch
2. **Polling is backup**: The broken `/requests` endpoint is only used when APNs fails
3. **Happy path works**: When notifications succeed, the broken backup isn't exercised

This is a **latent bug** that will cause failures when:
- APNs delivery is delayed
- Watch polls before notification arrives
- Network issues cause notification loss

---

## Recommended Fix Plan

### Phase A: Quick Fixes (30 min)

1. **Fix filter** in `claude-watch-cloud/src/index.ts`:
   ```typescript
   // Line 291
   const requests = data.messages.filter(m => m.payload?.type === 'action_requested');
   ```

2. **Flatten response** in same file:
   ```typescript
   // Line 298
   const flatRequests = requests.map(msg => ({
     id: msg.payload?.action?.id || msg.id,
     type: msg.payload?.type,
     title: msg.payload?.action?.title,
     description: msg.payload?.action?.description,
     filePath: msg.payload?.action?.file_path,
     command: msg.payload?.action?.command
   }));
   return c.json({ requests: flatRequests });
   ```

3. **Deploy** cloud worker

### Phase B: Proper API Contract (Future)

1. Create shared type definitions in `types/api-contract.ts`
2. Generate TypeScript types for CLI and Cloud
3. Generate Swift Codable structs for Watch
4. Add contract validation tests

---

## Files to Modify

| File | Change |
|------|--------|
| `claude-watch-cloud/src/index.ts` | Fix filter + flatten response |
| `ClaudeWatch/Services/WatchService.swift` | (Optional) Accept both cases |

---

## Test Plan

After fixes:

1. **Unit test**: Mock `/requests` response, verify Watch parses correctly
2. **Integration test**: Disable APNs, verify polling-only flow works
3. **E2E test**: Full flow with real Watch

---

## Related Documents

- `.claude/research/yes-no-questions-research.md` - Phase 9 pivot
- `.claude/plans/phase9-CONTEXT.md` - Current approach
- `docs/solutions/integration-issues/comp5-question-proxy-failure-analysis.md` - Previous failure analysis

---

## Appendix: Message Flow Diagram

```
CLI                          Cloud                         Watch
 │                             │                             │
 │  POST /api/message          │                             │
 │  {type: "to_watch",         │                             │
 │   payload: {                │                             │
 │     type: "action_requested"│                             │
 │     action: {...}           │                             │
 │   }}                        │                             │
 │ ─────────────────────────►  │                             │
 │                             │  Store in MESSAGES_KV       │
 │                             │  key: to_watch:{pairingId}  │
 │                             │                             │
 │                             │  GET /requests/{pairingId}  │
 │                             │ ◄───────────────────────────│
 │                             │                             │
 │                             │  Filter: m.type === "action_requested"
 │                             │  FAILS because m.type === "to_watch"
 │                             │                             │
 │                             │  Returns: {requests: []}    │
 │                             │ ────────────────────────────►│
 │                             │                             │
 │                             │  Watch sees no actions      │
 │                             │                             │
```

---

*Created: 2026-01-22*
*Author: Claude*
*Status: Ready for next phase implementation*
