# Ralph Autonomous Loop - Documentation Index

Welcome to Ralph! This directory contains everything needed for autonomous watchOS app development.

---

## 🚀 Quick Start (Read This First!)

**Want to watch Ralph work right now?**

👉 **[QUICK_START.md](QUICK_START.md)** - 2-minute guide to start Ralph and see live progress

---

## 📚 Core Documentation

### For Understanding Ralph

| Document | Purpose | Read When |
|----------|---------|-----------|
| **[QUICK_START.md](QUICK_START.md)** | How to run and watch Ralph | Ready to start |
| **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** | All monitoring options | Want visibility details |
| `../tasks.yaml` | Complete task list (12 tasks) | Want task details |

### For Ralph Itself (Don't Edit)

| File | Purpose | Ralph Uses This To |
|------|---------|-------------------|
| `../PROMPT.md` | Ralph's instructions | Know how to work |
| `../ralph.sh` | Execution harness | Run sessions |
| `../tasks.yaml` | Task tracking | Know what's done |
| `../session-log.md` | Session history | Handoff context |
| `../metrics.json` | Statistics | Track progress |

---

## 🎯 What Ralph Does

Ralph is an **autonomous coding loop** that:

1. ✅ Reads tasks from tasks.yaml
2. ✅ Implements code changes in Swift/SwiftUI
3. ✅ Runs verifications (build, tests, grep)
4. ✅ Creates git commits
5. ✅ Updates progress tracking
6. ✅ Moves to next task
7. ✅ Repeats until app ships

**No human intervention needed** (except approving PR at the end).

---

## 📊 Progress Visibility

### Real-Time Monitoring

**Live Dashboard** (updates every 5 seconds):
```bash
./.claude/ralph/monitor-ralph.sh --watch
```

Shows:
- Current task Ralph is working on
- Live step-by-step progress
- Recent commits
- Build status
- Verification results

**How it works:**
Ralph uses **TodoWrite** to break tasks into sub-steps and updates them as it progresses. The monitor reads these updates and displays them live!

### Manual Checks

**Snapshot view:**
```bash
./.claude/ralph/monitor-ralph.sh
```

**Raw progress log:**
```bash
tail -f .claude/ralph/current-progress.log
```

**Task status:**
```bash
cat tasks.yaml | grep completed
```

---

## 📋 The Task List

### Phase 0: Ralph Self-Improvement
- **R1** - Fix task tracking (15 min)
- **R2** - Prevent plan-only behavior (30 min)

### Phase 1: App Store Blockers (CRITICAL)
- **C1** - Add accessibility labels (45 min)
- **C2** - Create app icons (45 min)
- **C3** - Add AI consent dialog (60 min)

### Phase 2: HIG Compliance (HIGH)
- **H1** - Fix fonts below 11pt (30 min)
- **H2** - Wire App Groups (45 min)
- **H3** - Add recording indicator (45 min)
- **H4** - Update Swift to 5.9 (20 min)

### Phase 3-5: Polish (OPTIONAL)
- **M1-M3** - Digital Crown, Always-On, Dynamic Type
- **LG1-LG2** - Liquid Glass materials, spring animations
- **T1** - UI tests

**Total: 9 required tasks, 3 optional tasks**

See `../tasks.yaml` for complete task definitions with verification commands.

---

## 🎬 How to Use Ralph

### 1. Start Ralph

```bash
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/ralph.sh
```

### 2. Watch Progress (Optional)

In another terminal:
```bash
./.claude/ralph/monitor-ralph.sh --watch
```

### 3. Wait for Completion

Ralph will announce:
```
🚀 ALL CRITICAL TASKS COMPLETE - APP READY TO SHIP
```

### 4. Review and Merge

```bash
# See what Ralph did
git log --oneline -10

# Review changes
git diff HEAD~9..HEAD

# Push to remote
git push origin main
```

---

## 📂 Directory Structure

