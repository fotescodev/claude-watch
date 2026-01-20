# Competitive Parity Implementation Spec

> **Agent Instructions**: This document contains step-by-step implementation tasks derived from Happy Coder competitive analysis. Execute tasks in order. Each task is atomic and independently verifiable.

## Overview

**Source Analysis**: `.claude/analysis/happy-vs-claude-watch-comparison.md`
**Reference Code**: `happy-cli-reference/`, `happy-server-reference/`, `happy-reference/`

**Execution Order**:
1. COMP4: Activity Batching (quick win, watch-only)
2. COMP1: SessionStart Hook (foundation)
3. COMP3: E2E Encryption (phased, high-value)

---

## PHASE 1: Activity Batching (COMP4)

**Complexity**: Low
**Files Modified**: 1 (WatchService.swift)
**Dependencies**: None
**Estimated Tasks**: 3

### Task 1.1: Add ActivityBatcher class to WatchService.swift

**File**: `ClaudeWatch/Services/WatchService.swift`
**Location**: Add after line ~1630 (after `ReconnectionConfig` struct)

**Code to Add**:
```swift
// MARK: - Activity Batching (Happy Pattern)
/// Batches high-frequency updates and flushes every 2 seconds
/// Prevents UI thrashing and reduces network calls
/// Reference: happy-reference/sources/sync/sync.ts (ActivityUpdateAccumulator)
class ActivityBatcher {
    private var pendingProgress: SessionProgress?
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval = 2.0
    private let onFlush: (SessionProgress) -> Void

    init(onFlush: @escaping (SessionProgress) -> Void) {
        self.onFlush = onFlush
    }

    /// Add a progress update to the batch
    func add(_ progress: SessionProgress) {
        // Keep the latest progress (overwrites previous)
        pendingProgress = progress
        scheduleFlush()
    }

    /// Schedule a flush if not already scheduled
    private func scheduleFlush() {
        guard flushTimer == nil else { return }

        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: false) { [weak self] _ in
            self?.flush()
        }
    }

    /// Flush pending updates
    private func flush() {
        flushTimer?.invalidate()
        flushTimer = nil

        if let progress = pendingProgress {
            pendingProgress = nil
            onFlush(progress)
        }
    }

    /// Force immediate flush (for app lifecycle events)
    func flushNow() {
        flushTimer?.invalidate()
        flushTimer = nil

        if let progress = pendingProgress {
            pendingProgress = nil
            onFlush(progress)
        }
    }

    /// Cancel pending flush (for cleanup)
    func cancel() {
        flushTimer?.invalidate()
        flushTimer = nil
        pendingProgress = nil
    }
}
```

**Verification**:
```bash
grep -q "class ActivityBatcher" ClaudeWatch/Services/WatchService.swift && echo "PASS" || echo "FAIL"
```

---

### Task 1.2: Add batcher instance to WatchService

**File**: `ClaudeWatch/Services/WatchService.swift`
**Location**: Add after line ~60 (in "Private" section, after `pollingTask`)

**Find this code**:
```swift
    // MARK: - Cloud Mode Polling
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 2.0
```

**Add after it**:
```swift
    // MARK: - Activity Batching
    private var activityBatcher: ActivityBatcher?
```

**Location**: In `init()` method, add initialization after line ~104 (after `checkFoundationModelsAvailability()`)

**Find this code**:
```swift
        // Check Foundation Models availability
        checkFoundationModelsAvailability()
    }
```

**Add before the closing brace**:
```swift
        // Initialize activity batcher
        activityBatcher = ActivityBatcher { [weak self] progress in
            Task { @MainActor in
                self?.applyBatchedProgress(progress)
            }
        }
```

**Verification**:
```bash
grep -q "private var activityBatcher" ClaudeWatch/Services/WatchService.swift && echo "PASS" || echo "FAIL"
```

---

### Task 1.3: Route progress updates through batcher

**File**: `ClaudeWatch/Services/WatchService.swift`

**Step A**: Add the batched progress handler method.
**Location**: Add after `fetchSessionProgress()` method (around line ~1257)

