# SDK-URL Migration: Agent Execution Spec

> **For**: Claude Opus 4.6 agent team
> **Date**: 2026-02-11
> **Prereqs**: Read `.claude/inbox/sdk-url-websocket-analysis.md` and `WEBSOCKET_PROTOCOL_REVERSED.md` (cloned at `/tmp/remmy-websocket/`)
> **Branch**: `claude/investigate-websocket-terminal-utUEt`

---

## Conventions

- **AC** = Acceptance Criteria (all must pass for task to be complete)
- **TEST** = Automated test that validates the AC
- Every task is self-contained — an agent picks it up, reads the referenced files, implements, tests, commits.
- Tasks within a workstream are sequential. Workstreams A-D can partially overlap.
- All new Python code goes in `MCPServer/bridge/`. All new tests go alongside source files as `*_test.py`.

---

## Workstream A: Bridge Server (Python)

> New component: `MCPServer/bridge/` — a Python async WebSocket server that speaks NDJSON to Claude CLI and exposes a REST+WebSocket API for the watch (via cloud relay).

### A1: NDJSON WebSocket Server

**File**: `MCPServer/bridge/ndjson_server.py`

**Description**: Accept a single Claude CLI WebSocket connection. Parse incoming NDJSON (newline-delimited JSON). Dispatch parsed messages to registered handlers by `type` field.

**Input contract** (from CLI):
Each WebSocket message is one or more `\n`-terminated JSON lines. Types: `system`, `assistant`, `result`, `stream_event`, `control_request`, `tool_progress`, `tool_use_summary`, `auth_status`, `keep_alive`.

**AC**:
1. Server listens on configurable port (default 8787), path `/ws/cli/{session_id}`
2. On WebSocket upgrade, stores the connection as the active CLI socket for that session_id
3. Incoming data is split on `\n`, each non-empty line parsed as JSON
4. Each parsed message dispatched to a handler registered by `msg["type"]`
5. `keep_alive` messages silently consumed (no dispatch)
6. Malformed lines logged and skipped (no crash)
7. On CLI disconnect, all pending permission requests for that session marked as cancelled
8. Server can send NDJSON back: `json.dumps(msg) + "\n"` via `send_to_cli(session_id, msg)`

**TEST A1.1** — Connection acceptance:
```
Given: Server running on port 8787
When: WebSocket client connects to ws://localhost:8787/ws/cli/test-session-123
Then: Connection accepted, session "test-session-123" registered
```

**TEST A1.2** — NDJSON parsing:
```
Given: Connected CLI socket
When: Client sends '{"type":"system","subtype":"init","session_id":"abc","model":"sonnet","cwd":"/tmp","tools":["Bash"],"permissionMode":"default","claude_code_version":"2.1.37","mcp_servers":[],"slash_commands":[],"uuid":"u1"}\n'
Then: Handler for "system" called with parsed dict, subtype="init"
```

**TEST A1.3** — Multi-line message:
```
Given: Connected CLI socket
When: Client sends two JSON objects in one WebSocket frame separated by \n
Then: Both dispatched independently to their respective handlers
```

**TEST A1.4** — Malformed line:
```
Given: Connected CLI socket
When: Client sends 'not valid json\n{"type":"keep_alive"}\n'
Then: First line logged as warning, second line dispatched normally, no crash
```

**TEST A1.5** — Disconnect cleanup:
```
Given: Connected CLI socket with 2 pending permission requests
When: CLI WebSocket closes
Then: Both pending requests marked cancelled, session.cli_socket = None
```

**Dependencies**: Python 3.11+, `websockets` library

---

### A2: Message Types & Session State

**File**: `MCPServer/bridge/types.py`, `MCPServer/bridge/session.py`

**Description**: Define Python dataclasses for all NDJSON message types. Maintain per-session state (model, tools, cost, turns, context %, pending permissions, message history).

**AC**:
1. Dataclass or TypedDict for each CLI message type:
   - `SystemInitMessage` (type=system, subtype=init): session_id, model, cwd, tools, permissionMode, claude_code_version, mcp_servers, slash_commands
   - `SystemStatusMessage` (type=system, subtype=status): status ("compacting"|None), permissionMode
   - `AssistantMessage` (type=assistant): message.content (list of ContentBlock), parent_tool_use_id, uuid
   - `ResultMessage` (type=result): subtype (success|error_*), is_error, total_cost_usd, num_turns, duration_ms, modelUsage, stop_reason
   - `ControlRequestMessage` (type=control_request): request_id, request.subtype, request.tool_name, request.input, request.tool_use_id
   - `StreamEventMessage` (type=stream_event): event, parent_tool_use_id
   - `ToolProgressMessage` (type=tool_progress): tool_use_id, tool_name, elapsed_time_seconds
