# Claude Code Interaction Primitives V2.0

**Version:** 2.0
**Last Updated:** January 2026
**Purpose:** Complete formal model of Claude Code's interaction grammar for wrist remote design
**Product:** Claude Watch - watchOS Companion for Claude Code
**PRD Alignment:** v1.1
**Changelog:** Added missing primitives (TodoWrite, AskUserQuestion, Task), new flows F15-F21, persona mappings

---

## Executive Summary

This document provides a **comprehensive** model of Claude Code's terminal-based interaction patterns, formally mapped to enable Claude Watch—a watchOS companion app—to serve as an intelligent wrist remote. Every primitive is sourced from official Anthropic documentation with citations.

**V2.0 Additions:**
- TodoWrite tool support (read-only progress view)
- AskUserQuestion tool support (option selection UI)
- Task tool support (sub-agent monitoring)
- Session Resume capability (F15)
- Context Warning flow (F16)
- Question Response flow (F18)

**Design Principle:** Claude Watch transforms the Claude Code approval workflow from a desktop-tethered experience to a wrist-accessible, glanceable interaction model optimized for four personas: Alex (speed), Jordan (reliability), Sam (detail), Riley (easy setup).

---

## 1. Session States

### 1.1 Primary States

| State | Description | Watch UI Implication | Persona Focus |
|-------|-------------|---------------------|---------------|
| **IDLE** | No active task, ready for input | Status: "Ready" with green indicator | Jordan |
| **RUNNING** | Task executing, may produce actions | Progress ring, task name visible | Alex, Sam |
| **WAITING_APPROVAL** | Blocked on user permission | **Critical:** Action card with Approve/Reject | All |
| **WAITING_QUESTION** | **NEW:** Claude asked user a question | Question card with options | All |
| **PAUSED** | Execution paused by user | Amber status, "Resume" available | Sam |
| **COMPACTING** | Context being summarized | "Compacting..." indicator | Jordan |
| **RESUMING** | Previous session being restored | "Resuming..." indicator | Alex |
| **COMPLETED** | Task finished successfully | Completion celebration | All |
| **FAILED** | Task encountered error | Error state, retry options | Sam, Jordan |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

### 1.2 Transient States

| State | Trigger | Watch Display |
|-------|---------|---------------|
| **Permission Prompt** | Claude requests approval | Action card |
| **Diff Review** | File edit proposed | Type icon + description |
| **Running Command** | Bash executing | Progress indicator |
| **Background Task** | User pressed `Ctrl+B` | Tasks list entry |
| **Extended Thinking** | Toggle via `Tab` | Not shown on watch |
| **Checkpointing** | Before each edit | Silent (badge increment) |
| **Rewind Menu** | `Esc+Esc` or `/rewind` | Not shown (desktop only) |
| **Error State** | Tool failure | Error banner |

### 1.3 Watch State Display

| State | Complication | Status Header | Haptic |
|-------|-------------|---------------|--------|
| IDLE | "✓ Ready" | Green, "No active task" | None |
| RUNNING | "⚡ 42%" | Orange progress, task name | None |
| WAITING_APPROVAL | Badge "3" | Orange pulse, "Approval needed" | `.notification` |
| WAITING_QUESTION | Badge "?" | Blue pulse, "Question" | `.notification` |
| COMPACTING | "..." | Amber, "Compacting context" | None |
| RESUMING | "↻" | Amber, "Resuming session" | None |
| COMPLETED | "✓ Done" | Green, completion time | `.success` |
| FAILED | "⚠️" | Red, error type | `.error` |

---

## 2. Permission Modes

### 2.1 Mode Definitions

| Mode | SDK Value | Behavior | Watch UI |
|------|-----------|----------|----------|
| **Normal** | `default` | Each action requires approval | Full approval cards |
| **Auto-Accept** | `acceptEdits` | Auto-approves file edits | Progress only (edits) |
| **Plan** | `plan` | Read-only, no execution | View-only cards |
| **Bypass** | `bypassPermissions` | Skip all checks | **Not accessible from watch** |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/sdk/sdk-permissions

