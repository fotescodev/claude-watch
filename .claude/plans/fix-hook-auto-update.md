# Bug: ensureHook() doesn't update existing hook files

## Problem

`ensureHook()` in `cc-watch.ts` checks `isHookConfigured()` and skips if a hook already exists. This means `npx cc-watch` never updates the hook to a newer version. Users get stuck on old hook behavior after upgrading cc-watch.

Discovered when: Published 0.1.4 with dual-gate session isolation (env var + config file), but `npx cc-watch` didn't copy the new hook because the old one was already installed.

## Fix

`ensureHook()` should always copy the latest hook file from the package, then check/update registration. The `installHookScript()` function in `hooks-config.ts` already uses `copyFileSync` (overwrites), so just remove the early return.

### cc-watch.ts

```typescript
function ensureHook(): void {
  // Always install latest hook file (overwrites existing)
  const hookSpinner = ora("Updating approval hook...").start();
  const result = setupHook();
  if (result.installed && result.registered) {
    hookSpinner.succeed("Approval hook up to date");
  } else {
    hookSpinner.warn("Hook installation incomplete");
  }
}
```

### setup.ts

Same change in `configureHook()` — always copy, never skip.

## Files

- `claude-watch-npm/src/cli/cc-watch.ts` — `ensureHook()`
- `claude-watch-npm/src/cli/setup.ts` — `configureHook()`

## Verification

```bash
# Install old hook manually
echo "old" > ~/.claude/hooks/watch-approval-cloud.py
# Run cc-watch
npx cc-watch
# Check hook was updated
head -5 ~/.claude/hooks/watch-approval-cloud.py  # Should show new version
```