2. `Session` class with fields:
   - `id: str`, `cli_session_id: str | None`, `cli_socket: WebSocket | None`
   - `model: str`, `cwd: str`, `tools: list[str]`, `permission_mode: str`
   - `total_cost_usd: float`, `num_turns: int`, `context_used_percent: int`
   - `is_compacting: bool`
   - `pending_permissions: dict[str, PermissionRequest]` (request_id → request)
   - `message_history: list[dict]` (for replay to late-joining watch clients)
   - `pending_messages: list[str]` (queued while CLI not yet connected)
   - `todo_tasks: list[TodoItem]` (extracted from TodoWrite tool calls)
   - `current_activity: str | None`, `session_start_time: float`
3. `PermissionRequest` dataclass:
   - `request_id: str`, `tool_name: str`, `input: dict`, `description: str | None`
   - `tool_use_id: str`, `agent_id: str | None`, `timestamp: float`
4. `TodoItem` dataclass:
   - `content: str`, `status: str` (pending|in_progress|completed), `active_form: str | None`

**TEST A2.1** — Session state update from init:
```
Given: Empty session
When: handle_system_init(session, SystemInitMessage(model="sonnet", cwd="/proj", tools=["Bash","Edit"]))
Then: session.model == "sonnet", session.cwd == "/proj", session.tools == ["Bash","Edit"]
```

**TEST A2.2** — Context % computation:
```
Given: ResultMessage with modelUsage={"sonnet": {"inputTokens": 80000, "outputTokens": 20000, "contextWindow": 200000}}
When: session.update_from_result(msg)
Then: session.context_used_percent == 50
```

**TEST A2.3** — Pending permission lifecycle:
```
Given: Empty session
When: add_permission(PermissionRequest(request_id="r1", tool_name="Bash", input={"command":"ls"}))
Then: session.pending_permissions["r1"] exists
When: resolve_permission("r1")
Then: session.pending_permissions is empty
```

---

### A3: Permission Handler

**File**: `MCPServer/bridge/permissions.py`

**Description**: Handle `can_use_tool` control requests. Queue them as pending. When watch responds, construct and send `control_response` back to CLI.

**AC**:
1. On receiving `control_request` with `request.subtype == "can_use_tool"`:
   - Create `PermissionRequest` from message fields
   - Add to `session.pending_permissions[request_id]`
   - Notify watch clients (via cloud relay or direct WebSocket)
   - If session mode is `autoAccept`: immediately respond with `allow` + original input
2. `approve_permission(session_id, request_id, updated_input=None)`:
   - Construct: `{"type":"control_response","response":{"subtype":"success","request_id":rid,"response":{"behavior":"allow","updatedInput": updated_input or original_input}}}`
   - Send to CLI via NDJSON
   - Remove from pending_permissions
3. `deny_permission(session_id, request_id, message="Denied by user")`:
   - Construct: `{"type":"control_response","response":{"subtype":"success","request_id":rid,"response":{"behavior":"deny","message":msg}}}`
   - Send to CLI via NDJSON
   - Remove from pending_permissions
4. `approve_all(session_id)`:
   - Iterate all pending_permissions, call `approve_permission` for each
5. Timeout: if no response in 300s, keep pending (CLI blocks indefinitely; this is by design)

**TEST A3.1** — Approval round-trip:
```
Given: CLI connected, sends control_request {subtype:"can_use_tool", tool_name:"Bash", input:{"command":"ls"}, request_id:"r1"}
When: approve_permission("session1", "r1")
Then: CLI receives '{"type":"control_response","response":{"subtype":"success","request_id":"r1","response":{"behavior":"allow","updatedInput":{"command":"ls"}}}}\n'
And: session.pending_permissions is empty
```

**TEST A3.2** — Denial round-trip:
```
Given: Pending permission "r2" for tool "Bash" with input {"command":"rm -rf /"}
When: deny_permission("session1", "r2", "Too dangerous")
Then: CLI receives control_response with behavior:"deny", message:"Too dangerous"
And: session.pending_permissions is empty
```

**TEST A3.3** — Auto-accept mode:
```
Given: Session with mode "autoAccept"
When: control_request arrives for tool "Edit"
Then: control_response with behavior:"allow" sent immediately (no watch round-trip)
And: pending_permissions stays empty (never queued)
```

**TEST A3.4** — Approve all batch:
```
Given: 3 pending permissions (r1, r2, r3)
When: approve_all("session1")
Then: CLI receives 3 separate control_response messages, all with behavior:"allow"
And: pending_permissions is empty
```

---

### A4: AskUserQuestion Handler

**File**: `MCPServer/bridge/questions.py`

**Description**: Special handling for `can_use_tool` where `tool_name == "AskUserQuestion"`. Parse question structure, extract recommendation, transform for watch.

**AC**:
1. Detect `tool_name == "AskUserQuestion"` in permission handler, route here
2. Parse `input.questions` array. Each question has:
   - `question: str` (the question text)
   - `header: str` (short key, e.g. "Auth method")
   - `options: list[{label: str, description: str}]`
   - `multiSelect: bool`
3. For each question, find recommended option:
   - Scan `options[].label` for "(Recommended)" suffix
   - If found, that's the default answer
   - If not found, use first option as default
