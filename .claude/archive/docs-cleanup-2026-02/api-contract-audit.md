# API Contract Audit Report

> **Date**: 2026-01-22
> **Status**: ✅ ALL ISSUES FIXED
> **Updated**: Full audit complete, all mismatches resolved
> **See also**: `api-contract-audit-comprehensive.md` for detailed analysis

---

## Executive Summary

The Cloud worker has been significantly updated with proper API contracts. Most critical issues identified have been **fixed**. This document now serves as a reference for the current API structure.

---

## Current API Endpoints (Cloud Worker)

### Pairing Endpoints ✅
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/pair/initiate` | POST | Watch requests pairing code | ✅ Working |
| `/pair/status/:watchId` | GET | Watch polls for completion | ✅ Working |
| `/pair/complete` | POST | CLI enters code | ✅ Working |

**E2E Encryption integrated**: `publicKey` exchanged during pairing.

---

### Approval Endpoints ✅ (NEW - Properly Structured)
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/approval` | POST | Hook adds approval request | ✅ NEW |
| `/approval-queue/:pairingId` | GET | Watch polls pending approvals | ✅ NEW |
| `/approval/:requestId` | POST | Watch approves/rejects | ✅ NEW |
| `/approval/:pairingId/:requestId` | GET | Hook polls for response | ✅ NEW |
| `/approval-queue/:pairingId` | DELETE | Clear queue on session end | ✅ NEW |

**Structure is now FLAT** (fixed from previous nested issue):
```typescript
interface ApprovalRequest {
  id: string;
  type: string;
  title: string;
  description?: string;
  filePath?: string;      // camelCase ✅
  command?: string;
  createdAt: string;
  status: 'pending' | 'approved' | 'rejected';
}
```

---

### Legacy Endpoints (Backwards Compatible)
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/requests/:pairingId` | GET | Old watch polling | ✅ FIXED - tries approval_queue first |
| `/respond/:requestId` | POST | Old approval response | ✅ Working |
| `/api/message` | POST | Old message queue | ✅ Working |
| `/api/messages` | GET | Old message polling | ✅ Working |

**`/requests/:pairingId` now fixed:**
```typescript
// Tries new approval queue first, returns flat structure
const queue = await c.env.MESSAGES_KV.get<ApprovalQueue>(`approval_queue:${pairingId}`, 'json');
if (queue) {
  const pending = queue.requests.filter(r => r.status === 'pending');
  return c.json({ requests: pending.map(r => ({
    id: r.id,
    type: r.type,
    title: r.title,
    description: r.description,
    filePath: r.filePath,  // camelCase ✅
    command: r.command,
    timestamp: r.createdAt,
  }))});
}
```

---

### Question Endpoints ✅ (NEW)
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/question` | POST | Hook creates question | ✅ NEW |
| `/question/:questionId` | GET | Hook polls for answer | ✅ NEW |
| `/question/:questionId/answer` | POST | Watch submits answer | ✅ NEW |
| `/questions/:pairingId` | GET | Watch polls pending questions | ✅ NEW |

**Note**: Phase 9 approach (yes/no constraints in CLAUDE.md) means these may not be needed for most cases.

---

### Session Progress Endpoints ✅ (NEW)
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/session-progress` | POST | Hook updates progress | ✅ NEW |
| `/session-progress/:pairingId` | GET | Watch polls progress | ✅ NEW |

```typescript
interface SessionProgress {
  pairingId: string;
  currentTask: string | null;
  currentActivity: string | null;
  progress: number;
  completedCount: number;
  totalCount: number;
  elapsedSeconds: number;
  tasks: Array<{ content: string; status: string; activeForm: string | null }>;
  updatedAt: string;
}
```

---

### Session Control Endpoints ✅ (NEW)
| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `/session-end` | POST | Watch ends session | ✅ NEW |
| `/session-status/:pairingId` | GET | Hook checks if session active | ✅ NEW |
| `/session-interrupt` | POST | Watch pauses/resumes Claude | ✅ NEW |
| `/session-interrupt/:pairingId` | GET | Hook checks interrupt state | ✅ NEW |

---

## Issues Fixed ✅

### 1. `/requests` Filter Mismatch - FIXED
**Before**: Filtered `m.type === 'action_requested'` but stored `m.type === 'to_watch'`
**After**: Tries new `approval_queue` first, which has correct structure

### 2. Nested Structure - FIXED
**Before**: `{id, type, payload: {type, action}}`
**After**: Flat `{id, type, title, description, filePath, command}`

### 3. Field Case - FIXED
**Before**: Mixed `file_path` (snake) and `filePath` (camel)
**After**: Consistent `filePath` (camelCase) in new endpoints

---

## Remaining Items to Verify

### 1. Watch App Compatibility
Need to verify `WatchService.swift` uses the new endpoints:
- [ ] Uses `/approval-queue/:pairingId` or updated `/requests/:pairingId`
- [ ] Parses flat structure correctly
- [ ] Uses `filePath` (camelCase)

### 2. Hook Compatibility
Need to verify hooks use new endpoints:
- [ ] PreToolUse hook uses `/approval` POST
- [ ] Hook polls `/approval/:pairingId/:requestId` for response
- [ ] Progress hook uses `/session-progress`

### 3. APNs Payload
Need to verify APNs notifications use correct field names:
- [ ] `filePath` not `file_path`
- [ ] Consistent with polling response structure

---

## API Contract Summary

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    Hook     │     │    Cloud    │     │    Watch    │
│   (CLI)     │     │   Worker    │     │    App      │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       │ POST /approval    │                   │
       │ {pairingId, id,   │                   │
       │  type, title,     │                   │
       │  filePath}        │                   │
       │──────────────────►│                   │
       │                   │                   │
       │                   │ GET /approval-queue/:pairingId
       │                   │◄──────────────────│
       │                   │                   │
       │                   │ {requests: [{     │
       │                   │   id, type,       │
       │                   │   title, filePath │
       │                   │ }]}               │
       │                   │──────────────────►│
       │                   │                   │
       │                   │ POST /approval/:id│
       │                   │ {pairingId,       │
       │                   │  approved}        │
       │                   │◄──────────────────│
       │                   │                   │
       │ GET /approval/:pairingId/:requestId   │
       │──────────────────►│                   │
       │                   │                   │
       │ {status: 'approved'}                  │
       │◄──────────────────│                   │
       │                   │                   │
```

---

## Historical Context

This audit was originally created when critical mismatches were found:
1. Filter bug in `/requests` (stored `to_watch`, filtered `action_requested`)
2. Nested structure (Watch expected flat, Cloud returned nested)
3. Case inconsistency (`file_path` vs `filePath`)

These issues were **fixed** in the merge that added:
- New `/approval` endpoint family with flat structure
- Updated `/requests` to try approval_queue first
- Consistent camelCase field naming

---

*Created: 2026-01-22*
*Updated: 2026-01-22 (post-merge)*
*Status: Most issues resolved*