### 2.2 Mode Switching

**Terminal:** `Shift+Tab` cycles modes
**Watch:** Tap mode indicator or mode selector view

```
Mode Cycle: Plan → Normal → Auto-Accept → Plan
```

### 2.3 Mode Colors (Anthropic Brand)

| Mode | Color | Hex | Icon |
|------|-------|-----|------|
| Normal | Anthropic Blue | `#6a9bcc` | Shield |
| Auto-Accept | Anthropic Orange | `#d97757` | Bolt |
| Plan | Anthropic Green | `#788c5d` | Book |

---

## 3. User Actions

### 3.1 Approval Actions

| Action | Terminal | Watch | Haptic |
|--------|----------|-------|--------|
| **Approve** | `y` / Enter | Green button | `.success` |
| **Reject** | `n` | Red button | `.error` |
| **Approve All** | N/A | Bulk button | `.success` |
| **Skip** | `s` | Swipe dismiss | `.impact(light)` |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

### 3.2 **NEW:** Question Response Actions

When Claude uses `AskUserQuestion` tool:

| Action | Watch UI | Effect |
|--------|----------|--------|
| **Select Option** | Tap option button | Sends selected answer |
| **Select Multiple** | Toggle checkmarks | Sends multiple answers |
| **Custom Input** | Voice dictation | Sends "Other" response |
| **Dismiss** | Swipe away | Sends no response (timeout) |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/common-workflows

### 3.3 Quick Commands

| Command | Icon | Sends | Persona |
|---------|------|-------|---------|
| **Go** | `play.fill` | Resume execution | Alex |
| **Test** | `bolt.fill` | "Run tests" | Sam |
| **Fix** | `wrench.fill` | "Fix errors" | Sam |
| **Stop** | `stop.fill` | Interrupt signal | All |
| **Resume** | `arrow.counterclockwise` | `--continue` | **NEW** Jordan |
| **Compact** | `arrow.down.circle` | `/compact` | **NEW** Sam |

### 3.4 Slash Commands → Watch Mapping

| Command | Watch Exposure | Rationale |
|---------|---------------|-----------|
| `/help` | Not exposed | Terminal-specific |
| `/clear` | Not exposed | Terminal-specific |
| `/compact` | Quick Command | **NEW:** Context management |
| `/init` | Not exposed | Filesystem operation |
| `/config` | Not exposed | Complex settings |
| `/permissions` | Not exposed | Detailed configuration |
| `/rewind` | Simplified | Quick undo (latest only) |
| `/memory` | Not exposed | Text editing required |
| `/tasks` | Tasks View | Full support |
| `/status` | Complication + Status | Full support |
| `/resume` | Quick Command | **NEW:** Session resume |
| `/agents` | Tasks View (nested) | **NEW:** Sub-agent display |

### 3.5 Keyboard Shortcuts → Watch Gestures

| Shortcut | Function | Watch Equivalent |
|----------|----------|------------------|
| `Shift+Tab` | Cycle mode | Mode selector tap |
| `Ctrl+C` | Interrupt | Stop button |
| `Ctrl+B` | Background | Automatic |
| `Esc` | Stop generation | Not exposed |
| `Esc+Esc` | Rewind menu | Quick undo button |
| `y` / `n` | Approve/Reject | Buttons |
| `Tab` | Toggle thinking | Not exposed |

---

## 4. System Outputs

### 4.1 Action Request Types

| Type | Icon | Color | Watch Card Style |
|------|------|-------|------------------|
| `EDIT` | Pencil | Orange | Standard |
| `CREATE` | Doc+ | Blue | Standard |
| `DELETE` | Trash | Red | **Warning** border |
| `BASH` | Terminal | Purple | Standard |
| `TOOL_USE` | Gear | Orange | Standard |
| `MCP_TOOL` | Server | Blue | Standard |