**Code to Add**:
```swift
    /// Apply batched progress update to UI
    /// Called by ActivityBatcher after 2-second window
    private func applyBatchedProgress(_ progress: SessionProgress) {
        sessionProgress = progress
        lastProgressUpdate = Date()
    }
```

**Step B**: Modify `fetchSessionProgress()` to use batcher instead of direct assignment.
**Location**: Find the section in `fetchSessionProgress()` that sets `sessionProgress` (around line ~1236)

**Find this code**:
```swift
        await MainActor.run {
            if totalCount > 0 {
                sessionProgress = SessionProgress(
```

**Replace the entire `await MainActor.run` block with**:
```swift
        // Batch the progress update (flushes every 2 seconds)
        let progress = SessionProgress(
            currentTask: currentTask,
            currentActivity: currentActivity,
            progress: progress,
            completedCount: completedCount,
            totalCount: totalCount,
            elapsedSeconds: elapsedSeconds,
            tasks: tasks
        )

        await MainActor.run {
            if totalCount > 0 {
                // Route through batcher for smoother updates
                activityBatcher?.add(progress)
            } else if sessionProgress != nil {
                // Only clear if we had progress before (avoid clearing on initial empty response)
                // Check staleness threshold
                if let lastUpdate = lastProgressUpdate,
                   Date().timeIntervalSince(lastUpdate) > progressStaleThreshold {
                    sessionProgress = nil
                    lastProgressUpdate = nil
                }
            }
        }
```

**Step C**: Flush batcher on app lifecycle events.
**Location**: In `handleAppDidEnterBackground()` method

**Find this code**:
```swift
    func handleAppDidEnterBackground() {
        // Stop polling in background to save battery
        if useCloudMode {
            stopPolling()
            return
        }
```

**Add after `stopPolling()`**:
```swift
            // Flush any pending batched updates before backgrounding
            activityBatcher?.flushNow()
```

**Verification**:
```bash
grep -q "activityBatcher?.add" ClaudeWatch/Services/WatchService.swift && \
grep -q "applyBatchedProgress" ClaudeWatch/Services/WatchService.swift && \
echo "PASS" || echo "FAIL"
```

---

### Task 1.4: Build and test

**Commands**:
```bash
# Build for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build 2>&1 | tail -5

# Verify build succeeded
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build 2>&1 | grep -q "BUILD SUCCEEDED" && echo "BUILD PASS" || echo "BUILD FAIL"
```

**Commit**:
```bash
git add ClaudeWatch/Services/WatchService.swift
git commit -m "perf(service): Add activity batching for smoother updates

Implements Happy's ActivityUpdateAccumulator pattern:
- Batches high-frequency progress updates
- Flushes every 2 seconds
- Reduces UI thrashing and network calls
- Improves battery life on watch

Reference: happy-reference/sources/sync/sync.ts"
```

---

## PHASE 2: SessionStart Hook (COMP1)

**Complexity**: Medium
**Files Modified**: 3 (new hook, settings.json, worker)
**Dependencies**: None
**Estimated Tasks**: 5

### Task 2.1: Create SessionStart hook script

**File**: `.claude/hooks/session-start.py` (NEW FILE)

