# COMP5 Question Proxy Failure Analysis

> **Date**: 2026-01-22
> **Branch**: codex-review
> **Status**: ABANDONED - Lessons learned, starting fresh
> **Time Invested**: ~4-6 hours across multiple sessions

---

## Executive Summary

The codex-review branch attempted to implement COMP5 (watch-based question response) but failed due to **architectural misalignment** between components. Each piece (CLI, Cloud, Watch, Hook) was built independently without a shared contract, resulting in 100% failure rate when connected.

---

## The Problem We Were Solving

Claude's `AskUserQuestion` tool outputs to stdout (not a hook), so watch approval hooks cannot intercept user questions. The goal was to:
1. Detect questions from Claude's stdout
2. Forward them to the watch
3. Let user tap an option on watch
4. Inject the answer back into Claude's stdin

---

## What Was Built (codex-review branch)

| Component | File | Lines | Status |
|-----------|------|-------|--------|
| StdinProxy | `cli/stdin-proxy.ts` | 366 | Broken |
| QuestionView | `Views/QuestionView.swift` | 381 | Complete but unused |
| Cloud Endpoints | `workers/index.ts` | ~100 | Mismatched |
| Hook Integration | `watch-approval-cloud.py` | ~50 | Bypassed |
| DATA_FLOW.md | `.claude/DATA_FLOW.md` | 431 | Good documentation |

---

## Why It Failed

### Root Cause: No Shared API Contract

Each component made assumptions about the others:

```
CLI assumed:    POST /question → {questionId: "abc"}
Cloud provided: POST /question → {id: "xyz"}  ← Different field name

CLI polled:     GET /question-response/:pairingId/:questionId
Cloud provided: GET /question/:questionId  ← Different path structure

CLI sent:       {pairingId, question: {id, type, prompt, options}}
Cloud expected: {pairingId, question: string}  ← Different data type
```

### Specific Failures

#### 1. Question ID Mismatch (100% failure)
```typescript
// CLI generates ID
const questionId = crypto.randomUUID();
await fetch('/question', { body: { questionId, ... } });
await fetch(`/question-response/${pairingId}/${questionId}`);  // Polls this ID

// Cloud ignores client ID, generates new one
const questionId = crypto.randomUUID();  // Different ID!
kv.put(`question:${questionId}`, data);  // Stored under different ID

// Result: CLI polls forever for an ID that doesn't exist
```

#### 2. Endpoint Path Mismatch (404 always)
```typescript
// CLI calls:
GET /question-response/{pairingId}/{questionId}

// Cloud provides:
GET /question/{questionId}

// Result: 404 Not Found, CLI thinks no answer yet
```

#### 3. Data Structure Mismatch (parsing fails)
```typescript
// CLI sends:
{ pairingId: "...", question: { id: "...", type: "multiple_choice", prompt: "...", options: [...] } }

// Cloud expects:
{ pairingId: "...", question: "What option?" }  // Just a string!

// Result: Server stores wrong data, watch can't parse
```

#### 4. Debounce Blocks Notifications
```python
# Hook has 3-second debounce
if time.time() - last_notification_time < 3.0:
    return  # Silently drops notification!

# Result: Question notification never reaches watch
```

#### 5. stdin Raw Mode Conflict (input duplication)
```typescript
// Passthrough listener
process.stdin.setRawMode(true);
process.stdin.on('data', (d) => claude.stdin.write(d));

// Question input listener (SAME STREAM!)
process.stdin.on('data', (d) => handleAnswer(d));

// Result: Same keystroke processed twice, or race condition
```

#### 6. Promises That Never Resolve (hangs forever)
```typescript
async pollWatchAnswer(): Promise<string> {
  while (Date.now() - start < timeout) {
    // ... polling logic
  }
  return new Promise(() => {});  // NEVER RESOLVES!
}

// Used in:
await Promise.race([pollWatchAnswer(), readTerminalInput()]);

// Result: If both fail, hangs forever with no timeout
```

---

