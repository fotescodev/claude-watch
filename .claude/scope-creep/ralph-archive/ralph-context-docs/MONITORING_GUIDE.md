# How to Monitor Ralph's Progress

Ralph now provides **real-time visibility** into what it's working on. Here's how to watch Ralph as it autonomously builds your app.

---

## Quick Start: Watch Ralph Work

### Option 1: Live Dashboard (Recommended)

```bash
./.claude/ralph/monitor-ralph.sh --watch
```

This shows:
- ✅ Current task status (which task Ralph is on)
- ✅ Recent commits (what Ralph has finished)
- ✅ Session summary (total progress)
- ✅ Live progress updates (what Ralph is doing RIGHT NOW)

**Auto-refreshes every 5 seconds**

### Option 2: Snapshot View

```bash
./.claude/ralph/monitor-ralph.sh
```

Shows current status once without live updates.

### Option 3: Raw Progress Log

```bash
tail -f .claude/ralph/current-progress.log
```

See Ralph's step-by-step progress as it happens.

---

## What You'll See

### 1. Task Status

```
📋 Task Status:

  ✓ Completed: 3 / 15 tasks

  ▶ Next Task: C1
    Add accessibility labels to interactive elements
    Priority: critical
```

**Shows:**
- How many tasks done vs total
- What task Ralph is working on next
- Priority level

### 2. Recent Commits

```
📝 Recent Commits:

  abc1234 fix(ralph): Track task IDs in session metrics
  def5678 fix(ralph): Prevent plan-only sessions
  ghi9012 fix(a11y): Add accessibility labels to interactive elements
```

**Shows:**
- Last 5 commits Ralph created
- Commit messages show what was accomplished

### 3. Live Progress

```
⚡ Live Progress:

  → STARTING TASK C1: Add accessibility labels
  ✓ Read MainView.swift (1182 lines)
  ✓ Read PairingView.swift (113 lines)
  → Identifying interactive elements...
  ✓ Found 24 buttons in MainView.swift
  ✓ Found 3 interactive elements in PairingView.swift
  → Adding accessibility labels to MainView...
  ✓ Added labels to lines 59, 284, 301, 352...
  → Running verification command...
  ✓ Grep count: 27 (target: ≥10) PASS
  → Building project...
  ✓ BUILD SUCCEEDED
  → Creating commit...
  ✓ Committed: fix(a11y): Add accessibility labels
  ✓ TASK C1 COMPLETED
```

**Shows:**
- Ralph's current step (→ arrow)
- Completed steps (✓ checkmark)
- Files being modified
- Verification results
- Build status

---

## Behind the Scenes: How This Works

Ralph now uses **TodoWrite** for every task:

### At Task Start
Ralph breaks the task into steps and creates a checklist:

```javascript
TodoWrite([
  { content: "Read target files", status: "pending", activeForm: "Reading files" },
  { content: "Add accessibility labels", status: "pending", activeForm: "Adding labels" },
  { content: "Run verification", status: "pending", activeForm: "Verifying changes" },
  { content: "Build project", status: "pending", activeForm: "Building project" },
  { content: "Create commit", status: "pending", activeForm: "Committing changes" }
])
```

### During Work
Ralph updates the checklist as it progresses:

```javascript
// Mark current step as in_progress
TodoWrite([
  { content: "Read target files", status: "completed" },
  { content: "Add accessibility labels", status: "in_progress", activeForm: "Adding labels" },
  { content: "Run verification", status: "pending", activeForm: "Verifying changes" },
  ...
])

// Then mark as completed when done
TodoWrite([
  { content: "Read target files", status: "completed" },
  { content: "Add accessibility labels", status: "completed" },
  { content: "Run verification", status: "in_progress", activeForm: "Verifying changes" },
  ...
])
```

### You See It Live
The monitoring dashboard reads Ralph's TodoWrite updates and shows them to you in real-time!

---

## Multiple Ways to Track Progress

### 1. **Live Dashboard** (Best for watching)
```bash
./.claude/ralph/monitor-ralph.sh --watch
```
Auto-refreshing view of Ralph's current work.

### 2. **Task Status File** (Best for scripts)
```bash
cat .claude/ralph/tasks.yaml | grep -A2 "completed:"
```
See which tasks are done programmatically.

### 3. **Session Log** (Best for history)
```bash
cat .claude/ralph/session-log.md
```
Read detailed notes from every session.

### 4. **Git Log** (Best for commits)
```bash
git log --oneline --all
```
See exactly what Ralph has committed.

### 5. **Metrics JSON** (Best for stats)
```bash
cat .claude/ralph/metrics.json | jq
```
View cumulative statistics.

---

## Example: Watching Ralph Work on C1

You start Ralph:
```bash
./.claude/ralph/ralph.sh
```

In another terminal, watch progress:
```bash
./.claude/ralph/monitor-ralph.sh --watch
```

