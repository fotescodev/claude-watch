# Claude Watch Architecture Skeleton

> **READ THIS BEFORE PROPOSING SOLUTIONS.** Understand where your change fits.
>
> This is the source of truth for system design. For detailed API endpoints, see `DATA_FLOW.md`.

---

## System Components

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              CLAUDE WATCH SYSTEM                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   MAC (Developer Machine)                                                       │
│   ├── Claude Code (agent runtime)                                               │
│   │   ├── PreToolUse hooks → approval requests                                  │
│   │   ├── PostToolUse hooks → progress updates                                  │
│   │   └── SessionStart hooks → context injection                                │
│   │                                                                             │
│   └── cc-watch CLI (claude-watch-npm/)                                          │
│       ├── Pairing flow → POST /pair/complete                                    │
│       └── Spawns Claude with CLAUDE_WATCH_SESSION_ACTIVE=1                      │
│                                                                                 │
│   CLOUDFLARE WORKER (claude-watch-cloud/)                                       │
│   ├── /pair/* → Pairing handshake (watch initiates, CLI completes)              │
│   ├── /approval/* → Tool approval requests + responses                          │
│   ├── /session-progress/* → Progress updates from TodoWrite hook                │
│   └── APNs → Push notifications to watch (instant alerts)                       │
│                                                                                 │
│   APPLE WATCH (ClaudeWatch/)                                                    │
│   ├── WatchService.swift → Polls cloud, sends responses, manages state          │
│   ├── Views/ → MainView (approvals), PairingView (setup), ProgressView          │
│   └── Complications/ → Watch face widgets for quick access                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flows (Which Code Talks to What)

| Flow | Direction | Files Involved |
|------|-----------|----------------|
| **Pairing** | Watch → Cloud → CLI | `WatchService.swift` → `index.ts` → `cc-watch.ts` |
| **Approval** | Hook → Cloud → Watch → Cloud → Hook | `watch-approval-cloud.py` → `index.ts` → `WatchService.swift` |
| **Progress** | Hook → Cloud → Watch | `progress-tracker.py` → `index.ts` → `WatchService.swift` |

### Key File Locations

| Component | Path | Purpose |
|-----------|------|---------|
| **Watch App** | `ClaudeWatch/` | SwiftUI watchOS app |
| **Watch Service** | `ClaudeWatch/Services/WatchService.swift` | All cloud API calls, polling, state |
| **Cloud Worker** | `claude-watch-cloud/src/index.ts` | Cloudflare Worker (message router) |
| **CLI** | `claude-watch-npm/src/cli/cc-watch.ts` | Pairing + Claude launcher |
| **Approval Hook** | `.claude/hooks/watch-approval-cloud.py` | PreToolUse → sends approvals |
| **Progress Hook** | `.claude/hooks/progress-tracker.py` | PostToolUse → sends progress |

---

## Before You Change Code

Answer these questions FIRST:

1. **Which component?** (Hook / Cloud / Watch / CLI)
2. **Which flow?** (Pairing / Approval / Progress)
3. **What calls what?** Check `DATA_FLOW.md` for endpoint details
4. **Does it need changes in multiple places?** Most features touch 2-3 components

### Common Patterns

| Task | Components to Modify |
|------|---------------------|
| Add new approval type | Hook + Cloud + Watch |
| Change notification content | Hook + Cloud (APNs payload) |
| Add new UI element | Watch only |
| Change polling interval | Watch only (WatchService) |
| Add new API endpoint | Cloud + caller (Hook or Watch) |

---

## Critical Constraints

### Watch Input Limitations
- Watch can **ONLY** tap approve/reject buttons
- Watch **CANNOT** select from numbered options
- Watch **CANNOT** type text input
- Watch **CANNOT** see multi-line question context

**Implication:** Claude must ask yes/no questions when `CLAUDE_WATCH_SESSION_ACTIVE=1`

### Communication Architecture
- **All communication goes through cloud** (no direct hook↔watch)
- Hooks check `CLAUDE_WATCH_SESSION_ACTIVE=1` before activating
- Cloud uses APNs for instant notifications, polling as fallback
- Watch polls every 2 seconds when app is in foreground

### Session Isolation
- `CLAUDE_WATCH_SESSION_ACTIVE=1` gates watch mode
- Set by `cc-watch` when spawning Claude
- Hooks exit early (code 0) if not set
- Multiple Claude sessions can run, only cc-watch sessions use watch

---

## Debugging Checklist

When something doesn't work:

1. **Check which component failed**
   - Hook logs: `/tmp/claude-watch-hook-debug.log`
   - Cloud logs: `wrangler tail` (Cloudflare dashboard)
   - Watch logs: Xcode console or `log stream`

2. **Trace the flow**
   - See `DATA_FLOW.md` for exact endpoint sequence
   - Each flow has a numbered step diagram

3. **Check known solutions**
   - `docs/solutions/INDEX.md` - categorized by symptom
   - Search for similar error messages

---

## Quick Reference

### Environment Variables
| Variable | Purpose | Set By |
|----------|---------|--------|
| `CLAUDE_WATCH_SESSION_ACTIVE` | Gates watch mode | cc-watch |
| `CLAUDE_WATCH_PAIRING_ID` | Current pairing | cc-watch or ~/.claude-watch-pairing |
| `CLAUDE_WATCH_DEBUG` | Verbose logging | User |

### Cloud Server
- **URL:** `https://claude-watch.fotescodev.workers.dev`
- **Health:** `GET /health` → `{"status":"ok"}`

### Pairing Flow (Watch-Initiated)
```
Watch: POST /pair/initiate → receives code "ABC123"
Watch: Displays code to user
CLI:   User runs `npx cc-watch`, enters code
CLI:   POST /pair/complete {code: "ABC123"}
Watch: Polls /pair/status/:watchId → {paired: true, pairingId}
```

---

## Learnings Log

> Undocumented patterns discovered during development. Add new entries with date.

### 2026-01-23: Initial architecture documentation
- Created from existing DATA_FLOW.md and codebase analysis
- Key insight: Most features require changes in 2-3 components (hook + cloud + watch)

### 2026-01-21: E2E encryption key exchange
- Keys exchanged during pairing, not after
- Watch sends publicKey in `/pair/initiate`
- CLI sends publicKey in `/pair/complete`
- Watch receives cliPublicKey from `/pair/status`

### 2026-01-22: Question handling simplified
- COMP5 complex stdout interception abandoned
- Solution: Constrain Claude to yes/no questions via CLAUDE.md
- Watch's existing approve/reject UI handles this perfectly

---

*Last updated: 2026-01-23*
