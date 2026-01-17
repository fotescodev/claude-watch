# Ralph Task Execution for Apple Platforms

Execute one task from the iOS/watchOS/macOS project. Follow the phases below.

---

## Phase 0: Task Selection & Clarification

### Step 0.1: Read Current State

```bash
# Read tasks to find what to do
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
- Are there multiple valid interpretations?

**If ambiguous**: Ask clarifying questions NOW, not during implementation.
**If clear**: Proceed to Phase 1.

---

## Phase 1: Context Gathering

### Step 1.1: Read Task Files

Read ALL files listed in the task's `files` array:

```bash
# Example: Read each file the task references
cat ClaudeWatch/Views/MainView.swift
cat ClaudeWatch/DesignSystem/Claude.swift
```

### Step 1.2: Find Similar Patterns

Search the codebase for similar implementations:

```bash
# Find related patterns
grep -r "similar_pattern" ClaudeWatch/ --include="*.swift"
```

**Follow existing conventions.** Don't reinvent - copy patterns from the codebase.

### Step 1.3: Check Documented Learnings

Read relevant learnings if they exist:

```bash
# Check for solutions to similar problems
ls docs/solutions/
```

---

## Phase 2: Execute the Task

### Step 2.1: Make Code Changes

1. **Edit** files to implement the task requirements
2. **Follow** existing code patterns found in Phase 1
3. **Use** proper Apple platform APIs (see Code Standards below)

### Step 2.2: Xcode Project Sync (CRITICAL)

**Xcode projects require explicit file registration.** New files on disk don't automatically compile.

When creating a NEW `.swift` file:

1. Create the file with Write tool
2. Add to `*.xcodeproj/project.pbxproj`:
   - `PBXFileReference` entry
   - `PBXBuildFile` entry
   - Add to appropriate `PBXGroup`
   - Add to `PBXSourcesBuildPhase`

**Verify sync:**
```bash
# Check all Swift files are in project
for f in $(find ClaudeWatch -name "*.swift" ! -path "*/Tests/*"); do
  grep -q "$(basename $f)" ClaudeWatch.xcodeproj/project.pbxproj || echo "MISSING: $f"
done
```

### Step 2.3: Build Verification (MANDATORY)

Build MUST succeed before proceeding.

**For watchOS:**
```bash
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

**For iOS:**
```bash
SIMULATOR=$(xcrun simctl list devices available | grep -i "iPhone" | head -1 | sed 's/^ *//' | sed 's/ (.*//')
xcodebuild -project [Project].xcodeproj -scheme [Scheme] \
  -destination "platform=iOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

**If build fails:**
1. Check for missing files in project.pbxproj
2. Check Swift compilation errors
3. Fix issues and rebuild
4. DO NOT proceed until build passes

---

## Phase 3: Quality Gate

### Step 3.1: Run Task Verification

Execute the verification command from tasks.yaml:

```bash
# Example verification
./.claude/ralph/state-manager.sh verify [TASK_ID]
```

The verification MUST pass.

### Step 3.2: Code Quality Checklist

Before marking complete, verify:

- [ ] Build passes (xcodebuild succeeds)
- [ ] Task verification command passes
- [ ] No new compiler warnings introduced
- [ ] Code follows existing patterns in codebase
- [ ] Accessibility labels on interactive elements
- [ ] No force unwraps (`!`) without justification

### Step 3.3: UI Screenshot (If Applicable)

**If the task modified UI**, capture a screenshot:

```bash
# Boot simulator and capture
xcrun simctl boot "[Simulator Name]"
xcrun simctl io "[Simulator Name]" screenshot ~/Desktop/task-[ID]-after.png
```

### Step 3.4: Optional Reviewer Agents

For complex tasks (5+ files changed), consider running reviewers.

**Step 3.4.1: Check for compound-engineering plugin**

```bash
# Check if compound-engineering is available
if ls ~/.claude/plugins/cache/*/compound-engineering/ 2>/dev/null | head -1; then
  echo "compound-engineering: AVAILABLE"
else
  echo "compound-engineering: NOT INSTALLED (using project-local agents only)"
fi
```

**Step 3.4.2: Run project-local reviewers (always available)**

```
# Swift code review
Task swift-reviewer: "Review changes for Swift best practices"

# SwiftUI patterns
Task swiftui-specialist: "Review SwiftUI implementation"

# Architecture review
Task watchos-architect: "Review watchOS architecture decisions"
```

**Step 3.4.3: Run compound-engineering reviewers (if available)**

If the plugin check passed, also run these for deeper analysis:

```
# Code simplicity (YAGNI, over-engineering)
Task code-simplicity-reviewer: "Check for unnecessary complexity"

# Performance analysis
Task performance-oracle: "Analyze performance implications"

# Pattern recognition
Task pattern-recognition-specialist: "Check for anti-patterns and code smells"
```

**Skip reviewers for simple tasks** (1-2 files, straightforward changes).

---

## Phase 4: Complete & Ship

### Step 4.1: Mark Task Complete

```bash
./.claude/ralph/state-manager.sh complete [TASK_ID]
```

### Step 4.2: Create Commit

Use the commit_template from tasks.yaml:

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

## Apple Platform Code Standards

### Swift Style
- Use `async/await` for async operations
- Prefer `guard` for early exits
- Use `@MainActor` for UI updates
- Follow Swift API Design Guidelines

### SwiftUI Patterns
- Use `@State` for local view state
- Use `@Environment` for dependency injection
- Use `@Observable` macro (iOS 17+/watchOS 10+)
- Keep views under 100 lines

### Accessibility (Required)
- Add `.accessibilityLabel()` to all interactive elements
- Add `.accessibilityHint()` for non-obvious actions
- Respect `@Environment(\.accessibilityReduceMotion)`
- Test with VoiceOver

### watchOS Specific
- Use `.sensoryFeedback()` for haptics
- Prefer single-tap interactions
- Use SF Symbols for icons
- Support Always-On Display states

### iOS Specific
- Support Dynamic Type
- Respect Safe Area Insets
- Handle keyboard appearance
- Support Dark Mode

---

## Quick Reference

```bash
# View all tasks
./.claude/ralph/state-manager.sh list

# View specific task
./.claude/ralph/state-manager.sh show [ID]

# Run verification
./.claude/ralph/state-manager.sh verify [ID]

# Mark complete
./.claude/ralph/state-manager.sh complete [ID]

# Check Xcode sync
./.claude/ralph/watchos-verify.sh --quick

# Full verification (build + tests)
./.claude/ralph/watchos-verify.sh

# Capture simulator screenshot
xcrun simctl io booted screenshot ~/Desktop/screenshot.png
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
