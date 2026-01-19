# Designing Tasks for Ralph

This document explains how to break down features into tasks that Ralph can execute autonomously.

## The Problem with Vague Tasks

**Original FE1 (too vague):**
```yaml
- id: "FE1"
  title: "Real task progress tracking from Claude Code sessions"
  description: |
    The progress indicator could track actual Claude Code session activity.
    Requires: Extending the hook/worker protocol to send session metadata.
```

**Why Ralph failed on this:**
1. No concrete implementation steps
2. "Extending the protocol" is a design decision, not an action
3. No reference to existing code patterns
4. No test commands to verify success
5. No data format specifications

## The Analysis Process

### Step 1: Identify the Data Flow

Ask: "What data needs to move where?"

```
Claude Code → [something] → Cloudflare Worker → [something] → Watch App
```

For FE1, the data flow is:
```
TodoWrite tool call
       ↓
PostToolUse hook captures it
       ↓
Hook extracts task list + progress
       ↓
HTTP POST to /session-progress
       ↓
Worker stores in KV
       ↓
Worker sends silent APNs push
       ↓
Watch receives notification
       ↓
MainView updates UI
```

### Step 2: Identify System Boundaries

Each boundary crossing = one task:

| Boundary | Task |
|----------|------|
| Claude Code → Hook | FE1a: Create the hook |
| Hook → Worker | FE1b: Create the endpoint |
| Worker → Watch | (included in FE1b via APNs) |
| Watch notification → UI | FE1c: Handle and display |

### Step 3: Find Reference Implementations

For each task, find existing code that does something similar:

| Task | Reference |
|------|-----------|
| FE1a (hook) | `.claude/hooks/watch-approval-cloud.py` - sends data to worker |
| FE1b (endpoint) | `/request` endpoint - receives data, sends APNs |
| FE1c (notification) | `CLAUDE_ACTION` handling - parses payload, updates state |

### Step 4: Define Data Formats

Specify exact JSON/struct formats:

**Hook → Worker:**
```json
{
  "pairingId": "uuid",
  "currentTask": "Running tests",
  "progress": 0.66,
  "completedCount": 4,
  "totalCount": 6
}
```

**Worker → Watch (APNs):**
```json
{
  "aps": {"content-available": 1},
  "type": "progress",
  "currentTask": "Running tests",
  "progress": 0.66
}
```

**Watch State:**
```swift
struct SessionProgress {
  var currentTask: String?
  var progress: Double
  var completedCount: Int
  var totalCount: Int
}
```

### Step 5: Write Test Commands

Every task needs a way to verify it works:

```bash
# FE1a - Test hook parses input
echo '{"tool": "TodoWrite", ...}' | python3 .claude/hooks/progress-tracker.py

# FE1b - Test endpoint accepts data
curl -X POST .../session-progress -d '{"pairingId": "test", ...}'

# FE1c - Test watch handles notification
xcrun simctl push "Watch" com.app /tmp/progress-test.json
```

## Task Template

```yaml
- id: "XX1"
  title: "Verb + specific noun + context"
  description: |
    One-sentence summary of what this does.

    IMPLEMENTATION:
    1. Specific step with file path
    2. Another step with code example
    3. Wire up to existing system

    DATA FORMAT:
    ```json
    {"exact": "format", "ralph": "needs"}
    ```

    REFERENCE FILES:
    - path/to/similar/implementation.py

    TEST:
    ```bash
    command to verify it works
    ```
  priority: medium
  parallel_group: N  # Sequential order
  completed: false
  depends_on:
    - "previous-task-id"
  verification: |
    grep -q "expected_string" expected/file.py
  acceptance_criteria:
    - "Specific, verifiable criterion"
    - "Another measurable outcome"
  files:
    - "exact/path/to/modify.swift"
  tags:
    - category
  commit_template: "type(scope): What was done"
```

## Checklist for Ralph-Ready Tasks

Before adding a task, verify:

- [ ] **Title is action-oriented**: "Add X to Y" not "X integration"
- [ ] **Description has IMPLEMENTATION section**: Numbered steps
- [ ] **Code examples included**: Exact syntax Ralph should use
- [ ] **Data formats specified**: JSON/struct definitions
- [ ] **Reference files listed**: Similar patterns to follow
- [ ] **Test command provided**: How to verify success
- [ ] **Acceptance criteria are measurable**: Not "works well"
- [ ] **Files array is accurate**: Exact paths to modify
- [ ] **Dependencies declared**: `depends_on` for sequential work
- [ ] **Verification script works**: Can be run to check completion

## Anti-Patterns to Avoid

| Bad | Good |
|-----|------|
| "Improve performance" | "Add caching to /api/users endpoint" |
| "Fix the bug" | "Handle null response in parseUser()" |
| "Integrate with X" | "Add POST /webhook endpoint for X callbacks" |
| "Make it work" | "Return 200 when payload.type == 'ping'" |
| "Refactor auth" | "Extract JWT validation to middleware" |

## When to Split vs. Keep Together

**Split when:**
- Different files/systems involved
- Different skills needed (Python vs Swift vs TypeScript)
- Can be tested independently
- Natural checkpoint for verification

**Keep together when:**
- Single file change
- Tightly coupled logic
- Would be confusing to test separately
- Less than ~50 lines of code

## Example: Breaking Down "Add Dark Mode"

**Vague:** "Add dark mode support"

**Analyzed:**
1. What data? Color values, user preference
2. Boundaries? Settings storage, UI components, system integration
3. Reference? Existing theme code, Apple HIG

**Split into:**
```yaml
- id: "DM1"
  title: "Add dark mode color palette to Design/Colors.swift"
  # Define the colors

- id: "DM2"
  title: "Add theme preference to UserSettings"
  depends_on: ["DM1"]
  # Store user choice

- id: "DM3"
  title: "Apply theme colors to MainView"
  depends_on: ["DM2"]
  # Wire up the UI
```

---

Remember: **Ralph is literal.** The more specific the task, the better the result.