4. Transform to watch-friendly format:
   ```python
   WatchQuestion(
       request_id=original_request_id,
       question_text=questions[0].question,  # first question's text
       recommended_answer=recommended_label,  # without "(Recommended)" suffix
       option_count=len(questions[0].options),
       all_options=[opt.label for opt in questions[0].options]
   )
   ```
5. On watch **approve**: construct `updatedInput` that includes `answers` dict:
   ```python
   updated_input = dict(original_input)  # copy
   updated_input["answers"] = {}
   for i, q in enumerate(original_input["questions"]):
       # Map header -> selected option label
       updated_input["answers"][q["header"]] = recommended_answers[i]
   ```
   Send `control_response` with `behavior: "allow"` and this `updatedInput`
6. On watch **reject**: send `control_response` with `behavior: "deny"`, message: "Deferred to terminal by user"
7. Handle edge cases:
   - Question with 0 options → deny with message "No options available"
   - Question with no recommended option → use first option
   - Multiple questions in payload → recommend first option for each

**TEST A4.1** — Recommended option extraction:
```
Given: input.questions = [{
    "header": "DB",
    "question": "Which database?",
    "options": [
        {"label": "PostgreSQL (Recommended)", "description": "..."},
        {"label": "MySQL", "description": "..."},
        {"label": "SQLite", "description": "..."}
    ],
    "multiSelect": false
}]
When: extract_recommendation(questions[0])
Then: Returns "PostgreSQL"  (stripped of " (Recommended)" suffix)
```

**TEST A4.2** — Approve with updatedInput:
```
Given: AskUserQuestion permission request with header "DB", recommended "PostgreSQL"
When: watch approves
Then: CLI receives control_response with:
  response.response.behavior == "allow"
  response.response.updatedInput.answers == {"DB": "PostgreSQL"}
  response.response.updatedInput.questions == original questions (unchanged)
```

**TEST A4.3** — Deny falls back to terminal:
```
Given: AskUserQuestion permission request
When: watch rejects
Then: CLI receives control_response with:
  response.response.behavior == "deny"
  response.response.message == "Deferred to terminal by user"
```

**TEST A4.4** — Multi-question payload:
```
Given: input.questions has 3 questions, each with different recommended options
When: watch approves
Then: updatedInput.answers has 3 entries, one per question header, each with the recommended label
```

**TEST A4.5** — No recommended option falls back to first:
```
Given: Question with options ["Alpha", "Beta", "Gamma"] (none marked recommended)
When: extract_recommendation(question)
Then: Returns "Alpha" (first option)
```

---

### A5: Progress Tracker

**File**: `MCPServer/bridge/progress.py`

**Description**: Extract progress information from native protocol messages. No hooks needed.

**AC**:
1. **TodoWrite extraction**: When `assistant` message contains a `tool_use` content block with `name == "TodoWrite"`:
   - Parse `input.todos` array
   - Update `session.todo_tasks` with new task list
   - Compute `progress = completed_count / total_count`
   - Set `session.current_activity` from the `in_progress` task's `activeForm`
2. **Tool progress tracking**: On `tool_progress` message:
   - Update `session.current_activity` to `f"{tool_name} running... {elapsed_time_seconds:.0f}s"`
3. **Context % computation**: On `result` message:
   - Extract `modelUsage[model].inputTokens + outputTokens` / `contextWindow`
   - Update `session.context_used_percent`
   - If `context_used_percent >= 85`: flag `session.context_warning = True`
4. **Compaction detection**: On `system/status`:
   - If `status == "compacting"`: set `session.is_compacting = True`
   - If `status == None`: set `session.is_compacting = False`
5. **Session completion**: On `result` message:
   - If `subtype == "success"` and all todos completed → `session.status = "completed"`
   - If `subtype` starts with `"error_"` → `session.status = "failed"`
6. **Elapsed time**: Track `session.session_start_time = time.time()` on first `user` message. Compute elapsed on demand.

**TEST A5.1** — TodoWrite parsing:
```
Given: assistant message with content blocks:
  [{"type":"text","text":"..."}, {"type":"tool_use","id":"tu1","name":"TodoWrite","input":{"todos":[
    {"content":"Fix bug","status":"completed","activeForm":"Fixing bug"},
    {"content":"Write tests","status":"in_progress","activeForm":"Writing tests"},
    {"content":"Deploy","status":"pending","activeForm":"Deploying"}
  ]}}]
When: handle_assistant(session, msg)
Then: session.todo_tasks has 3 items
And: session.progress == 1/3 ≈ 0.33
And: session.current_activity == "Writing tests"
```

**TEST A5.2** — Context % from result:
```
Given: result message with modelUsage={"claude-sonnet-4-5-20250929": {"inputTokens": 170000, "outputTokens": 10000, "contextWindow": 200000}}
When: handle_result(session, msg)
Then: session.context_used_percent == 90
And: session.context_warning == True
```