## What Worked (Salvageable Ideas)

### 1. Child Process Spawning Pattern
The basic architecture is correct:
```typescript
const claude = spawn('claude', args, {
  stdio: ['pipe', 'pipe', 'pipe'],
  env: { ...process.env, CLAUDE_WATCH_SESSION_ACTIVE: '1' },
});
```

### 2. Question Detection Regex
The patterns for detecting Claude questions are reasonable:
```typescript
// Numbered options
/([^\n]+\?)\s*\n((?:\s*\d+\.\s+[^\n]+\n?)+)/

// Y/N confirmation
/([^\n]+\?)\s*[\[(]?[yY]\/[nN][\])]?/

// Bracketed selection
/([^\n]+):\s*\[([^\]]+)\]\s*$/
```

### 3. Key Sequence Injection
The approach of sending escape sequences is correct:
```typescript
const down = "\x1b[B";   // Arrow down
const enter = "\r";      // Enter
const space = " ";       // Space for multi-select

// Build sequence to select option 3:
// Down, Down, Enter
```

### 4. QuestionView.swift Design
The watch UI is well-designed with:
- Single-select (tap to submit)
- Multi-select (checkboxes + submit button)
- "Other" option for voice/terminal fallback
- Claude design system integration
- Accessibility support

### 5. DATA_FLOW.md Documentation
Comprehensive API reference with:
- All endpoints documented
- Request/response formats
- Test coverage tracking
- Flow diagrams

---

## Lessons Learned

### 1. API Contract First
**ALWAYS** define the shared API contract before implementing:
```yaml
# Define this FIRST, share across all components
POST /question:
  request: { pairingId: string, questionId: string, question: QuestionPayload }
  response: { success: true }

GET /question/{pairingId}/{questionId}:
  response: { status: 'pending' | 'answered', answer?: string }
```

### 2. Single Source of Truth for IDs
Client generates IDs, server stores them as-is:
```
Client: questionId = "abc-123"
Server: kv.put("question:abc-123", data)
Client: poll("question:abc-123")  ← Same ID everywhere
```

### 3. Test Each Layer Independently
Before integration:
- Test CLI question detection with mock stdout
- Test cloud endpoints with curl
- Test watch UI with mock data
- Test hook with mock server

### 4. No Silent Failures
Every failure path needs logging:
```typescript
// BAD
if (!response.ok) return null;

// GOOD
if (!response.ok) {
  console.error(`[Question] Cloud returned ${response.status}: ${await response.text()}`);
  return null;
}
```

### 5. Timeouts on Everything
```typescript
// BAD
await Promise.race([pollWatch(), readTerminal()]);

// GOOD
await Promise.race([
  pollWatch(),
  readTerminal(),
  timeout(30000, 'No response in 30s'),
]);
```

### 6. One stdin Listener
Don't create multiple listeners on the same stream:
```typescript
// BAD: Two listeners compete
process.stdin.on('data', passthrough);
process.stdin.on('data', handleQuestion);

// GOOD: Single router
process.stdin.on('data', (d) => {
  if (awaitingQuestionAnswer) handleQuestion(d);
  else passthrough(d);
});
```

---

## Files to Reference

| What | Where |
|------|-------|
| Working QuestionView UI | `git show origin/codex-review:ClaudeWatch/Views/QuestionView.swift` |
| DATA_FLOW documentation | `git show origin/codex-review:.claude/DATA_FLOW.md` |
| Broken stdin-proxy | `git show origin/codex-review:claude-watch-npm/src/cli/stdin-proxy.ts` |
| Key sequence builder | Search for `buildSelectionKeys` in stdin-proxy.ts |

---

## Recommendation

Start fresh with PHASE 10, using:
1. API contract defined first (in phase10-CONTEXT.md)
2. CLI, Cloud, Watch implement to same spec
3. Test each component before integration
4. No debouncing for questions
5. Single stdin listener pattern
6. Timeouts on all async operations

See: `.claude/plans/phase10-CONTEXT.md`
