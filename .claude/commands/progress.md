---
description: Show current project status, phase, and next steps (GSD-inspired)
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(git status:*)
---

# /progress - Project Status Summary

**Purpose**: Quick orientation at the start of any session. Shows where we are and what's next.

## Instructions

Read and synthesize these sources to provide a concise status report:

### 0. Architecture Context (REQUIRED)
```
Read: .claude/ARCHITECTURE.md
Understand: System components, data flows, critical constraints
```
**Before proposing ANY solution, confirm you understand how Hook → Cloud → Watch communicate.**

For task-specific reading order, see: `.claude/AGENT_GUIDE.md`

### 1. Session State
```
Read: .claude/state/SESSION_STATE.md
Extract: Current phase, active work, blockers, handoff notes
```

### 2. Task Status
```
Read: .claude/ralph/tasks.yaml
Count: completed vs pending tasks
Identify: Next 3 actionable tasks
```

### 3. Recent Activity
```bash
git log --oneline -10
```
Extract: What shipped recently

### 4. Build Health
```bash
# Quick build check (don't run full build)
ls -la ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/ 2>/dev/null || echo "No recent build"
```

## Output Format

```
## Claude Watch Progress

**Phase**: [N] - [Phase Name]
**Progress**: [████████░░] XX%

### Active Work
- [ ] Task 1 (status)
- [ ] Task 2 (status)
- [ ] Task 3 (status)

### Blockers
- [None / List blockers]

### Recent Commits
- abc123 feat: ...
- def456 fix: ...

### Next Steps
1. [Most important next action]
2. [Second priority]
3. [Third priority]

### Quick Commands
- `/build` - Build for simulator
- `/deploy-device` - Deploy to physical watch
- `/ship-check` - Pre-submission validation
```

## When to Use

- **Session start**: Run `/progress` to orient yourself
- **After long break**: Check what was happening
- **Before handoff**: Verify state before ending session

## Auto-Update

After using `/progress`, offer to update `SESSION_STATE.md` if anything has changed.