**TEST A5.3** — Compaction lifecycle:
```
Given: system message with subtype="status", status="compacting"
When: handle_system(session, msg)
Then: session.is_compacting == True

Given: system message with subtype="status", status=None
When: handle_system(session, msg)
Then: session.is_compacting == False
```

---

### A6: CLI Launcher

**File**: `MCPServer/bridge/launcher.py`

**Description**: Spawn Claude Code CLI with `--sdk-url`, manage process lifecycle, support session resume.

**AC**:
1. `launch(port, cwd, model=None, permission_mode=None) -> session_id`:
   - Generate UUID for session_id
   - Construct command: `claude --sdk-url ws://localhost:{port}/ws/cli/{session_id} --print --output-format stream-json --input-format stream-json --verbose -p ""`
   - If model: add `--model {model}`
   - If permission_mode: add `--permission-mode {permission_mode}`
   - Spawn as subprocess, capture PID
   - Store `(session_id, pid, process, cli_session_id=None)` in sessions map
   - Return session_id
2. `relaunch(session_id) -> bool`:
   - Kill old process (SIGTERM, wait 2s, then SIGKILL if needed)
   - Spawn new process with `--resume {cli_session_id}` if known
   - Return True on success
3. `kill(session_id)`:
   - SIGTERM, wait 5s, then SIGKILL
4. `set_cli_session_id(session_id, cli_session_id)`:
   - Called when bridge receives `system/init` with CLI's internal session_id
   - Stored for `--resume` on relaunch
5. Process exit monitoring:
   - On process exit, log exit code, update session state to "exited"
   - If exited within 5s of launch with `--resume`, clear cli_session_id (resume failed)

**TEST A6.1** — Launch command construction:
```
Given: port=8787, cwd="/home/user/project", model="claude-opus-4-6"
When: launch(8787, "/home/user/project", model="claude-opus-4-6")
Then: subprocess.Popen called with args containing:
  ["claude", "--sdk-url", "ws://localhost:8787/ws/cli/<uuid>",
   "--print", "--output-format", "stream-json", "--input-format", "stream-json",
   "--verbose", "--model", "claude-opus-4-6", "-p", ""]
And: cwd="/home/user/project"
```

**TEST A6.2** — Relaunch with resume:
```
Given: Session "s1" with cli_session_id="abc-123", process running
When: relaunch("s1")
Then: Old process killed
And: New process spawned with args containing "--resume", "abc-123"
```

**TEST A6.3** — Kill graceful then force:
```
Given: Session "s1" with running process (PID mock)
When: kill("s1"), process doesn't exit within 5s
Then: SIGTERM sent, then SIGKILL sent after timeout
```

---

### A7: Watch-Facing REST API

**File**: `MCPServer/bridge/api.py`

**Description**: HTTP endpoints consumed by the watch (via cloud relay). These mirror the current cloud worker API contracts so the watch needs ZERO changes initially.

**AC**:
1. **GET /approval-queue/{pairing_id}** → Returns pending permissions formatted as:
   ```json
   {
     "requests": [
       {
         "id": "<request_id>",
         "type": "bash|file_edit|file_create",
         "title": "Run: ls -la",
         "description": "List files in directory",
         "filePath": null,
         "command": "ls -la"
       }
     ],
     "totalCount": 1
   }
   ```
   - Maps `tool_name` to `type`: Bash→"bash", Edit/MultiEdit/NotebookEdit→"file_edit", Write→"file_create"
   - `title`: For Bash = first 50 chars of command; For Edit/Write = filename from file_path
   - `description`: For Bash = full command; For Edit = "Edit {file_path}"; For Write = "Create {file_path}"
   - AskUserQuestion → type="question" (handled separately, see A4)

2. **POST /approval/{request_id}** ← Watch sends `{ "pairingId": "...", "approved": true|false }`
   - If approved: calls `approve_permission(session_id, request_id)`
   - If rejected: calls `deny_permission(session_id, request_id)`
   - Returns `{ "success": true }`

3. **GET /session-progress/{pairing_id}** → Returns:
   ```json
   {
     "progress": {
       "currentTask": "Write tests",
       "currentActivity": "Writing tests",
       "progress": 0.67,
       "completedCount": 2,
       "totalCount": 3,
       "elapsedSeconds": 120,
       "tasks": [
         {"content": "Fix bug", "status": "completed", "activeForm": "Fixing bug"},
         {"content": "Write tests", "status": "in_progress", "activeForm": "Writing tests"},
         {"content": "Deploy", "status": "pending", "activeForm": "Deploying"}
       ]
     }
   }
   ```

4. **GET /questions/{pairing_id}** → Returns pending AskUserQuestion items:
   ```json
   {
     "questions": [
       {
         "questionId": "<request_id>",
         "question": "Which database?",
         "recommendedAnswer": "PostgreSQL",
         "options": [{"label":"PostgreSQL","description":"..."},...]
       }
     ]
   }
   ```

5. **POST /question/{question_id}/answer** ← Watch sends `{ "pairingId": "...", "accepted": true, "handleOnMac": false }`
   - If accepted: calls question handler approve
   - If handleOnMac: calls question handler deny