### 4.2 **NEW:** Question Request Format

When Claude uses `AskUserQuestion`:

```json
{
  "type": "QUESTION",
  "questionId": "q_abc123",
  "question": "Which database should we use?",
  "header": "Database",
  "options": [
    {"label": "PostgreSQL", "description": "Recommended for production"},
    {"label": "SQLite", "description": "Simple local development"},
    {"label": "MongoDB", "description": "Document-based NoSQL"}
  ],
  "multiSelect": false,
  "timestamp": "2026-01-21T14:32:00Z"
}
```

**Watch Display:**
```
┌─────────────────────────────────────┐
│  ❓ QUESTION                        │
├─────────────────────────────────────┤
│  Which database should we use?      │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ● PostgreSQL                    ││
│  │   Recommended for production    ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ SQLite                        ││
│  │   Simple local development      ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ MongoDB                       ││
│  │   Document-based NoSQL          ││
│  └─────────────────────────────────┘│
│                                     │
│  [Other...] (voice input)           │
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/common-workflows

### 4.3 **NEW:** Todo Progress Format

When Claude uses `TodoWrite`:

```json
{
  "type": "TODO_UPDATE",
  "todos": [
    {"content": "Set up database", "status": "completed", "activeForm": "Setting up database"},
    {"content": "Create user model", "status": "in_progress", "activeForm": "Creating user model"},
    {"content": "Add authentication", "status": "pending", "activeForm": "Adding authentication"}
  ],
  "timestamp": "2026-01-21T14:32:00Z"
}
```

**Watch Display (Read-Only):**
```
┌─────────────────────────────────────┐
│  📋 PROGRESS                        │
├─────────────────────────────────────┤
│  ✓ Set up database                  │
│  ● Creating user model...           │
│  ○ Add authentication               │
│                                     │
│  1/3 complete                       │
└─────────────────────────────────────┘
```

**Note:** Todo list is read-only on watch (no editing capability).

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

### 4.4 **NEW:** Sub-Agent Progress Format

When Claude uses `Task` tool:

```json
{
  "type": "SUBAGENT_UPDATE",
  "agentId": "agent_xyz789",
  "agentType": "explore",
  "task": "Research authentication patterns",
  "status": "running",
  "progress": 45,
  "parentId": "session_abc123",
  "timestamp": "2026-01-21T14:32:00Z"
}
```

**Watch Display (Nested in Tasks):**
```
┌─────────────────────────────────────┐
│  🔄 TASKS (2)                       │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 🟢 Main Task                    ││
│  │   └─ 🔵 explore agent (45%)    ││
│  │      Research auth patterns     ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/sub-agents

### 4.5 Statusline JSON Feed

```json
{
  "model": {"display_name": "Claude Sonnet 4", "api_name": "claude-sonnet-4"},
  "workspace": {"current_dir": "/myproject", "git_branch": "main", "git_dirty": true},
  "session": {"id": "abc123", "context_tokens": 45000, "context_limit": 200000, "pending_approvals": 2},
  "tasks": {"running": 1, "background": 3},
  "todos": {"total": 5, "completed": 2, "in_progress": 1}
}
```

**NEW Fields:**
- `todos.total` - Total todo items
- `todos.completed` - Completed count
- `todos.in_progress` - Currently active

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/statusline

### 4.6 Available Tools (Complete List)

| Tool | Purpose | Watch Handling |
|------|---------|----------------|
| `Bash` | Shell commands | Approval card |
| `Read` | Read files | Silent (no approval) |
| `Write` | Create files | Approval card |
| `Edit` | Modify files | Approval card |
| `Glob` | Pattern match | Silent |
| `Grep` | Search content | Silent |
| `Task` | Sub-agents | **NEW:** Nested task display |
| `TaskOutput` | Get output | Silent |
| `KillShell` | Stop shell | Approval card |
| `NotebookEdit` | Jupyter | Approval card |
| `WebFetch` | Fetch URL | Approval card |
| `WebSearch` | Search web | Approval card |
| `TodoWrite` | Task list | **NEW:** Progress display |
| `AskUserQuestion` | Get input | **NEW:** Question card |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