```
.claude/ralph/
├── PROMPT.md                   ← Ralph's instructions (Ralph reads)
├── INITIALIZER.md              ← Setup guide (Ralph reads)
├── tasks.yaml                  ← Task definitions (Ralph reads)
│
├── session-log.md              ← Session history (Ralph writes)
├── metrics.json                ← Statistics (Ralph writes)
├── current-progress.log        ← Live progress (Ralph writes)
│
├── ralph.sh                    ← Execution harness
├── monitor-ralph.sh            ← Live monitoring dashboard
├── watchos-verify.sh           ← Verification helper
│
└── ralph-context-docs/         ← Human documentation
    ├── README.md               ← This file (overview + testing)
    ├── QUICK_START.md          ← 2-minute start guide
    ├── MONITORING_GUIDE.md     ← Monitoring details
    └── DOC_AUDIT.md            ← Documentation cleanup history
```

---

## 🔍 Key Features

### 1. Task Tracking
Ralph tracks which tasks are complete in `tasks.yaml`. Each task has:
- Clear problem statement
- Specific files to modify
- Automated verification
- Definition of done

### 2. Progress Visibility
Ralph uses **TodoWrite** to announce every step:
- "Reading MainView.swift..."
- "Adding accessibility labels..."
- "Running verification..."
- "BUILD SUCCEEDED"

You see this live in the monitoring dashboard!

### 3. Verification
Every task has automated verification:
```bash
# Example: C1 verification
count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift | wc -l)
[ "$count" -ge 10 ] && exit 0 || exit 1
```

Ralph cannot mark a task complete unless verification passes.

### 4. Failure Handling
If Ralph encounters errors:
- Documents issue in session-log.md
- Does NOT mark task complete
- Exits cleanly
- Next run retries from same task

### 5. Autonomous Operation
Ralph requires zero human intervention:
- Reads instructions from PROMPT.md
- Selects tasks from tasks.yaml
- Modifies Swift files
- Runs builds
- Creates commits
- Updates tracking files

---

## 🛠️ Customization

### Add New Tasks

Edit `../tasks.yaml` and add a new task entry:
```yaml
- id: "NEW1"
  title: "Task title"
  description: |
    Detailed description of what needs to be done.
  priority: critical  # or high, medium, low
  parallel_group: 1
  completed: false
  verification: |
    # Bash command that exits 0 if task is complete
    grep -q "expectedPattern" ClaudeWatch/File.swift
  acceptance_criteria:
    - "Criterion 1"
    - "Criterion 2"
  files:
    - "ClaudeWatch/Path/To/File.swift"
  tags:
    - tag1
    - tag2
  commit_template: "type(scope): description"
```

Ralph will pick it up automatically on next run.

### Adjust Priorities

Edit `tasks.yaml`:
```yaml
- id: "C1"
  priority: critical  # Change this
  completed: false
```

Ralph processes by priority: critical > high > medium > low.

### Skip Optional Tasks

In `tasks.yaml`, mark as completed without implementing:
```yaml
- id: "M1"
  completed: true  # Skip this task
```

Ralph will move to next task.

---

## 📊 Success Metrics

Ralph completes when:
- ✅ 9 required tasks done (R1, R2, C1-C3, H1-H4)
- ✅ All verifications pass
- ✅ App builds without errors
- ✅ Ready for TestFlight

**Estimated timeline:** 5 hours of autonomous work

---

## 🚨 Troubleshooting

### Ralph Not Starting

```bash
# Check if ralph.sh is executable
ls -la ralph.sh

# Make executable if needed
chmod +x ralph.sh

# Check claude CLI is available
which claude
```

### No Progress Updates

```bash
# Check if progress log exists
ls -la current-progress.log

# Start Ralph if not running
./ralph.sh
```

### Build Failures

Ralph will:
1. Attempt to fix (invoke `/fix-build` skill)
2. Retry up to 3 times
3. Document in session-log.md if blocked

You can:
```bash
# Check what failed
cat session-log.md | tail -100

# Fix environmental issue (Xcode, simulator, etc.)
# Then restart Ralph
./ralph.sh
```

---

## 📖 Reading Order

**For first-time users:**
1. This README (overview + testing)
2. [QUICK_START.md](QUICK_START.md) (how to run)
3. [MONITORING_GUIDE.md](MONITORING_GUIDE.md) (how to watch)

