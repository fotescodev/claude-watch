# Ralph Single Task Executor

Execute ONE specific task. You receive a TASK_ID as input.

## Input
You will be given: `TASK_ID=XXX`

## Execution Flow

### 1. Load Task
```bash
cd /Users/dfotesco/claude-watch/claude-watch
./.claude/ralph/state-manager.sh show TASK_ID
```

### 2. Determine Task Type & Simulator Strategy
Check the task's `tags` to determine execution strategy:

| Tag | Strategy | Reason |
|-----|----------|--------|
| `verification` | No build needed | Just reading/verifying code |
| `e2e`, `simulator` | EXCLUSIVE simulator access | Needs to run app |
| `bug-fix`, `feature` | BUILD LOCK required | Modifies code, needs build |
| `manual` | Skip automated execution | Requires human |

**SIMULATOR COORDINATION:**
```bash
# Check if another agent has build lock
LOCK_FILE="/tmp/ralph-build.lock"
if [[ -f "$LOCK_FILE" ]]; then
    # Wait for lock (max 5 minutes)
    for i in {1..60}; do
        [[ ! -f "$LOCK_FILE" ]] && break
        sleep 5
    done
fi

# Acquire lock before building
echo "$$" > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT
```

### 3. Read Context
- Read all files in the task's `files` array
- Search for similar patterns in codebase

### 4. Execute
- Make code changes as specified
- Follow existing code patterns

### 5. Build (if code was changed)
**ONLY if task modifies code (not verification tasks):**
```bash
# Acquire build lock first
LOCK_FILE="/tmp/ralph-build.lock"
echo "$$" > "$LOCK_FILE"

SIMULATOR="Apple Watch Series 11 (46mm)"
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30

# Release lock
rm -f "$LOCK_FILE"
```

### 6. Verify & Complete
```bash
./.claude/ralph/state-manager.sh verify TASK_ID
./.claude/ralph/state-manager.sh complete TASK_ID
```

### 7. Commit (IMPORTANT: Use unique branch to avoid conflicts)
```bash
BRANCH="ralph/TASK_ID-$(date +%s)"
git checkout -b "$BRANCH"
git add -A
git commit -m "[commit_template from task]

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 8. Return Result
Return a JSON summary:
```json
{
  "task_id": "TASK_ID",
  "status": "completed|failed",
  "branch": "ralph/TASK_ID-xxx",
  "commit": "abc123",
  "files_changed": 3,
  "error": null
}
```

## Parallel Execution Rules

### Tasks that CAN run in parallel:
- `verification` tasks (read-only)
- Tasks with different file sets
- Tasks that don't need builds

### Tasks that need SEQUENTIAL execution:
- Multiple `bug-fix` or `feature` tasks (build lock)
- `e2e` tests (exclusive simulator access)
- Tasks modifying the same files

### Simulator Management
```
┌─────────────────────────────────────────────────────┐
│  PARALLEL EXECUTION SIMULATOR STRATEGY              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Agent 1 (verification) ──► No simulator needed     │
│  Agent 2 (verification) ──► No simulator needed     │
│  Agent 3 (bug-fix) ────────► BUILD LOCK ──► Build   │
│  Agent 4 (e2e) ────────────► Wait for lock          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Rules
- Do NOT ask questions - execute autonomously
- Do NOT switch tasks - only execute the given TASK_ID
- Create a unique branch to avoid git conflicts with parallel tasks
- ACQUIRE BUILD LOCK before any xcodebuild command
- Return structured result for orchestrator
