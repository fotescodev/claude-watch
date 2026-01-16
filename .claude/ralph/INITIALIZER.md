# watchOS Ralph Loop - Initialization

You are initializing the watchOS Ralph Loop for the Claude Watch project. This is a one-time setup that prepares the autonomous coding environment.

## Initialization Tasks

Complete these tasks in order:

### 1. Verify Environment

Check the development environment is ready:

```bash
# Verify Xcode
xcodebuild -version

# Verify Swift
swift --version

# Verify watchOS simulators available
xcrun simctl list devices | grep -i "watch"

# Verify git status
git status
```

**Requirements:**
- Xcode 16+ (for watchOS 26 SDK)
- Swift 5.9+
- At least one watchOS simulator available
- Git repository initialized

### 2. Verify Project Structure

Confirm the Claude Watch project structure:

```
claude-watch/
├── ClaudeWatch/
│   ├── App/
│   ├── Views/
│   ├── Services/
│   └── Complications/
├── ClaudeWatch.xcodeproj/
└── .claude/
    └── ralph/
```

Read key files to verify project health:
- `ClaudeWatch/App/ClaudeWatchApp.swift`
- `ClaudeWatch/Services/WatchService.swift`
- `ClaudeWatch/Views/MainView.swift`

### 3. Run Baseline Build

Verify the project compiles:

```bash
# Invoke the /build skill
```

If build fails, invoke `/fix-build` skill and resolve issues before continuing.

### 4. Run Initial Audit

Invoke `/watchos-audit` skill to get baseline assessment of:
- Deprecated API usage
- Accessibility compliance
- HIG compliance
- Font sizes
- Touch targets

Document findings in session-log.md.

### 5. Initialize Metrics

Verify `.claude/ralph/metrics.json` exists with initial structure:

```json
{
  "version": "1.0",
  "project": "ClaudeWatch",
  "platform": "watchOS",
  "initialized": "{current_timestamp}",
  "lastSession": "",
  "totalSessions": 0,
  "totalTokens": { "input": 0, "output": 0 },
  "estimatedCost": 0.00,
  "tasksCompleted": 0,
  "tasksFailed": 0,
  "totalRetries": 0,
  "buildFailures": 0,
  "sessions": []
}
```

### 6. Verify Task List

Read `.claude/ralph/tasks.yaml` and verify:
- All tasks have required fields (id, title, priority, completed, verification)
- Dependencies are valid (depends_on references existing task IDs)
- Verification commands are executable

### 7. Create Initial Session Log Entry

Write to `.claude/ralph/session-log.md`:

```markdown
## Initialization - {timestamp}

**Status:** COMPLETED

### Environment
- Xcode: {version}
- Swift: {version}
- watchOS SDK: {version}
- Simulator: {available simulators}

### Baseline Assessment
- Build status: {PASS/FAIL}
- Deprecated APIs: {count}
- Accessibility labels: {count}
- Font size issues: {count}

### Task Summary
- Total tasks: {count}
- Critical: {count}
- High: {count}
- Medium: {count}
- Low: {count}

### Notes
- {any observations about project state}
- {recommendations for first tasks}

---
```

### 8. Commit Initialization

```bash
git add .claude/ralph/
git commit -m "chore(ralph): Initialize watchOS Ralph Loop

- Created metrics.json with initial state
- Updated session-log.md with baseline assessment
- Verified tasks.yaml structure
- Confirmed build passes"
```

## Completion

After all tasks complete, output:

```
=== INITIALIZATION COMPLETE ===
Project: Claude Watch
Platform: watchOS
Tasks: {count} tasks ready
Build: PASSING

Run ./ralph.sh to start the autonomous loop.
================================
```

## Begin Initialization

Start by verifying the environment. Execute the checks above and document results.