6. **POST /session-interrupt** ← Watch sends `{ "pairingId": "...", "action": "stop"|"resume" }`
   - "stop": sends `control_request { subtype: "interrupt" }` to CLI
   - "resume": sends next queued user message (or no-op if nothing queued)
   - Returns `{ "success": true }`

7. **GET /session-interrupt/{pairing_id}** → Returns `{ "interrupted": false, "action": null }`
   (Kept for backward compat with hooks during migration; bridge tracks internally)

8. **GET /state** → Full session state snapshot for debugging

**TEST A7.1** — Approval queue format matches current cloud API:
```
Given: 2 pending permissions: Bash("ls") and Edit("/src/main.py")
When: GET /approval-queue/pair-123
Then: Response matches schema above with 2 requests, type "bash" and "file_edit"
```

**TEST A7.2** — Approval response triggers permission resolve:
```
Given: Pending permission "r1" for Bash("ls")
When: POST /approval/r1 {"pairingId":"pair-123","approved":true}
Then: CLI receives control_response with behavior:"allow"
And: GET /approval-queue/pair-123 returns empty requests[]
```

**TEST A7.3** — Session progress format matches current cloud API:
```
Given: Session with 3 todo tasks (1 completed, 1 in_progress, 1 pending)
When: GET /session-progress/pair-123
Then: Response matches schema with progress=0.33, completedCount=1, totalCount=3
```

**TEST A7.4** — Interrupt sends control_request:
```
Given: Active CLI session
When: POST /session-interrupt {"pairingId":"pair-123","action":"stop"}
Then: CLI receives '{"type":"control_request","request_id":"<uuid>","request":{"subtype":"interrupt"}}\n'
```

---

### A8: Bridge Entrypoint & Initialize

**File**: `MCPServer/bridge/__init__.py`, `MCPServer/bridge/main.py`

**Description**: Main entrypoint that wires everything together. Sends `initialize` control_request on CLI connect.

**AC**:
1. `python -m MCPServer.bridge --port 8787` starts:
   - WebSocket server on `/ws/cli/{session_id}` (for CLI)
   - HTTP REST API on same port (for watch cloud relay)
2. On CLI WebSocket connect:
   - Wait for `system/init` message
   - Extract `session_id` from init message, store as `cli_session_id`
   - Optionally send `initialize` control_request with `appendSystemPrompt`:
     ```
     You are being controlled from an Apple Watch. The watch can ONLY approve or reject.
     When asking questions, recommend ONE approach and ask "Proceed? (y/n)".
     NEVER present numbered option lists.
     ```
3. After `initialize` response (or immediately if skipping): bridge is ready for `user` messages
4. CLI launcher integration: `--launch` flag auto-spawns Claude with `--sdk-url`
5. Pairing ID mapping: `--pairing-id <id>` maps a pairing_id to the session for watch API routing

**TEST A8.1** — End-to-end startup:
```
Given: Bridge started with --port 8787 --launch --pairing-id pair-123
Then: Claude CLI process spawned with --sdk-url ws://localhost:8787/ws/cli/<session_id>
And: HTTP endpoints accessible at http://localhost:8787/approval-queue/pair-123
```

**TEST A8.2** — Initialize control_request sent:
```
Given: CLI connects to bridge
When: CLI sends system/init
Then: Bridge sends control_request with subtype:"initialize" containing appendSystemPrompt
And: Waits for control_response before routing user messages
```

---

## Workstream B: cc-watch CLI Migration

### B1: Launch Bridge + CLI with --sdk-url

**File**: `claude-watch-npm/src/cli/cc-watch.ts`

**Description**: Replace env-var-based session spawning with bridge-based `--sdk-url` launch.

**AC**:
1. After pairing completes, instead of:
   ```ts
   // OLD: spawn claude with env vars
   CLAUDE_WATCH_SESSION_ACTIVE=1
   ```
   Do:
   ```ts
   // NEW: start bridge, then spawn claude with --sdk-url
   const bridge = spawn('python', ['-m', 'MCPServer.bridge', '--port', '8787', '--pairing-id', pairingId])
   // Bridge handles CLI launch internally
   ```
2. Add `--use-sdk-url` flag (default: true). `--no-sdk-url` falls back to hooks for migration safety.
3. On SIGINT/SIGTERM: kill bridge process (which kills CLI child)
4. Bridge stdout/stderr piped to cc-watch console
5. Keep existing pairing flow exactly as-is (POST /pair/complete to cloud)

**TEST B1.1** — SDK-url mode launch:
```
Given: User runs `npx cc-watch` and completes pairing
When: Pairing succeeds with pairingId "pair-123"
Then: Python bridge process spawned with --port 8787 --pairing-id pair-123
And: Bridge spawns claude with --sdk-url ws://localhost:8787/ws/cli/<uuid>
And: No CLAUDE_WATCH_SESSION_ACTIVE env var set
```

