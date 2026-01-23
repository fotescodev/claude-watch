# Question Flow Bug Prevention Strategies

> **Purpose**: Prevent common bugs in the Claude Watch question flow integration.
> **Last Updated**: 2026-01-21

---

## Table of Contents

1. [Diagnostic Checklist: Questions Not Showing on Watch](#1-diagnostic-checklist-questions-not-showing-on-watch)
2. [Diagnostic Checklist: Answers Not Returning to Terminal](#2-diagnostic-checklist-answers-not-returning-to-terminal)
3. [Test Commands: Verify Pairing IDs Match](#3-test-commands-verify-pairing-ids-match)
4. [Suggested Code Improvements](#4-suggested-code-improvements)
5. [Potential E2E Test Additions](#5-potential-e2e-test-additions)

---

## 1. Diagnostic Checklist: Questions Not Showing on Watch

### Issue Summary

Questions from Claude's `AskUserQuestion` tool do not appear on the Apple Watch, preventing watch-based question answering.

### Pre-Flight Checks

```bash
# Run this diagnostic script
echo "=== Question Flow Diagnostic ==="

# 1. Check session is active
if [ "$CLAUDE_WATCH_SESSION_ACTIVE" = "1" ]; then
  echo "✓ Session active (CLAUDE_WATCH_SESSION_ACTIVE=1)"
else
  echo "✗ CRITICAL: Session not active"
  echo "  → Must run via 'npx cc-watch', not 'claude' directly"
fi

# 2. Check proxy mode
if [ "$CLAUDE_WATCH_PROXY_MODE" = "1" ]; then
  echo "✓ Proxy mode enabled (CLAUDE_WATCH_PROXY_MODE=1)"
else
  echo "⚠ Proxy mode not set (hook will try to handle questions)"
fi

# 3. Check pairing ID
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  echo "✓ Pairing ID (file): ${PAIRING_ID:0:12}..."
else
  echo "✗ No pairing ID in ~/.claude-watch-pairing"
fi

# 4. Check config.json pairing ID
CONFIG_PAIRING=$(jq -r '.pairingId // empty' ~/.claude-watch/config.json 2>/dev/null)
if [ -n "$CONFIG_PAIRING" ]; then
  echo "✓ Pairing ID (config): ${CONFIG_PAIRING:0:12}..."
else
  echo "✗ No pairingId in ~/.claude-watch/config.json"
fi

# 5. Compare the two pairing IDs
if [ "$PAIRING_ID" = "$CONFIG_PAIRING" ]; then
  echo "✓ Pairing IDs MATCH"
elif [ -n "$PAIRING_ID" ] && [ -n "$CONFIG_PAIRING" ]; then
  echo "✗ MISMATCH: File vs Config pairing IDs differ!"
  echo "  File:   $PAIRING_ID"
  echo "  Config: $CONFIG_PAIRING"
fi

# 6. Check cloud connectivity
echo ""
echo "=== Cloud Server Checks ==="
if curl -s --max-time 5 https://claude-watch.fotescodev.workers.dev/health | grep -q '"status":"ok"'; then
  echo "✓ Cloud server healthy"
else
  echo "✗ Cloud server unreachable"
fi

# 7. Check for pending questions
if [ -n "$PAIRING_ID" ]; then
  QUESTIONS=$(curl -s "https://claude-watch.fotescodev.workers.dev/questions/$PAIRING_ID")
  Q_COUNT=$(echo "$QUESTIONS" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('questions',[])))" 2>/dev/null || echo "0")
  echo "  Pending questions: $Q_COUNT"
fi

# 8. Check hook debug log
echo ""
echo "=== Recent Hook Activity ==="
if [ -f /tmp/claude-watch-hook-debug.log ]; then
  echo "Last 5 hook entries:"
  tail -5 /tmp/claude-watch-hook-debug.log
else
  echo "No hook debug log found"
fi
```

### Common Causes and Fixes

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | No questions sent to cloud | Running `claude` instead of `npx cc-watch` | Always use `npx cc-watch` for question support |
| 2 | Question sent but watch shows nothing | Watch polling wrong endpoint | Verify watch calls `GET /questions/:pairingId` |
| 3 | Question appears briefly then disappears | Race condition in UI state | Check `pendingQuestion` state not being overwritten |
| 4 | "No pairing ID" in hook log | Pairing file empty or missing | Re-pair via `npx cc-watch` |
| 5 | Pairing ID mismatch | Simulator vs device have different pairings | Use same pairing for all targets (see section 3) |
| 6 | Cloud returns 404 | Endpoint doesn't exist | Check `/question` endpoint exists in cloud worker |
| 7 | Question stuck in "pending" | Watch not receiving via polling | Check watch `startPolling()` includes `fetchPendingQuestions()` |

### Step-by-Step Verification

1. **Create a test question manually**:
   ```bash
   PAIRING_ID=$(cat ~/.claude-watch-pairing)
   curl -s -X POST "https://claude-watch.fotescodev.workers.dev/question" \
     -H "Content-Type: application/json" \
     -d "{
       \"pairingId\": \"$PAIRING_ID\",
       \"type\": \"question\",
       \"question\": \"Test: Which framework?\",
       \"header\": \"Testing\",
       \"options\": [{\"label\": \"React\"}, {\"label\": \"Vue\"}],
       \"multiSelect\": false
     }"
   ```

2. **Verify question is stored**:
   ```bash
   curl -s "https://claude-watch.fotescodev.workers.dev/questions/$PAIRING_ID" | python3 -m json.tool
   ```

3. **If question appears in cloud but not on watch**: Problem is in WatchService polling
4. **If question doesn't appear in cloud**: Problem is in hook/stdin-proxy

---

## 2. Diagnostic Checklist: Answers Not Returning to Terminal

### Issue Summary

User answers a question on the watch, but the answer never returns to Claude/terminal, causing the session to hang.

### Pre-Flight Checks

```bash
echo "=== Answer Return Diagnostic ==="

# 1. Check we're in proxy mode
if [ "$CLAUDE_WATCH_PROXY_MODE" = "1" ]; then
  echo "✓ Proxy mode: stdin-proxy.ts handles answers"
else
  echo "⚠ Non-proxy mode: hook handles answers via stdout"
fi

# 2. Check last question ID
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  QUESTIONS=$(curl -s "https://claude-watch.fotescodev.workers.dev/questions/$PAIRING_ID")
  echo "Current pending questions:"
  echo "$QUESTIONS" | python3 -m json.tool
fi

# 3. Check hook log for question handling
echo ""
echo "=== Question Handling in Hook Log ==="
grep -i "question\|answer" /tmp/claude-watch-hook-debug.log 2>/dev/null | tail -10

# 4. Check if answer was recorded in cloud
# (Need specific questionId - check hook log for it)
```

### Common Causes and Fixes

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | Answer shows "success" on watch, terminal stuck | stdin-proxy not receiving poll result | Check `pollWatchAnswer()` is polling correct endpoint |
| 2 | Hook prints answer but Claude ignores | Using wrong function: `send_question_notification_only()` | Use `handle_question()` for full flow |
| 3 | Answer received but wrong format | Option index off-by-one | Check 0-based vs 1-based index conversion |
| 4 | Multiple answers for same question | Race between watch and terminal input | `raceForAnswer()` should cancel loser properly |
| 5 | Terminal shows "answer sent" but Claude stuck | stdin write failed | Check `this.claudeProcess?.stdin.write()` succeeds |
| 6 | "skipped" status but terminal doesn't prompt | Skip not implemented in stdin-proxy | Handle `status: "skipped"` case in poll loop |

### Key Code Paths

**Proxy Mode (Recommended)**:
```
stdin-proxy.ts:pollWatchAnswer()
  → GET /question/:questionId
  → Parse selectedIndices
  → Write answer to Claude stdin
```

**Hook Mode (Legacy)**:
```
watch-approval-cloud.py:handle_question()
  → POST /question (create)
  → GET /question/:questionId (poll)
  → Return answer via hookSpecificOutput
```

### Function Selection Guide

| Function | Purpose | When to Use |
|----------|---------|-------------|
| `send_question_notification_only()` | Info notification only | When `infoOnly: true` - answer in terminal |
| `handle_question()` | Full question flow | When waiting for watch answer |
| `StdinProxy.handleQuestion()` | Proxy mode | Always when proxy mode is enabled |

**WARNING**: Using `send_question_notification_only()` when you need `handle_question()` will cause answers to never return!

### Verification Steps

1. **Check question status in cloud**:
   ```bash
   QUESTION_ID="your-question-id"  # From hook log
   curl -s "https://claude-watch.fotescodev.workers.dev/question/$QUESTION_ID" | python3 -m json.tool
   ```

2. **Expected states**:
   - `pending`: Watch hasn't answered yet
   - `answered`: Watch answered, `selectedIndices` populated
   - `skipped`: User chose "answer in terminal"

3. **If status is "answered" but terminal stuck**: Problem in stdin-proxy answer injection

---

## 3. Test Commands: Verify Pairing IDs Match

### The Problem

Watch and Mac can get out of sync if:
- User re-pairs one side but not the other
- Simulator and device have different stored IDs
- Config file and legacy file have different values

### Verification Script

```bash
#!/bin/bash
# Save as: verify-pairing-ids.sh

echo "=========================================="
echo "  Claude Watch Pairing ID Verification"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Mac-side pairing IDs
echo ""
echo "=== MAC SIDE ==="

# Legacy file
LEGACY_ID=$(cat ~/.claude-watch-pairing 2>/dev/null | tr -d '\n')
if [ -n "$LEGACY_ID" ]; then
  echo -e "  ~/.claude-watch-pairing:    ${GREEN}${LEGACY_ID:0:12}...${NC}"
else
  echo -e "  ~/.claude-watch-pairing:    ${RED}NOT SET${NC}"
fi

# Config file
CONFIG_ID=$(jq -r '.pairingId // empty' ~/.claude-watch/config.json 2>/dev/null)
if [ -n "$CONFIG_ID" ]; then
  echo -e "  ~/.claude-watch/config.json: ${GREEN}${CONFIG_ID:0:12}...${NC}"
else
  echo -e "  ~/.claude-watch/config.json: ${RED}NOT SET${NC}"
fi

# Environment variable (runtime)
if [ -n "$CLAUDE_WATCH_PAIRING_ID" ]; then
  echo -e "  CLAUDE_WATCH_PAIRING_ID:     ${GREEN}${CLAUDE_WATCH_PAIRING_ID:0:12}...${NC}"
else
  echo -e "  CLAUDE_WATCH_PAIRING_ID:     ${YELLOW}not set (using file)${NC}"
fi

# 2. Check consistency
echo ""
echo "=== CONSISTENCY CHECK ==="
if [ "$LEGACY_ID" = "$CONFIG_ID" ] && [ -n "$LEGACY_ID" ]; then
  echo -e "  ${GREEN}✓ Legacy and config files MATCH${NC}"
else
  echo -e "  ${RED}✗ MISMATCH between legacy and config!${NC}"
  echo "    Fix: rm ~/.claude-watch-pairing && npx cc-watch"
fi

# 3. Cloud validation
echo ""
echo "=== CLOUD VALIDATION ==="
PAIRING_ID="${LEGACY_ID:-$CONFIG_ID}"
if [ -n "$PAIRING_ID" ]; then
  # Check if this pairing ID has any data in cloud
  QUEUE_RESULT=$(curl -s "https://claude-watch.fotescodev.workers.dev/approval-queue/$PAIRING_ID")
  if echo "$QUEUE_RESULT" | grep -q '"requests"'; then
    echo -e "  ${GREEN}✓ Pairing ID recognized by cloud${NC}"
  else
    echo -e "  ${YELLOW}⚠ Pairing ID not found in cloud (may be new)${NC}"
  fi
fi

# 4. Watch side (requires simulator)
echo ""
echo "=== WATCH SIDE ==="
WATCH_SIM="Apple Watch Series 11 (46mm)"
if xcrun simctl list devices 2>/dev/null | grep -q "$WATCH_SIM.*Booted"; then
  # Read from simulator defaults
  DEVICE_ID=$(xcrun simctl list devices | grep "$WATCH_SIM" | grep -oE "[0-9A-F-]{36}")
  WATCH_PAIRING=$(xcrun simctl spawn "$DEVICE_ID" defaults read com.edgeoftrust.claudewatch pairingId 2>/dev/null || echo "")

  if [ -n "$WATCH_PAIRING" ]; then
    echo -e "  Simulator pairingId: ${GREEN}${WATCH_PAIRING:0:12}...${NC}"

    if [ "$WATCH_PAIRING" = "$PAIRING_ID" ]; then
      echo -e "  ${GREEN}✓ Watch simulator MATCHES Mac${NC}"
    else
      echo -e "  ${RED}✗ Watch simulator has DIFFERENT pairing ID!${NC}"
      echo "    Fix: Re-pair on simulator, or:"
      echo "    xcrun simctl spawn \"$DEVICE_ID\" defaults delete com.edgeoftrust.claudewatch pairingId"
    fi
  else
    echo -e "  Simulator pairingId: ${YELLOW}not set (not paired)${NC}"
  fi
else
  echo -e "  ${YELLOW}Watch simulator not running${NC}"
  echo "  To check: xcrun simctl boot \"$WATCH_SIM\" && open -a Simulator"
fi

# 5. Physical watch note
echo ""
echo "=== PHYSICAL WATCH ==="
echo "  Cannot read pairing ID from physical watch via script."
echo "  Check watch app Settings > Pairing ID"
echo "  Or: Tap 'Unpair' then re-pair to sync IDs"

echo ""
echo "=========================================="
```

### Quick Fix Commands

```bash
# Fix 1: Sync legacy file with config
jq -r '.pairingId' ~/.claude-watch/config.json > ~/.claude-watch-pairing

# Fix 2: Clear simulator and re-pair
xcrun simctl spawn "Apple Watch Series 11 (46mm)" defaults delete com.edgeoftrust.claudewatch pairingId

# Fix 3: Clear everything and start fresh
rm ~/.claude-watch-pairing ~/.claude-watch/config.json
# Then run: npx cc-watch
```

---

## 4. Suggested Code Improvements

### 4.1 Add Pairing ID Logging in More Places

**File**: `watch-approval-cloud.py`

```python
# At the start of every cloud request, log the pairing ID being used
def create_question_request(request_data: dict) -> str:
    pairing_id = request_data.get("pairingId")
    log_debug(f"create_question_request: pairingId={pairing_id[:12] if pairing_id else 'NONE'}...")
    # ... existing code
```

**File**: `stdin-proxy.ts`

```typescript
// In createCloudQuestion, log pairing ID
private async createCloudQuestion(question: ParsedQuestion): Promise<string | null> {
  console.error(chalk.dim(`[DEBUG] Creating question with pairingId: ${this.pairingId.slice(0, 12)}...`));
  // ... existing code
}
```

**File**: `WatchService.swift`

```swift
// In fetchPendingQuestions, log pairing ID
private func fetchPendingQuestions() async throws {
    print("[Questions] Fetching for pairingId: \(pairingId.prefix(12))...")
    // ... existing code
}
```

### 4.2 Add Pairing ID Mismatch Detection

**File**: `pairing-store.ts` - Add validation function:

```typescript
/**
 * Validate that legacy and config pairing IDs match.
 * Logs warning if mismatch detected.
 */
export function validatePairingConsistency(): { valid: boolean; warning?: string } {
  const config = readPairingConfig();
  const legacyPath = join(homedir(), ".claude-watch-pairing");

  let legacyId: string | null = null;
  if (existsSync(legacyPath)) {
    legacyId = readFileSync(legacyPath, "utf-8").trim();
  }

  if (config?.pairingId && legacyId && config.pairingId !== legacyId) {
    return {
      valid: false,
      warning: `Pairing ID mismatch! Config: ${config.pairingId.slice(0, 8)}... vs File: ${legacyId.slice(0, 8)}...`
    };
  }

  return { valid: true };
}
```

### 4.3 Add Function Selection Warning

**File**: `watch-approval-cloud.py` - Add prominent comment:

```python
# CRITICAL: Function Selection for Questions
#
# send_question_notification_only() - INFO ONLY notification
#   - Use when: infoOnly=true, answer will be typed in terminal
#   - Does NOT wait for watch response
#   - Does NOT return answer to Claude
#
# handle_question() - FULL QUESTION FLOW
#   - Use when: Waiting for watch to select an option
#   - Creates question, polls for answer, returns to Claude
#   - BLOCKS until answer received or timeout
#
# WRONG: Using send_question_notification_only() when expecting answer
#        This will cause the session to hang!
```

### 4.4 Startup Pairing Validation

**File**: `cc-watch.ts` - Add at session start:

```typescript
// After loading config, validate consistency
const consistency = validatePairingConsistency();
if (!consistency.valid) {
  console.log(chalk.yellow(`  Warning: ${consistency.warning}`));
  console.log(chalk.yellow(`  Run 'rm ~/.claude-watch-pairing' and re-pair to fix.`));
}
```

---

## 5. Potential E2E Test Additions

### 5.1 Pairing ID Consistency Test

**File**: `.claude/hooks/test-pairing-consistency.py`

```python
#!/usr/bin/env python3
"""Test that pairing IDs are consistent across all storage locations."""

import json
import os
from pathlib import Path

def test_pairing_consistency():
    home = Path.home()

    # Read legacy file
    legacy_path = home / ".claude-watch-pairing"
    legacy_id = legacy_path.read_text().strip() if legacy_path.exists() else None

    # Read config file
    config_path = home / ".claude-watch" / "config.json"
    config_id = None
    if config_path.exists():
        config = json.loads(config_path.read_text())
        config_id = config.get("pairingId")

    # Check environment variable
    env_id = os.environ.get("CLAUDE_WATCH_PAIRING_ID")

    print("Pairing ID Sources:")
    print(f"  Legacy file:  {legacy_id[:12] if legacy_id else 'NOT SET'}...")
    print(f"  Config file:  {config_id[:12] if config_id else 'NOT SET'}...")
    print(f"  Environment:  {env_id[:12] if env_id else 'NOT SET'}...")

    # Validate consistency
    ids = [id for id in [legacy_id, config_id] if id]

    if len(set(ids)) > 1:
        print("\n✗ FAIL: Pairing IDs do not match!")
        return False

    if not ids:
        print("\n⚠ WARNING: No pairing ID found")
        return True  # Not a failure, just not paired

    print("\n✓ PASS: Pairing IDs are consistent")
    return True

if __name__ == "__main__":
    import sys
    sys.exit(0 if test_pairing_consistency() else 1)
```

### 5.2 Question Flow End-to-End Test (Automated)

**File**: `.claude/hooks/test-question-flow-e2e.py`

```python
#!/usr/bin/env python3
"""
Automated E2E test for question flow.

Tests:
1. Question creation succeeds
2. Question appears in pending list
3. Answer submission works
4. Question marked as answered
5. Answer contains correct indices
"""

import json
import os
import sys
import time
import urllib.request

CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"

def get_pairing_id():
    # Try config file first
    config_path = os.path.expanduser("~/.claude-watch/config.json")
    if os.path.exists(config_path):
        with open(config_path) as f:
            config = json.load(f)
            if config.get("pairingId"):
                return config["pairingId"]

    # Fall back to legacy file
    legacy_path = os.path.expanduser("~/.claude-watch-pairing")
    if os.path.exists(legacy_path):
        with open(legacy_path) as f:
            return f.read().strip()

    return None

def test_question_flow():
    print("=" * 60)
    print("  Question Flow E2E Test (Automated)")
    print("=" * 60)

    pairing_id = get_pairing_id()
    if not pairing_id:
        print("\n✗ FAIL: No pairing ID found")
        return False

    print(f"\n[1] Using pairing ID: {pairing_id[:12]}...")

    # Step 1: Create question
    print("\n[2] Creating test question...")
    question_data = {
        "pairingId": pairing_id,
        "type": "question",
        "question": "E2E Test: Select an option",
        "header": "Automated Test",
        "options": [
            {"label": "Option A", "description": "First"},
            {"label": "Option B", "description": "Second"},
        ],
        "multiSelect": False,
    }

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question",
        data=json.dumps(question_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            question_id = result.get("questionId")
    except Exception as e:
        print(f"  ✗ FAIL: Could not create question: {e}")
        return False

    if not question_id:
        print("  ✗ FAIL: No questionId in response")
        return False

    print(f"  ✓ Question created: {question_id[:12]}...")

    # Step 2: Verify question is pending
    print("\n[3] Verifying question is pending...")
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/questions/{pairing_id}",
        method="GET"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        questions = result.get("questions", [])

    found = any(q.get("id") == question_id for q in questions)
    if not found:
        print("  ✗ FAIL: Question not in pending list")
        return False

    print("  ✓ Question found in pending list")

    # Step 3: Submit answer (automated - select option 0)
    print("\n[4] Submitting answer (Option A)...")
    answer_data = {"selectedIndices": [0]}

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}/answer",
        data=json.dumps(answer_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
    except Exception as e:
        print(f"  ✗ FAIL: Could not submit answer: {e}")
        return False

    print("  ✓ Answer submitted")

    # Step 4: Verify question is answered
    print("\n[5] Verifying question status...")
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}",
        method="GET"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())

    status = result.get("status")
    selected = result.get("selectedIndices")

    if status != "answered":
        print(f"  ✗ FAIL: Status is '{status}', expected 'answered'")
        return False

    if selected != [0]:
        print(f"  ✗ FAIL: selectedIndices is {selected}, expected [0]")
        return False

    print("  ✓ Question marked as answered")
    print(f"  ✓ Selected indices: {selected}")

    # Step 5: Verify removed from pending
    print("\n[6] Verifying removed from pending list...")
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/questions/{pairing_id}",
        method="GET"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        questions = result.get("questions", [])

    still_there = any(q.get("id") == question_id for q in questions)
    if still_there:
        print("  ⚠ WARNING: Question still in pending list (may need cleanup)")
    else:
        print("  ✓ Question removed from pending list")

    print("\n" + "=" * 60)
    print("  ✓ E2E TEST PASSED")
    print("=" * 60)
    return True

if __name__ == "__main__":
    success = test_question_flow()
    sys.exit(0 if success else 1)
```

### 5.3 Function Selection Lint Test

**File**: `.claude/hooks/test-function-selection.py`

```python
#!/usr/bin/env python3
"""
Lint test to verify correct function is used for questions.

Checks that:
- handle_question() is called for questions requiring watch answers
- send_question_notification_only() is only called when infoOnly=True
"""

import ast
import sys
from pathlib import Path

def check_question_function_usage():
    hook_path = Path(__file__).parent / "watch-approval-cloud.py"

    if not hook_path.exists():
        print(f"✗ FAIL: Hook file not found: {hook_path}")
        return False

    source = hook_path.read_text()

    # Parse the AST
    tree = ast.parse(source)

    # Find all calls to the question functions
    notification_only_calls = []
    handle_question_calls = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                if node.func.id == "send_question_notification_only":
                    notification_only_calls.append(node.lineno)
                elif node.func.id == "handle_question":
                    handle_question_calls.append(node.lineno)

    print("Question Function Usage:")
    print(f"  send_question_notification_only() calls: {len(notification_only_calls)}")
    for line in notification_only_calls:
        print(f"    - Line {line}")

    print(f"  handle_question() calls: {len(handle_question_calls)}")
    for line in handle_question_calls:
        print(f"    - Line {line}")

    # Check that handle_question is used in main() for QUESTION_TOOLS
    # This is a basic check - could be more sophisticated
    if "handle_question(tool_input)" not in source:
        print("\n✗ FAIL: handle_question(tool_input) not found in main path")
        return False

    print("\n✓ PASS: Question functions appear correctly used")
    return True

if __name__ == "__main__":
    success = check_question_function_usage()
    sys.exit(0 if success else 1)
```

### 5.4 Stdin Proxy Question Detection Test

**File**: `claude-watch-npm/src/__tests__/stdin-proxy-detection.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
// Note: Would need to export parseQuestion from stdin-proxy.ts for testing

describe('Question Detection Edge Cases', () => {

  it('should detect questions with many options', () => {
    const buffer = `
❯ Select framework

Choose your preferred framework for this project.

❯ 1. React
     Popular UI library
  2. Vue
     Progressive framework
  3. Angular
     Full framework
  4. Svelte
     Compiler-based
  5. Solid
     Fine-grained reactivity

Enter to select · ↑/↓ to navigate · Esc to cancel
`;
    // parseQuestion(buffer) should return question with 5 options
  });

  it('should not detect partial question buffers', () => {
    const partialBuffer = `
❯ Problem

What kind of problem are
`;
    // parseQuestion(partialBuffer) should return null (incomplete)
  });

  it('should handle ANSI escape codes', () => {
    const ansiBuffer = `\x1b[1m❯ Test\x1b[0m

Question text

  1. Option A
  2. Option B

Enter to select`;
    // parseQuestion should strip ANSI codes first
  });
});
```

### 5.5 Integration Test: Proxy Mode vs Hook Mode

Add to `test-hooks.py`:

```python
def test_proxy_mode_skips_hook_question_handling():
    """
    When CLAUDE_WATCH_PROXY_MODE=1 is set, the hook should NOT
    handle questions - let stdin-proxy handle them instead.
    """
    import subprocess

    # Set up environment with proxy mode
    env = os.environ.copy()
    env["CLAUDE_WATCH_SESSION_ACTIVE"] = "1"
    env["CLAUDE_WATCH_PROXY_MODE"] = "1"

    # Send an AskUserQuestion to the hook
    input_data = json.dumps({
        "tool_name": "AskUserQuestion",
        "tool_input": {
            "questions": [{
                "question": "Test?",
                "options": [{"label": "A"}, {"label": "B"}]
            }]
        }
    })

    result = subprocess.run(
        ["python3", HOOK_PATH],
        input=input_data,
        capture_output=True,
        text=True,
        env=env,
        timeout=5
    )

    # Hook should exit 0 without output (let proxy handle it)
    assert result.returncode == 0, f"Expected exit 0, got {result.returncode}"
    assert result.stdout.strip() == "", f"Expected no output, got: {result.stdout}"

    print("  ✓ PASS: Proxy mode correctly skips hook question handling")
```

---

## Quick Reference Card

### When Questions Don't Show on Watch

1. Check `CLAUDE_WATCH_SESSION_ACTIVE=1`
2. Check pairing IDs match (run verification script)
3. Verify question created in cloud: `curl /questions/:pairingId`
4. Check watch is polling (WatchService.startPolling())

### When Answers Don't Return

1. Check `CLAUDE_WATCH_PROXY_MODE=1` if using stdin-proxy
2. Verify correct function: `handle_question()` not `send_question_notification_only()`
3. Check question status: `curl /question/:id` should be "answered"
4. Check stdin-proxy poll loop is running

### Pairing ID Sync

```bash
# Quick fix - sync files
jq -r '.pairingId' ~/.claude-watch/config.json > ~/.claude-watch-pairing

# Nuclear option - clear and re-pair
rm ~/.claude-watch-pairing ~/.claude-watch/config.json
npx cc-watch
```