**Content**:
```python
#!/usr/bin/env python3
"""
SessionStart hook for Claude Watch session tracking.

Fires when Claude Code starts, resumes, or forks a session.
Captures session ID and sends to cloud worker for tracking.

Reference: happy-cli-reference/src/claude/session.ts

Usage in .claude/settings.json:
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.py\""
      }]
    }]
  }
}
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# Configuration
CLOUD_SERVER_URL = os.environ.get(
    "CLAUDE_WATCH_SERVER_URL",
    "https://claude-watch.fotescodev.workers.dev"
)
PAIRING_FILE = Path.home() / ".claude-watch-pairing"
SESSION_FILE = Path.home() / ".claude-watch-session"
DEBUG = os.environ.get("CLAUDE_WATCH_DEBUG", "0") == "1"

def debug_log(msg: str):
    """Log debug message if DEBUG is enabled."""
    if DEBUG:
        print(f"[session-start] {msg}", file=sys.stderr)

def get_pairing_id() -> str | None:
    """Read pairing ID from file."""
    if not PAIRING_FILE.exists():
        return None
    return PAIRING_FILE.read_text().strip()

def get_session_id() -> str | None:
    """Get session ID from environment or stdin."""
    # Try environment variable first
    session_id = os.environ.get("CLAUDE_SESSION_ID")
    if session_id:
        debug_log(f"Got session ID from env: {session_id}")
        return session_id

    # Try reading from stdin (hook input)
    try:
        if not sys.stdin.isatty():
            input_data = sys.stdin.read()
            if input_data:
                data = json.loads(input_data)
                session_id = data.get("session_id") or data.get("sessionId")
                if session_id:
                    debug_log(f"Got session ID from stdin: {session_id}")
                    return session_id
    except (json.JSONDecodeError, IOError) as e:
        debug_log(f"Failed to read stdin: {e}")

    return None

def save_session_id(session_id: str):
    """Save session ID to local file for other hooks to use."""
    SESSION_FILE.write_text(session_id)
    debug_log(f"Saved session ID to {SESSION_FILE}")

def send_session_start(pairing_id: str, session_id: str) -> bool:
    """Send session start event to cloud worker."""
    url = f"{CLOUD_SERVER_URL}/session-start"

    payload = json.dumps({
        "pairingId": pairing_id,
        "sessionId": session_id,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "event": "start"
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            debug_log(f"Session start sent: {resp.status}")
            return resp.status == 200
    except urllib.error.URLError as e:
        debug_log(f"Failed to send session start: {e}")
        return False

def main():
    """Main entry point."""
    # Check if watch session is active
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        debug_log("Watch session not active, skipping")
        sys.exit(0)

    # Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        debug_log("No pairing ID found, skipping")
        sys.exit(0)

    # Get session ID
    session_id = get_session_id()
    if not session_id:
        debug_log("No session ID found, skipping")
        sys.exit(0)

    # Save session ID locally
    save_session_id(session_id)

    # Send to cloud
    success = send_session_start(pairing_id, session_id)

    # Always exit 0 to not block Claude
    sys.exit(0)

if __name__ == "__main__":
    main()
```

**Make executable**:
```bash
chmod +x .claude/hooks/session-start.py
```

**Verification**:
```bash
[ -f .claude/hooks/session-start.py ] && [ -x .claude/hooks/session-start.py ] && echo "PASS" || echo "FAIL"
```

---

### Task 2.2: Register SessionStart hook in settings.json

**File**: `.claude/settings.json`

**Read current file first**, then add SessionStart hook to the `hooks` object.

**Find the hooks section** and add SessionStart:
```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.py\""
          }
        ]
      }
    ],
    "PreToolUse": [
      // ... existing PreToolUse hooks
    ],
    "PostToolUse": [
      // ... existing PostToolUse hooks
    ]
  }
}
```

**Verification**:
```bash
jq -e '.hooks.SessionStart' .claude/settings.json >/dev/null && echo "PASS" || echo "FAIL"
```

---

### Task 2.3: Add /session-start endpoint to Cloudflare Worker

**File**: `MCPServer/worker/src/index.ts`

**Location**: Add new endpoint handler (find the route handlers section)

