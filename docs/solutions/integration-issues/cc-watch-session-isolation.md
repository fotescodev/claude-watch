---
title: "Watch Hooks Affecting All Claude Sessions - Session Isolation"
category: integration-issues
severity: high
platform: watchOS
date: 2025-01-19
symptoms:
  - Watch hooks trigger on ANY Claude Code session, not just watch-enabled ones
  - User cannot tell which terminal has watch mode active
  - End Session from watch doesn't stop notifications
  - Confusing UX with multiple sessions
components:
  - watch-approval-cloud.py
  - progress-tracker.py
  - WatchService.swift
  - SheetViews.swift
  - MCPServer/worker/src/index.js
  - claude-watch-npm/src/cli/setup.ts
tags:
  - watchOS
  - hooks
  - session-isolation
  - CLAUDE_WATCH_SESSION_ACTIVE
  - cc-watch
  - end-session
---

# Watch Hooks Affecting All Claude Sessions

## Problem

Claude Watch hooks were intercepting tool calls from **all** Claude Code sessions, not just those launched via `npx cc-watch`. This caused:

1. Normal `claude` terminal sessions to unexpectedly wait for watch approval
2. No way to disconnect the watch mid-session
3. Confusion about which session was being monitored

## Root Cause

The hooks checked for a pairing ID but not whether the current session was specifically a watch-enabled session. Any Claude session in a project with hooks configured would interact with the watch.

## Solution

Three-part isolation mechanism:

### 1. Session Isolation via Environment Variable

`cc-watch` sets `CLAUDE_WATCH_SESSION_ACTIVE=1` when spawning Claude. Hooks check this first:

```python
# .claude/hooks/watch-approval-cloud.py
def main():
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        sys.exit(0)  # Not a watch session - let terminal handle permissions
```

```typescript
// claude-watch-npm/src/cli/setup.ts
const claude = spawn("claude", [], {
  env: {
    ...process.env,
    CLAUDE_WATCH_SESSION_ACTIVE: "1",
  },
});
```

### 2. End Session from Watch

Users can tap "End Session" in watch Settings to disconnect:

```swift
// ClaudeWatch/Views/SheetViews.swift
Button {
    Task {
        await service.endSession()
    }
} label: {
    SettingsActionRow(icon: "stop.circle.fill", title: "End Session", color: Claude.danger)
}
```

The `endSession()` method signals the cloud and clears local state.

### 3. Cloud API Protection

The worker rejects requests after session ends:

```javascript
// MCPServer/worker/src/index.js
const sessionEnded = await env.PAIRINGS.get(`session-ended:${pairingId}`);
if (sessionEnded) {
  return jsonResponse({ error: 'Session ended', sessionEnded: true }, 400);
}
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│  npx cc-watch                    │  claude (normal)        │
│  ─────────────────               │  ──────────────────     │
│  CLAUDE_WATCH_SESSION_ACTIVE=1   │  (no env var)           │
│  → Watch mode ON                 │  → Terminal mode only   │
│  → Hooks send to watch           │  → Hooks do nothing     │
└─────────────────────────────────────────────────────────────┘
```

## Prevention

For future integrations requiring session isolation:

1. **Check env var FIRST** in hook main()
2. **Exit with code 0** on skip (not 1 or 2)
3. **No logging** when skipping
4. **Set env var only in wrapper CLI**, never in shell profile

## Verification

```bash
# Without env var - hook does nothing
echo '{"tool_name": "Bash"}' | python .claude/hooks/watch-approval-cloud.py
# (exits silently)

# With env var - hook activates
CLAUDE_WATCH_SESSION_ACTIVE=1 echo '{"tool_name": "Bash"}' | python .claude/hooks/watch-approval-cloud.py
# (sends to watch)
```

## Related

- cc-watch npm package: `npx cc-watch@0.1.2`
- Cloudflare Worker: claude-watch.fotescodev.workers.dev
