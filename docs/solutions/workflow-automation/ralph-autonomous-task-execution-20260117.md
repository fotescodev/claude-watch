---
module: ralph
date: 2026-01-17
problem_type: feature_implementation
component: autonomous-execution
symptoms:
  - "Manual task execution from plans required significant developer intervention"
  - "No structured workflow for Apple platform development tasks"
  - "Lack of quality gates in task execution pipeline"
  - "Missing integration between plan documents and executable tasks"
root_cause: Absence of an autonomous task execution system that could convert implementation plans into structured, executable tasks with built-in quality assurance
resolution_type: new_system
severity: enhancement
tags:
  - ralph
  - autonomous-execution
  - watchos
  - ios
  - macos
  - apple-platforms
  - task-automation
  - swiftui
  - code-review
  - quality-gates
  - compound-engineering
  - workflow-automation
---

# Ralph: Autonomous Task Execution System for Apple Platforms

## State of the Union (SOTU) - January 17, 2026

### Current Status: OPERATIONAL

Ralph is a fully functional autonomous task execution system for Apple platform development (watchOS, iOS, macOS). It converts implementation plans into executable tasks and runs them through a structured 4-phase workflow.

### What Exists

| Component | Location | Status |
|-----------|----------|--------|
| PROMPT.md | `.claude/ralph/PROMPT.md` | Complete - 4-phase workflow |
| tasks.yaml | `.claude/ralph/tasks.yaml` | 18 UX tasks (UX0-UX17) |
| /ralph-it skill | `.claude/commands/ralph-it.md` | Complete - plan-to-task converter |
| state-manager.sh | `.claude/ralph/state-manager.sh` | Complete - task state management |
| Project agents | `.claude/agents/` | 4 agents (swift-reviewer, swiftui-specialist, watchos-architect, websocket-expert) |

### Recent Changes (This Session)

1. **Flattened file structure** - Reduced from 14 files/6 directories to 5 files
2. **Fixed buggy defer pattern** - `Task { @MainActor in defer { } }` instead of nested Task
3. **Added optional compound-engineering integration** - Graceful plugin detection
4. **Retained Liquid Glass/watchOS 26** - Confirmed current, not hypothetical
5. **Integrated /workflows:work patterns** - 4-phase execution model

### Pending Work

18 UX improvement tasks in `tasks.yaml` ready for execution:
- UX0: Build verification (prerequisite)
- UX1-UX2: Design system consolidation
- UX3-UX6: View extraction and organization
- UX7-UX12: Animation, accessibility, haptics
- UX13: Liquid Glass adoption (watchOS 26)
- UX14-UX17: Polish and cleanup

### How to Run Ralph

```bash
# In Claude Code CLI (uses Claude Max subscription)
claude

# Then invoke Ralph
cat .claude/ralph/PROMPT.md
# Follow the phases...

# Or use the skill
/ralph-it plans/your-plan.md
```

---

## Problem Statement

Executing tasks from implementation plans required:
- Manual interpretation of plan steps
- No consistent quality gates
- Missing build verification
- Ad-hoc code review (or none)
- No structured clarification phase

## Solution: 4-Phase Workflow

### Phase 0: Task Selection & Clarification

**Purpose**: Select task and verify requirements are clear BEFORE coding.

```
=== STARTING TASK ===
ID: UX1
Title: Create centralized design system
Priority: critical
Parallel Group: 10
======================
```

**Clarification checklist**:
- Are file paths clear?
- Is implementation approach specified?
- Are there multiple valid interpretations?

**If ambiguous**: Ask NOW, not during implementation.

### Phase 1: Context Gathering

**Purpose**: Understand before modifying.

1. **Read task files** from `files` array in tasks.yaml
2. **Find similar patterns** in codebase
3. **Check documented learnings** in `docs/solutions/`

```bash
# Example pattern search
grep -r "similar_pattern" ClaudeWatch/ --include="*.swift"
```

### Phase 2: Execute

**Purpose**: Implement with continuous verification.

1. **Make code changes** following existing patterns
2. **Xcode project sync** for new files (critical for `.xcodeproj`)
3. **Build verification** (MANDATORY)

```bash
# watchOS build
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

**Build must pass before proceeding.**

### Phase 3: Quality Gate

1. **Run task verification** from tasks.yaml
2. **Code quality checklist**:
   - [ ] Build passes
   - [ ] Task verification passes
   - [ ] No new warnings
   - [ ] Follows existing patterns
   - [ ] Accessibility labels present
   - [ ] No unjustified force unwraps
3. **UI screenshot** if visual changes
4. **Optional reviewer agents**

### Phase 4: Complete & Ship

```bash
# Mark complete
./.claude/ralph/state-manager.sh complete [TASK_ID]

# Commit
git add -A
git commit -m "[commit_template from task]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Optional Compound-Engineering Integration

Ralph gracefully detects and uses compound-engineering when available.

### Detection

```bash
if ls ~/.claude/plugins/cache/*/compound-engineering/ 2>/dev/null | head -1; then
  echo "compound-engineering: AVAILABLE"
else
  echo "compound-engineering: NOT INSTALLED (using project-local agents only)"
fi
```

### Agent Hierarchy

**Always available (project-local)**:
- `swift-reviewer` - Swift best practices
- `swiftui-specialist` - SwiftUI patterns
- `watchos-architect` - watchOS architecture

**When compound-engineering installed**:
- `code-simplicity-reviewer` - YAGNI, over-engineering
- `performance-oracle` - Performance analysis
- `pattern-recognition-specialist` - Anti-patterns, code smells

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
- `.accessibilityLabel()` on interactive elements
- `.accessibilityHint()` for non-obvious actions
- Respect `@Environment(\.accessibilityReduceMotion)`

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

## Prevention Strategies

### 1. Clarify First
**Problem**: Ambiguous tasks lead to wasted effort.
**Prevention**: Ask clarifying questions in Phase 0, not during execution.

### 2. Build Must Pass
**Problem**: Proceeding with broken builds compounds errors.
**Prevention**: Hard gate - no code changes until build passes.

### 3. Plugin Detection
**Problem**: Assuming plugins exist causes failures.
**Prevention**: Check before use, graceful fallback to project-local agents.

### 4. Pattern Adherence
**Problem**: New patterns create inconsistency.
**Prevention**: Search codebase for existing patterns, match them.

### 5. One Task Per Session
**Problem**: Multiple tasks reduce focus.
**Prevention**: Complete one task, commit, then next.

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

# Capture screenshot
xcrun simctl io booted screenshot ~/Desktop/screenshot.png
```

---

## Related Documentation

- [UX Improvement Plan](../../../plans/feat-ux-improvement-watchos.md)
- [Ralph Context Docs](../../../.claude/ralph/ralph-context-docs/README.md)
- [watchOS 26 Deprecation Warnings](../build-errors/watchos26-deprecation-warnings-20260115.md)
- [WebSocket Cloud Mode Fix](../runtime-errors/unnecessary-websocket-cloud-mode-WatchService-20260116.md)

---

## Rules

1. **ONE TASK PER SESSION** - Complete one task, then exit
2. **CLARIFY FIRST** - Ask questions in Phase 0, not during execution
3. **FOLLOW PATTERNS** - Copy existing code style, don't reinvent
4. **BUILD MUST PASS** - No exceptions, fix errors before proceeding
5. **VERIFY BEFORE COMPLETE** - Run verification, ensure it passes
6. **COMMIT YOUR WORK** - Every completed task gets a commit
