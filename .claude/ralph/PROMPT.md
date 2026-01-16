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
3. **CRITICAL: If creating NEW Swift files, you MUST also add them to project.pbxproj** (see Xcode Project Sync below)
4. **Build** to verify changes compile (see Build Verification below)

### Xcode Project Sync (CRITICAL)

**Xcode projects require explicit file registration.** Files on disk don't automatically get compiled.

When creating a NEW `.swift` file:
1. Create the file with Write tool
2. Add it to `ClaudeWatch.xcodeproj/project.pbxproj`:
   - Add a `PBXFileReference` entry (e.g., `SRC007 /* NewFile.swift */`)
   - Add a `PBXBuildFile` entry (e.g., `VIEW004 /* NewFile.swift in Sources */`)
   - Add the file reference to the appropriate `PBXGroup` (e.g., `GRP_VIEWS`)
   - Add the build file to `PHASE_SOURCES`

**Verify sync before building:**
```bash
# Check all Swift files are in project
for f in $(find ClaudeWatch -name "*.swift" ! -path "*/Tests/*"); do
  grep -q "$(basename $f)" ClaudeWatch.xcodeproj/project.pbxproj || echo "MISSING: $f"
done
```

### Build Verification (MANDATORY)

Build verification is **required** before marking any task complete.

**Step 1: Discover available simulator:**
```bash
xcrun simctl list devices available | grep -i "Apple Watch" | head -1
```

**Step 2: Build with discovered simulator:**
```bash
# Use the simulator name from step 1 (e.g., "Apple Watch Series 11 (42mm)")
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

**The build MUST succeed before proceeding.** If it fails:
1. Check for missing files in project.pbxproj
2. Check for Swift compilation errors
3. Fix the issues and rebuild

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

# Check project sync (all Swift files in Xcode project)
./.claude/ralph/watchos-verify.sh --quick

# Build project (dynamic simulator)
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination "platform=watchOS Simulator,name=$SIMULATOR" build

# Full verification (includes build)
./.claude/ralph/watchos-verify.sh
```

---

**BEGIN EXECUTION NOW** - Read tasks.yaml and start working on the first incomplete task.
