# Ralph Task Execution for Apple Platforms

Execute one task from the iOS/watchOS/macOS project. Follow the phases below.

---

## Phase 0: Task Selection & Clarification

### Step 0.1: Read Current State
```bash
cat .claude/ralph/tasks.yaml
```

Find the first task where `completed: false` (lowest parallel_group, then highest priority).

### Step 0.2: Announce Selection
```
=== STARTING TASK ===
ID: [task id]
Title: [task title]
Priority: [priority]
Parallel Group: [parallel_group]
======================
```

### Step 0.3: Clarification Check
**Before executing**, check if the task description is ambiguous:
- Are the file paths clear?
- Is the implementation approach specified?

**If ambiguous**: Ask clarifying questions NOW, not during implementation.
**If clear**: Proceed to Phase 1.

---

## Phase 1: Context Gathering

### Step 1.1: Read Task Files
Read ALL files listed in the task's `files` array.

### Step 1.2: Find Similar Patterns
Search the codebase for similar implementations. **Follow existing conventions.**

### Step 1.3: Check Documented Learnings
```bash
ls docs/solutions/
```

---

## Phase 2: Execute the Task

### Step 2.1: Make Code Changes
1. **Edit** files to implement the task requirements
2. **Follow** existing code patterns found in Phase 1
3. **Use** proper Apple platform APIs

### Step 2.2: Build Verification (MANDATORY)
Build MUST succeed before proceeding.

```bash
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ ([A-F0-9-]*).*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

**If build fails:** Fix issues and rebuild. DO NOT proceed until build passes.

---

## Phase 3: Quality Gate

### Step 3.1: Run Task Verification
```bash
./.claude/ralph/state-manager.sh verify [TASK_ID]
```

### Step 3.2: Code Quality Checklist
- [ ] Build passes
- [ ] Task verification passes
- [ ] No new compiler warnings
- [ ] Code follows existing patterns

---

## Phase 4: Complete & Ship

### Step 4.1: Mark Task Complete
```bash
./.claude/ralph/state-manager.sh complete [TASK_ID]
```

### Step 4.2: Create Commit
```bash
git add -A
git commit -m "[commit_template from task]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 4.3: Announce Completion
```
=== TASK COMPLETED ===
ID: [task id]
Title: [task title]
Files Changed: [count]
Build: PASSED
Verification: PASSED
Commit: [commit hash]
======================
```

---

## Quick Reference

```bash
./.claude/ralph/state-manager.sh list      # View all tasks
./.claude/ralph/state-manager.sh show [ID] # View specific task
./.claude/ralph/state-manager.sh verify [ID] # Run verification
./.claude/ralph/state-manager.sh complete [ID] # Mark complete
./.claude/ralph/watchos-verify.sh          # Full verification
```

---

## Rules

1. **ONE TASK PER SESSION** - Complete one task, then exit
2. **CLARIFY FIRST** - Ask questions in Phase 0, not during execution
3. **FOLLOW PATTERNS** - Copy existing code style, don't reinvent
4. **BUILD MUST PASS** - No exceptions, fix errors before proceeding
5. **VERIFY BEFORE COMPLETE** - Run verification, ensure it passes
6. **COMMIT YOUR WORK** - Every completed task gets a commit

---

**BEGIN EXECUTION NOW** - Read tasks.yaml and start Phase 0.