**Code to Add** (find appropriate location in route handling):
```typescript
// Session start tracking (from Happy pattern)
// Stores session metadata for history/resume features
if (request.method === 'POST' && url.pathname === '/session-start') {
  try {
    const body = await request.json() as {
      pairingId: string;
      sessionId: string;
      timestamp: string;
      event: string;
    };

    const { pairingId, sessionId, timestamp, event } = body;

    if (!pairingId || !sessionId) {
      return new Response(JSON.stringify({ error: 'Missing pairingId or sessionId' }), {
        status: 400,
        headers: corsHeaders
      });
    }

    // Store session metadata in KV
    const sessionKey = `session:${pairingId}`;
    const sessionData = {
      sessionId,
      startedAt: timestamp,
      lastEvent: event,
      updatedAt: new Date().toISOString()
    };

    await env.CLAUDE_WATCH_KV.put(sessionKey, JSON.stringify(sessionData), {
      expirationTtl: 86400 // 24 hours
    });

    // Also update the pairing record with current session
    const pairingKey = `pairing:${pairingId}`;
    const existingPairing = await env.CLAUDE_WATCH_KV.get(pairingKey);
    if (existingPairing) {
      const pairingData = JSON.parse(existingPairing);
      pairingData.currentSessionId = sessionId;
      pairingData.lastSessionStart = timestamp;
      await env.CLAUDE_WATCH_KV.put(pairingKey, JSON.stringify(pairingData), {
        expirationTtl: 604800 // 7 days
      });
    }

    return new Response(JSON.stringify({
      success: true,
      sessionId,
      message: 'Session start recorded'
    }), {
      status: 200,
      headers: corsHeaders
    });

  } catch (error) {
    console.error('Session start error:', error);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500,
      headers: corsHeaders
    });
  }
}
```

**Verification**:
```bash
grep -q "session-start" MCPServer/worker/src/index.ts && echo "PASS" || echo "FAIL"
```

---

### Task 2.4: Add GET /session endpoint for watch to query

**File**: `MCPServer/worker/src/index.ts`

**Location**: Add after the POST /session-start handler

**Code to Add**:
```typescript
// Get current session info
if (request.method === 'GET' && url.pathname.startsWith('/session/')) {
  const pairingId = url.pathname.split('/')[2];

  if (!pairingId) {
    return new Response(JSON.stringify({ error: 'Missing pairingId' }), {
      status: 400,
      headers: corsHeaders
    });
  }

  const sessionKey = `session:${pairingId}`;
  const sessionData = await env.CLAUDE_WATCH_KV.get(sessionKey);

  if (!sessionData) {
    return new Response(JSON.stringify({
      hasSession: false,
      sessionId: null
    }), {
      status: 200,
      headers: corsHeaders
    });
  }

  const session = JSON.parse(sessionData);
  return new Response(JSON.stringify({
    hasSession: true,
    ...session
  }), {
    status: 200,
    headers: corsHeaders
  });
}
```

**Verification**:
```bash
grep -q "GET.*session" MCPServer/worker/src/index.ts && echo "PASS" || echo "FAIL"
```

---

### Task 2.5: Test and commit

**Test the hook**:
```bash
# Test hook parsing (should exit 0 without error)
echo '{"session_id": "test-123"}' | CLAUDE_WATCH_SESSION_ACTIVE=1 python3 .claude/hooks/session-start.py
echo "Exit code: $?"
```

**Deploy worker** (if using wrangler):
```bash
cd MCPServer/worker && npx wrangler deploy
```

**Commit**:
```bash
git add .claude/hooks/session-start.py .claude/settings.json MCPServer/worker/src/index.ts
git commit -m "feat(hooks): Add SessionStart hook for session tracking

Implements Happy's session tracking pattern:
- SessionStart hook fires on session start/resume/fork
- Stores session ID locally and in cloud
- Worker stores session metadata in KV
- Enables future session history features

Reference: happy-cli-reference/src/claude/session.ts"
```

---

## PHASE 3: E2E Encryption (COMP3)

**Complexity**: High
**Files Modified**: Multiple across CLI, Worker, Watch
**Dependencies**: COMP1 (for session context)
**Estimated Tasks**: 12 (across 3 sub-phases)

> **Note**: This is a multi-phase implementation. Each sub-phase is independently deployable and testable.

### Sub-Phase 3A: Add encryption to CLI (cc-watch)

#### Task 3A.1: Add tweetnacl dependency

**File**: `claude-watch-npm/package.json`

**Add to dependencies**:
```json
{
  "dependencies": {
    "tweetnacl": "^1.0.3",
    "tweetnacl-util": "^0.15.1"
  }
}
```

**Install**:
```bash
cd claude-watch-npm && npm install tweetnacl tweetnacl-util
```

**Verification**:
```bash
grep -q "tweetnacl" claude-watch-npm/package.json && echo "PASS" || echo "FAIL"
```

---

