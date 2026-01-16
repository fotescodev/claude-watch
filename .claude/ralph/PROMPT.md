# Ralph Task Execution

Execute one task from the watchOS Claude Watch project. Do not plan or discuss - implement now.

## Step 1: Read Current State

Read these files to understand what to do:
- `.claude/ralph/tasks.yaml` - Find the first task with `completed: false`
- Read the task's `files` list to know what to modify

## Step 2: Select Task

From tasks.yaml, find the first incomplete task (lowest parallel_group, highest priority).
Announce your selection:
```
=== STARTING TASK ===
ID: [task id]
Title: [task title]
======================
```

## Step 3: Execute the Task

Make the code changes required by the task description:

1. **Read** all files in the task's `files` list
2. **Edit** those files to implement the task requirements
3. **Build** to verify changes compile: `xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build 2>&1 | tail -20`

### Code Standards

When adding Swift code:
- Add `.accessibilityLabel()` to interactive elements
- Use semantic fonts (`.caption`, `.headline`) not hardcoded sizes
- Use `async/await`, not completion handlers
- Follow existing code style in the file

## Step 4: Verify Your Work

Run the task's verification command from tasks.yaml:
```bash
# Example for accessibility task:
count=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift 2>/dev/null | wc -l)
echo "Found $count accessibility labels"
```

The verification must pass before proceeding.

## Step 5: Mark Complete

Use the state manager to mark the task done:
```bash
./.claude/ralph/state-manager.sh complete [TASK_ID]
```

## Step 6: Commit

Create a git commit:
```bash
git add -A
git commit -m "[task commit_template from tasks.yaml]"
```

## Step 7: Announce Completion

```
=== TASK COMPLETED ===
ID: [task id]
Title: [task title]
Commit: [commit hash]
======================
```

---

## Rules

1. **ONE TASK ONLY** - Complete one task per session
2. **EXECUTE, DON'T PLAN** - Make actual code changes using Edit/Write tools
3. **VERIFY BEFORE MARKING DONE** - Run verification, ensure it passes
4. **USE STATE MANAGER** - Call state-manager.sh to mark complete
5. **COMMIT YOUR WORK** - Every completed task needs a commit

## Quick Reference

```bash
# View task status
./.claude/ralph/state-manager.sh list

# Mark task complete
./.claude/ralph/state-manager.sh complete C1

# Run task verification
./.claude/ralph/state-manager.sh verify C1

# Build project
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

---

**BEGIN EXECUTION NOW** - Read tasks.yaml and start working on the first incomplete task.