**For understanding tasks:**
1. `../tasks.yaml` (complete task definitions)
2. This README "The Task List" section
3. `.claude/APPSTORE-ROADMAP.md` (high-level roadmap in project root)

**For Ralph developers:**
1. `../PROMPT.md` (Ralph's instructions)
2. `../ralph.sh` (execution harness)
3. `../INITIALIZER.md` (setup guide)

---

## 🎉 What Makes This Special

Unlike typical automation:

1. **Autonomous** - No human required after starting
2. **Visible** - Real-time progress updates via TodoWrite
3. **Verified** - Every task has automated checks
4. **Self-fixing** - Ralph improves itself first (R1, R2)
5. **Complete** - Goes from "not started" to "ready to ship"

---

## ✅ Validation & Testing

### Prerequisites

- macOS with Xcode 15+ installed
- watchOS Simulator available (`xcrun simctl list devices | grep -i watch`)
- Claude CLI installed (`claude --version`)
- Python 3 with PyYAML (`python3 -c "import yaml; print('OK')"`)

### Quick Validation

Run this for a quick validation (no Claude execution):

```bash
./.claude/ralph/ralph.sh --help && \
./.claude/ralph/watchos-verify.sh --quick && \
python3 -c "import yaml; d=yaml.safe_load(open('.claude/ralph/tasks.yaml')); print(f'Ready: {len([t for t in d[\"tasks\"] if not t[\"completed\"]])} tasks pending')"
```

Expected output:
```
[help text]
[verification results]
Ready: 12 tasks pending
```

### Testing Phases

**Phase 1: File Validation**
- Verify script permissions (`ralph.sh`, `watchos-verify.sh` are executable)
- Validate `tasks.yaml` syntax (`python3 -c "import yaml; yaml.safe_load(open('.claude/ralph/tasks.yaml'))"`)
- Validate `metrics.json` format

**Phase 2: Script Testing**
- Help command: `./.claude/ralph/ralph.sh --help`
- Dry run: `./.claude/ralph/ralph.sh --dry-run --single`
- Verification harness: `./.claude/ralph/watchos-verify.sh --quick`

**Phase 3: Integration Testing**
- Initialize: `./.claude/ralph/ralph.sh --init`
- Single session: `./.claude/ralph/ralph.sh --single`
- Verify task completion in `tasks.yaml`

**Phase 4: Loop Testing**
- Multi-iteration: `./.claude/ralph/ralph.sh --max-iterations 3`
- Error recovery with `--max-retries`

### Success Criteria

Ralph Loop is fully functional when:
1. Initialization completes without errors
2. Single session completes one task
3. Verification runs all checks
4. Loop completes multiple tasks
5. Error handling logs failures correctly
6. Skills and agents invoke properly

### Troubleshooting

**Build Fails:**
- Check Xcode: `xcode-select -p`
- Check simulator: `xcrun simctl list devices | grep -i watch`
- Try manual build: `xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch build`

**Claude Not Found:**
- Install: `npm install -g @anthropic-ai/claude-code`
- Verify: `claude --version`

**YAML Parse Errors:**
- Validate: `python3 -c "import yaml; yaml.safe_load(open('.claude/ralph/tasks.yaml'))"`
- Check for tab characters (use spaces only)

---

## 🚀 Ready to Start?

**Simplest path:**

```bash
# Terminal 1 - Start Ralph
./.claude/ralph/ralph.sh

# Terminal 2 - Watch Ralph work
./.claude/ralph/monitor-ralph.sh --watch
```

Ralph will autonomously build your watchOS app! 🎉

---

## 📞 Support

**Documentation:**
- This README - Complete overview and testing guide
- [QUICK_START.md](QUICK_START.md) - Quick start guide
- [MONITORING_GUIDE.md](MONITORING_GUIDE.md) - Visibility options
- `../tasks.yaml` - Complete task definitions

**Logs:**
- `../session-log.md` - What Ralph did
- `../current-progress.log` - Live progress
- `../metrics.json` - Statistics

**Issues:**
- Check `../session-log.md` for errors
- Review verification command output
- Ensure Xcode/simulator available

---

**🎯 Ralph is ready to autonomously ship your watchOS app!**

Start with [QUICK_START.md](QUICK_START.md) →
