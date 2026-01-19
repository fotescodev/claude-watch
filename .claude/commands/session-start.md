---
description: Automatic session orientation - run at start of every session
allowed-tools: Read, Glob, Grep, Bash(git log:*), Bash(git status:*)
---

# /session-start - Automatic Session Orientation

**Purpose**: Provides instant context at the start of any Claude session. Answers "where did we leave off?" and "what's next?"

## Instructions

Execute these steps automatically and provide a concise summary:

### Step 1: Read Session State

```
Read: .claude/state/SESSION_STATE.md
Extract:
- Current phase and progress percentage
- Active work items
- Blockers (if any)
- Handoff notes from previous session
- Next session priority items
```

### Step 2: Check Recent Git Activity

```bash
git log --oneline --since="24 hours ago" --author="Claude\|claude" 2>/dev/null | head -10
```

If Claude made changes overnight, summarize what was completed.

### Step 3: Scan Task Status

```
Read: .claude/ralph/tasks.yaml
Count:
- Total tasks
- Completed tasks
- In-progress tasks
- Critical priority incomplete tasks
```

### Step 4: Check Build Health

```bash
# Check if last build succeeded
ls -la ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/Debug-watchsimulator/*.app 2>/dev/null && echo "Build artifacts exist" || echo "No recent build"
```

### Step 5: Identify Immediate Actions

Based on the above, identify the top 3 things to work on right now.

## Output Format

```
## Session Start: Claude Watch

### Current State
**Phase**: [N] - [Phase Name] ([XX]% complete)
**Last Session**: [date] - [brief summary]

### Overnight Activity
[If Claude worked overnight, summarize commits. Otherwise: "No overnight activity"]

### Task Status
- Completed: X/Y tasks
- In Progress: [task names]
- Critical Blockers: [if any]

### Build Health
[Build status - OK / Needs rebuild / Has errors]

### Handoff Notes
> [Notes from previous session]

### Immediate Priorities
1. **[Most important]**: [brief description]
2. **[Second priority]**: [brief description]
3. **[Third priority]**: [brief description]

### Quick Actions
- `/build` - Rebuild if needed
- `/ship-check` - Validate submission readiness
- `/discuss-phase 5` - Review phase decisions

---
Ready to work. What would you like to focus on?
```

## When This Runs

**Automatic**: This skill can be triggered by a SessionStart hook in settings.json

**Manual**: Run `/session-start` at any time for orientation

## Hook Configuration

To make this run automatically at session start, add to `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "skill",
        "skill": "session-start"
      }
    ]
  }
}
```

## Key Principle

This command exists to prevent the "looking everywhere" problem. It gives Claude exactly the context needed to start working immediately, without exploring random directories or reading irrelevant files.
