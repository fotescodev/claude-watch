---
title: "Watch Questions Not Displaying and Answers Not Returning to Terminal"
slug: watch-question-pairing-mismatch
category: integration-issues
symptoms:
  - "Watch shows 'Listening...' instead of displaying questions"
  - "Debug log shows '[Questions] Found 0 questions' despite questions being sent"
  - "Questions appear on watch after re-pairing but answers don't return to terminal"
  - "AskUserQuestion tool appears to hang or timeout"
  - "Watch and Mac have different pairing IDs in configuration"
root_causes:
  - cause: "Pairing ID Mismatch"
    description: "Watch and Mac CLI stored different pairing IDs after incomplete pairing or config corruption"
    evidence: "Watch had ID '46b7f1d1-...' while Mac had 'e48a037f-...'"
  - cause: "Wrong Function Called in Hook"
    description: "Hook called send_question_notification_only() which exits immediately instead of handle_question() which polls for answer"
    evidence: "Line 475 of watch-approval-cloud.py used wrong function"
  - cause: "Missing Stdin Proxy"
    description: "Watch answers cannot be injected into Claude's terminal UI without stdin proxy"
    evidence: "Must run via 'npx cc-watch' for answer injection"
components:
  - watch-approval-cloud.py
  - WatchService.swift
  - stdin-proxy.ts
severity: high
resolution_time: "45 minutes"
tags:
  - pairing
  - questions
  - AskUserQuestion
  - stdin-injection
  - hook
  - polling
date_documented: 2026-01-21
---

# Watch Questions Not Displaying and Answers Not Returning

## Problem Summary

Questions sent via Claude's `AskUserQuestion` tool either:
1. Don't appear on the Apple Watch at all, OR
2. Appear on watch but answers don't return to the terminal

## Symptoms

- Watch displays "Listening..." idle state instead of question UI
- Xcode console shows `[Questions] Found 0 questions` repeatedly
- After fixing pairing, questions appear but selecting an option doesn't affect terminal
- Terminal still waits for keyboard input even after answering on watch

## Root Causes

### 1. Pairing ID Mismatch (Questions Not Appearing)

The watch and Mac CLI can store different pairing IDs if:
- User re-paired one device but not the other
- Simulator vs physical device have different stored IDs
- Config file corruption

**Evidence from debug logs:**
```
# Watch debug log
[Polling] Starting poll loop for pairingId: 46b7f1d1-d4b1-4e61-ae00-7cac52ab10b7

# Mac config
$ cat ~/.claude-watch-pairing
e48a037f-5066-4ea0-a6a6-d10edd0ddabc
```

Questions are sent to Mac's pairing ID, but watch polls a different ID = no questions found.

### 2. Wrong Function in Hook (Answers Not Returning)

The hook code at `.claude/hooks/watch-approval-cloud.py` had:

```python
# BROKEN: exits immediately without waiting
send_question_notification_only(tool_input)
sys.exit(0)
```

Instead of:

```python
# CORRECT: waits for watch answer
handle_question(tool_input)
sys.exit(0)
```

### 3. Missing Stdin Proxy (Full Answer Support)

Even with the hook fix, PreToolUse hooks **cannot inject responses** into Claude's terminal. Claude reads `AskUserQuestion` answers from stdin, not hook output.

**Solution**: Run via `npx cc-watch` which uses `StdinProxy` to:
1. Spawn Claude as child process
2. Intercept stdout for question patterns
3. Send questions to watch
4. Inject watch answers into Claude's stdin

## Solution

### Step 1: Diagnose Pairing ID Mismatch

```bash
# Check Mac pairing ID
cat ~/.claude-watch-pairing

# Check watch debug log for its pairing ID
# Look for: [Polling] Starting poll loop for pairingId: ...

# Compare - they should match!
```

### Step 2: Re-pair Devices

1. **On Apple Watch**: Settings → Pair New Device (displays 6-digit code)
2. **On Mac**: Run `npx cc-watch` and enter the code from watch
3. Both devices now share the same pairing ID

### Step 3: Verify Hook Uses Correct Function

In `.claude/hooks/watch-approval-cloud.py`, ensure the question handling calls `handle_question()`:

```python
# Handle AskUserQuestion
if tool_name in QUESTION_TOOLS:
    if os.environ.get("CLAUDE_WATCH_PROXY_MODE") == "1":
        # Proxy mode: stdin-proxy.ts handles questions
        sys.exit(0)
    else:
        # Non-proxy mode: send to watch and WAIT for answer
        handle_question(tool_input)  # ← Must use this, not send_question_notification_only()
        sys.exit(0)
```

### Step 4: Run via cc-watch

For full question support with answer injection:

```bash
# Always use this instead of plain 'claude'
npx cc-watch
```

This sets `CLAUDE_WATCH_PROXY_MODE=1` and enables stdin injection.

## Complete Working Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  User runs: npx cc-watch                                                    │
│                                                                             │
│  1. StdinProxy spawns Claude with CLAUDE_WATCH_PROXY_MODE=1                 │
│                                                                             │
│  2. Claude asks question (AskUserQuestion tool)                             │
│     - Hook sees PROXY_MODE=1, skips (exits 0)                               │
│     - StdinProxy detects question UI in stdout                              │
│                                                                             │
│  3. StdinProxy → POST /question { pairingId, question, options }            │
│                                                                             │
│  4. Watch polls GET /questions/:pairingId → displays question               │
│                                                                             │
│  5. User taps answer → POST /question/:id/answer { selectedIndices }        │
│                                                                             │
│  6. StdinProxy polls GET /question/:id → receives answer                    │
│                                                                             │
│  7. StdinProxy writes to Claude's stdin → Claude continues                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Role |
|------|------|
| `.claude/hooks/watch-approval-cloud.py` | PreToolUse hook - routes questions to watch |
| `claude-watch-npm/src/cli/stdin-proxy.ts` | Spawns Claude, intercepts questions, injects answers |
| `ClaudeWatch/Services/WatchService.swift` | Watch-side polling (`fetchPendingQuestions()`) |
| `ClaudeWatch/Views/QuestionView.swift` | Watch UI + `ClaudeQuestion.from()` parsing |

## Verification Commands

```bash
# Test pairing IDs match
MAC_ID=$(cat ~/.claude-watch-pairing)
echo "Mac: $MAC_ID"
# Compare with watch debug log

# Test question creation
curl -s -X POST "https://claude-watch.fotescodev.workers.dev/question" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\": \"$MAC_ID\", \"question\": \"Test?\", \"options\": [{\"label\": \"Yes\"}, {\"label\": \"No\"}]}"

# Check pending questions
curl -s "https://claude-watch.fotescodev.workers.dev/questions/$MAC_ID"
```

## Prevention

1. **Always re-pair both devices together** when debugging connection issues
2. **Use `npx cc-watch`** for all Claude sessions requiring watch interaction
3. **Verify pairing IDs match** before investigating deeper issues
4. **Check hook function** - `handle_question()` waits, `send_question_notification_only()` doesn't

## Related Documentation

- [DATA_FLOW.md](/.claude/DATA_FLOW.md) - Flow 3: Question (AskUserQuestion)
- [cc-watch-session-isolation.md](./cc-watch-session-isolation.md) - Session environment variables
- [question-flow-prevention-strategies.md](./question-flow-prevention-strategies.md) - Diagnostic checklists
