# Reverse Engineering: Anthropic's Claude Remote Control

> **Purpose**: Deep technical analysis of how Anthropic built Claude Remote to inform Remmy's architecture.
> **Date**: 2026-02-25
> **Status**: Research complete

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Comparison](#2-architecture-comparison)
3. [Communication Protocol Deep Dive](#3-communication-protocol-deep-dive)
4. [Hooks System Internals](#4-hooks-system-internals)
5. [Security Model](#5-security-model)
6. [Agent SDK & Control Protocol](#6-agent-sdk--control-protocol)
7. [What Remmy Does Differently (and Better)](#7-what-remmy-does-differently-and-better)
8. [What Anthropic Does Better (Gaps in Remmy)](#8-what-anthropic-does-better-gaps-in-remmy)
9. [Architectural Insights for Remmy V2](#9-architectural-insights-for-remmy-v2)
10. [Implementation Recommendations](#10-implementation-recommendations)

---

## 1. Executive Summary

Anthropic's Claude Remote Control (shipped 2026-02-25) and Remmy solve the **same fundamental problem** — remote control of a local Claude Code session — but take dramatically different approaches:

| Dimension | Claude Remote | Remmy |
|-----------|--------------|-------|
| **Surface** | Web browser + Claude mobile app | Apple Watch |
| **Interaction model** | Full conversation (text input, rich output) | Approve/reject + tappable options |
| **Connection** | Outbound HTTPS polling → Anthropic API | Outbound HTTPS polling → Cloudflare Worker |
| **Hook mechanism** | None (built into CLI core) | PreToolUse shell hook (external script) |
| **Security** | Short-lived credentials, TLS, API auth | E2E encryption (x25519 + ChaChaPoly), pairing codes |
| **Who controls permissions** | User via web/mobile UI | User via watch buttons |
| **Client technology** | React web + native mobile apps | Native watchOS SwiftUI |

**Key insight**: Claude Remote is a *conversation relay*. Remmy is a *permission gateway*. They're architecturally complementary, not competitive.

---

## 2. Architecture Comparison

### 2.1 Claude Remote Control Architecture

```
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Local Machine   │      │  Anthropic API   │      │  Remote Device   │
│                  │      │                  │      │                  │
│  claude CLI      │─────▶│  Session Router  │◀─────│  claude.ai/code  │
│  (runs locally)  │      │  (cloud relay)   │      │  or Claude app   │
│                  │      │                  │      │  (web/mobile UI) │
│  • Full env      │      │  • TLS transport │      │  • Rich text IO  │
│  • Files, MCP    │      │  • Short-lived   │      │  • Full convo    │
│  • Tools         │      │    credentials   │      │  • QR pairing    │
│  • Git, shell    │      │  • Msg routing   │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘

Connection flow:
1. `claude remote-control` → registers session with Anthropic API
2. Local CLI polls API for incoming messages (outbound HTTPS only)
3. Remote device connects via session URL or QR code
4. API routes messages bidirectionally over streaming connection
5. All execution stays local; remote device is a "window"
```

**Key characteristics:**
- **No inbound ports** — outbound HTTPS only, firewall-friendly
- **Registration + polling** — CLI registers, then polls for work
- **Streaming connection** — server routes messages between client and local session
- **Session URL** — unique URL acts as authentication (treat like a password)
- **Auto-reconnection** — survives laptop sleep, network drops (10-min timeout)
- **One remote session per CLI instance**

### 2.2 Remmy Architecture

```
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  Local Machine   │      │  Cloudflare      │      │  Apple Watch     │
│                  │      │  Worker          │      │                  │
│  claude CLI      │      │                  │      │  WatchService    │
│  (native TUI)    │      │  • /approval/*   │      │  (URLSession)    │
│  ↓               │      │  • /question/*   │      │                  │
│  PreToolUse hook │─────▶│  • /pair/*       │◀─────│  • Polls q/2s    │
│  (Python script) │      │  • /progress/*   │      │  • APNs fallback │
│  ↓               │      │  • KV store      │      │  • Tap approve/  │
│  Polls for       │◀─────│  • APNs push     │─────▶│    reject        │
│  response        │      │                  │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘

Connection flow:
1. Watch initiates pairing → POST /pair/initiate → gets 6-digit code
2. User enters code in remmy-cli → POST /pair/complete
3. remmy-cli installs hook, spawns Claude with CLAUDE_WATCH_SESSION_ACTIVE=1
4. On tool use: hook intercepts → POST /approval → watch polls → user taps
5. Hook polls for response → returns allow/deny to Claude
```

### 2.3 Fundamental Architectural Differences

| Aspect | Claude Remote | Remmy |
|--------|-------------|-------|
| **Where the relay lives** | Anthropic's API infrastructure | Cloudflare Worker (your own) |
| **What gets relayed** | Full conversation messages | Only approval requests + questions |
| **Integration point** | Built into `claude` binary | External PreToolUse hook |
| **Pairing** | OAuth + session URL | 6-digit code + E2E key exchange |
| **Latency** | Streaming (near real-time) | Polling (1-2s per cycle) |
| **Data exposure** | Full conversation flows through API | Only tool metadata flows through cloud |
| **Offline resilience** | 10-min timeout, auto-reconnect | 5-min approval timeout |

---

## 3. Communication Protocol Deep Dive

### 3.1 Claude Remote: The Registration + Polling Pattern

Anthropic's implementation uses a **registration-then-poll** pattern:

```
LOCAL CLI                           ANTHROPIC API
   │                                     │
   ├── POST /register-session ──────────▶│  (register, get session_id + URL)
   │◀── {session_url, credentials} ──────│
   │                                     │
   │  [POLL LOOP]                        │
   ├── GET /poll-for-work ──────────────▶│  (long-poll or SSE)
   │◀── {messages: [...]} ───────────────│  (or empty if no new messages)
   │                                     │
   │  [WHEN WORK ARRIVES]                │
   ├── POST /submit-result ─────────────▶│  (tool results, assistant responses)
   │◀── {ack} ──────────────────────────│
   │                                     │
   │  [REMOTE DEVICE CONNECTS]           │
   │                     ┌───────────────│◀── Browser opens session URL
   │                     │               │
   │                     ▼               │
   │              Streaming connection   │  (messages routed bidirectionally)
   │                                     │
```

**Critical details:**
- Uses **outbound HTTPS only** — no WebSocket listener, no port forwarding
- **Multiple short-lived credentials** — each scoped to a single purpose, expire independently
- The "streaming connection" is likely **Server-Sent Events (SSE)** or **HTTP long-polling** from the CLI side, with WebSocket from the browser side
- Session URL is the *only* authentication — anyone with it can interact
- The API acts as a **message router**, not a compute layer

### 3.2 Remmy: The Hook + Cloud Relay Pattern

```
CLAUDE CLI          HOOK SCRIPT          CLOUD WORKER          WATCH
   │                    │                     │                   │
   ├─ PreToolUse ──────▶│                     │                   │
   │  (JSON on stdin)   │                     │                   │
   │                    ├── POST /approval ──▶│                   │
   │                    │   {type, title,     │                   │
   │                    │    description}     │                   │
   │                    │                    ├── APNs push ─────▶│
   │                    │                     │                   │
   │                    │  [POLL LOOP - 1s]   │◀── GET /queue ───│
   │                    ├── GET /approval ──▶│── {requests} ────▶│
   │                    │   /{pid}/{rid}      │                   │
   │                    │◀─ {pending} ────────│                   │
   │                    │   (repeat...)       │                   │
   │                    │                     │◀── POST approve ─│
   │                    ├── GET /approval ──▶│                   │
   │                    │◀─ {approved} ───────│                   │
   │                    │                     │                   │
   │◀─ exit 0 (allow) ─│                     │                   │
   │   or exit 2 (deny) │                     │                   │
```

**Critical details:**
- Hook receives **JSON on stdin** with tool_name, tool_input, session_id, cwd
- Hook returns decision via **exit code** (0=allow, 2=deny) or **JSON on stdout**
- Cloud is a **dumb relay** — stores requests in KV, serves them to watchers
- Watch polls **every 2 seconds** (with APNs as fast-path notification)
- **5-minute timeout** on approval polling before auto-deny

### 3.3 Protocol Comparison

| Protocol Aspect | Claude Remote | Remmy |
|----------------|--------------|-------|
| **Transport** | HTTPS + SSE/long-poll | HTTPS REST + polling |
| **Message format** | Full conversation JSON | Approval request JSON |
| **Latency (user action → effect)** | ~100-500ms (streaming) | ~1-3s (polling interval) |
| **Bandwidth** | High (full messages + tool outputs) | Low (only metadata) |
| **Offline handling** | Auto-reconnect within 10min | Timeout after 5min |
| **Authentication** | OAuth + session URL | Pairing code + E2E encryption |

---

## 4. Hooks System Internals

### 4.1 How Claude Code Hooks Work (The Foundation Remmy Uses)

Claude Code's hook system is the **critical infrastructure** that makes Remmy possible. Here's the complete picture:

#### Hook Lifecycle Events (17 total)

```
SESSION START
  │
  ├── SessionStart (startup | resume | clear | compact)
  │
  ▼
AGENTIC LOOP (repeats)
  │
  ├── UserPromptSubmit → user sends a message
  │   │
  │   ▼
  │   [Claude reasons, decides to use a tool]
  │   │
  │   ├── PreToolUse ←──── ★ THIS IS WHERE REMMY HOOKS IN ★
  │   │   • Receives: tool_name, tool_input, tool_use_id
  │   │   • Can return: allow / deny / ask
  │   │   • Exit 0 = allow, Exit 2 = deny
  │   │   • JSON stdout = structured decision
  │   │
  │   ├── PermissionRequest (if not already allowed)
  │   │
  │   ├── [Tool executes]
  │   │
  │   ├── PostToolUse (on success)
  │   │   OR PostToolUseFailure (on failure)
  │   │
  │   └── SubagentStart / SubagentStop (if spawning agents)
  │
  ├── Stop → Claude finishes responding
  │
  └── Notification → Claude needs attention
      │
      └── (permission_prompt | idle_prompt | auth_success | elicitation_dialog)
  │
  ▼
SESSION END
  ├── PreCompact (manual | auto)
  ├── ConfigChange
  └── SessionEnd (clear | logout | prompt_input_exit | other)
```

#### PreToolUse Hook Input Schema (What Remmy Receives)

```json
{
  "session_id": "abc123",
  "cwd": "/Users/dev/myproject",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": {
    "command": "npm test"
  },
  "tool_use_id": "toolu_01XYZ..."
}
```

For other tools:
```json
// Edit tool
{"tool_name": "Edit", "tool_input": {"file_path": "/src/app.ts", "old_string": "...", "new_string": "..."}}

// Write tool
{"tool_name": "Write", "tool_input": {"file_path": "/src/new.ts", "content": "..."}}

// AskUserQuestion
{"tool_name": "AskUserQuestion", "tool_input": {"questions": [{"question": "...", "options": [...]}]}}
```

#### PreToolUse Hook Output Schema (What Remmy Returns)

**Option A: Exit code only**
```bash
exit 0   # Allow the tool call
exit 2   # Deny the tool call (stderr becomes feedback to Claude)
```

**Option B: Structured JSON (more control)**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow" | "deny" | "ask",
    "permissionDecisionReason": "Approved from Apple Watch",
    "additionalContext": "User approved this via watch at 14:32"
  }
}
```

The `additionalContext` field is **injected into Claude's context** — this is how Remmy could communicate watch feedback back to Claude beyond just allow/deny.

#### Hook Configuration Format

```json
// ~/.claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",           // empty = match ALL tools
        "hooks": [
          {
            "type": "command",
            "command": "/Users/dev/.claude/hooks/watch-approval-cloud.py"
          }
        ]
      }
    ]
  }
}
```

**Matcher is a regex** — `"Bash"` matches only Bash, `"Edit|Write"` matches both, `""` matches everything.

#### Hook Environment Variables Available

| Variable | Value |
|----------|-------|
| `CLAUDE_PROJECT_DIR` | Project directory path |
| `CLAUDE_SESSION_ID` | Current session ID |
| Any env var from parent | Inherited (including `CLAUDE_WATCH_SESSION_ACTIVE`) |

### 4.2 What Claude Remote Does NOT Use Hooks For

Claude Remote Control **does not use the hooks system**. It's built directly into the `claude` binary as a first-party feature:

- `claude remote-control` starts a new subprocess mode within the CLI
- The CLI itself handles registration, polling, message routing
- No external scripts, no hook configuration needed
- Permissions flow through the web/mobile UI natively

**This is the biggest architectural difference**: Remmy is an *external extension* via hooks, while Claude Remote is an *internal feature* of the CLI.

### 4.3 Implications for Remmy

**Advantages of the hook approach:**
1. Works with ANY version of Claude Code (no CLI patches needed)
2. Can be installed/removed without modifying Claude itself
3. Session isolation via env var is elegant and zero-config for non-watch sessions
4. The hook can add `additionalContext` back to Claude (new capability!)

**Disadvantages of the hook approach:**
1. Polling latency (1s intervals) vs streaming in Claude Remote
2. Hook process spawned for EVERY tool call (overhead, though mitigated by fast-path exit)
3. Cannot intercept *conversation messages* — only tool calls
4. Cannot stream partial responses to the watch
5. The `AskUserQuestion` workaround (deny + temp file) is fragile

---

## 5. Security Model

### 5.1 Claude Remote Security

| Layer | Implementation |
|-------|---------------|
| **Transport** | TLS (same as all Claude Code traffic) |
| **Authentication** | OAuth via `/login` + session URL |
| **Session URL** | Acts as bearer token — anyone with URL can interact |
| **Credentials** | Multiple short-lived, single-purpose, independently expiring |
| **No inbound ports** | Outbound HTTPS only |
| **Trust model** | Anthropic's API is the trusted intermediary |

**Key weakness**: Session URL is the only access control. If leaked, anyone can control the session.

### 5.2 Remmy Security

| Layer | Implementation |
|-------|---------------|
| **Transport** | TLS to Cloudflare Worker |
| **Authentication** | 6-digit pairing code + pairingId token |
| **E2E Encryption** | x25519 key agreement + ChaChaPoly/XSalsa20-Poly1305 |
| **Key Exchange** | During pairing: watch pubkey → cloud → CLI; CLI pubkey → cloud → watch |
| **Session isolation** | `CLAUDE_WATCH_SESSION_ACTIVE=1` env var |
| **Trust model** | Cloud worker is a dumb relay; E2E encryption means cloud can't read payloads |

**Key advantage over Claude Remote**: E2E encryption means the relay (Cloudflare) cannot read approval request contents. Claude Remote's relay (Anthropic API) *can* see all messages (though they're trusted to handle them properly).

### 5.3 Security Comparison

| Aspect | Claude Remote | Remmy | Winner |
|--------|-------------|-------|--------|
| **Data exposure to relay** | Full conversation | Only tool metadata (E2E encrypted) | Remmy |
| **Authentication strength** | OAuth + session URL | Pairing code + E2E keys | Remmy |
| **Credential rotation** | Multiple short-lived | Static pairingId | Claude Remote |
| **Session URL leakage risk** | High impact (full access) | N/A (no session URL) | Remmy |
| **Enterprise readiness** | Managed settings, policy control | N/A | Claude Remote |

---

## 6. Agent SDK & Control Protocol

### 6.1 The NDJSON Protocol (Bridge Architecture Uses This)

The Agent SDK communicates with Claude Code via **Newline-Delimited JSON (NDJSON)**. This is the protocol Remmy's bridge architecture uses:

```
CLI → SDK Consumer (via stdout):
{"type":"system","subtype":"init","session_id":"abc","cwd":"/project"}\n
{"type":"assistant","content":[{"type":"text","text":"I'll help you..."}]}\n
{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}}\n
{"type":"result","content":[...],"modelUsage":{"input_tokens":100,"output_tokens":50}}\n

SDK Consumer → CLI (via stdin for streaming input mode):
{"type":"user","message":{"role":"user","content":"Fix the bug"}}\n
```

#### Message Types

| Type | Direction | Purpose |
|------|-----------|---------|
| `system` | CLI → Consumer | Session init, metadata |
| `assistant` | CLI → Consumer | Claude's complete response |
| `stream_event` | CLI → Consumer | Partial streaming events |
| `result` | CLI → Consumer | Final result with usage stats |
| `user` | Consumer → CLI | User messages (streaming input mode) |

#### Control Messages (Permission Handling)

When Claude Code needs permission for a tool call, it can use `--permission-prompt-tool` to route the decision to an MCP tool. This is an **alternative to hooks** for programmatic permission handling:

```
Layer 1: Static Allow Rules (settings.json allowedTools)  → if matched, allow
Layer 2: Static Deny Rules (disallowedTools)                → if matched, deny
Layer 3: --permission-prompt-tool <MCP tool>                → dynamic decision
```

### 6.2 Agent SDK Hooks (Programmatic, Not Shell)

The Agent SDK supports hooks as **callback functions** (not shell commands):

```python
# Python Agent SDK hook
async def log_file_change(input_data, tool_use_id, context):
    file_path = input_data.get("tool_input", {}).get("file_path", "unknown")
    return {}  # Empty = allow

options = ClaudeAgentOptions(
    hooks={
        "PostToolUse": [
            HookMatcher(matcher="Edit|Write", hooks=[log_file_change])
        ]
    }
)
```

```typescript
// TypeScript Agent SDK hook
const logFileChange: HookCallback = async (input) => {
  const filePath = (input as any).tool_input?.file_path ?? "unknown";
  return {};
};
```

**Key insight**: The Agent SDK provides a *programmatic* alternative to shell-based hooks. A future version of Remmy could use the Agent SDK directly instead of shell hooks, gaining:
- Native async/await instead of polling
- Structured response types instead of exit codes
- Direct integration instead of temp files

### 6.3 Streaming Output Events

```
StreamEvent(message_start)
StreamEvent(content_block_start)     ← text block beginning
StreamEvent(content_block_delta)     ← text chunks (this is the streaming text)
StreamEvent(content_block_stop)
StreamEvent(content_block_start)     ← tool_use block beginning
StreamEvent(content_block_delta)     ← tool input chunks (JSON)
StreamEvent(content_block_stop)
StreamEvent(message_delta)           ← stop reason, usage
StreamEvent(message_stop)
AssistantMessage                     ← complete message with all content
... tool executes ...
ResultMessage                        ← final result
```

---

## 7. What Remmy Does Differently (and Better)

### 7.1 Minimal Data Exposure

Claude Remote sends **full conversation content** through Anthropic's API. Remmy sends only **tool metadata** (type, title, description) through the cloud relay, and can E2E encrypt even that. The watch never sees source code or file contents — only "Run: npm test" or "Edit: src/app.ts".

### 7.2 Physical Approval Gate

Remmy provides a **physical, deliberate approval mechanism**. Tapping "Approve" on a watch requires more intentional action than clicking a button in a browser tab you might have forgotten about. This aligns with RIGOR mode's philosophy.

### 7.3 Zero Infrastructure for Users (vs Claude Remote's Anthropic Account)

Claude Remote requires a Pro/Max plan ($20-200/month). Remmy's cloud worker runs on Cloudflare's free tier and is fully self-hosted.

### 7.4 Session Isolation Design

Remmy's `CLAUDE_WATCH_SESSION_ACTIVE=1` env var is a clean, zero-config isolation mechanism. Multiple Claude sessions can run simultaneously — only the one spawned by remmy-cli activates the hook. Claude Remote doesn't have this — it's either on or off per CLI instance.

### 7.5 E2E Encryption

Remmy's x25519 + ChaChaPoly encryption means the Cloudflare relay can't read payloads. Claude Remote trusts Anthropic's infrastructure to handle message content securely.

---

## 8. What Anthropic Does Better (Gaps in Remmy)

### 8.1 Full Conversation Relay

Claude Remote lets you **send messages, see responses, view full context**. Remmy only handles approval/rejection and simple question selection. You can't read what Claude is saying or send freeform input from the watch.

**Gap**: Remmy has no way to show "what Claude is doing" in rich detail.

### 8.2 Streaming Latency

Claude Remote uses streaming connections for near-real-time message delivery. Remmy polls every 1-2 seconds, adding perceptible latency to every interaction.

**Gap**: Could reduce to ~500ms with WebSocket on the watch side.

### 8.3 Auto-Reconnection

Claude Remote handles laptop sleep and network drops gracefully with automatic reconnection (up to 10 minutes). Remmy's hook has a hard 5-minute timeout that auto-denies.

**Gap**: Should increase timeout and add reconnection logic.

### 8.4 Multi-Device Support

Claude Remote works on phone, tablet, laptop browser, desktop app. Remmy only works on Apple Watch.

**Gap**: By design (watch is the differentiator), but consider iPhone companion.

### 8.5 Built-in Integration

Claude Remote is a first-party feature — no hook installation, no external scripts, no settings.json modification. Remmy requires installing a hook, registering it in settings, and spawning Claude with special env vars.

**Gap**: Inherent to the third-party hook approach. The Agent SDK could reduce this friction.

### 8.6 Credential Rotation

Claude Remote uses **multiple short-lived credentials** that expire independently. Remmy uses a **static pairingId** that doesn't rotate.

**Gap**: Should implement periodic credential rotation or session tokens.

### 8.7 Enterprise Controls

Claude Remote respects managed settings (`allow_remote_sessions: false`), enterprise policies, and organizational controls. Remmy has no enterprise awareness.

**Gap**: Low priority for current audience, but worth noting.

---

## 9. Architectural Insights for Remmy V2

### 9.1 Adopt the `additionalContext` Field

Claude Code hooks can return `additionalContext` that gets **injected into Claude's context**. Remmy should use this to communicate watch feedback:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "User rejected from watch",
    "additionalContext": "The developer rejected this action via their Apple Watch. They may want you to take a different approach."
  }
}
```

This gives Claude richer feedback than just "denied."

### 9.2 Consider Agent SDK Migration

Instead of the shell-hook + temp-file approach, Remmy could use the Agent SDK directly:

```python
# Hypothetical: Remmy as Agent SDK consumer
from claude_agent_sdk import query, ClaudeAgentOptions, HookMatcher

async def watch_approval(input_data, tool_use_id, context):
    # Send to cloud, poll for watch response
    result = await send_to_cloud_and_poll(input_data)
    if result.approved:
        return {"hookSpecificOutput": {"permissionDecision": "allow"}}
    else:
        return {"hookSpecificOutput": {"permissionDecision": "deny",
                "permissionDecisionReason": result.reason}}

options = ClaudeAgentOptions(
    hooks={
        "PreToolUse": [HookMatcher(matcher="", hooks=[watch_approval])]
    }
)

async for message in query(prompt=user_input, options=options):
    # Forward streaming events to watch for rich progress
    if isinstance(message, StreamEvent):
        await push_to_cloud(message)
```

**Benefits:**
- Native async instead of process spawning + polling
- Structured types instead of JSON parsing + exit codes
- Can receive streaming events for progress display
- Can handle `AskUserQuestion` natively (no temp file hack)
- Session management built in

**Drawbacks:**
- Requires wrapping Claude's agentic loop (vs hook's transparency)
- More complex deployment
- Loses the "native TUI" experience (must build custom UI or go headless)

### 9.3 Hybrid Architecture: Hooks + SDK Streaming

Best of both worlds:

```
┌──────────────────────────────────────────────────────────────┐
│  HYBRID APPROACH                                              │
│                                                               │
│  1. Keep PreToolUse hook for approval (it works!)             │
│  2. Add PostToolUse hook for progress updates                 │
│  3. Add Stop hook for task completion notifications           │
│  4. Add Notification hook for idle/permission alerts          │
│  5. Use Agent SDK streaming for rich progress (optional)      │
│                                                               │
│  Hook events Remmy should use:                                │
│  ├── PreToolUse     → approval/rejection (existing)           │
│  ├── PostToolUse    → "tool X completed" progress update      │
│  ├── Stop           → "Claude finished, check results"        │
│  ├── Notification   → "Claude needs input" alert              │
│  ├── SessionStart   → "Session started" confirmation          │
│  └── SessionEnd     → "Session ended" cleanup                 │
└──────────────────────────────────────────────────────────────┘
```

### 9.4 WebSocket on Watch Side

Replace polling with WebSocket for lower latency:

```
Current:  Watch → HTTP GET /queue every 2s → Cloud → Response
Proposed: Watch ←→ WebSocket to Cloud ←→ Push events instantly
```

watchOS supports `URLSessionWebSocketTask` since watchOS 6. This would reduce approval latency from ~2s to ~100ms.

### 9.5 Adopt Claude Remote's Resilience Pattern

- **Increase timeout** from 5 minutes to 10+ minutes
- **Add exponential backoff** to polling when cloud is unreachable
- **Implement auto-reconnect** for watch-to-cloud connection
- **Persist pending approvals** across app launches (already in KV, but watch should cache locally)

### 9.6 Credential Rotation

Implement rotating session tokens:

```
Current: pairingId is permanent (until unpaired)
Proposed: pairingId + sessionToken (rotates every hour)
          Watch requests new token via /auth/refresh
          Old tokens valid for 5-min grace period
```

---

## 10. Implementation Recommendations

### Priority 1: Quick Wins (Use Existing Hooks Better)

| Change | Effort | Impact |
|--------|--------|--------|
| Use `additionalContext` in hook responses | Low | Claude gets richer feedback |
| Add PostToolUse hook for progress | Low | Watch shows real-time progress |
| Add Notification hook for alerts | Low | Watch alerts on idle/permission |
| Add Stop hook for completion | Low | Watch notifies when done |
| Increase approval timeout to 10min | Low | Matches Claude Remote's resilience |

### Priority 2: Protocol Improvements

| Change | Effort | Impact |
|--------|--------|--------|
| WebSocket on watch side | Medium | ~10x latency reduction |
| Session token rotation | Medium | Better security |
| Exponential backoff for cloud errors | Low | Better reliability |
| Cache pending approvals on watch | Medium | Survives app restart |

### Priority 3: Architecture Evolution

| Change | Effort | Impact |
|--------|--------|--------|
| Agent SDK integration (for streaming progress) | High | Rich progress on watch |
| iPhone companion app | High | Broader device support |
| Question handling without temp file hack | Medium | More robust Q&A flow |
| Bridge + hooks hybrid mode | High | Best of both architectures |

---

## Appendix A: Claude Code Hook Events Reference

| Event | Matcher | Input Fields | Decision Control |
|-------|---------|-------------|-----------------|
| `SessionStart` | startup\|resume\|clear\|compact | source | stdout → context |
| `UserPromptSubmit` | none | prompt | additionalContext, modifiedPrompt |
| `PreToolUse` | tool name regex | tool_name, tool_input, tool_use_id | allow/deny/ask |
| `PermissionRequest` | tool name regex | tool_name, tool_input | allow/deny/dismiss |
| `PostToolUse` | tool name regex | tool_name, tool_input, tool_output | block (re-run) |
| `PostToolUseFailure` | tool name regex | tool_name, tool_input, error | (informational) |
| `Notification` | notification type | type, title, body | (informational) |
| `SubagentStart` | agent type | agent_name, agent_type | (informational) |
| `SubagentStop` | agent type | agent_name, result | (informational) |
| `Stop` | none | stop_hook_active | block (continue) |
| `TaskCompleted` | none | task content | (informational) |
| `ConfigChange` | config source | source, file_path | block |
| `PreCompact` | manual\|auto | trigger | (informational) |
| `SessionEnd` | reason | reason | (informational) |

## Appendix B: Source URLs

- [Claude Remote Control docs](https://code.claude.com/docs/en/remote-control)
- [Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [CLI Reference](https://code.claude.com/docs/en/cli-reference)
- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview)
- [Agent SDK Streaming Input](https://platform.claude.com/docs/en/agent-sdk/streaming-vs-single-mode)
- [Agent SDK Streaming Output](https://platform.claude.com/docs/en/agent-sdk/streaming-output)
- [Security](https://code.claude.com/docs/en/security)
- [Permissions](https://code.claude.com/docs/en/permissions)
- [Data Usage](https://code.claude.com/docs/en/data-usage)
- [How Claude Code Works](https://code.claude.com/docs/en/how-claude-code-works)
- [Claude Code GitHub](https://github.com/anthropics/claude-code)
- [VentureBeat: Claude Remote announced](https://venturebeat.com/orchestration/anthropic-just-released-a-mobile-version-of-claude-code-called-remote)
