# Ralph Autonomous Loop - Ready to Ship

## What I've Created

I've built a **complete task breakdown** for Ralph to autonomously work through until your watchOS app ships to the App Store.

### Documents Created:

1. **`SHIPPING_ROADMAP.md`** - Complete roadmap with 15 tasks
2. **`TASK_BREAKDOWN.md`** - Detailed breakdown of first 3 critical tasks
3. **This summary** - Quick reference guide

---

## How Ralph Will Work

Ralph will execute tasks in this order:

### Phase 0: Self-Improvement (Sessions 1-2)
**Fix Ralph first before touching app code**

1. **R1** - Fix task tracking (15 min)
   - Problem: Ralph reports "unknown" task IDs
   - Fix: Track which task Ralph is working on

2. **R2** - Prevent plan-only behavior (30 min)
   - Problem: Ralph creates plans but doesn't implement
   - Fix: Require code changes, forbid planning-only

### Phase 1: App Store Blockers (Sessions 3-5)
**Must complete before submission**

3. **C1** - Add accessibility labels (45 min)
   - Add `.accessibilityLabel()` to 27+ UI elements
   - Required for VoiceOver and App Store approval

4. **C2** - Create app icons (45 min)
   - Generate 8 PNG icons for all watchOS sizes
   - Required for App Store submission

5. **C3** - Add consent dialog (60 min)
   - Show AI data consent on first launch
   - Required for Claude API usage compliance

### Phase 2: HIG Compliance (Sessions 6-9)
**Required for quality bar**

6. **H1** - Fix fonts below 11pt (30 min)
7. **H2** - Wire App Groups for complications (45 min)
8. **H3** - Add recording indicator (45 min)
9. **H4** - Update Swift to 5.9+ (20 min)

### Phase 3-5: Polish (Optional, Sessions 10-15)
**Nice to have, not blocking**

- Digital Crown support
- Always-On Display
- Dynamic Type
- Liquid Glass materials
- Spring animations
- UI tests

---

## Each Task Has:

✅ **Clear Problem Statement** - What's broken and why it matters
✅ **Specific Changes Required** - Exact files and line numbers to modify
✅ **Automated Verification** - Bash commands Ralph runs to verify success
✅ **Definition of Done** - Checklist before marking complete
✅ **Commit Message** - Pre-written conventional commit format

---

## Ralph's Execution Loop

For each task, Ralph will:

1. ✅ Read task from SHIPPING_ROADMAP.md
2. ✅ Announce: "STARTING TASK {ID}: {Title}"
3. ✅ Read all target files
4. ✅ Make code changes (Edit/Write tools)
5. ✅ Run verification command
6. ✅ If verification fails: fix and retry (max 3 attempts)
7. ✅ If verification passes: commit with provided message
8. ✅ Update tasks.yaml: `completed: true`
9. ✅ Update session-log.md with notes
10. ✅ Announce: "TASK {ID} COMPLETED"

---

## Success Criteria

Ralph completes when:

- ✅ **9 required tasks done** (R1, R2, C1-C3, H1-H4)
- ✅ **All verifications pass**
- ✅ **App builds without errors**
- ✅ **Ready for TestFlight submission**

Ralph will announce: **"ALL CRITICAL TASKS COMPLETE - APP READY TO SHIP"**

---

## Starting Ralph

```bash
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/ralph.sh
```

Ralph will:
1. Read SHIPPING_ROADMAP.md
2. Start with R1 (fix task tracking)
3. Work autonomously until all tasks complete
4. Create commits as it goes
5. Handle failures and retries automatically

---

## 👀 Watch Ralph Work (Real-Time Monitoring)

### **NEW: Live Progress Dashboard**

In a separate terminal, run:
```bash
./.claude/ralph/monitor-ralph.sh --watch
```

**You'll see in real-time:**
- ✅ Which task Ralph is working on (e.g., "C1: Add accessibility labels")
- ✅ Current step (e.g., "Adding labels to MainView.swift...")
- ✅ Progress updates every 5 seconds
- ✅ Completed tasks and recent commits
- ✅ Build status and verification results

**Example output:**
```
📋 Task Status:
  ✓ Completed: 2 / 15 tasks
  ▶ Next Task: C1 - Add accessibility labels

⚡ Live Progress:
  → STARTING TASK C1
  ✓ Read MainView.swift (1182 lines)
  → Adding accessibility labels...
  ✓ MainView: 24 labels added
  → Running verification...
  ✓ Grep count: 27 ≥ 10 PASS
  ✓ BUILD SUCCEEDED
```

**How it works:**
Ralph uses **TodoWrite** to break each task into sub-steps and updates them as it works. The monitor dashboard shows these updates in real-time!

See **`MONITORING_GUIDE.md`** for full details.

---

## Monitoring Progress

### Check Status:
```bash
# See which tasks are complete
cat .claude/ralph/tasks.yaml | grep -A1 "id:"

# See last session results
tail -20 .claude/ralph/session-log.md

# See cumulative metrics
cat .claude/ralph/metrics.json
```

### View Recent Work:
```bash
# See commits Ralph created
git log --oneline --author="Ralph" -10

# See what files Ralph modified
git diff HEAD~5..HEAD --stat
```

---

## What Makes This Different

Unlike the previous attempt, Ralph now:

1. **Cannot skip implementation**
   - Session fails if no files modified
   - Must create commits to proceed

2. **Tracks work accurately**
   - Reports real task IDs (not "unknown")
   - Session log shows what was done

3. **Has clear success criteria**
   - Every task has automated verification
   - No ambiguity about "done"

4. **Works autonomously**
   - 15 tasks fully specified
   - Can run unattended until shipped

---

## If Ralph Gets Stuck

Ralph will:
1. Document the blocker in session-log.md
2. Not mark task as complete
3. Exit cleanly
4. Loop will retry on next run

You can:
1. Check session-log.md for error details
2. Fix environmental issues (Xcode, simulator, etc.)
3. Run `./ralph.sh` again to retry
4. Or manually complete the blocked task and mark it done

---

## Estimated Timeline

**Minimum** (required tasks only): ~5 hours of Ralph runtime
- Phase 0: 45 min
- Phase 1: 2.5 hours
- Phase 2: 2 hours

**Complete** (all polish): ~8-10 hours
- Includes optional enhancements
- Liquid Glass design
- Full test coverage

Ralph can run continuously or in batches (pause/resume anytime).

---

## Next Steps

1. **Review SHIPPING_ROADMAP.md** - See all 15 tasks
2. **Start Ralph**: `./.claude/ralph/ralph.sh`
3. **Monitor progress**: Check session-log.md and git log
4. **Wait for**: "ALL CRITICAL TASKS COMPLETE - APP READY TO SHIP"

---

## Key Files

- **SHIPPING_ROADMAP.md** - Complete task list (this is the master)
- **tasks.yaml** - Task status tracking (Ralph updates this)
- **session-log.md** - Session history and handoff notes
- **metrics.json** - Cumulative statistics
- **PROMPT.md** - Ralph's execution instructions
- **ralph.sh** - Ralph's execution harness

---

🚀 **Ralph is ready to autonomously ship your watchOS app!**
