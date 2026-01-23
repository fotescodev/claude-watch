# Claude Code Watch Remote Capability Map V2.0

**Version:** 2.0
**Last Updated:** January 2026
**Purpose:** Define what Claude Watch does—not a terminal mirror, but a purpose-built control surface
**Product:** Claude Watch - watchOS Companion for Claude Code
**PRD Alignment:** v1.1
**Changelog:** Added flows F15-F21, persona integration, Anthropic brand alignment

---

## Executive Summary

Claude Watch transforms Claude Code's terminal workflow into a wrist-accessible experience optimized for **triage and decisive actions**. The desktop handles detailed work; the watch handles quick decisions and monitoring.

**V2.0 Additions:**
- 7 new user flows (F15-F21)
- Question Response capability (AskUserQuestion tool)
- Todo Progress display (TodoWrite tool)
- Sub-Agent monitoring (Task tool)
- Session Resume capability
- Context Warning alerts
- Persona-specific UX optimizations

---

## 1. Top 7 Wrist Jobs-to-be-Done

### Job #1: Approval Triage (F1, F4, F5, F6)
**"Unblock Claude without leaving my current activity"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| Approve/reject file edits | Single-tap decision | Alex |
| Approve/reject bash commands | Quick review | Sam |
| Batch approve similar requests | Clear backlog | Alex |
| Dangerous operation warnings | Safety check | Sam |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/security

### Job #2: Task Monitoring (F19, F20, F21)
**"Know if something is stuck or failed without checking my laptop"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| Running/background task count | Glance at complication | Jordan |
| Alert on task failure | Haptic notification | All |
| View last line of output | Quick health check | Sam |
| Stop runaway process | Emergency kill | All |
| **NEW:** Sub-agent progress | Nested task view | Sam |
| **NEW:** Todo progress | Read-only checklist | All |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

### Job #3: Mode Management (F7)
**"Quickly adjust Claude's autonomy level"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| Toggle Plan ↔ Normal ↔ Accept | One-tap mode switch | Alex |
| See current mode at a glance | Complication indicator | All |
| Mode switch confirmation | Safety for Auto-Accept | Sam |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

### Job #4: Context Awareness (F16) **NEW**
**"Know when Claude is running low on memory"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| Context usage percentage | Complication gauge | Jordan |
| **NEW:** Warning at 75%, 85%, 95% | Proactive haptic alert | Sam |
| **NEW:** One-tap compact | Trigger /compact | Sam |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/slash-commands

### Job #5: Session Presence (F15) **NEW**
**"Stay connected and resume work easily"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| Current working directory | Know which project | Jordan |
| Git branch indicator | Context for approvals | Sam |
| **NEW:** Session list | Available sessions | Jordan |
| **NEW:** Quick resume | One-tap continue | Jordan |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

### Job #6: Question Response (F18) **NEW**
**"Answer Claude's questions without returning to desk"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| **NEW:** View question | See what Claude asks | All |
| **NEW:** Select option | Tap to choose | All |
| **NEW:** Multi-select | Toggle multiple | Sam |
| **NEW:** Voice input | Dictate "Other" | Alex |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/common-workflows

### Job #7: Quick Undo (F17) **NEW**
**"Revert recent changes without full rewind menu"**

| What | Why Wrist | Persona |
|------|-----------|---------|
| **NEW:** Undo last change | Simplified rewind | Sam |
| **NEW:** Files preview | See what reverts | Sam |
| **NEW:** Confirmation | Safety check | All |

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/checkpointing

---

## 2. Watch vs. Desktop Responsibilities

### Watch Territory ✓

| Capability | Watch Responsibility | Rationale |
|------------|---------------------|-----------|
| **Binary decisions** | Approve/Reject | No nuance needed |
| **Question answers** | Option selection | **NEW** Simple choices |
| **Status at a glance** | Context %, mode, task count | Information density |
| **Emergency stops** | Kill task, cancel | Immediate action |
| **Mode toggles** | Plan/Normal/Accept | Quick adjustment |
| **Batch operations** | Approve all, reject all | Efficiency |
| **Todo viewing** | Read-only progress | **NEW** No editing |
| **Quick undo** | Latest checkpoint only | **NEW** Simplified |

