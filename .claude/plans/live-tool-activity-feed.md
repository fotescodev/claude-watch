# Live Tool Activity Heartbeat

## The Distinction

Two separate concepts — don't conflate:

1. **WorkingView** (exists, `ClaudeWatch/Views/WorkingView.swift`) — **task-level progress**. "3/5 tasks done", checklist, progress bar. Answers: "where are we in the plan?"
2. **Activity heartbeat** (new) — **tool-level pulse**. BASH... EDIT... READ... streaming by. Answers: "what is Claude doing *right now*?"

WorkingView = project manager view. Heartbeat = the terminal scrolling by.

## What It Would Look Like

A compact live ticker showing the most recent tool call:

```
┌─────────────────────────┐
│ ● Working          1:35 │
│                         │
│  ✓ Fix hook path        │
│  ● Add re-pair prompt   │
│  ○ Update tests         │
│                         │
│  ━━━━━━━░░░░  60%       │
│                         │
│  BASH  bun test src/... │  ← heartbeat row
└─────────────────────────┘
```

Or a dedicated swipe-to view with more history:

```
┌─────────────────────────┐
│ ● Activity         1:35 │
│                         │
│  BASH  bun test...   2s │
│  EDIT  config.ts     <1s│
│  READ  default.ts    <1s│
│  READ  prompt.ts     <1s│
│  BASH  git status    <1s│
│                         │
└─────────────────────────┘
```

Tool badges color-coded like Claude Code TUI:
- **BASH** — red (matches terminal's red dots)
- **EDIT/WRITE** — blue
- **READ/Grep/Glob** — gray/dim
- **Task** — orange (subagent spawn)

## Data Flow Changes Needed

### Hook (watch-approval-cloud.py)
Currently only sends events that need approval. Would need to also fire lightweight "activity" pings for all tool uses (or at least the interesting ones — skip Read/Grep to reduce noise).

### Cloud Worker
Add a ring buffer endpoint: `POST /session/{id}/activity` stores last ~10 tool events. Watch picks them up on existing poll via `GET /session/{id}/activity`.

### Watch (WatchService)
Poll activity alongside existing approval polling. Store as `[ToolActivity]` array. Expose to views.

### UI Options
- **Option A**: Single heartbeat row at bottom of WorkingView (minimal, ambient)
- **Option B**: Separate swipeable page/tab (more detail, less clutter)
- **Option C**: Both — heartbeat row in WorkingView, full feed on swipe

## Design Constraints
- Watch screen ~180pt wide — badge (40pt) + text (~140pt truncated)
- Read-only — no interaction, just ambient awareness
- Don't overwhelm — throttle display to 1 update/second max
- Battery: reuse existing polling interval (don't add new timers)
- Most tool calls are Read/Grep — may want to filter to "interesting" ones only

## Idle Screen Rethink

The current idle screen (mascot + "Run: find /User... 3m ago") adds little value. It's a parking screen. The real gap: Claude can be actively working but the watch shows "Idle" because no progress data has arrived yet.

With the heartbeat, the idle-during-session state disappears:
- **No session** → "Ready" (mascot, minimal)
- **Session active, no tasks** → Activity heartbeat (tool calls streaming)
- **Session active, tasks** → WorkingView (task checklist + heartbeat row)

The idle screen essentially becomes the activity feed when a session is active.

## Open Questions
- Should non-approval tool calls even go through the cloud, or is this a local-only feature via a different channel?
- How to handle rapid-fire (10 Reads in 1 second) — show latest only, or batch?
- Is the existing 2s poll interval fast enough to feel "live"?
- Should "Ready" (no session) even show the last activity summary, or just be clean?
