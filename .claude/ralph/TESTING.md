# watchOS Ralph Loop - Testing Checklist

Use this checklist on your macOS environment with Xcode installed to validate the Ralph Loop implementation.

---

## Prerequisites

- [ ] macOS with Xcode 15+ installed
- [ ] watchOS Simulator available (`xcrun simctl list devices | grep -i watch`)
- [ ] Claude CLI installed (`claude --version`)
- [ ] Python 3 with PyYAML (`python3 -c "import yaml; print('OK')"`)
- [ ] jq installed (optional, for metrics) (`jq --version`)

---

## Phase 1: File Validation

### 1.1 Script Permissions
```bash
# Verify scripts are executable
ls -la .claude/ralph/*.sh

# Expected: ralph.sh and watchos-verify.sh have execute permission (x)
```
- [ ] ralph.sh is executable
- [ ] watchos-verify.sh is executable

### 1.2 YAML Validation
```bash
# Validate tasks.yaml syntax
python3 -c "import yaml; data=yaml.safe_load(open('.claude/ralph/tasks.yaml')); print(f'Tasks: {len(data[\"tasks\"])}')"

# Expected: Tasks: 13
```
- [ ] tasks.yaml is valid YAML
- [ ] 13 tasks loaded

### 1.3 JSON Validation
```bash
# Validate metrics.json
python3 -c "import json; json.load(open('.claude/ralph/metrics.json')); print('Valid')"

# Expected: Valid
```
- [ ] metrics.json is valid JSON

---

## Phase 2: Script Testing

### 2.1 Help Command
```bash
./.claude/ralph/ralph.sh --help

# Expected: Shows usage information with all options
```
- [ ] Help displays correctly
- [ ] All options documented

### 2.2 Dry Run Mode
```bash
./.claude/ralph/ralph.sh --dry-run --single

# Expected: Shows PROMPT.md content without executing Claude
```
- [ ] Preflight checks pass
- [ ] Prompt content displayed
- [ ] No actual Claude execution

### 2.3 Verification Harness (Full)
```bash
./.claude/ralph/watchos-verify.sh

# Expected: Runs all checks including build
```
- [ ] Build check runs (may take 1-2 minutes)
- [ ] Deprecated API check passes
- [ ] Accessibility check runs
- [ ] Font size check runs
- [ ] Summary displayed

### 2.4 Verification Harness (Quick)
```bash
./.claude/ralph/watchos-verify.sh --quick

# Expected: Skips build, runs code checks only
```
- [ ] Build skipped
- [ ] Code checks run
- [ ] Completes in <5 seconds

---

## Phase 3: Integration Testing

### 3.1 Initialize Ralph Loop
```bash
./.claude/ralph/ralph.sh --init

# Expected: Runs INITIALIZER.md, sets up environment
```
- [ ] Environment validated
- [ ] Baseline build passes
- [ ] Session log updated
- [ ] Metrics initialized

### 3.2 Single Session Test
```bash
./.claude/ralph/ralph.sh --single

# Expected: Completes one task from tasks.yaml
```
- [ ] Task selected correctly (highest priority incomplete)
- [ ] Files read before editing
- [ ] Changes made to correct files
- [ ] Build passes after changes
- [ ] Task verification passes
- [ ] tasks.yaml updated (completed: true)
- [ ] Git commit created
- [ ] Session log updated

### 3.3 Verification After Session
```bash
# Check task was marked complete
grep -A5 "id: \"C1\"" .claude/ralph/tasks.yaml

# Check session log
tail -30 .claude/ralph/session-log.md

# Check metrics
cat .claude/ralph/metrics.json | jq '.totalSessions, .tasksCompleted'
```
- [ ] Task status updated
- [ ] Session logged
- [ ] Metrics incremented

---

## Phase 4: Loop Testing