### Desktop Territory ✗

| Capability | Desktop Responsibility | Rationale |
|------------|----------------------|-----------|
| **Diff review** | Full code comparison | Screen real estate |
| **Text input** | Prompts, instructions | Keyboard needed |
| **File navigation** | Browse, search, read | Complex interaction |
| **Configuration** | Settings, rules | Detailed forms |
| **Full rewind** | Checkpoint selection | Complex UI |
| **Todo editing** | Add/modify tasks | Requires input |

### Handoff Scenarios

| Scenario | Watch Action | Desktop Follow-up |
|----------|-------------|------------------|
| Complex diff | "View on Desktop" | Desktop shows diff |
| Failed task | "Escalate" | Full error display |
| Request change | Tap "Request Change" | Input alternative |
| Full question | "Answer on Desktop" | Text input |
| Full rewind | "Rewind on Desktop" | Checkpoint picker |

---

## 3. Complete User Flows

### Existing Flows (F1-F14)

| Flow | Name | Description |
|------|------|-------------|
| F1 | First Launch & Consent | Initial app setup |
| F2 | Cloud Pairing (Manual) | Enter 6-character code |
| F3 | Cloud Pairing (QR) | iOS camera scan |
| F4 | Single Action Approval | Approve one action |
| F5 | Bulk Approval | Approve multiple |
| F6 | Action Rejection | Reject with feedback |
| F7 | Mode Switching | Change permission mode |
| F8 | Voice Command | Dictate prompt |
| F9 | Quick Command | Go/Test/Fix/Stop |
| F10 | Settings Access | App configuration |
| F11 | Notification Approval | From push notification |
| F12 | Error Recovery | Handle connection issues |
| F13 | Demo Mode | Try without connection |
| F14 | Complication Interaction | Tap from watch face |

### New Flows (F15-F21) **V2.0**

#### F15: Session Resume

**Trigger:** User opens app with no active session
**Primitive:** `--continue` / `--resume` CLI flags
**Persona:** Jordan (reliability)

```
┌─────────────────────────────────────┐
│  ↻ RECENT SESSIONS                  │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ myproject/feature-auth          ││
│  │ 15 min ago • 72% context        ││
│  │ ┌─────────────────────────────┐ ││
│  │ │        [Resume]             │ ││
│  │ └─────────────────────────────┘ ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ api-server/main                 ││
│  │ 2 hours ago • 45% context       ││
│  │ ┌─────────────────────────────┐ ││
│  │ │        [Resume]             │ ││
│  │ └─────────────────────────────┘ ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Steps:
1. User opens Claude Watch app
2. App shows "No active session"
3. Displays list of resumable sessions
4. User taps "Resume" on desired session
5. Watch sends resume request to server
6. Server runs `claude --resume [id]`
7. Session restored, status updates

Haptic: .success on resume completion
Time: 5-10 seconds
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

#### F16: Context Warning

**Trigger:** Context tokens exceed 75% threshold
**Primitive:** Statusline JSON context tracking
**Persona:** Sam (detail)

```
┌─────────────────────────────────────┐
│  ⚠️ CONTEXT WARNING                 │
├─────────────────────────────────────┤
│                                     │
│  Context usage at 85%               │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ████████████████░░░ 170K/200K   ││
│  └─────────────────────────────────┘│
│                                     │
│  Compaction recommended.            │
│  Save ~50K tokens.                  │
│                                     │
│  ┌─────────────────────────────────┐│
│  │        [Compact Now]            ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │        [Dismiss]                ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Thresholds:
- 75%: Yellow indicator, no alert
- 85%: Amber notification, haptic
- 95%: Red alert, strong haptic

