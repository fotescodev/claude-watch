# Session State - Claude Watch

> Last updated: 2026-02-20
> Session: Complications brainstorm + double-tap fix
>
> **Branch:** `restructuring`

## Single Source of Truth

**`.claude/plans/MIGRATION_PROGRESS.md`** — all workstream tracking, test counts, timeline.

## Current State

**Post-cleanup. Hooks architecture is clean. Ready for E1-E5 new capabilities.**

```
[x] remmy-cli built (dist/cli.mjs, 14KB + dist/hooks/)
[x] remmy globally linked (/opt/homebrew/bin/remmy → dist/cli.mjs)
[x] 147 CLI tests passing (110 lib + 15 hooks + 22 commands)
[x] Cloud worker healthy (https://claude-watch.fotescodev.workers.dev)
[x] Hook installed at ~/.claude/hooks/watch-approval-cloud.py
[x] Hook registered in ~/.claude/settings.json (PreToolUse)
[x] All watch views E2E tested on simulator (see docs/E2E_TESTING.md)
[x] C1: Watch approval flow verified in live Claude session
[x] AskUserQuestion routes to watch — answer via /tmp/remmy-question-answer.json
[x] R5: KV TTL fixed — session data 5min → 1hr, deployed
[x] F1-F3: Legacy cleanup — 17 hook files, 6 cloud endpoints, stale config removed
```

## Architecture

```
remmy-cli → install hook → spawn claude (native TUI)
                ↓
     watch-approval-cloud.py (PreToolUse hook)
                ↓
         Cloud Worker ← Watch polls
```

### AskUserQuestion Flow (NEW)

```
Claude calls AskUserQuestion
  → Hook intercepts, POSTs to /question on cloud
  → Watch shows QuestionResponseView with options
  → User taps an option
  → Watch POSTs answer to /question/:questionId
  → Hook polls, gets answer, writes /tmp/remmy-question-answer.json
  → Hook denies tool (exit 2)
  → Claude reads temp file, proceeds with user's choice
```

Graceful degradation: cloud failure or "Handle on Mac" → falls through to terminal.

## Recent Commits

| Commit | Description |
|--------|-------------|
| `e48b8f4` | feat: route AskUserQuestion to watch + fix KV TTL expiry |
| `2d084f0` | fix: use workers.dev as default cloud URL |
| `a461bfc` | fix: hook install path resolution and add re-pair dialogue |
| `f2276f5` | feat: E2E tested full watch flow, fix task list windowing |

## What's Next

| Priority | Item | Status |
|----------|------|--------|
| **P1** | Activity Rings (Build/Ship/Guard) | Brainstormed, see `.claude/plans/watchos-complications-brainstorm.md` |
| **P1** | Interactive widget approve/reject buttons | Brainstormed |
| **P1** | APNs complication push for real-time widget updates | Brainstormed |
| **P2** | Session mood ring complication | Brainstormed |
| **P2** | Watch face sharing during onboarding | Brainstormed |
| **P3** | Claude Radio (walkie-talkie voice to Claude) | Brainstormed |
| P3 | Developer daily dashboard | Brainstormed |
| -- | E1: Permission Learning ("Always Allow" from watch) | PENDING |
| -- | E2: Model Switching from Watch | PENDING |
| -- | E3: Real-Time Streaming | PENDING |
| -- | R8, R10: Test coverage gaps | PENDING |

## Key Learnings

1. Claude Code hooks can only allow/deny — cannot inject answers into interactive tools
2. Workaround: deny AskUserQuestion + write answer to temp file + Claude reads it
3. Cloud KV TTL of 5 min was too short — long thinking pauses caused session data to expire
4. The watch QuestionResponseView already supported multi-option questions — only the hook was missing
5. `--sdk-url` is undocumented and potentially unsupported — hooks approach is safer long-term
6. `.handGestureShortcut(.primaryAction)` requires watchOS 11.0 — was incorrectly gated at 26.0
7. `ControlWidget` APIs genuinely require watchOS 26.0 — not available earlier
8. `.claude/inbox/` consolidated into `.claude/plans/` — single directory
