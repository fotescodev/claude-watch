# Bug: npx caching breaks `cc-watch run` after upgrade

## Problem

`npx cc-watch run` may use a cached old version (e.g., 0.1.3) that doesn't have the `run` command. The old version treats "run" as an unknown command, prints help, and exits. The user then runs `claude` directly — without `CLAUDE_WATCH_SESSION_ACTIVE=1` — and the hook is inert.

Result: Claude runs normally, bash commands prompt in terminal, watch shows Idle.

## Symptoms

- Hook runs but exits with no opinion (no JSON output)
- Claude shows its own "Do you want to proceed?" prompt
- Watch stays on "Session Started" / Idle
- `echo $CLAUDE_WATCH_SESSION_ACTIVE` is empty in the Claude session

## Fixes

### 1. `run` command should verify pairing + env var

Before spawning Claude, `run` should:
- Check `~/.claude-watch/config.json` exists (paired)
- Print confirmation: "Watch approvals enabled for this session"
- If not paired, print error and suggest `npx cc-watch` first

### 2. Add version check / cache-bust guidance

In help text and README, document:
```bash
npx cc-watch@latest run    # Force latest version
```

### 3. Consider `run` as default command

If user is already paired, `npx cc-watch` could launch Claude directly (with env var) instead of just printing "Ready!". This eliminates the two-step flow and the caching problem.

Alternative: `npx cc-watch` pairs if needed, then always launches Claude with the env var. Single command, no `run` subcommand needed.

## Files

- `claude-watch-npm/src/index.ts` — `run` command
- `claude-watch-npm/src/cli/cc-watch.ts` — default command flow

## Decision Needed

Should `npx cc-watch` (default) pair + launch Claude? Or keep the two-step `npx cc-watch` then `npx cc-watch run`?

Tradeoff: Single command is simpler UX but re-introduces "cc-watch spawns Claude" (which we removed for simplicity). However, the spawn is now minimal — just `exec` with env var, no monitoring/YOLO/progress bars.