Steps:
1. Statusline reports 85% context usage
2. Watch receives CONTEXT_WARNING event
3. Notification with haptic alert
4. User sees warning card
5. User taps "Compact Now"
6. Watch sends compact request
7. Server runs `/compact`
8. Completion notification shows savings

Haptic: .warning at 85%, .critical at 95%
Time: 3-5 seconds for action
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/slash-commands

#### F17: Quick Undo

**Trigger:** User wants to revert last change
**Primitive:** Checkpointing system (simplified)
**Persona:** Sam (detail)

```
┌─────────────────────────────────────┐
│  ↶ UNDO LAST CHANGE?                │
├─────────────────────────────────────┤
│                                     │
│  Revert changes to:                 │
│                                     │
│  • src/auth.ts (+15 -3)             │
│  • src/config.ts (+2 -1)            │
│                                     │
│  This will restore files to         │
│  their state before the last edit.  │
│                                     │
│  ┌─────────────┐ ┌────────────────┐ │
│  │   Cancel    │ │     Undo       │ │
│  └─────────────┘ └────────────────┘ │
└─────────────────────────────────────┘

Steps:
1. User accesses Quick Undo (quick command or gesture)
2. Watch shows last checkpoint summary
3. Files affected listed with change stats
4. User taps "Undo" to confirm
5. Watch sends rewind request
6. Server restores checkpoint
7. Confirmation with haptic

Limitation: Only reverts to MOST RECENT checkpoint.
Full rewind menu requires desktop.

Haptic: .success on undo completion
Time: 2-5 seconds
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/checkpointing

#### F18: Question Response

**Trigger:** Claude asks question via AskUserQuestion tool
**Primitive:** `AskUserQuestion` tool
**Persona:** All (critical path)

```
┌─────────────────────────────────────┐
│  ❓ CLAUDE ASKS                     │
├─────────────────────────────────────┤
│                                     │
│  Which testing framework?           │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ ● Jest (Recommended)            ││
│  │   Standard for React projects   ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Vitest                        ││
│  │   Fast, Vite-native             ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ○ Mocha                         ││
│  │   Flexible, configurable        ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │     [Other...] (dictate)        ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Single Select:
1. Notification: "Claude has a question"
2. User opens question card
3. Options displayed with descriptions
4. User taps to select option
5. Selection sent to Claude Code
6. Claude continues with answer

Multi-Select (when multiSelect: true):
1. Options show checkboxes instead of radio
2. User toggles multiple options
3. "Submit" button to confirm all selections

Other Input:
1. User taps "Other..."
2. Voice input UI appears
3. User dictates custom answer
4. Transcription sent as "Other" response

Haptic: .notification on question arrival
Time: 5-15 seconds depending on complexity
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/common-workflows

#### F19: Sub-Agent Monitoring

**Trigger:** Claude spawns sub-agent via Task tool
**Primitive:** `Task` tool, sub-agents
**Persona:** Sam (detail)

```
┌─────────────────────────────────────┐
│  🔄 TASKS (2)                       │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 🟢 Main Session                 ││
│  │ Building auth system            ││
│  │                                 ││
│  │   └─ 🔵 explore (45%)          ││
│  │      Research OAuth patterns    ││
│  │                                 ││
│  │   └─ 🔵 Bash                   ││
│  │      npm install                ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Sub-Agent Detail View:
┌─────────────────────────────────────┐
│  ← explore agent                    │
├─────────────────────────────────────┤
│                                     │
│  Type: Explore                      │
│  Task: Research OAuth patterns      │
│  Status: 🔵 Running (45%)           │
│  Parent: Main Session               │
│                                     │
│  Current Action:                    │
│  Reading auth.middleware.ts         │
│                                     │
│  ┌─────────────────────────────────┐│
│  │         [Stop Agent]            ││
│  └─────────────────────────────────┘│
└─────────────────────────────────────┘

Steps:
1. Claude spawns sub-agent
2. Watch receives SUBAGENT_SPAWNED event
3. Sub-agent appears nested under main task
4. Progress updates via SUBAGENT_PROGRESS
5. User can tap to view details
6. Stop button available for each agent
7. Completion shown with result summary

Haptic: .subtle on spawn, .success on completion
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/sub-agents

#### F20: Todo Progress View

**Trigger:** Claude uses TodoWrite tool
**Primitive:** `TodoWrite` tool
**Persona:** All

```
┌─────────────────────────────────────┐
│  📋 PROGRESS                        │
├─────────────────────────────────────┤
│                                     │
│  ✓ Initialize project               │
│  ✓ Set up database                  │
│  ● Creating user model...           │
│  ○ Add authentication               │
│  ○ Write tests                      │
│                                     │
│  ────────────────────────────────   │
│  2/5 complete                       │
│                                     │
└─────────────────────────────────────┘