**TEST B1.2** — Fallback mode:
```
Given: User runs `npx cc-watch --no-sdk-url`
When: Pairing succeeds
Then: Claude spawned with CLAUDE_WATCH_SESSION_ACTIVE=1 (old behavior)
And: Hooks activated (no bridge process)
```

**TEST B1.3** — Cleanup on exit:
```
Given: Bridge and CLI running
When: User presses Ctrl+C
Then: Bridge process receives SIGTERM
And: Bridge kills CLI child process
And: Both processes exit
```

---

### B2: Cloud Worker Relay Endpoint

**File**: `claude-watch-cloud/src/index.ts` (modify existing)

**Description**: Add a relay mode where the cloud worker proxies watch requests to the bridge running on the developer's machine.

**AC**:
1. New endpoint: **POST /bridge/register** ← cc-watch calls with `{ pairingId, bridgeUrl }` after bridge starts
   - Stores mapping: pairingId → bridgeUrl in KV
   - bridgeUrl is the localhost URL (e.g., `http://localhost:8787`)
   - Uses WebSocket or SSE tunnel for NAT traversal (if needed — defer to Phase F)
2. For MVP: Watch polls cloud as before. Cloud proxies to bridge:
   - `GET /approval-queue/{pairingId}` → Cloud fetches from bridge `http://localhost:8787/approval-queue/{pairingId}` → returns to watch
   - This keeps watch code unchanged
3. Alternative (simpler MVP): Bridge pushes to cloud. Bridge POST /approval-queue/{pairingId} → Cloud stores in KV → Watch polls as before.
4. **Decision needed**: Direct bridge push to cloud (simpler) vs. cloud-to-bridge relay (requires tunnel). **For MVP, use bridge-push-to-cloud**.

**TEST B2.1** — Bridge pushes approval to cloud:
```
Given: Bridge has pending permission for Bash("ls")
When: Bridge POSTs to cloud /approval-push/{pairingId} with request data
Then: Cloud stores in KV
And: Watch GET /approval-queue/{pairingId} returns the request
```

---

## Workstream C: Watch App Changes

### C1: Zero Watch Changes for MVP

**Description**: For MVP, the watch app changes NOTHING. The bridge exposes the same REST API contract as the current cloud worker. The cloud worker relays between watch and bridge.

**AC**:
1. `WatchService.swift` continues polling same cloud endpoints
2. `ClaudeWatchApp.swift` notification handling unchanged
3. All views unchanged
4. Complications unchanged
5. Only difference: responses are faster (bridge → cloud → watch vs hook → poll → cloud → watch)

**TEST C1.1** — Regression: existing approval flow still works:
```
Given: Bridge running, CLI connected
When: Claude calls Bash tool, needs permission
Then: Watch receives approval request via same cloud polling
And: Watch approves
And: Claude continues execution
```

---

### C2: Direct WebSocket to Bridge (Post-MVP)

**File**: `ClaudeWatch/Services/WatchService.swift`

**Description**: Add option for watch to connect directly to bridge WebSocket (when on same LAN), bypassing cloud relay entirely.

**AC**:
1. New connection mode: `useDirectBridge: Bool` (default false)
2. New property: `bridgeWSURL: String` (e.g. `ws://192.168.1.100:8787/ws/watch/{pairing_id}`)
3. WebSocket connection to bridge using existing `URLSessionWebSocketTask` infrastructure
4. Bridge sends JSON messages (NOT NDJSON — bridge translates):
   - `{"type":"permission_request","request":{...}}` → triggers approval UI
   - `{"type":"permission_cancelled","request_id":"..."}` → clears approval
   - `{"type":"session_progress","progress":{...}}` → updates progress
   - `{"type":"question_request","question":{...}}` → triggers question UI
   - `{"type":"cli_connected"}` / `{"type":"cli_disconnected"}` → connection status
5. Watch sends:
   - `{"type":"permission_response","request_id":"...","approved":true|false}`
   - `{"type":"question_response","question_id":"...","accepted":true,"handleOnMac":false}`
   - `{"type":"interrupt","action":"stop"|"resume"}`
6. Falls back to cloud polling if bridge WebSocket drops

**TEST C2.1** — Direct WebSocket approval:
```
Given: Watch connected to bridge WebSocket
When: Bridge sends {"type":"permission_request","request":{"id":"r1","tool_name":"Bash","input":{"command":"ls"}}}
Then: Watch shows approval UI
When: User taps approve
Then: Watch sends {"type":"permission_response","request_id":"r1","approved":true}
And: CLI receives allow response within <100ms
```

---

## Workstream D: Integration Tests

### D1: End-to-End Approval Flow

**File**: `MCPServer/bridge/tests/test_e2e_approval.py`

**Description**: Full integration test: launch bridge → connect mock CLI → send can_use_tool → approve via REST API → verify CLI receives response.

