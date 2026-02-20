# Session State - Claude Watch

> Last updated: 2026-02-20
> Session: Bug fixes (hook path + re-pair + cloud URL)
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
[x] Hook installed at ~/.claude/hooks/watch-approval-cloud.py
[x] Hook registered in ~/.claude/settings.json (PreToolUse)
[x] All watch views E2E tested on simulator (see docs/E2E_TESTING.md)
[x] Hook path resolution fixed — works from both src/ and dist/
[x] Re-pair dialogue added — "Keep this pairing? (Y/n)"
[x] Default cloud URL fixed — uses workers.dev (remmy.watch had no /health)
```

## Architecture

```
remmy-cli → install hook → spawn claude (native TUI)
                ↓
     watch-approval-cloud.py (PreToolUse hook)
                ↓
         Cloud Worker ← Watch polls
```

## Recent Commits

| Commit | Description |
|--------|-------------|
| `2d084f0` | fix: use workers.dev as default cloud URL |
| `a461bfc` | fix: hook install path resolution and add re-pair dialogue |
| `f2276f5` | feat: E2E tested full watch flow, fix task list windowing |

## Discovery: Keychain Persistence

watchOS Keychain survives app reinstalls on both simulator and device. `pairingId` is stored in Keychain (`KeychainHelper`), so reinstalling the app does NOT trigger the pairing screen. Use Settings > Unpair or Erase Simulator to reset.

## Key Learnings

1. `bun build` sets `import.meta.dirname` to the output directory — copy non-code assets into `dist/` during build
2. `remmy.watch` domain exists but has no `/health` route — actual worker is at `claude-watch.fotescodev.workers.dev`
3. After `deleteConfig()` in re-pair flow, `getCloudUrl()` falls back to `DEFAULT_CLOUD_URL` — must be correct
4. `bun run test` exits code 1 despite 0 failures — mocked `process.exit` in command tests
