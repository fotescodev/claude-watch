# Phase 10 Context: Streaming Terminal UI + Watch Questions

> Decisions captured: 2026-01-22
> Architecture pivot: From stdin injection → streaming JSON
> Participants: dfotesco

## Executive Summary

Phase 10 implements a **custom terminal UI** for cc-watch using Claude's streaming JSON mode. This replaces the failed stdin injection approach with a clean JSON protocol where questions come as structured messages.

**Key pivot**: We're NOT parsing terminal output or injecting stdin. Instead:
- Claude runs with `--output-format stream-json`
- Questions arrive as `control_request` JSON messages
- We send answers back as `control_response` JSON
- We build our own terminal UI using Ink (React for CLI)

---

## Confirmed Decisions (2026-01-22)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Architecture** | Streaming JSON mode | Happy Coder proves this works; clean JSON protocol |
| **Terminal UI** | Full Ink-based UI | Professional look with colors, boxes, spinners |
| **Question fallback** | Terminal fallback after 30s | Watch may be unavailable; always allow terminal input |
| **Question routing** | Watch first, terminal second | Watch gets priority, terminal is backup |

---

## Architecture

### Before (Failed Approach)
```
cc-watch spawns claude CLI (interactive mode)
    ↓
Parse stdout for question patterns (fragile!)
    ↓
Inject answer via stdin (timing-sensitive!)
    ↓
❌ FAILS - escape codes, race conditions
```

### After (Streaming JSON)
```
cc-watch spawns:
  claude --output-format stream-json \
         --input-format stream-json \
         --permission-prompt-tool stdio

    ↓
Claude sends JSON to stdout:
  { "type": "control_request", "request_id": "abc",
    "request": { "subtype": "can_use_tool", "tool_name": "AskUserQuestion", ... }}

    ↓
cc-watch parses JSON:
  1. AskUserQuestion → send to watch, wait for answer
  2. Other tools → send to watch for approval
  3. assistant/text → render in terminal UI

    ↓
cc-watch sends JSON to stdin:
  { "type": "control_response", "response": { "request_id": "abc", ... }}

    ↓
✅ Claude receives structured response and continues
```

---

## Implementation Plan

### Phase 10.1: Add Ink Dependencies

```bash
cd claude-watch-npm
npm install ink react ink-spinner ink-box chalk
npm install -D @types/react
```

### Phase 10.2: Create Ink Terminal UI

**File**: `claude-watch-npm/src/ui/TerminalUI.tsx`

```typescript
// React/Ink-based terminal UI
// - Shows Claude's text output
// - Shows pending questions (with watch status)
// - Shows token count and elapsed time
// - Status bar at bottom
```

Reference: `/tmp/happy-ui/happy-main/cli/src/ui/ink/RemoteModeDisplay.tsx`

### Phase 10.3: Update StreamingClaudeRunner

**File**: `claude-watch-npm/src/cli/streaming-claude.ts`

Current state: Basic implementation exists, needs:
1. Integration with Ink UI for rendering
2. Better AskUserQuestion handling with watch routing
3. Terminal fallback when watch times out

### Phase 10.4: Question Flow

```
1. Claude sends control_request for AskUserQuestion
2. Parse questions array from request.input
3. Send to watch via POST /question
4. Start 30-second timer
5. Poll GET /question/:id for answer
6. If watch answers: send control_response with selected indices
7. If timeout: show question in terminal, wait for local input
8. Send control_response with answer
```

### Phase 10.5: Watch Integration

Watch side is already implemented:
- `QuestionView.swift` - UI for questions (exists from codex-review)
- `WatchService.swift` - fetchPendingQuestions, answerQuestion methods
- Cloud endpoints - `/question` routes exist

Need to verify cloud accepts client-provided question ID.

---

## File Changes Required

| File | Action | Description |
|------|--------|-------------|
| `claude-watch-npm/package.json` | Modify | Add ink, react dependencies |
| `claude-watch-npm/src/ui/TerminalUI.tsx` | Create | Ink-based terminal UI component |
| `claude-watch-npm/src/ui/MessageView.tsx` | Create | Render Claude's messages |
| `claude-watch-npm/src/ui/QuestionPrompt.tsx` | Create | Terminal fallback for questions |
| `claude-watch-npm/src/cli/streaming-claude.ts` | Modify | Integrate with Ink UI |
| `claude-watch-npm/src/cli/cc-watch.ts` | Modify | Use Ink render instead of console.log |
| `MCPServer/worker/src/index.ts` | Modify | Accept client-provided question ID |

---

## Success Criteria

- [ ] cc-watch shows professional Ink-based UI
- [ ] Claude's text output renders in terminal
- [ ] Questions route to watch via cloud
- [ ] Watch answers within 30s → Claude continues
- [ ] Watch timeout → terminal fallback works
- [ ] Tool approvals still work (existing flow)
- [ ] Token count and timing displayed

---

## Reference Files from Happy

Key files to study:
```
/tmp/happy-ui/happy-main/cli/src/
├── ui/ink/
│   ├── RemoteModeDisplay.tsx    # Main terminal UI
│   ├── messageBuffer.ts         # Message accumulation
│   └── *.tsx                    # Components
├── claude/
│   ├── sdk/query.ts             # Streaming JSON handling
│   └── utils/permissionHandler.ts # Permission flow
└── ui/messageFormatterInk.ts    # Message formatting
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Ink adds complexity | Start with Happy's patterns, adapt |
| Streaming JSON quirks | Test incrementally, log all messages |
| Watch cloud latency | 30s timeout with terminal fallback |
| Build issues | TypeScript strict mode, test early |

---

## Out of Scope

- Full Claude TUI replication (just need text + questions)
- Tool approval UI changes (keep existing flow)
- Watch UI changes (already done)
- Multi-device support

---

## Pre-Implementation Checklist

Before coding:
1. [ ] Verify streaming JSON mode works: `claude --output-format stream-json -p "hello"`
2. [ ] Verify cloud /question endpoint accepts `id` field
3. [ ] Verify watch QuestionView still works (test with simulator)
4. [ ] Install Ink dependencies and test basic render

---

## Tasks for tasks.yaml

```yaml
- id: "P10-1"
  title: "Add Ink dependencies and test basic render"
  priority: critical
  completed: false

- id: "P10-2"
  title: "Create Ink-based TerminalUI component"
  priority: critical
  depends_on: ["P10-1"]
  completed: false

- id: "P10-3"
  title: "Integrate StreamingClaudeRunner with Ink UI"
  priority: critical
  depends_on: ["P10-2"]
  completed: false

- id: "P10-4"
  title: "Implement AskUserQuestion → watch routing"
  priority: critical
  depends_on: ["P10-3"]
  completed: false

- id: "P10-5"
  title: "Add terminal fallback for question timeout"
  priority: high
  depends_on: ["P10-4"]
  completed: false

- id: "P10-6"
  title: "E2E test: question → watch → answer → continue"
  priority: high
  depends_on: ["P10-5"]
  completed: false
```
