---
name: add-hook-to-capture-todowrite-events-fro
description: Harvested from Ralph task FE1a - Add hook to capture TodoWrite events from Claude Code
tags: [enhancement,hooks,progress-tracking, auto-harvested]
harvested_from: FE1a
harvested_at: 2026-01-19T01:59:37Z
---

# Add hook to capture TodoWrite events from Claude Code

## When to Use
This skill was automatically harvested from a successful Ralph task completion.
Use when facing similar patterns in watchOS development.

## Context
Create a PostToolUse hook that intercepts TodoWrite tool calls
and extracts the task list with statuses.

IMPLEMENTATION:
1. Create .claude/hooks/progress-tracker.py
2. Hook triggers on PostToolUse for TodoWrite tool
3. Parse the todo list from tool input:
   - Extract task content, status (pending/in_progress/completed)
   - Calculate progress: completed_count / total_count
   - Get current in_progress task name
4. Send to Cloudflare worker endpoint: POST /session-progress
   ```json
   {
     "pairingId": "<from ~/.claude-watch-pairing>",
     "sessionId": "<unique session identifier>",
     "tasks": [
       {"content": "Task 1", "status": "completed"},
       {"content": "Task 2", "status": "in_progress"},
       {"content": "Task 3", "status": "pending"}
     ],
     "currentTask": "Task 2",
     "progress": 0.33
   }
   ```
5. Register hook in .claude/settings.json under PostToolUse

REFERENCE FILES:
- .claude/hooks/watch-approval-cloud.py (example of sending to worker)
- .claude/settings.json (hook registration format)

TEST:
```bash
# Simulate TodoWrite call
echo '{"tool": "TodoWrite", "input": {"todos": [{"content": "Test", "status": "completed"}]}}' | python3 .claude/hooks/progress-tracker.py
```

## Implementation Pattern
This skill was harvested automatically. Review the commit history for task FE1a
to understand the specific implementation details.

## Files Affected
- .claude/hooks/progress-tracker.py
- .claude/settings.json

## Verification
```bash
[ -f .claude/hooks/progress-tracker.py ] && \
grep -q "PostToolUse" .claude/settings.json && \
grep -q "TodoWrite" .claude/hooks/progress-tracker.py
```
