---
status: pending
priority: p1
issue_id: 003
tags: [code-review, ralph, prompt-engineering, agent-behavior]
dependencies: []
---

# Agent Enters Plan Mode Instead of Execution Mode

## Problem Statement

Claude agents receiving `PROMPT.md` are entering "plan mode" despite explicit instructions to execute. This causes sessions to create documentation/plans instead of actually implementing code changes.

**Impact:** CRITICAL - Agents don't do the work, just plan it.

## Findings

### Evidence from Architecture Strategist

**Session Log Evidence:**

From `.specstory/history/2026-01-16_16-16-31Z-hash-watchos-ralph-loop.md` lines 902-904:

```
"I'm currently in **plan mode** which means I cannot execute tasks -
I can only explore, research, and create an implementation plan."
```

**Root Cause:** The prompt structure in `PROMPT.md` uses **role instructions** instead of **task descriptions**.

**Current PROMPT.md structure (WRONG):**

```markdown
# watchOS Ralph Loop - Autonomous Coding Agent

You are an expert watchOS/SwiftUI developer...

## ⚠️ CRITICAL: EXECUTION MODE ONLY - NO PLANNING

**YOU ARE IN EXECUTION MODE, NOT PLANNING MODE.**

Ralph sessions that do NOT modify code will be marked as FAILED...
```

This is **telling** the agent what mode to be in, but Claude Code may already be in plan mode based on invocation context.

### How Ralph Invokes Claude

**Location:** `.claude/ralph/ralph.sh` line 379

```bash
run_claude_session() {
    local prompt_file="$1"
    local session_id="$2"

    cd "$PROJECT_ROOT" || return 1

    # Pipes PROMPT.md to claude with --print flag
    cat "$prompt_file" | claude --print
}
```

**The Problem:** The `--print` flag or pipe context may trigger Claude Code's planning behavior rather than execution.

### Why Agents Plan Instead of Execute

1. **Context Detection:** Claude Code detects it's being fed a long prompt via stdin
2. **Mode Selection:** Interprets this as "analyze this document" rather than "do this work"
3. **Role Confusion:** PROMPT.md says "you are in execution mode" but doesn't structure the request as executable

## Proposed Solutions

### Solution 1: Restructure Prompt as Task Request (RECOMMENDED)

**Effort:** Small (2 hours)
**Risk:** Low
**Pros:**
- Action-oriented structure
- Clear task with specific steps
- Induces execution behavior
- No invocation changes needed

**Cons:**
- Requires rewriting PROMPT.md
- May need iteration to perfect

**Implementation:**

Replace `.claude/ralph/PROMPT.md` with action-oriented structure:

```markdown
# Task Execution Request

Execute the following task immediately. Do not plan, analyze, or discuss - implement now.

## Current Task

**ID:** {{TASK_ID}}
**Title:** {{TASK_TITLE}}
**Priority:** {{TASK_PRIORITY}}

## Required Actions (Execute in Order)

1. **Read these files:**
   {{#each TASK_FILES}}
   - {{this}}
   {{/each}}

2. **Make these changes:**
   {{TASK_DESCRIPTION}}

3. **Verify your work:**
   ```bash
   {{TASK_VERIFICATION}}
   ```
   Must pass before proceeding.

4. **Mark task complete:**
   ```bash
   ./.claude/ralph/state-manager.sh complete {{TASK_ID}}
   ```

5. **Commit changes:**
   ```bash
   git add -A
   git commit -m "{{TASK_COMMIT_TEMPLATE}}"
   ```

## Success Criteria

You must complete ALL of these:
- [ ] Files modified (git diff shows changes)
- [ ] Verification command exits 0
- [ ] Task marked complete in tasks.yaml
- [ ] Git commit created

## Files to Modify

{{#each TASK_FILES}}
- {{this}}
{{/each}}

Plus:
- .claude/ralph/tasks.yaml (mark completed: true)

---

**IMPORTANT:** This is an execution request, not a planning request. Implement the changes NOW using Edit/Write tools. Do not create plans or ask questions.
```

**Template Variables:**