---

## 5. Security Semantics

### 5.1 Read-Only Defaults

| Operation | Default | Watch Approval |
|-----------|---------|----------------|
| File read | Allowed | No |
| File edit | Requires approval | Yes |
| File create | Requires approval | Yes |
| File delete | Requires approval | **Yes + Warning** |
| Bash command | Requires approval | Yes |
| Network access | Requires approval | Yes |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/security

### 5.2 Dangerous Operation Indicators

| Operation | Risk Level | Watch Style |
|-----------|------------|-------------|
| Edit file | Normal | Standard card |
| Create file | Normal | Standard card |
| Delete file | **Elevated** | Red border |
| `rm -rf` | **Critical** | Red banner, strong haptic |
| System command | **Critical** | Confirmation dialog |

### 5.3 Hooks Integration

| Hook | Watch Relevance |
|------|-----------------|
| `PreToolUse` | May auto-allow (no card shown) |
| `PermissionRequest` | Card display triggered |
| `PostToolUse` | Silent logging |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/hooks

---

## 6. Connection Architecture

### 6.1 System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEVELOPER'S MACHINE                          │
│  ┌───────────┐    ┌─────────────┐    ┌─────────────────────┐   │
│  │  Claude   │───▶│    MCP      │───▶│   Python Server     │   │
│  │   Code    │    │  Protocol   │    │   (WebSocket)       │   │
│  └───────────┘    └─────────────┘    └──────────┬──────────┘   │
└─────────────────────────────────────────────────┼───────────────┘
                                                  │
                 ┌────────────────────────────────┼────────────┐
                 │              NETWORK           │            │
                 │  ┌────────────────────────────▼─────────┐  │
                 │  │         Local WebSocket              │  │
                 │  │    OR  Cloud Relay (Cloudflare)      │  │
                 │  │    OR  APNs (Push Notifications)     │  │
                 │  └────────────────────────────┬─────────┘  │
                 └───────────────────────────────┼────────────┘
                                                 │
┌────────────────────────────────────────────────▼────────────────┐
│                        APPLE WATCH                              │
│  ┌───────────┐    ┌─────────────────┐    ┌────────────────┐    │
│  │  SwiftUI  │◀──▶│  WatchService   │◀──▶│ Notifications  │    │
│  │   Views   │    │  (State Mgmt)   │    │ (UNUserNotif)  │    │
│  └───────────┘    └─────────────────┘    └────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Message Types

| Type | Direction | Purpose |
|------|-----------|---------|
| `state_sync` | Server → Watch | Full state on connect |
| `action_requested` | Server → Watch | New approval needed |
| `action_response` | Watch → Server | User's decision |
| `progress_update` | Server → Watch | Task progress |
| `mode_changed` | Bidirectional | Mode update |
| `question_asked` | **NEW** Server → Watch | Question from Claude |
| `question_answered` | **NEW** Watch → Server | User's answer |
| `todo_update` | **NEW** Server → Watch | Todo list change |
| `session_list` | **NEW** Server → Watch | Available sessions |
| `resume_session` | **NEW** Watch → Server | Resume request |

### 6.3 Reconnection Strategy

| Attempt | Delay | Strategy |
|---------|-------|----------|
| 1 | 0s | Immediate |
| 2 | 2s | Short delay |
| 3 | 4s | Backoff |
| 4-10 | 8s | Exponential |
| Max | 60s | Manual retry |

---

## 7. New User Flows (F15-F21)

### F15: Session Resume

