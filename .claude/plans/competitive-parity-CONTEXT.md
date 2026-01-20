# Competitive Parity Phase Context

> Decisions captured: 2026-01-20
> Source: Happy Coder competitive analysis

## Key Decisions

### 1. Implementation Order
**Choice**: COMP4 → COMP1 → COMP3 (skip COMP2 for now)
**Rationale**:
- COMP4 (batching) is quick win, watch-only, immediate UX improvement
- COMP1 (SessionStart) is foundation needed for future features
- COMP3 (E2E encryption) is biggest differentiator but highest complexity
- COMP2 (thinking state) is nice-to-have, can come later

### 2. Activity Batching Interval
**Choice**: 2 seconds (match Happy)
**Rationale**: Happy uses 2s, proven to work well. Not configurable initially.
**Implementation**: `ActivityBatcher` class in WatchService.swift

### 3. SessionStart Hook Approach
**Choice**: Python script (consistent with existing hooks)
**Rationale**: All other hooks are Python. Keep consistency.
**Implementation**: `.claude/hooks/session-start.py`

### 4. Session Data Storage
**Choice**: Local file + Cloud KV
**Rationale**:
- Local (`~/.claude-watch-session`) for other hooks to read
- Cloud KV for watch to query session info
**Implementation**: POST to `/session-start`, GET from `/session/:pairingId`

### 5. E2E Encryption Library
**Choice**:
- CLI: `tweetnacl` (npm) - same as Happy
- Watch: Swift CryptoKit (native, NaCl-compatible)
**Rationale**:
- TweetNaCl is battle-tested, Happy uses it
- CryptoKit is native to Apple platforms, no external deps

### 6. E2E Encryption Phasing
**Choice**: 3 sub-phases, each independently deployable
**Rationale**: Lower risk, can ship incremental value
**Phases**:
1. CLI generates keypair, sends public key to server
2. Worker stores only encrypted blobs
3. Watch decrypts locally

### 7. Thinking State Approach (COMP2 - deferred)
**Choice**: Option A (timing heuristic) when implemented
**Rationale**: Simplest, no Claude Code changes needed
**Implementation**: If no activity for 3+ seconds during active session, show "thinking"

## Implementation Notes

- All code changes are in the implementation spec: `.claude/plans/competitive-parity-implementation.md`
- Reference code is in `happy-*-reference/` directories (git-ignored)
- Ralph tasks added: COMP1, COMP2, COMP3, COMP4 in `tasks.yaml`

## Out of Scope

- Full message history (like Happy's session scanner) - future work
- Daemon architecture - not needed for watch use case
- Multi-platform (Android/web) - watch-only focus
- RPC device-to-device commands - future work

## Verification Criteria

- [ ] COMP4: `ActivityBatcher` class exists, progress updates batched
- [ ] COMP1: SessionStart hook fires, session ID tracked in KV
- [ ] COMP3: Requests encrypted, server stores only ciphertext

## Next Steps

1. Run `/ralph-it COMP4` or implement Phase 1 manually
2. Test on simulator
3. Proceed to COMP1
4. E2E encryption (COMP3) after core features stable