**AC**:
1. Test starts bridge on random port
2. Connects WebSocket client as mock CLI
3. Mock CLI sends `system/init` message
4. Mock CLI sends `control_request { subtype: "can_use_tool", tool_name: "Bash", input: {"command":"ls"} }`
5. Test calls `GET /approval-queue/{pairing_id}` and verifies request appears
6. Test calls `POST /approval/{request_id}` with `approved: true`
7. Mock CLI receives `control_response` with `behavior: "allow"`
8. Latency from step 6 to step 7 is < 100ms

**TEST D1.1** — Happy path (above)
**TEST D1.2** — Rejection path (approved: false → behavior: "deny")
**TEST D1.3** — Multiple concurrent requests → approve_all
**TEST D1.4** — CLI disconnect during pending → requests cancelled

---

### D2: End-to-End Question Flow

**File**: `MCPServer/bridge/tests/test_e2e_questions.py`

**AC**:
1. Mock CLI sends `can_use_tool { tool_name: "AskUserQuestion", input: { questions: [...] } }`
2. Test calls `GET /questions/{pairing_id}` and verifies question appears with recommended answer
3. Test calls `POST /question/{id}/answer` with `accepted: true`
4. Mock CLI receives `control_response` with `updatedInput.answers` containing recommended selection
5. Test also covers: reject → deny response, no recommended option → first option used

---

### D3: End-to-End Progress Flow

**File**: `MCPServer/bridge/tests/test_e2e_progress.py`

**AC**:
1. Mock CLI sends `assistant` message containing TodoWrite tool_use block
2. Test calls `GET /session-progress/{pairing_id}` and verifies tasks, progress %, current activity
3. Mock CLI sends `tool_progress` → verify `currentActivity` updates
4. Mock CLI sends `result` → verify `context_used_percent` and session status

---

### D4: End-to-End Interrupt Flow

**File**: `MCPServer/bridge/tests/test_e2e_interrupt.py`

**AC**:
1. Mock CLI connected and "running"
2. Test calls `POST /session-interrupt` with `action: "stop"`
3. Mock CLI receives `control_request { subtype: "interrupt" }`
4. Test calls `POST /session-interrupt` with `action: "resume"` → verify no crash

---

### D5: CLI Launcher Integration

**File**: `MCPServer/bridge/tests/test_launcher.py`

**AC**:
1. Test launches bridge with `--launch` flag
2. Verifies `claude` process spawned with correct `--sdk-url` argument
3. Kills bridge → verifies `claude` process also killed
4. Test session resume: set cli_session_id, kill CLI, relaunch → verify `--resume` flag used

**Note**: Uses mock `claude` binary (shell script that connects WebSocket and echoes)

---

### D6: Regression Test Against Current Watch API Contract

**File**: `MCPServer/bridge/tests/test_api_compat.py`

**Description**: Verify bridge REST API returns responses with exact same JSON schema as current cloud worker.

**AC**:
1. For each endpoint, compare bridge response schema against documented cloud worker schema (from workstream A7)
2. Field names, types, and nesting must match exactly
3. Missing or extra fields are test failures
4. This ensures the watch app needs zero changes

**Tests**:
- `GET /approval-queue/{id}` → matches `{"requests":[...],"totalCount":N}` schema
- `POST /approval/{id}` → matches `{"success":true}` schema
- `GET /session-progress/{id}` → matches `{"progress":{...}}` schema
- `GET /questions/{id}` → matches `{"questions":[...]}` schema
- `POST /question/{id}/answer` → matches `{"success":true}` schema
- `POST /session-interrupt` → matches `{"success":true}` schema

---

## Workstream E: New Capabilities (Post-MVP)

### E1: Permission Learning ("Always Allow" Button)

**File**: `MCPServer/bridge/permissions.py` (extend), new watch UI

**AC**:
1. When approving a permission, bridge optionally includes `updatedPermissions` in response:
   ```json
   {
     "behavior": "allow",
     "updatedInput": {"command": "git status"},
     "updatedPermissions": [{
       "type": "addRules",
       "rules": [{"toolName": "Bash", "ruleContent": "git:*"}],
       "behavior": "allow",
       "destination": "session"
     }]
   }
   ```
2. Watch UI: Long-press on approve button shows "Always Allow [tool_name]" option
3. Bridge tracks learned rules, auto-approves matching future requests
4. Rules scoped to session (cleared on session end)

**TEST E1.1**: Approve with "always allow git" → next git command auto-approved without watch prompt

---

### E2: Model Switching from Watch

**File**: `MCPServer/bridge/control.py`, watch settings view

**AC**:
1. New bridge endpoint: `POST /set-model` ← `{ "pairingId": "...", "model": "claude-opus-4-6" }`
2. Bridge sends `control_request { subtype: "set_model", model: "claude-opus-4-6" }` to CLI
3. Watch settings shows model picker (Sonnet / Opus / Haiku)
4. Bridge verifies model is in `system/init.models` list

**TEST E2.1**: POST /set-model with "claude-opus-4-6" → CLI receives set_model control_request

---

### E3: Real-Time Streaming

**File**: `MCPServer/bridge/streaming.py`, watch WebSocket handler