### 4.1 Multi-Iteration Test
```bash
./.claude/ralph/ralph.sh --max-iterations 3

# Expected: Runs 3 sessions, completing 3 tasks
```
- [ ] Loop continues between sessions
- [ ] Different task selected each iteration
- [ ] Handles completion correctly
- [ ] Stops at iteration limit

### 4.2 Interrupt Handling
```bash
./.claude/ralph/ralph.sh &
sleep 10
kill -INT %1

# Expected: Clean shutdown with message
```
- [ ] Catches interrupt signal
- [ ] Cleanup runs
- [ ] Exit code 130

### 4.3 Error Recovery
```bash
# Introduce a build error, then run
./.claude/ralph/ralph.sh --single --max-retries 2

# Expected: Attempts fix, retries, documents failure
```
- [ ] Invokes /fix-build on failure
- [ ] Retries up to max-retries
- [ ] Documents failure in session-log
- [ ] Does NOT mark task complete on failure

---

## Phase 5: Skill Integration

### 5.1 Build Skill
```bash
# In Claude session, verify /build works
claude --print "Invoke /build skill"
```
- [ ] /build skill invoked
- [ ] Build output displayed
- [ ] Exit code captured

### 5.2 Audit Skill
```bash
# In Claude session, verify /watchos-audit works
claude --print "Invoke /watchos-audit skill"
```
- [ ] /watchos-audit skill invoked
- [ ] Audit results displayed

### 5.3 Agent Invocation
```bash
# In Claude session, verify agents work
claude --print "Use watchos-architect agent to review the app architecture"
```
- [ ] Agent invoked via Task tool
- [ ] Response received

---

## Phase 6: End-to-End Test

### 6.1 Complete One Full Task
Run the loop and let it complete Task C1 (accessibility labels):

```bash
./.claude/ralph/ralph.sh --single
```

**Verify:**
- [ ] MainView.swift has new .accessibilityLabel() calls
- [ ] SettingsView.swift has new .accessibilityLabel() calls
- [ ] Build passes
- [ ] Verification command passes: `grep -r 'accessibilityLabel' ClaudeWatch/Views/*.swift | wc -l` >= 10
- [ ] Git commit created with message matching template
- [ ] tasks.yaml shows C1 completed: true

### 6.2 Run Verification After Task
```bash
./.claude/ralph/watchos-verify.sh
```
- [ ] Accessibility label count increased
- [ ] No new deprecated APIs introduced
- [ ] Build still passes

---

## Troubleshooting

### Build Fails
1. Check Xcode is installed: `xcode-select -p`
2. Check simulator exists: `xcrun simctl list devices | grep -i watch`
3. Try manual build: `xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build`

### Claude Not Found
1. Install Claude CLI: `npm install -g @anthropic-ai/claude-code`
2. Verify: `claude --version`

### YAML Parse Errors
1. Validate syntax: `python3 -c "import yaml; yaml.safe_load(open('.claude/ralph/tasks.yaml'))"`
2. Check for tab characters (use spaces only)

### Session Hangs
1. Check Claude API status
2. Try with `--dry-run` first
3. Check network connectivity

---

## Success Criteria

The Ralph Loop is fully functional when:

1. **Initialization works**: `--init` completes without errors
2. **Single session works**: `--single` completes one task
3. **Verification works**: `watchos-verify.sh` runs all checks
4. **Loop works**: Multiple iterations complete tasks
5. **Error handling works**: Failures are logged, not marked complete
6. **Integration works**: Skills and agents are invoked correctly

---

## Quick Test Command

Run this for a quick validation:

```bash
# Quick validation (no Claude execution)
./.claude/ralph/ralph.sh --help && \
./.claude/ralph/watchos-verify.sh --quick && \
python3 -c "import yaml; d=yaml.safe_load(open('.claude/ralph/tasks.yaml')); print(f'Ready: {len([t for t in d[\"tasks\"] if not t[\"completed\"]])} tasks pending')"
```

Expected output:
```
[help text]
[verification results]
Ready: 13 tasks pending
```