**Trigger:** User wants to continue previous work
**Primitive:** `--continue` / `--resume` CLI flags

```
┌─────────────────────────────────────┐
│  ↻ RECENT SESSIONS                  │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ myproject/feature-auth          ││
│  │ 15 min ago • 72% context        ││
│  │ [Resume]                        ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ api-server/main                 ││
│  │ 2 hours ago • 45% context       ││
│  │ [Resume]                        ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

### F16: Context Warning

**Trigger:** Context tokens > 75%
**Primitive:** Statusline context tracking

```
┌─────────────────────────────────────┐
│  ⚠️ CONTEXT WARNING                 │
├─────────────────────────────────────┤
│  Context usage at 85%               │
│                                     │
│  [████████████████░░░] 170K/200K    │
│                                     │
│  ┌─────────────────────────────────┐│
│  │      [Compact Now]              ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │      [Dismiss]                  ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/slash-commands

### F17: Quick Undo (Simplified Rewind)

**Trigger:** User wants to undo last change
**Primitive:** Checkpointing system (simplified)

```
┌─────────────────────────────────────┐
│  ↶ UNDO LAST CHANGE?                │
├─────────────────────────────────────┤
│  Revert changes to:                 │
│  • src/auth.ts (+15 -3)             │
│  • src/config.ts (+2 -1)            │
│                                     │
│  ┌─────────────────┐ ┌────────────┐ │
│  │     Cancel      │ │    Undo    │ │
│  └─────────────────┘ └────────────┘ │
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/checkpointing

### F18: Question Response

**Trigger:** Claude asks user a question via AskUserQuestion
**Primitive:** `AskUserQuestion` tool

```
┌─────────────────────────────────────┐
│  ❓ CLAUDE ASKS                     │
├─────────────────────────────────────┤
│  Which testing framework?           │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ● Jest (Recommended)            ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Vitest                        ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Mocha                         ││
│  └─────────────────────────────────┘│
│                                     │
│  [Other...] (dictate)               │
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/common-workflows

### F19: Sub-Agent Monitoring

**Trigger:** Task tool spawns sub-agent
**Primitive:** `Task` tool, sub-agents

```
┌─────────────────────────────────────┐
│  🔄 SUB-AGENT RUNNING               │
├─────────────────────────────────────┤
│  Type: explore                      │
│  Task: Research API patterns        │
│  Progress: 45%                      │
│                                     │
│  Parent: Main session               │
│                                     │
│  ┌─────────────────────────────────┐│
│  │         [Stop Agent]            ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/sub-agents

### F20: Todo Progress View

**Trigger:** TodoWrite tool active
**Primitive:** `TodoWrite` tool

```
┌─────────────────────────────────────┐
│  📋 CURRENT TASKS                   │
├─────────────────────────────────────┤
│  ✓ Initialize project               │
│  ✓ Set up database                  │
│  ● Creating user model...           │
│  ○ Add authentication               │
│  ○ Write tests                      │
│                                     │
│  2/5 complete                       │
└─────────────────────────────────────┘
```

**Note:** Read-only view, no editing from watch.

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

### F21: Background Task Alert

**Trigger:** User presses Ctrl+B on terminal
**Primitive:** Background task system

```
Notification:
┌─────────────────────────────────────┐
│  📋 Task Backgrounded               │
│  npm run build moved to background  │
│  Tap to view progress               │
└─────────────────────────────────────┘
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

---

## 8. Persona-Specific Requirements

### Alex (Mobile Developer) - Speed

| Need | Implementation | Target |
|------|----------------|--------|
| Fast approval | One-tap approve | < 2s |
| Bulk approve | "Approve All" | < 5s |
| No timeouts | Push notifications | 0/day |

### Jordan (Remote Worker) - Reliability

| Need | Implementation | Target |
|------|----------------|--------|
| Session resume | F15 flow | **NEW** |
| Cloud mode | Cloudflare relay | 99.9% |
| Progress visibility | Complication | < 60s latency |

