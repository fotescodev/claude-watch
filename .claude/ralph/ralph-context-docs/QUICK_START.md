# Ralph Quick Start - Watch It Work! 🚀

## The Simple Way to Watch Ralph

### Step 1: Open Two Terminals

**Terminal 1 - Ralph (left side):**
```bash
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/ralph.sh
```

**Terminal 2 - Monitor (right side):**
```bash
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/monitor-ralph.sh --watch
```

### Step 2: Watch Ralph Work!

That's it! You'll now see:

**Terminal 1** - Ralph's actual work:
```
=== STARTING TASK ===
ID: C1
Title: Add accessibility labels to interactive elements
Priority: critical
=====================

Reading MainView.swift...
Found 24 interactive buttons
Adding accessibility labels...
...
```

**Terminal 2** - Live dashboard updates every 5 seconds:
```
╔══════════════════════════════════════════════════════════════════╗
║              Ralph Progress Monitor (Live)                       ║
╚══════════════════════════════════════════════════════════════════╝

📋 Task Status:
  ✓ Completed: 2 / 15 tasks
  ▶ Next Task: C1 - Add accessibility labels to interactive elements

📝 Recent Commits:
  abc1234 fix(ralph): Track task IDs in session metrics
  def5678 fix(ralph): Prevent plan-only sessions

📊 Session Summary:
  Sessions run:     3
  Tasks completed:  2
  Tasks failed:     0

⚡ Live Progress:
  → STARTING TASK C1
  ✓ Read MainView.swift (1182 lines)
  ✓ Read PairingView.swift (113 lines)
  → Adding accessibility labels to buttons...
  ✓ Added 24 labels to MainView
  ✓ Added 3 labels to PairingView
  → Running verification (grep count ≥10)...
  ✓ Found 27 accessibility labels - PASS
  → Building project for watchOS Simulator...
  ✓ BUILD SUCCEEDED
  → Creating commit...
  ✓ Committed: fix(a11y): Add accessibility labels
  ✓ TASK C1 COMPLETED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Last updated: 14:32:45 | Refreshing every 5 seconds...
```

---

## What You'll See Ralph Do

### Phase 0: Fix Itself (Sessions 1-2)
```
⚡ Live Progress:
  → STARTING TASK R1: Fix task tracking
  ✓ Read ralph.sh
  ✓ Added task ID extraction
  ✓ Updated metrics tracking
  ✓ Verification passed
  ✓ Committed: fix(ralph): Track task IDs
  ✓ TASK R1 COMPLETED

  → STARTING TASK R2: Prevent plan-only behavior
  ✓ Read ralph.sh and PROMPT.md
  ✓ Added file change validation
  ✓ Updated execution requirements
  ✓ Verification passed
  ✓ Committed: fix(ralph): Require code changes
  ✓ TASK R2 COMPLETED
```

### Phase 1: App Store Blockers (Sessions 3-5)
```
⚡ Live Progress:
  → STARTING TASK C1: Accessibility labels
  ✓ Found 27 interactive elements
  ✓ Added labels to all elements
  ✓ Verification: 27 ≥ 10 PASS
  ✓ BUILD SUCCEEDED
  ✓ TASK C1 COMPLETED

  → STARTING TASK C2: App icons
  ✓ Generated 8 PNG icons
  ✓ Updated Contents.json
  ✓ Verification: 8 icons found
  ✓ BUILD SUCCEEDED
  ✓ TASK C2 COMPLETED

  → STARTING TASK C3: Consent dialog
  ✓ Created ConsentView.swift
  ✓ Added @AppStorage tracking
  ✓ Integrated with app launch
  ✓ Verification passed
  ✓ BUILD SUCCEEDED
  ✓ TASK C3 COMPLETED
```

### Phase 2: Polish (Sessions 6-9)
```
⚡ Live Progress:
  → STARTING TASK H1: Fix font sizes
  → STARTING TASK H2: App Groups
  → STARTING TASK H3: Recording indicator
  → STARTING TASK H4: Swift 5.9
  ...
```

---

## Understanding the Status Colors

When you watch the monitor, you'll see different colors:

- **🟢 Green** (`✓`) - Completed steps, successful builds
- **🔵 Cyan** (`→`) - Currently working on this step
- **🔴 Red** (`✗`) - Errors or failures (check session-log.md)
- **🟡 Yellow** (`⚠`) - Warnings or non-critical issues