#### Task 3A.2: Create encryption utility module

**File**: `claude-watch-npm/src/crypto/encryption.ts` (NEW FILE)

**Content**:
```typescript
/**
 * End-to-end encryption for Claude Watch
 * Uses TweetNaCl (same as Happy) for zero-knowledge encryption
 *
 * Reference: happy-cli-reference/src/utils/hmac_sha512.ts
 * Reference: happy-reference/sources/sync/encryption/encryption.ts
 */

import nacl from 'tweetnacl';
import { encodeBase64, decodeBase64, encodeUTF8, decodeUTF8 } from 'tweetnacl-util';

export interface KeyPair {
  publicKey: Uint8Array;
  secretKey: Uint8Array;
}

export interface EncryptedPayload {
  nonce: string;      // Base64 encoded
  ciphertext: string; // Base64 encoded
  publicKey: string;  // Base64 encoded (ephemeral)
}

/**
 * Generate a new keypair for encryption
 */
export function generateKeyPair(): KeyPair {
  return nacl.box.keyPair();
}

/**
 * Derive a keypair from a seed (e.g., pairing secret)
 */
export function deriveKeyPair(seed: Uint8Array): KeyPair {
  // Hash the seed to get 32 bytes for key derivation
  const hash = nacl.hash(seed).slice(0, 32);
  return nacl.box.keyPair.fromSecretKey(hash);
}

/**
 * Encrypt a message for a recipient's public key
 * Uses ephemeral keypair for forward secrecy
 */
export function encrypt(
  message: string,
  recipientPublicKey: Uint8Array
): EncryptedPayload {
  const messageBytes = decodeUTF8(message);
  const nonce = nacl.randomBytes(nacl.box.nonceLength);
  const ephemeralKeyPair = nacl.box.keyPair();

  const ciphertext = nacl.box(
    messageBytes,
    nonce,
    recipientPublicKey,
    ephemeralKeyPair.secretKey
  );

  return {
    nonce: encodeBase64(nonce),
    ciphertext: encodeBase64(ciphertext),
    publicKey: encodeBase64(ephemeralKeyPair.publicKey)
  };
}

/**
 * Decrypt a message using our secret key
 */
export function decrypt(
  payload: EncryptedPayload,
  secretKey: Uint8Array
): string | null {
  try {
    const nonce = decodeBase64(payload.nonce);
    const ciphertext = decodeBase64(payload.ciphertext);
    const senderPublicKey = decodeBase64(payload.publicKey);

    const decrypted = nacl.box.open(
      ciphertext,
      nonce,
      senderPublicKey,
      secretKey
    );

    if (!decrypted) {
      return null;
    }

    return encodeUTF8(decrypted);
  } catch (error) {
    console.error('Decryption failed:', error);
    return null;
  }
}

/**
 * Encrypt JSON data
 */
export function encryptJSON<T>(
  data: T,
  recipientPublicKey: Uint8Array
): EncryptedPayload {
  return encrypt(JSON.stringify(data), recipientPublicKey);
}

/**
 * Decrypt JSON data
 */
export function decryptJSON<T>(
  payload: EncryptedPayload,
  secretKey: Uint8Array
): T | null {
  const decrypted = decrypt(payload, secretKey);
  if (!decrypted) {
    return null;
  }

  try {
    return JSON.parse(decrypted) as T;
  } catch {
    return null;
  }
}

/**
 * Encode keypair for storage
 */
export function encodeKeyPair(keyPair: KeyPair): {
  publicKey: string;
  secretKey: string;
} {
  return {
    publicKey: encodeBase64(keyPair.publicKey),
    secretKey: encodeBase64(keyPair.secretKey)
  };
}

/**
 * Decode keypair from storage
 */
export function decodeKeyPair(encoded: {
  publicKey: string;
  secretKey: string;
}): KeyPair {
  return {
    publicKey: decodeBase64(encoded.publicKey),
    secretKey: decodeBase64(encoded.secretKey)
  };
}
```

**Verification**:
```bash
[ -f claude-watch-npm/src/crypto/encryption.ts ] && echo "PASS" || echo "FAIL"
```