### Sam (Power User) - Detail

| Need | Implementation | Target |
|------|----------------|--------|
| Context awareness | F16 warning | **NEW** |
| Question responses | F18 flow | **NEW** |
| Dangerous op detection | Red borders | 100% catch |

### Riley (iOS Companion) - Setup

| Need | Implementation | Target |
|------|----------------|--------|
| QR pairing | iOS camera scan | < 15s |
| Confidence building | Descriptive text | Clear |
| Error recovery | Guided flows | Step-by-step |

---

## 9. Complete Primitive Inventory

### Mapped to Watch ✅

| Primitive | Watch Feature |
|-----------|---------------|
| `y`/`n` approval | Approve/Reject buttons |
| `Shift+Tab` | Mode selector |
| `Ctrl+C` | Stop button |
| `Ctrl+B` | Automatic backgrounding |
| `/tasks` | Tasks view |
| `/status` | Complication |
| `/compact` | **NEW:** Quick command |
| `--resume` | **NEW:** Session resume (F15) |
| `AskUserQuestion` | **NEW:** Question card (F18) |
| `TodoWrite` | **NEW:** Progress view (F20) |
| `Task` | **NEW:** Sub-agent display (F19) |
| Context pressure | **NEW:** Warning flow (F16) |
| Checkpoints | **NEW:** Quick undo (F17) |

### Correctly Excluded ❌

| Primitive | Reason |
|-----------|--------|
| `/init`, `/config`, `/memory` | Filesystem/terminal |
| `/vim`, `/keybindings` | Input methods |
| `Tab` (thinking) | Verbose output |
| `/rewind` (full menu) | Complex UI |
| `--system-prompt` | Server config |
| `Ctrl+V` (paste image) | No camera |

---

## Appendix A: Quick Reference Card

```
╔════════════════════════════════════════════════════════════╗
║  CLAUDE WATCH V2.0 - COMPLETE REFERENCE                    ║
╠════════════════════════════════════════════════════════════╣
║  STATES                                                    ║
║    IDLE ──────── Ready                                     ║
║    RUNNING ───── Task executing                            ║
║    WAITING ───── Approval needed                           ║
║    QUESTION ──── Claude asked (NEW)                        ║
║    COMPACTING ── Context reducing (NEW)                    ║
║    RESUMING ──── Session restoring (NEW)                   ║
╠════════════════════════════════════════════════════════════╣
║  QUICK COMMANDS                                            ║
║    Go ─────────── Resume                                   ║
║    Test ───────── Run tests                                ║
║    Fix ────────── Auto-fix                                 ║
║    Stop ───────── Halt execution                           ║
║    Resume ─────── Continue session (NEW)                   ║
║    Compact ────── Reduce context (NEW)                     ║
╠════════════════════════════════════════════════════════════╣
║  NEW FLOWS (V2.0)                                          ║
║    F15 ───────── Session Resume                            ║
║    F16 ───────── Context Warning                           ║
║    F17 ───────── Quick Undo                                ║
║    F18 ───────── Question Response                         ║
║    F19 ───────── Sub-Agent Monitoring                      ║
║    F20 ───────── Todo Progress                             ║
║    F21 ───────── Background Alert                          ║
╚════════════════════════════════════════════════════════════╝
```

---

## Appendix B: Anthropic Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--anthropic-dark` | `#141413` | N/A (OLED black) |
| `--anthropic-light` | `#faf9f5` | Text |
| `--anthropic-orange` | `#d97757` | Primary accent |
| `--anthropic-blue` | `#6a9bcc` | Normal mode |
| `--anthropic-green` | `#788c5d` | Success, Plan mode |
| `--anthropic-mid-gray` | `#b0aea5` | Secondary text |

---

*Document V2.0 - Complete primitive coverage for Claude Watch. All citations verified against official Anthropic documentation as of January 2026.*