---

## How Long Will It Take?

**Phase 0** (Fix Ralph): ~45 minutes
- R1: 15 min
- R2: 30 min

**Phase 1** (Critical): ~2.5 hours
- C1: 45 min
- C2: 45 min
- C3: 60 min

**Phase 2** (Polish): ~2 hours
- H1-H4: 30-45 min each

**Total for shipping:** ~5 hours of Ralph runtime

---

## Pausing and Resuming

### To Pause:
```bash
# In Terminal 1 (Ralph), press:
Ctrl+C
```

Ralph will:
- Finish current step if possible
- Save progress to tasks.yaml
- Update session log

### To Resume:
```bash
# Just run Ralph again:
./.claude/ralph/ralph.sh
```

Ralph will:
- Read tasks.yaml
- Pick up where it left off
- Continue with next incomplete task

---

## Checking Progress Without Live View

Don't want the live dashboard? Just check status:

```bash
# Quick status snapshot
./.claude/ralph/monitor-ralph.sh

# Which tasks are done?
cat .claude/ralph/tasks.yaml | grep "completed:"

# What did Ralph do last?
tail -50 .claude/ralph/session-log.md

# See Ralph's commits
git log --oneline -10
```

---

## When Ralph Completes

You'll see:
```
⚡ Live Progress:
  ✓ TASK H4 COMPLETED
  ✓ ALL CRITICAL TASKS COMPLETE
  ✓ BUILD SUCCEEDED
  ✓ VERIFICATION PASSED

🚀 APP READY TO SHIP

📋 Task Status:
  ✓ Completed: 9 / 9 required tasks
  ✓ 0 failed
```

At this point:
- ✅ All critical tasks done (R1, R2, C1-C3, H1-H4)
- ✅ App builds without errors
- ✅ All verifications pass
- ✅ Ready for TestFlight or App Store submission

---

## Troubleshooting

### "Monitor shows nothing"

Ralph hasn't started yet. Make sure Terminal 1 is running ralph.sh.

### "Monitor shows old data"

Clear the progress log:
```bash
rm .claude/ralph/current-progress.log
```

Then restart the monitor.

### "Ralph seems stuck"

Check Terminal 1 for errors. Ralph might be waiting for:
- Xcode to build
- Verification to complete
- User input (if something went wrong)

You can also check:
```bash
cat .claude/ralph/session-log.md | tail -50
```

---

## Files Ralph Updates

As Ralph works, watch these files change:

| File | What It Shows |
|------|---------------|
| `tasks.yaml` | Which tasks are complete |
| `session-log.md` | Detailed session notes |
| `metrics.json` | Statistics and counts |
| Git commits | Actual code changes |
| `current-progress.log` | Real-time progress |

---

## Pro Tips

### Split Screen Setup

**Best visual setup:**
```
┌─────────────────────┬─────────────────────┐
│   Terminal 1        │   Terminal 2        │
│   Ralph Working     │   Live Monitor      │
│                     │                     │
│ $ ./ralph.sh        │ $ monitor --watch   │
│                     │                     │
│ Reading files...    │ 📋 Task: C1         │
│ Making changes...   │ ⚡ Adding labels... │
│ Building...         │ ✓ BUILD SUCCESS     │
└─────────────────────┴─────────────────────┘
```

### Tail Just the Progress

Minimal overhead:
```bash
tail -f .claude/ralph/current-progress.log
```

### Check Once Per Hour

Don't need live updates?
```bash
# Add to cron or just run manually
./.claude/ralph/monitor-ralph.sh > /tmp/ralph-status.txt
cat /tmp/ralph-status.txt
```

---

## Summary

**To watch Ralph work:**

1. **Terminal 1:** `./.claude/ralph/ralph.sh`
2. **Terminal 2:** `./.claude/ralph/monitor-ralph.sh --watch`

**You'll see:**
- Which task Ralph is on
- What step it's doing
- Build status
- Verification results
- Commits being created
- Real-time progress every 5 seconds

**Ralph will autonomously:**
- Fix itself (R1, R2)
- Complete all App Store blockers (C1, C2, C3)
- Polish the app (H1-H4)
- Announce when ready to ship

🎉 **Sit back and watch Ralph build your app!**