Ralph.sh would need to substitute:
- `{{TASK_ID}}` - e.g., "C1"
- `{{TASK_TITLE}}` - e.g., "Add accessibility labels"
- `{{TASK_FILES}}` - List from tasks.yaml
- `{{TASK_DESCRIPTION}}` - From tasks.yaml
- `{{TASK_VERIFICATION}}` - From tasks.yaml
- `{{TASK_COMMIT_TEMPLATE}}` - From tasks.yaml

### Solution 2: Use Direct CLI Arguments Instead of Stdin

**Effort:** Medium (3 hours)
**Risk:** Medium
**Pros:**
- Avoids stdin pipe trigger
- More explicit invocation
- Can use --no-plan flag if available

**Cons:**
- Prompt might exceed CLI arg limits
- Less flexible than file-based prompts

**Implementation:**

Modify `.claude/ralph/ralph.sh`:

```bash
run_claude_session() {
    local prompt_file="$1"
    local session_id="$2"

    cd "$PROJECT_ROOT" || return 1

    # Build compact task string
    local task_prompt="Execute task ${next_task_id}: $(yq '.tasks[] | select(.id == env(next_task_id)) | .description' "$TASKS_FILE")"

    # Invoke directly (not via stdin)
    claude "$task_prompt" --execute --no-plan
}
```

### Solution 3: Create Execution Wrapper Script

**Effort:** Small (1 hour)
**Risk:** Low
**Pros:**
- Clear execution contract
- Can add pre/post hooks
- Reusable pattern

**Cons:**
- Another layer of indirection
- Debugging slightly harder

**Implementation:**

Create `.claude/ralph/execute-task.sh`:

```bash
#!/bin/bash
# Execute a single Ralph task without planning

TASK_ID="$1"
RALPH_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$RALPH_DIR/../.." && pwd)"

# Read task from YAML
TASK_YAML=$(yq ".tasks[] | select(.id == \"$TASK_ID\")" "$RALPH_DIR/tasks.yaml")

# Build execution prompt
cat <<EOF | claude --execute
You must implement this task immediately. No planning allowed.

Task: $(echo "$TASK_YAML" | yq '.title')

Actions:
$(echo "$TASK_YAML" | yq '.description')

Files to modify:
$(echo "$TASK_YAML" | yq '.files[]')

When done:
1. Run verification: $(echo "$TASK_YAML" | yq '.verification')
2. Mark complete: ./.claude/ralph/state-manager.sh complete $TASK_ID
3. Commit: git commit -am "$(echo "$TASK_YAML" | yq '.commit_template')"
EOF
```

## Recommended Action

**Implement Solution 1** (Restructure Prompt) immediately.

**Why:**
- Addresses root cause (prompt structure)
- No invocation changes needed
- Most likely to work reliably

**Fallback:** If Solution 1 doesn't work, try Solution 3 (execution wrapper).

**Implementation steps:**
1. Create new action-oriented PROMPT.md template
2. Add templating logic to ralph.sh to substitute variables
3. Test with single session: `./ralph.sh --single`
4. Verify agent executes instead of plans

## Technical Details

**Affected Files:**
- `.claude/ralph/PROMPT.md` (complete rewrite)
- `.claude/ralph/ralph.sh` (add templating, lines 370-395)

**Prompt Engineering Changes:**
- Current: 402 lines of role instructions
- New: ~50 lines of action steps
- Focus: What to do (imperative) vs who you are (descriptive)

## Acceptance Criteria

- [ ] New action-oriented PROMPT.md created
- [ ] Template variables substituted by ralph.sh
- [ ] Test session executes task (no planning)
- [ ] Agent modifies files directly
- [ ] No "I'm in plan mode" messages
- [ ] Task completes without entering plan mode

## Work Log

**2026-01-16 - Investigation**
- Architecture Strategist identified agent mode confusion
- Found session log evidence of agents entering plan mode
- Analyzed PROMPT.md structure (role-based vs action-based)
- Reviewed ralph.sh invocation method (stdin pipe)

## Resources

- Current PROMPT.md: `.claude/ralph/PROMPT.md`
- Session evidence: `.specstory/history/2026-01-16_16-16-31Z-hash-watchos-ralph-loop.md`
- Invocation logic: `.claude/ralph/ralph.sh` lines 370-395
- Prompt engineering best practices: Action-oriented > Role-oriented
