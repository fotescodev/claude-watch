# Competitive Parity Phase Context

> Decisions captured: 2026-01-20 (updated with user choices)
> Source: Happy Coder competitive analysis

## Key Decisions

### 1. Implementation Order
**Choice**: COMP4 → COMP1 → COMP3 (skip COMP2 for now)
**Rationale**:
- COMP4 (batching) is quick win, watch-only, immediate UX improvement
- COMP1 (SessionStart) is foundation needed for future features
- COMP3 (E2E encryption) is biggest differentiator but highest complexity
- COMP2 (thinking state) is nice-to-have, can come later

### 2. Activity Batching Interval (COMP4)
**Choice**: 2 seconds (match Happy)
**Rationale**: Happy uses 2s, proven to work well. Not configurable initially.
**Implementation**: `ActivityBatcher` class in WatchService.swift

### 3. SessionStart Hook Approach (COMP1)
**Choice**: Python script (consistent with existing hooks)
**Rationale**: All other hooks are Python. Keep consistency.
**Implementation**: `.claude/hooks/session-start.py`

### 4. Session Data Storage (COMP1)
**Choice**: `~/.claude-watch-session` file + Cloud KV
**Rationale**:
- Local file matches existing `~/.claude-watch-pairing` pattern
- Cloud KV for watch to query session info
**Implementation**: POST to `/session-start`, GET from `/session/:pairingId`

### 5. E2E Encryption Library (COMP3)
**Choice**:
- CLI: `tweetnacl` + `tweetnacl-util` (npm) - same as Happy
- Watch: **CryptoKit** (native Apple framework)
**Rationale**:
- TweetNaCl is battle-tested, Happy uses it
- CryptoKit is native to Apple platforms, NaCl-compatible via Curve25519
- No external dependencies on watchOS

### 6. E2E Encryption Phasing (COMP3)
**Choice**: 3 sub-phases, each independently deployable
**Rationale**: Lower risk, can ship incremental value
**Phases**:
1. **3A**: CLI generates keypair, sends public key to server
2. **3B**: Worker stores only encrypted blobs (zero-knowledge)
3. **3C**: Watch decrypts locally using CryptoKit

### 7. CryptoKit Implementation Pattern
```swift
import CryptoKit

// Generate keypair
let privateKey = Curve25519.KeyAgreement.PrivateKey()
let publicKey = privateKey.publicKey

// Derive shared secret
let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerPublicKey)

// Derive symmetric key
let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: nonce,
    sharedInfo: Data(),
    outputByteCount: 32
)

// Encrypt/decrypt with ChaChaPoly (NaCl compatible)
let sealedBox = try ChaChaPoly.seal(plaintext, using: symmetricKey)
let decrypted = try ChaChaPoly.open(sealedBox, using: symmetricKey)
```

## Implementation Notes

- All code changes detailed in: `.claude/plans/competitive-parity-implementation.md`
- Reference code is in `happy-*-reference/` directories (git-ignored)
- Ralph tasks: COMP1, COMP2, COMP3, COMP4 in `tasks.yaml`
- Hooks respect `CLAUDE_WATCH_SESSION_ACTIVE` env var for session isolation

## Out of Scope

- COMP2 (Thinking state indicator) - deferred
- Full message history (like Happy's session scanner) - future work
- Daemon architecture - not needed for watch use case
- Multi-platform (Android/web) - watch-only focus
- FE2b (Stop/Play controls) - deferred

## Verification Criteria

### COMP4 Complete:
- [ ] `ActivityBatcher` class exists in WatchService.swift
- [ ] Progress updates routed through batcher
- [ ] Batcher flushes on background transition
- [ ] Build succeeds, UI updates smoothly

### COMP1 Complete:
- [ ] `session-start.py` hook exists and is executable
- [ ] Hook registered in settings.json under `SessionStart`
- [ ] Worker has `/session-start` and `GET /session/:pairingId` endpoints
- [ ] Hook fires on session start (test with DEBUG=1)

### COMP3A Complete (CLI):
- [ ] `tweetnacl` installed in cc-watch
- [ ] `encryption.ts` module exists
- [ ] Keypair generated during pairing
- [ ] Public key sent to server

### COMP3B Complete (Worker):
- [ ] Worker stores only encrypted payloads
- [ ] Worker forwards encrypted blobs without decryption

### COMP3C Complete (Watch):
- [ ] `EncryptionService.swift` exists using CryptoKit
- [ ] Watch decrypts requests locally
- [ ] Watch encrypts responses

## Next Steps

1. Implement COMP4 (quick win) - see implementation spec Task 1.1-1.4
2. Test on simulator
3. Proceed to COMP1
4. E2E encryption (COMP3) phases 3A → 3B → 3C