**AC**:
1. Bridge aggregates `stream_event` messages into text chunks
2. Sends summarized updates to watch every 500ms: `{"type":"stream_text","text":"Here is the latest..."}`
3. Watch displays scrolling text in WorkingView
4. Stops streaming when `assistant` message arrives (final response)

**TEST E3.1**: 10 stream_events with text deltas → watch receives 2-3 aggregated stream_text messages

---

### E4: Session Resume on Crash

**File**: `MCPServer/bridge/launcher.py` (extend)

**AC**:
1. Bridge monitors CLI process exit
2. On unexpected exit (exit code != 0): wait 2s, then relaunch with `--resume {cli_session_id}`
3. On relaunch, CLI reconnects to bridge WebSocket
4. Bridge replays pending permissions to CLI (if any were in-flight)
5. Watch shows brief "Reconnecting..." then resumes normal UI
6. Max 3 auto-relaunch attempts, then show error

**TEST E4.1**: Kill CLI process → bridge auto-relaunches within 5s → CLI reconnects → session continues

---

### E5: File Undo from Watch

**File**: `MCPServer/bridge/control.py`, new watch UI button

**AC**:
1. New bridge endpoint: `POST /rewind` ← `{ "pairingId": "...", "dryRun": true }`
2. Bridge sends `control_request { subtype: "rewind_files", user_message_id: "<last>", dry_run: true }`
3. Returns preview: `{ "canRewind": true, "filesChanged": 3, "insertions": 45, "deletions": 12 }`
4. If user confirms: `POST /rewind { "dryRun": false }` → bridge sends actual rewind
5. Watch shows "Undo: 3 files, +45/-12 lines. Confirm?"

**TEST E5.1**: Dry-run rewind → returns preview data. Execute rewind → CLI receives non-dry-run request.

---

## Workstream F: Cleanup & Deprecation

### F1: Remove Legacy Hooks

**Files to delete**:
- `.claude/hooks/watch-approval-cloud.py`
- `.claude/hooks/question-handler.py`
- `.claude/hooks/progress-tracker.py`
- `.claude/hooks/context-warning.py`
- `.claude/hooks/context-enforcer.py`

**AC**:
1. All above files deleted
2. `.claude/settings.json` hook registrations for these files removed
3. No remaining code references these files
4. Bridge handles all their responsibilities natively
5. `cc-watch --no-sdk-url` flag removed (no fallback to hooks)

**TEST F1.1**: After deletion, `grep -r "watch-approval-cloud" .` returns no results
**TEST F1.2**: After deletion, `grep -r "progress-tracker" .` returns no results
**TEST F1.3**: Bridge still handles all approval, question, progress, context flows

---

### F2: Remove Cloud Worker Approval Endpoints

**File**: `claude-watch-cloud/src/index.ts` (modify)

**AC**:
1. Remove endpoints: `/approval`, `/approval/{pairingId}/{requestId}`, `/approval-queue/{pairingId}`
2. Remove endpoints: `/question`, `/question/{pairingId}/{questionId}`, `/questions/{pairingId}`
3. Remove endpoints: `/session-progress`, `/session-progress/{pairingId}`
4. Remove endpoints: `/session-interrupt`, `/session-interrupt/{pairingId}`, `/session-end`, `/session-status/{pairingId}`
5. Keep endpoints: `/pair/*`, `/health`
6. Keep or add: `/bridge/*` relay endpoints (if cloud relay still needed)
7. Remove associated KV storage logic for deleted endpoints

**TEST F2.1**: Cloud worker deploys successfully with reduced endpoint set
**TEST F2.2**: Pairing flow still works end-to-end

---

### F3: Remove Temp Files & Config

**AC**:
1. Bridge no longer writes to `~/.claude-watch-session`, `~/.claude-watch-tasks.json`, `/tmp/claude-watch-*`
2. `CLAUDE_WATCH_SESSION_ACTIVE` env var no longer set or checked anywhere
3. Hook debug logs (`/tmp/claude-watch-hook-debug.log`) no longer created
4. All state lives in bridge process memory (and optional disk persistence for crash recovery)

---

## Execution Order

```
WEEK 1: Foundation
  A1 → A2 → A3 (NDJSON server + types + permissions)
  A4 (questions handler, parallel with A3)
  A5 (progress tracker, parallel with A3)

WEEK 2: Integration
  A6 (CLI launcher)
  A7 (REST API matching current cloud contract)
  A8 (entrypoint + initialize)
  D6 (API compatibility regression tests)

WEEK 3: CLI + E2E
  B1 (cc-watch launches bridge)
  D1-D5 (all E2E integration tests)
  C1 (verify watch works with zero changes)

WEEK 4: New capabilities
  E1-E5 (permission learning, model switch, streaming, resume, undo)

WEEK 5: Cleanup
  F1-F3 (remove hooks, cloud endpoints, temp files)
  C2 (optional: direct WebSocket from watch)
```

**Each task is a single agent commit. Tasks within a week can be parallelized across agents where dependencies allow.**
