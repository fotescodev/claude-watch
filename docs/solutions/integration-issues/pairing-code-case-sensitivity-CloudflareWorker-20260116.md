---
module: MCPServer
date: 2026-01-16
problem_type: integration_issue
component: service_object
symptoms:
  - "Valid pairing codes rejected with 'Invalid or expired code' error"
  - "Codes entered lowercase failed while uppercase codes worked"
  - "KV lookup returning null for valid codes"
root_cause: logic_error
resolution_type: code_fix
severity: high
tags: [pairing, cloudflare-worker, kv-storage, case-sensitivity, normalization]
---

# Troubleshooting: Pairing Code Case Sensitivity Causing Rejection

## Problem
Valid pairing codes were being rejected with "Invalid or expired code" error. Users entering codes in lowercase would fail, even though the codes were valid. This was due to case sensitivity mismatch between code storage and lookup.

## Environment
- Module: MCPServer (Cloudflare Worker)
- Platform: Cloudflare Workers + KV Storage
- Affected Component: MCPServer/worker/src/index.js
- Date: 2026-01-16

## Symptoms
- Valid pairing codes rejected with "Invalid or expired code" error
- Codes entered in lowercase failed while the same codes in uppercase worked
- KV lookup returning null for codes that definitely existed
- Inconsistent pairing success depending on user input case

## What Didn't Work

**Direct solution:** The problem was identified and fixed on the first attempt after tracing the code path from input to KV lookup.

## Solution

The Cloudflare Worker stored codes in uppercase but performed lookups without normalizing the input code first.

**Code changes**:
```javascript
// Before (broken):
async function lookupPairingCode(code) {
  // Code stored as uppercase, but lookup used raw input
  const data = await PAIRING_KV.get(code);
  if (!data) {
    throw new Error('Invalid or expired code');
  }
  return JSON.parse(data);
}

// After (fixed):
async function lookupPairingCode(code) {
  // Normalize code before lookup to match storage format
  const normalizedCode = code.toUpperCase().trim();
  const data = await PAIRING_KV.get(normalizedCode);
  if (!data) {
    throw new Error('Invalid or expired code');
  }
  return JSON.parse(data);
}
```

## Why This Works

1. **ROOT CAUSE**: The code generation function created uppercase codes (e.g., "ABC123") and stored them in KV with that exact key. However, when users entered codes on the watch (where autocorrect or default keyboard might produce lowercase), the lookup used the raw input without normalization.

2. **The solution** normalizes the input code by:
   - Converting to uppercase with `toUpperCase()` to match storage format
   - Trimming whitespace with `trim()` to handle accidental spaces

3. **Underlying issue**: Inconsistent data normalization between write and read paths. The storage side was opinionated about format (uppercase) but the lookup side was permissive (accepted any case).

## Prevention

- Normalize data at the API boundary, not just at storage time
- Document the expected format for pairing codes (e.g., "always uppercase, alphanumeric")
- Add validation that shows the normalized code back to users
- Consider case-insensitive comparison instead of case-sensitive keys:
  ```javascript
  // Alternative: always lowercase everywhere
  const key = code.toLowerCase().trim();
  ```
- Add integration tests that verify case-insensitive code lookup

## Related Issues

- See also: [pairing-flow-loading-spinner-PairingView-20260116.md](../ui-bugs/pairing-flow-loading-spinner-PairingView-20260116.md) - Related pairing flow issue
