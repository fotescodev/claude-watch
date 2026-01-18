# Ralph Parallel Executor

Execute Ralph tasks with TRUE parallel execution using multiple agents.

## How It Works

1. **Identify runnable tasks** - Find all tasks in the lowest `parallel_group` with dependencies met
2. **Spawn parallel agents** - Launch one Task agent per runnable task (simultaneously!)
3. **Wait for completion** - All agents work concurrently
4. **Merge results** - Combine branches from parallel work
5. **Repeat** - Move to next parallel_group

## Execution Flow

### Step 1: Get Parallel Tasks
```bash
cd /Users/dfotesco/claude-watch/claude-watch
python3 .claude/ralph/parallel-tasks.py
```

This returns JSON like:
```json
{
  "status": "ready",
  "parallel_group": 3,
  "count": 3,
  "tasks": [
    {"id": "FV1", "title": "Verify modes", ...},
    {"id": "FV2", "title": "Verify commands", ...},
    {"id": "FV4", "title": "Test rejection", ...}
  ]
}
```

### Step 2: Spawn Parallel Agents

For EACH task in the list, use the Task tool with `subagent_type: "general-purpose"`:

```
CRITICAL: Send ALL Task tool calls in a SINGLE message to run them in parallel!
```

Example prompt for each agent:
```
Execute Ralph task TASK_ID following .claude/ralph/TASK_EXECUTOR.md

Working directory: /Users/dfotesco/claude-watch/claude-watch
Task ID: [ID]
Task Title: [TITLE]

Execute autonomously. Create a unique branch. Return JSON result.
```

### Step 3: Collect Results

Each agent returns:
```json
{
  "task_id": "FV1",
  "status": "completed",
  "branch": "ralph/FV1-1234567",
  "commit": "abc123"
}
```

### Step 4: Merge Branches

After all agents complete:
```bash
git checkout main
for branch in ralph/*; do
  git merge --no-ff "$branch" -m "Merge parallel task"
done
```

### Step 5: Loop

Repeat from Step 1 until `parallel-tasks.py` returns `{"status": "all_complete"}`.

## Display Format

```
╔══════════════════════════════════════════════════════════════╗
║              PARALLEL EXECUTION - GROUP [N]                  ║
╠══════════════════════════════════════════════════════════════╣
║  Spawning [X] agents in parallel:                            ║
║  • [ID1]: [Title1]                                           ║
║  • [ID2]: [Title2]                                           ║
║  • [ID3]: [Title3]                                           ║
╚══════════════════════════════════════════════════════════════╝
```

After completion:
```
╔══════════════════════════════════════════════════════════════╗
║              GROUP [N] COMPLETE                              ║
╠══════════════════════════════════════════════════════════════╣
║  ✓ [ID1]: completed (abc123)                                 ║
║  ✓ [ID2]: completed (def456)                                 ║
║  ✗ [ID3]: failed - [error]                                   ║
╚══════════════════════════════════════════════════════════════╝
```

## Important Rules

1. **ALWAYS spawn agents in a SINGLE message** - This is what makes it parallel!
2. **Each agent creates its own branch** - Prevents git conflicts
3. **Orchestrator merges branches** - After all agents complete
4. **Failed tasks don't block others** - Parallel means independent

## Example

If tasks.yaml has:
```yaml
- id: A
  parallel_group: 1
  completed: false

- id: B
  parallel_group: 1
  completed: false

- id: C
  parallel_group: 2
  depends_on: [A, B]
  completed: false
```

Execution:
1. Group 1: Spawn agents for A and B **simultaneously**
2. Wait for both to complete
3. Merge branches
4. Group 2: Spawn agent for C
5. Done

**START NOW** - Run `python3 .claude/ralph/parallel-tasks.py` and spawn agents!
