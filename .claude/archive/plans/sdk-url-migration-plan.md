# Migration Plan: Hook-Based → `--sdk-url` WebSocket Protocol

> **Status**: PLANNING
> **Created**: 2026-02-11
> **Source**: Reverse-engineered from [fotescodev/remmy-websocket](https://github.com/fotescodev/remmy-websocket) (The Vibe Companion)
> **Reference**: `.claude/inbox/sdk-url-websocket-analysis.md`, `WEBSOCKET_PROTOCOL_REVERSED.md`

---

## Executive Summary

Replace the current **PreToolUse hooks → Cloud Worker → Watch polling** architecture with Claude Code's hidden `--sdk-url` WebSocket protocol. This gives us a **direct NDJSON-over-WebSocket control channel** between the CLI and our bridge server, eliminating hook fragility, polling latency, and the stdin injection problem that killed Phase 10.

---

## Architecture: Before & After

### CURRENT (Hook-Based)
```
┌──────────────┐    shell scripts     ┌──────────────┐    HTTP polling    ┌──────────────┐
│  Claude Code │ ──► PreToolUse Hook ──► Cloud Worker │ ◄──── (2-5s) ────► Apple Watch  │
│    (agent)   │ ◄── exit code 0/1 ◄──  (Cloudflare)  │ ────► APNs push ──►             │
└──────────────┘                      └──────────────┘                    └──────────────┘
     Problems:
     - Hooks can't intercept AskUserQuestion
     - stdin injection failed (Phase 10)
     - 2-5s polling latency per approval
     - 3 components to debug (hook + cloud + watch)
     - Hook timeout issues
```

### PROPOSED (--sdk-url)
```
┌──────────────┐   NDJSON/WebSocket    ┌──────────────┐    WebSocket/APNs   ┌──────────────┐
│  Claude Code │ ◄────────────────────► │ Bridge Server│ ◄─────────────────► │ Apple Watch  │
│ --sdk-url ws │   (real-time, typed)   │  (Python)    │   (real-time push)  │              │
└──────────────┘                        └──────────────┘                     └──────────────┘
     Benefits:
     - ALL tool calls as structured can_use_tool requests (incl. AskUserQuestion)
     - Bidirectional control (interrupt, set_model, set_permission_mode)
     - Real-time streaming (no polling)
     - Input modification (updatedInput) before execution
     - Session resume/fork support
     - Single debug point (bridge server)
```

---

## Part 1: Feature Parity Matrix (1:1 Migration)

Every current feature MUST continue working. This table maps each existing feature to its `--sdk-url` equivalent.

### 1.1 Core Approval Flow

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F1 | **Tool approval (Bash/Edit/Write)** | `watch-approval-cloud.py` hook → POST /approval → Watch polls → POST response → Hook polls | `can_use_tool` control_request arrives over WebSocket → Bridge routes to watch → Watch responds → Bridge sends `control_response` | **Simpler**: No hooks, no cloud polling, no hook timeout. Direct WebSocket round-trip. |
| F2 | **Tier-based risk classification** | Watch-side `ActionTier` enum classifies by tool_name + input patterns | Same classification logic, now in bridge OR watch. `can_use_tool` provides `tool_name` + `input` + `description` | **Identical data**: `tool_name` maps directly to our tiers. Input has `command`, `file_path`, etc. |
| F3 | **Approve All (batch)** | Watch sends bulk approval for queued actions | Bridge queues multiple `can_use_tool` requests, sends batch response when watch taps "Approve All" | **Better**: `pendingPermissions` Map supports N concurrent requests natively. |
| F4 | **Tier 3 reject-only** | Watch hides approve button for high-risk actions | Same UI logic. Bridge can even enforce this server-side by auto-denying known dangerous patterns. | **Better**: Bridge can add server-side safety layer. |
| F5 | **Auto-accept mode** | Watch cycles to `autoAccept` mode → immediately approves | Bridge auto-responds `{ behavior: "allow", updatedInput: original }` for all `can_use_tool` | **Better**: No round-trip to watch needed. Bridge handles locally. |

### 1.2 Question Handling (F18)

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F6 | **Binary question routing** | `question-handler.py` hook intercepts AskUserQuestion → POST /question → Watch shows Accept/Handle on Mac | `AskUserQuestion` arrives as `can_use_tool { tool_name: "AskUserQuestion", input: { questions, options } }` → Bridge extracts recommended answer → Watch approves → Bridge responds with `updatedInput` containing answer | **THIS IS THE FIX**: No stdin injection needed. `updatedInput` carries the selected answer back. |
| F7 | **Recommended answer extraction** | Hook parses question for "(Recommended)" suffix in options | Bridge parses same `input.questions[].options` array. Options with "(Recommended)" in label are the defaults. | **Identical logic**, different location (bridge vs hook). |
| F8 | **"Handle on Mac" fallback** | Watch defers to terminal when question is too complex | Bridge sends `{ behavior: "deny", message: "Deferred to terminal" }` → CLI falls back to terminal prompt | **Better**: Clean deny + message, CLI handles gracefully. |

### 1.3 Progress Tracking

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F9 | **Activity heartbeats** | `progress-tracker.py` PostToolUse hook → POST /session-progress | Bridge receives `tool_progress` messages (tool_name, elapsed_time) + `assistant` messages with TodoWrite tool_use blocks | **Better**: Native tool_progress gives real-time elapsed time. No separate hook needed. |
| F10 | **Todo list tracking** | Hook parses TodoWrite tool calls from PostToolUse | Bridge intercepts `assistant` messages containing `tool_use { name: "TodoWrite" }` content blocks. Extracts tasks from `input.todos`. | **Better**: See ALL tool calls, not just post-execution. Can show tasks as they're created. |
| F11 | **Session elapsed time** | Hook tracks `~/.claude-watch-session` file | Bridge tracks `duration_ms` from `result` messages + internal timer since session start | **Better**: Native timing from CLI, no file-based tracking. |
| F12 | **Task completion detection** | Hook checks todo statuses for all-complete | Bridge checks `result` message `subtype: "success"` + tracks todo completion from assistant messages | **Better**: Native success/error detection from `result.subtype`. |

### 1.4 Context Warning (F16)

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F13 | **Context window percentage** | `context-warning.py` PreToolUse hook estimates from API | Bridge computes from `result.modelUsage[model].contextWindow` + `inputTokens + outputTokens` | **Better**: Exact context window size and token counts from every `result` message. No estimation needed. |
| F14 | **Compaction detection** | Not currently detected | Bridge receives `system/status { status: "compacting" }` → `system/compact_boundary { pre_tokens }` → `system/status { status: null }` | **NEW**: Native compaction lifecycle. Can show "Compacting..." spinner + pre-compaction token count. |

### 1.5 Pairing & Session Management

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F15 | **Watch-initiated pairing** | Watch POST /pair/initiate → code display → CLI POST /pair/complete | **Keep cloud pairing** for initial setup. After pairing, cc-watch launches `claude --sdk-url ws://bridge:port` instead of setting env vars. | Cloud pairing stays — it's the discovery mechanism. Only the post-pairing channel changes. |
| F16 | **Session isolation** | `CLAUDE_WATCH_SESSION_ACTIVE=1` env var | `--sdk-url` inherently isolates — only sessions launched with this flag connect to bridge | **Simpler**: No env var needed. If CLI connects to bridge, it's a watch session. |
| F17 | **APNs push notifications** | Cloud worker sends APNs when new approval arrives | Bridge server sends APNs directly (or via cloud relay) when `can_use_tool` arrives | **Same**: APNs delivery doesn't change. Source changes from cloud worker to bridge. |

### 1.6 Session Control

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F18 | **Pause/Resume (interrupt)** | Watch POST /session-interrupt → Hook checks /session-interrupt/:pairingId | Bridge sends `control_request { subtype: "interrupt" }` directly to CLI | **Better**: Instant interrupt, no polling loop. CLI aborts current turn immediately. |
| F19 | **Mode cycling (normal/auto/plan)** | Watch mode selector → behavior changes on watch side | Bridge sends `control_request { subtype: "set_permission_mode", mode }` | **Better**: Mode change takes effect at CLI level. `bypassPermissions` means zero round-trips. |

### 1.7 Notifications & UI

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F20 | **REMMY_ACTION notification category** | UNNotificationCategory with approve/reject/approve-all actions | **Keep identical** — notification categories are watch-local | No change. |
| F21 | **Silent push for background updates** | `content-available: 1` via APNs | Bridge sends same APNs payload for background refresh | Same mechanism, different sender. |
| F22 | **View priority state machine** | MainView.swift priority: pairing > offline > question > approval > working > idle | **Keep identical** — this is purely watch-side UI logic | No change needed. |
| F23 | **Watch complications** | 4 accessory families reading shared UserDefaults | **Keep identical** — complications read from same data source | No change needed. |
| F24 | **Demo mode** | Screen cycling through B1, T1-T3, Q3, D1, E1, E2 states | **Keep identical** — demo mode is watch-only | No change needed. |

### 1.8 Security & Reliability

| # | Current Feature | Current Implementation | sdk-url Equivalent | Migration Notes |
|---|----------------|----------------------|-------------------|-----------------|
| F25 | **E2E encryption** | x25519 key exchange during pairing, ChaChaPoly on watch | **Keep for cloud relay leg**. Bridge↔CLI leg is local (no encryption needed). Bridge↔Watch through cloud still encrypted. | If bridge runs locally, bridge↔CLI is localhost (no encryption needed). Cloud leg keeps E2E. |
| F26 | **Keychain credential storage** | pairingId in Keychain, migration from UserDefaults | **Keep identical** — watch-local security | No change. |
| F27 | **Exponential backoff reconnection** | WatchService.swift: 16 retries with increasing delays | Bridge has native reconnection (CLI: 3 attempts, 1s-30s backoff). Watch keeps its own reconnection to bridge. | **Better**: CLI reconnection is built into the protocol. |
| F28 | **Message queuing when offline** | WatchService.swift: up to 50 messages queued | Bridge queues messages in `pendingMessages[]` when CLI isn't connected yet. Watch keeps its own queue. | **Better**: Bridge handles CLI-side queuing natively. |

---

## Part 2: New Capabilities Unlocked

These are features we've **wanted but couldn't build** with hooks, or **never knew were possible**.

### 2.1 Questions That Actually Work (Priority: CRITICAL)

**The AskUserQuestion Problem — SOLVED**

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Multi-option questions** | Watch can answer questions with >2 options by approving the recommended one | `can_use_tool { tool_name: "AskUserQuestion", input: { questions: [...] } }` → Bridge extracts best option → Watch approves → Bridge sends `updatedInput` with selected answer |
| **Multi-select questions** | Same pattern — bridge pre-selects recommended options | `updatedInput` contains the `answers` field with selected option labels |
| **Question text on watch** | Watch can display the actual question text (not just "approve?") | `input.questions[0].question` field contains the full question string |
| **Option descriptions** | Watch can show what each option means | `input.questions[0].options[].description` provides context |

**Implementation**: Bridge parses `AskUserQuestion` input, finds "(Recommended)" options, sends simplified question to watch with just the recommendation. Watch taps approve/reject. Bridge constructs `updatedInput` with the answer.

### 2.2 Input Modification (Priority: HIGH)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Command sanitization** | Strip dangerous flags (e.g., `-f` from `rm`, `--force` from `git push`) before execution | `updatedInput` can modify `command` field on `Bash` tool calls |
| **Path restriction** | Rewrite file paths to stay within project directory | `updatedInput` can modify `file_path` on `Edit`/`Write` calls |
| **Command transformation** | Change `rm` to `trash`, add `--dry-run` to destructive commands | Bridge rewrites `input.command` in `updatedInput` |

### 2.3 Permission Learning (Priority: HIGH)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **"Always allow" rules** | After approving `git status` once, auto-approve all `git:*` commands | `updatedPermissions: [{ type: "addRules", rules: [{ toolName: "Bash", ruleContent: "git:*" }], behavior: "allow", destination: "session" }]` |
| **"Always deny" rules** | Block `rm -rf` permanently for this session | Same with `behavior: "deny"` |
| **Per-project rules** | Save rules to project settings | `destination: "projectSettings"` persists across sessions |
| **Watch "trust this tool" button** | One-tap to always-allow a tool type | Bridge sends `updatedPermissions` with `destination: "session"` |

### 2.4 Runtime Control (Priority: MEDIUM)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Model switching** | Switch from Sonnet to Opus mid-session from watch | `control_request { subtype: "set_model", model: "claude-opus-4-6" }` |
| **Real interrupt** | Instant abort, not poll-based | `control_request { subtype: "interrupt" }` — CLI stops immediately |
| **Permission mode toggle** | Switch to `bypassPermissions` for trust mode, `plan` for read-only | `control_request { subtype: "set_permission_mode", mode }` |
| **Thinking budget control** | Increase thinking tokens when agent is stuck | `control_request { subtype: "set_max_thinking_tokens", max_thinking_tokens: 32000 }` |

### 2.5 Session Resilience (Priority: MEDIUM)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Session resume after crash** | If CLI dies, relaunch with full conversation context | `claude --sdk-url ws://bridge --resume <session_id>` |
| **Session fork** | Branch a conversation to try different approaches | `claude --sdk-url ws://bridge --resume <session_id> --fork-session` |
| **Message replay on reconnect** | CLI reconnects with `X-Last-Request-Id` header, bridge replays missed messages | Built into transport layer |
| **Process lifecycle management** | Bridge monitors CLI process, auto-relaunches on death | PID tracking + exited promise + relaunch with `--resume` |

### 2.6 Real-Time Streaming (Priority: MEDIUM)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Token-by-token display** | Watch shows text appearing in real-time | `stream_event` messages with `content_block_delta` events |
| **Tool execution progress** | "Bash running... 2.5s" | `tool_progress { tool_name, elapsed_time_seconds }` |
| **Compaction awareness** | Show "Compacting context..." spinner | `system/status { status: "compacting" }` → spinner → `{ status: null }` → done |

### 2.7 System Prompt Injection (Priority: MEDIUM)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Watch-mode instructions at init** | Inject "ask yes/no questions only" directly into system prompt | `initialize` control_request with `appendSystemPrompt: "Always ask binary yes/no questions..."` |
| **No env var hack needed** | Replace `CLAUDE_WATCH_SESSION_ACTIVE=1` + CLAUDE.md instructions | System prompt injection is cleaner and guaranteed to be read |
| **Custom agent definitions** | Define watch-specific agent behaviors | `initialize { agents: { "watch-assistant": { ... } } }` |

### 2.8 Sub-Agent Visibility (Priority: LOW)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Task completion notifications** | "Sub-agent 'fetch-data' completed" | `system/task_notification { task_id, status, summary }` |
| **Nested tool call tracking** | See which sub-agent is requesting which tool | `parent_tool_use_id` field on all messages traces the call chain |
| **Hook lifecycle visibility** | "PreToolUse hook running..." | `system/hook_started`, `system/hook_progress`, `system/hook_response` |

### 2.9 File Undo (Priority: LOW)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Rewind to checkpoint** | "Undo everything since my last message" | `control_request { subtype: "rewind_files", user_message_id, dry_run: true }` → preview → `dry_run: false` → execute |
| **Dry-run preview** | See how many files/lines would change before reverting | Response includes `filesChanged`, `insertions`, `deletions` |

### 2.10 MCP Server Management (Priority: LOW)

| Capability | What It Enables | How |
|-----------|----------------|-----|
| **Check MCP server status** | See if MCP servers are healthy | `mcp_status` control request |
| **Reconnect failed servers** | Fix broken MCP connections from watch | `mcp_reconnect { serverName }` |
| **Toggle servers on/off** | Disable noisy MCP servers mid-session | `mcp_toggle { serverName, enabled }` |

---

## Part 3: Implementation Phases

### Phase A: Bridge Server (Python) — Foundation
**Goal**: Standalone Python bridge that speaks NDJSON to Claude CLI and exposes an API for the watch.

**Tasks**:
1. **A1**: NDJSON WebSocket server (accept CLI connections, parse messages by type)
2. **A2**: Message router (system, assistant, result, control_request, stream_event, tool_progress, keep_alive)
3. **A3**: Permission handler (`can_use_tool` → pending map → `control_response`)
4. **A4**: CLI launcher (spawn `claude --sdk-url ws://bridge:port`, handle process lifecycle)
5. **A5**: Session state tracking (model, tools, session_id, cost, turns)
6. **A6**: REST/WebSocket API for watch (expose pending permissions, session state, progress)

**Deliverable**: `python bridge.py --port 8787` that can launch Claude, route approvals, and serve watch API.

**Validates**: F1-F5 (approval flow), F16 (session isolation), F18 (interrupt)

### Phase B: cc-watch CLI Migration
**Goal**: Modify cc-watch to use `--sdk-url` instead of env vars + hooks.

**Tasks**:
1. **B1**: Launch `claude --sdk-url ws://bridge:port` instead of setting `CLAUDE_WATCH_SESSION_ACTIVE=1`
2. **B2**: Send `initialize` control_request with `appendSystemPrompt` (watch-mode instructions)
3. **B3**: Handle session resume on reconnect (`--resume <session_id>`)
4. **B4**: Keep cloud pairing flow (only the post-pairing channel changes)
5. **B5**: APNs integration (bridge sends push notifications when `can_use_tool` arrives)

**Deliverable**: `npx cc-watch` launches bridge + CLI with `--sdk-url`, watch receives approvals via same cloud relay.

**Validates**: F15 (pairing), F17 (APNs), F25 (encryption)

### Phase C: AskUserQuestion Fix
**Goal**: Solve the multiple questions problem that killed Phase 10.

**Tasks**:
1. **C1**: Bridge intercepts `can_use_tool { tool_name: "AskUserQuestion" }`
2. **C2**: Parse `input.questions[]` — extract question text, options, recommended answer
3. **C3**: Transform to watch-friendly format (question + recommended answer + approve/reject)
4. **C4**: On approve: construct `updatedInput` with `answers: { "0": "recommended_label" }`
5. **C5**: On reject: send `{ behavior: "deny", message: "User chose to handle on Mac" }`
6. **C6**: Handle multi-question payloads (iterate and recommend for each)

**Deliverable**: Watch can answer any AskUserQuestion by approving the recommendation.

**Validates**: F6-F8 (question handling)

### Phase D: Progress Tracking Migration
**Goal**: Replace hook-based progress with native protocol messages.

**Tasks**:
1. **D1**: Extract TodoWrite tasks from `assistant` message content blocks (`tool_use { name: "TodoWrite" }`)
2. **D2**: Track `tool_progress` messages for real-time elapsed time
3. **D3**: Compute context % from `result.modelUsage` (exact tokens vs context window)
4. **D4**: Detect compaction from `system/status { status: "compacting" }` lifecycle
5. **D5**: Send progress updates to watch via existing cloud relay or direct WebSocket
6. **D6**: Handle `result` message for session completion (success/error/max_turns/max_budget)

**Deliverable**: Watch shows real-time progress without PostToolUse hooks.

**Validates**: F9-F14 (progress, context, compaction)

### Phase E: New Watch Capabilities
**Goal**: Wire up capabilities that hooks couldn't provide.

**Tasks**:
1. **E1**: Model switching (watch settings → bridge → `set_model` control request)
2. **E2**: Permission learning ("Always allow git" button → `updatedPermissions` in response)
3. **E3**: Input sanitization (strip `-f` flags, add `--dry-run` for dangerous commands)
4. **E4**: Thinking budget control (watch slider → `set_max_thinking_tokens`)
5. **E5**: Token-by-token streaming to watch (bridge → summarized stream events → watch)
6. **E6**: Rewind/undo button (watch → bridge → `rewind_files` control request)

**Deliverable**: Watch has model picker, trust buttons, undo, and streaming.

### Phase F: Resilience & Polish
**Goal**: Production-grade reliability.

**Tasks**:
1. **F1**: Session resume on CLI crash (bridge detects exit, relaunches with `--resume`)
2. **F2**: Message replay on reconnect (track last message UUID, replay buffer)
3. **F3**: Bridge persistence (save session state to disk, survive bridge restarts)
4. **F4**: Graceful degradation (fall back to cloud polling if bridge WebSocket drops)
5. **F5**: Concurrent session support (bridge manages multiple CLI processes)
6. **F6**: Remove legacy hooks (delete `watch-approval-cloud.py`, `question-handler.py`, `progress-tracker.py`, `context-warning.py`)

**Deliverable**: Production-ready system that survives crashes, reconnects, and scales.

---

## Part 4: What Gets Deleted

After full migration, these files become obsolete:

| File | Reason |
|------|--------|
| `.claude/hooks/watch-approval-cloud.py` | Replaced by `can_use_tool` WebSocket flow |
| `.claude/hooks/question-handler.py` | Replaced by `AskUserQuestion` via `can_use_tool` |
| `.claude/hooks/progress-tracker.py` | Replaced by native `tool_progress` + `assistant` parsing |
| `.claude/hooks/context-warning.py` | Replaced by `result.modelUsage` + `system/status compacting` |
| `.claude/hooks/context-enforcer.py` | Never activated; bridge can enforce natively |
| Cloud Worker approval endpoints | `/approval/*`, `/question/*`, `/session-progress/*` → bridge handles directly |

**Keep**:
- Cloud Worker pairing endpoints (`/pair/*`) — still needed for watch↔CLI discovery
- Cloud Worker APNs relay — bridge may still use cloud for push delivery
- All watch-side UI code — views, complications, notification categories stay identical
- E2E encryption — still needed for cloud relay leg

---

## Part 5: Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| `--sdk-url` is undocumented, may break in CLI updates | HIGH | Pin CLI version; protocol is stable (same as web UI uses); monitor for changes |
| Bridge adds a new process to manage | MEDIUM | Bridge runs alongside cc-watch; single `npx cc-watch` command manages both |
| Watch-to-bridge connectivity through cloud adds latency | MEDIUM | Bridge can run locally (localhost) for LAN scenarios; cloud relay for remote |
| Migration breaks existing users mid-session | MEDIUM | Feature flag: `--use-sdk-url` on cc-watch, default to hooks initially |
| CLI doesn't send `can_use_tool` for auto-approved tools | LOW | This is correct behavior — `bypassPermissions` mode means no prompts. Use `default` mode. |
| Multiple concurrent `can_use_tool` requests overwhelm watch | LOW | Bridge queues and batches, same as current "Approve All" pattern |

---

## Part 6: Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Approval round-trip latency | 2-5s (polling) | <500ms (WebSocket) |
| AskUserQuestion success rate | 0% (broken) | 100% (via updatedInput) |
| Components to debug per flow | 3 (hook + cloud + watch) | 1-2 (bridge + watch) |
| Hooks required | 4 (approval, question, progress, context) | 0 |
| Session resume after crash | Not supported | Automatic (--resume) |
| Context window accuracy | Estimated (hook-based) | Exact (from result.modelUsage) |
| Real-time streaming | Not possible | Token-by-token via stream_event |