States:
- ✓ completed (gray text)
- ● in_progress (highlighted, animated)
- ○ pending (dimmed)

Steps:
1. Claude uses TodoWrite to set tasks
2. Watch receives TODO_UPDATE event
3. Progress view accessible from status
4. Current in_progress task highlighted
5. Completion count shown at bottom

Note: READ-ONLY on watch.
Editing requires desktop terminal.

Haptic: .subtle on status change
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/cli-reference

#### F21: Background Task Alert

**Trigger:** User presses Ctrl+B on terminal
**Primitive:** Background task system
**Persona:** Jordan (reliability)

```
Push Notification:
┌─────────────────────────────────────┐
│  📋 Task Backgrounded               │
│                                     │
│  npm run build moved to background  │
│                                     │
│  [View]              [Dismiss]      │
└─────────────────────────────────────┘

Steps:
1. User presses Ctrl+B in terminal
2. Task moves to background with unique ID
3. Watch receives BACKGROUND_TASK_CREATED event
4. Notification alerts user
5. Task appears in Tasks view
6. Progress continues updating

Haptic: .notification
Time: Immediate notification
```

**Citation:** [OFFICIAL] https://code.claude.com/docs/en/interactive-mode

---

## 4. Approval Inbox UX

### Inbox Structure

```
┌─────────────────────────────────────┐
│  📥 APPROVALS (3)                   │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 📝 Edit: auth.ts                ││
│  │ +12 -3 lines • 2 hunks          ││
│  │ [Approve] [Reject]              ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ⚡ Bash: npm run test           ││
│  │ in /src • Low risk              ││
│  │ [Approve] [Reject]              ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ ❓ Question: Database           ││
│  │ Which database to use?          ││
│  │ [Answer]                        ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  [Approve All Edits]                │
└─────────────────────────────────────┘
```

### Card Types