**You'll see (in real-time):**

```
╔══════════════════════════════════════════════════════════════════╗
║              Ralph Progress Monitor (Live)                       ║
╚══════════════════════════════════════════════════════════════════╝

📋 Task Status:

  ✓ Completed: 2 / 15 tasks

  ▶ Next Task: C1
    Add accessibility labels to interactive elements
    Priority: critical

📝 Recent Commits:

  abc1234 fix(ralph): Track task IDs in session metrics
  def5678 fix(ralph): Prevent plan-only sessions

📊 Session Summary:

  Sessions run:     3
  Tasks completed:  2
  Tasks failed:     0

⚡ Live Progress:

  → STARTING TASK C1
  ✓ Read MainView.swift
  ✓ Read PairingView.swift
  → Adding accessibility labels...
  ✓ MainView: 24 labels added
  ✓ PairingView: 3 labels added
  → Running verification...
  ✓ Grep count: 27 ≥ 10 PASS
  → Building...
  ✓ BUILD SUCCEEDED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Last updated: 14:32:45 | Refreshing every 5 seconds...
```

**Every 5 seconds**, the display refreshes with Ralph's latest progress!

---

## Understanding Ralph's Status Updates

### ✓ Completed Steps (Green)
These steps are finished and verified.

### → In Progress (Cyan)
Ralph is currently working on this step.

### ✗ Failed Steps (Red)
Something went wrong. Check session-log.md for details.

### ⚠ Warnings (Yellow)
Non-critical issues Ralph encountered.

---

## Stopping and Resuming

### Gracefully Stop Ralph
```bash
# Press Ctrl+C in the Ralph terminal
```

Ralph will:
- Finish current step if possible
- Update session log
- Save progress

### Resume Ralph
```bash
./.claude/ralph/ralph.sh
```

Ralph will:
- Read previous progress from tasks.yaml
- Continue from next incomplete task
- Pick up where it left off

---

## Troubleshooting

### "No progress updates showing"

**Problem:** Ralph might not have started yet or progress file doesn't exist.

**Solution:**
```bash
# Check if Ralph is running
ps aux | grep "claude"

# Check if progress file exists
ls -la .claude/ralph/current-progress.log

# Start Ralph if not running
./.claude/ralph/ralph.sh
```

### "Monitor shows old data"

**Problem:** Cache from previous run.

**Solution:**
```bash
# Clear progress log and restart monitor
rm .claude/ralph/current-progress.log
./.claude/ralph/monitor-ralph.sh --watch
```

### "Can't see what Ralph is doing in real-time"

**Problem:** TodoWrite might not be working.

**Solution:**
Check if Ralph is following the new PROMPT.md requirements. Look for TodoWrite calls in the Claude CLI output.

---

## Tips for Best Experience

### Run in Split Terminal
```bash
# Terminal 1: Run Ralph
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/ralph.sh

# Terminal 2: Watch progress
./.claude/ralph/monitor-ralph.sh --watch
```

### Check Progress Periodically
If you don't want live updates, just check occasionally:
```bash
./.claude/ralph/monitor-ralph.sh
```

### Tail the Log
For minimal overhead:
```bash
tail -f .claude/ralph/current-progress.log
```

---

## What Ralph Reports

Ralph announces:

1. **Task Start**
   - Which task ID (R1, C1, etc.)
   - Task title and priority

2. **Reading Phase**
   - Files being read
   - Line counts
   - Existing patterns found

3. **Implementation Phase**
   - Files being modified
   - Specific changes (line numbers)
   - Number of changes made

4. **Verification Phase**
   - Commands being run
   - Verification results (PASS/FAIL)
   - Error messages if any

5. **Build Phase**
   - Build command
   - Build status (SUCCESS/FAILED)
   - Error count if failed

6. **Commit Phase**
   - Commit message
   - Files committed
   - Commit hash

7. **Completion**
   - Task marked complete
   - Session summary
   - Next task preview

---

## Files Ralph Updates

As Ralph works, these files are updated in real-time:

| File | Purpose | When Updated |
|------|---------|--------------|
| `current-progress.log` | Live step-by-step log | Continuously during session |
| `tasks.yaml` | Task completion status | When task completes |
| `session-log.md` | Detailed session notes | At session end |
| `metrics.json` | Cumulative statistics | At session end |
| Git commits | Actual code changes | When task completes |

---

## Summary

**To watch Ralph work:**
```bash
# Terminal 1
./.claude/ralph/ralph.sh

# Terminal 2
./.claude/ralph/monitor-ralph.sh --watch
```

**You'll see:**
- ✅ Which task Ralph is on
- ✅ What step Ralph is doing
- ✅ Real-time progress updates
- ✅ Verification results
- ✅ Build status
- ✅ Commits being created

**Ralph updates every few seconds as it works!**

🎉 **You now have full visibility into Ralph's autonomous work!**
