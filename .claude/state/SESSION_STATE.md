# Session State - Claude Watch

> Last updated: 2026-02-20
> Session: Bug fixes (hook path + re-pair)
>
> **Branch:** `restructuring`

## Single Source of Truth

**`.claude/plans/MIGRATION_PROGRESS.md`** — all workstream tracking, test counts, timeline.

## Current State

**All known bugs fixed. E2E tested. Ready for next feature work.**

```
[x] remmy-cli built (dist/cli.mjs, 14KB + dist/hooks/)
[x] remmy globally linked (/opt/homebrew/bin/remmy → dist/cli.mjs)
[x] 147 CLI tests passing (110 lib + 15 hooks + 22 commands)
[x] Cloud worker healthy (https://claude-watch.fotescodev.workers.dev)
[x] Pairing active (0cbfe60e-...) in ~/.remmy/config.json
[x] Hook installed at ~/.claude/hooks/watch-approval-cloud.py
[x] Hook registered in ~/.claude/settings.json (PreToolUse)
[x] All watch views E2E tested on simulator (see docs/E2E_TESTING.md)
[x] WorkingView task windowing fixed (center on current task)
[x] Hook path resolution fixed — works from both src/ and dist/
[x] Re-pair dialogue added — "Keep this pairing? (Y/n)"
```

## Architecture

```
remmy-cli → install hook → spawn claude (native TUI)
                ↓
     watch-approval-cloud.py (PreToolUse hook)
                ↓
         Cloud Worker ← Watch polls
```

## E2E Test Results (2026-02-20)

All views tested on watchOS Simulator (Series 11 46mm):

| View | Status |
|------|--------|
| Idle / Empty | PASS |
| Single Approval | PASS |
| Reject | PASS |
| Approval Queue (2+) | PASS |
| Approve All | PASS |
| Working (0/5 start) | PASS |
| Working (4/5 near end) | PASS |
| Success / Complete | PASS |
| Question (multi-option) | PASS |
| Pause | PASS |
| Session isolation | PASS |

See `docs/E2E_TESTING.md` for curl commands to reproduce all tests.

## Recent Commits

| Commit | Description |
|--------|-------------|
| `a461bfc` | fix: hook install path resolution and add re-pair dialogue |
| `f2276f5` | feat: E2E tested full watch flow, fix task list windowing |

## Key Learnings

1. `bun build` sets `import.meta.dirname` to the output directory — copy non-code assets into `dist/` during build
2. Bun `mock.module()` replaces ESM live bindings — use `.bind()` to capture real function before mocking
3. Cloud worker session-progress: fields must be FLAT at top level of POST body (not nested under `progress` key)
4. Question options must be objects `[{label, description}]` not strings — watch silently ignores string options
5. If `recommendedAnswer` is present in question, watch may auto-answer with it
6. Pause is watch-initiated only (user taps Pause button) — can't trigger from cloud
7. `bun run test` exits code 1 despite 0 failures — mocked `process.exit` in command tests causes this