| Type | Icon | Color (Anthropic) | Actions |
|------|------|-------------------|---------|
| Edit | 📝 | Orange (#d97757) | Approve, Reject |
| Create | 📄 | Blue (#6a9bcc) | Approve, Reject |
| Delete | 🗑️ | Red (#FF3B30) | Approve, Reject (warning) |
| Bash | ⚡ | Purple (#AF52DE) | Approve, Reject |
| Question | ❓ | Blue (#6a9bcc) | Answer |

### Diff Summary Format

```
DIFF SUMMARY (3-5 lines max):
1. HEADER: "{Action}: {filename}"
2. STATS: "+{added} -{removed} lines • {hunks} hunk(s)"
3-5. PREVIEW: Key changes (truncated)
```

---

## 5. Mode Toggle UX

### Mode Selector

```
┌─────────────────────────────────────┐
│  ⚙️ PERMISSION MODE                 │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────────┐│
│  │  📖  PLAN                       ││
│  │      Claude analyzes only       ││
│  │      Color: Green (#788c5d)     ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │  🛡️  NORMAL  ●                  ││
│  │      Ask before each action     ││
│  │      Color: Blue (#6a9bcc)      ││
│  └─────────────────────────────────┘│
│                                     │
│  ┌─────────────────────────────────┐│
│  │  ⚡  AUTO-ACCEPT                ││
│  │      Auto-approve file edits    ││
│  │      Color: Orange (#d97757)    ││
│  └─────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### Quick Toggle (Complication Tap)

```
Cycle: Plan → Normal → Auto-Accept → Plan
Mirrors: Shift+Tab on desktop
```

### Auto-Accept Warning

```
┌─────────────────────────────────────┐
│  ⚠️ Enable Auto-Accept?             │
├─────────────────────────────────────┤
│                                     │
│  Claude will automatically          │
│  approve all file edits.            │
│                                     │
│  Bash commands still require        │
│  your approval.                     │
│                                     │
│  ┌─────────────┐ ┌────────────────┐ │
│  │   Cancel    │ │    Enable      │ │
│  └─────────────┘ └────────────────┘ │
└─────────────────────────────────────┘
```

---

## 6. Status Glance UX

### Complication Layouts

**Circular Small:**
```
┌───────┐
│  ⚡   │  <- Mode icon
│  3    │  <- Pending count
└───────┘
```

**Modular Small:**
```
┌─────────────┐
│ CC │ 🟢 85% │
│ 3 pending   │
└─────────────┘
```

**Modular Large:**
```
┌─────────────────────────────────┐
│  Claude Code          🟢 85%   │
│  Normal Mode • /myproject      │
│  3 pending • 1 question        │
└─────────────────────────────────┘
```

### Full Glance View

```
┌─────────────────────────────────────┐
│  CLAUDE CODE                        │
├─────────────────────────────────────┤
│  🟢 Connected                       │
│                                     │
│  Model: Claude Sonnet 4             │
│  Mode:  Normal (Blue)               │
│                                     │
│  Project: /Users/dev/myapp          │
│  Branch:  feature/auth (dirty)      │
│                                     │
│  ─── Context ───                    │
│  [████████████░░░░░] 72%            │
│  144,000 / 200,000 tokens           │
│                                     │
│  ─── Activity ───                   │
│  📥 3 pending approvals             │
│  ❓ 1 pending question              │
│  🔄 2 tasks running                 │
│  📋 3/5 todos complete              │
│                                     │
├─────────────────────────────────────┤
│  [Inbox]  [Tasks]  [Mode]           │
└─────────────────────────────────────┘
```

---

## 7. Quick Commands

### V2.0 Command Grid

| Command | Icon | Sends | NEW |
|---------|------|-------|-----|
| Go | `play.fill` | Resume | - |
| Test | `bolt.fill` | "Run tests" | - |
| Fix | `wrench.fill` | "Fix errors" | - |
| Stop | `stop.fill` | Interrupt | - |
| Resume | `arrow.counterclockwise` | `--continue` | ✓ |
| Compact | `arrow.down.circle` | `/compact` | ✓ |
| Undo | `arrow.uturn.backward` | Quick rewind | ✓ |

### Voice Input

Available for:
- Custom prompts
- "Other" answers to questions
- Quick commands by name

---

## 8. Capability Enhancements (V2.0)

### Enhancement #1: Smart Approval Batching
Group similar requests for batch action.

### Enhancement #2: Proactive Context Alerts **NEW**
Warn at 75%, 85%, 95% thresholds.

### Enhancement #3: Task Health Heartbeat
Alert if tasks stalled > 2 minutes.

### Enhancement #4: Approval Timeout Escalation
Stronger haptic after 60s without response.

### Enhancement #5: Quick Reply Templates
"Add tests", "Add comments", "Simplify"

### Enhancement #6: Session Resume **NEW**
One-tap continue from watch.

### Enhancement #7: Emergency Kill All
Long-press to stop all tasks.

### Enhancement #8: Question Response **NEW**
Answer Claude's questions from wrist.

### Enhancement #9: Git-Aware Context
Show branch in approval cards.

### Enhancement #10: Mode Recommendation
Suggest Auto-Accept after 5+ approvals.

### Enhancement #11: Quick Undo **NEW**
Simplified rewind to latest checkpoint.

### Enhancement #12: Sub-Agent Awareness **NEW**
Nested display of spawned agents.

### Enhancement #13: Todo Progress **NEW**
Read-only task completion view.

### Enhancement #14: Background Task Alerts **NEW**
Notification when tasks backgrounded.

---

## 9. Persona-Specific Optimizations

### Alex (Mobile Developer) - Speed

| Optimization | Implementation |
|--------------|----------------|
| Fast approval | One-tap, < 2s |
| Bulk approve | "Approve All" prominent |
| Voice commands | Quick access |
| Notification actions | Approve from lock screen |

### Jordan (Remote Worker) - Reliability

| Optimization | Implementation |
|--------------|----------------|
| Session resume | F15 flow, prominent |
| Cloud mode | Reliable connection |
| Background alerts | F21 notifications |
| Progress visibility | Accurate complication |

### Sam (Power User) - Detail

| Optimization | Implementation |
|--------------|----------------|
| Context warnings | F16 proactive alerts |
| Sub-agent monitoring | F19 nested view |
| Quick undo | F17 simplified rewind |
| Question detail | Full option descriptions |

### Riley (iOS Companion) - Setup

| Optimization | Implementation |
|--------------|----------------|
| QR pairing | < 15 seconds |
| Demo mode | Try without connection |
| Clear errors | Step-by-step recovery |
| Descriptive cards | Explain what actions do |

---

## 10. Connection Architecture

### Message Types (V2.0)

| Type | Direction | Purpose | NEW |
|------|-----------|---------|-----|
| `state_sync` | Server → Watch | Full state | - |
| `action_requested` | Server → Watch | Approval needed | - |
| `action_response` | Watch → Server | User decision | - |
| `progress_update` | Server → Watch | Task progress | - |
| `mode_changed` | Bidirectional | Mode update | - |
| `question_asked` | Server → Watch | Question | ✓ |
| `question_answered` | Watch → Server | Answer | ✓ |
| `todo_update` | Server → Watch | Todo change | ✓ |
| `session_list` | Server → Watch | Sessions | ✓ |
| `resume_session` | Watch → Server | Resume | ✓ |
| `context_warning` | Server → Watch | Alert | ✓ |
| `subagent_update` | Server → Watch | Agent progress | ✓ |

### Offline Behavior

| Scenario | Watch Behavior | Recovery |
|----------|---------------|----------|
| Bluetooth lost | "Reconnecting..." | Auto-reconnect |
| Desktop sleeping | "Desktop Sleeping" | Wake on activity |
| No session | "No Active Session" | Show session list |
| Network issues | Queue actions locally | Sync on reconnect |

---

## Appendix A: Flow Summary Table

| Flow | Name | Primitive | Priority |
|------|------|-----------|----------|
| F1 | First Launch | - | P0 |
| F2 | Manual Pairing | - | P0 |
| F3 | QR Pairing | - | P0 |
| F4 | Single Approval | Permission | P0 |
| F5 | Bulk Approval | Permission | P0 |
| F6 | Rejection | Permission | P0 |
| F7 | Mode Switch | Shift+Tab | P0 |
| F8 | Voice Command | - | P1 |
| F9 | Quick Command | - | P1 |
| F10 | Settings | - | P2 |
| F11 | Notification | Push | P0 |
| F12 | Error Recovery | - | P1 |
| F13 | Demo Mode | - | P2 |
| F14 | Complication | - | P1 |
| **F15** | **Session Resume** | `--resume` | **P0** |
| **F16** | **Context Warning** | `/compact` | **P1** |
| **F17** | **Quick Undo** | Checkpoint | **P2** |
| **F18** | **Question Response** | `AskUserQuestion` | **P0** |
| **F19** | **Sub-Agent Monitor** | `Task` | **P2** |
| **F20** | **Todo Progress** | `TodoWrite` | **P2** |
| **F21** | **Background Alert** | `Ctrl+B` | **P1** |

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

*Document V2.0 - Complete capability map for Claude Watch with all user flows. PRD alignment verified.*