---

#### Task 3A.3: Integrate encryption into pairing flow

**File**: `claude-watch-npm/src/config/pairing-store.ts`

**Modifications needed**:
1. Import encryption utilities
2. Generate keypair during pairing
3. Store keypair with pairing config
4. Send public key to server during pairing

**Add to PairingConfig interface**:
```typescript
export interface PairingConfig {
  pairingId: string;
  cloudUrl: string;
  createdAt: string;
  // New encryption fields
  publicKey?: string;   // Base64 encoded
  secretKey?: string;   // Base64 encoded (stored locally only!)
  encryptionEnabled?: boolean;
}
```

**In createPairingConfig function, add keypair generation**:
```typescript
import { generateKeyPair, encodeKeyPair } from '../crypto/encryption.js';

export function createPairingConfig(cloudUrl: string): PairingConfig {
  const keyPair = generateKeyPair();
  const encoded = encodeKeyPair(keyPair);

  return {
    pairingId: '',
    cloudUrl,
    createdAt: new Date().toISOString(),
    publicKey: encoded.publicKey,
    secretKey: encoded.secretKey,
    encryptionEnabled: true
  };
}
```

**Verification**:
```bash
grep -q "encryptionEnabled" claude-watch-npm/src/config/pairing-store.ts && echo "PASS" || echo "FAIL"
```

---

### Sub-Phase 3B: Add encryption to Worker

> **Deferred**: Complete 3A first, then implement 3B

#### Task 3B.1: Store only encrypted payloads in KV

**File**: `MCPServer/worker/src/index.ts`

**Principle**: Worker receives encrypted blobs, stores them as-is, forwards to watch.
Worker NEVER decrypts. Watch public key sent during pairing.

---

### Sub-Phase 3C: Add decryption to Watch

> **Deferred**: Complete 3A and 3B first, then implement 3C

#### Task 3C.1: Add TweetNaCl-Swift or CryptoKit wrapper

**File**: `ClaudeWatch/Services/EncryptionService.swift` (NEW FILE)

**Note**: Swift has native CryptoKit which can do NaCl-compatible operations.

---

## Verification Checklist

After completing each phase, verify:

### Phase 1 (Batching)
- [ ] `ActivityBatcher` class exists in WatchService.swift
- [ ] Progress updates routed through batcher
- [ ] Batcher flushes on background transition
- [ ] Build succeeds
- [ ] UI updates are smooth (no flickering)

### Phase 2 (SessionStart)
- [ ] `session-start.py` hook exists and is executable
- [ ] Hook registered in settings.json
- [ ] Worker has /session-start endpoint
- [ ] Worker has GET /session/:pairingId endpoint
- [ ] Hook fires when Claude starts (check with DEBUG=1)

### Phase 3A (CLI Encryption)
- [ ] tweetnacl installed
- [ ] encryption.ts module exists
- [ ] Keypair generated during pairing
- [ ] Public key sent to server

---

## Commit Templates

```bash
# Phase 1
git commit -m "perf(service): Add activity batching for smoother updates"

# Phase 2
git commit -m "feat(hooks): Add SessionStart hook for session tracking"

# Phase 3A
git commit -m "feat(security): Add E2E encryption to CLI (phase 1/3)"

# Phase 3B
git commit -m "feat(security): Add E2E encryption to worker (phase 2/3)"

# Phase 3C
git commit -m "feat(security): Add E2E encryption to watch (phase 3/3)"
```

---

## Reference Files

| Feature | Happy Reference | Claude Watch Target |
|---------|-----------------|---------------------|
| Batching | `happy-reference/sources/sync/sync.ts` | `WatchService.swift` |
| Session | `happy-cli-reference/src/claude/session.ts` | `.claude/hooks/session-start.py` |
| Encryption | `happy-reference/sources/sync/encryption/` | `claude-watch-npm/src/crypto/` |
| Key derivation | `happy-cli-reference/src/utils/hmac_sha512.ts` | `encryption.ts` |

---

*Generated: 2026-01-20*
*For use with: Ralph autonomous task executor*
