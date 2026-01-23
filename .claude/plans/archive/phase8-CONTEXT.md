# Phase 8 Context: V2 Redesign + Full Flow Implementation

> Decisions captured: 2026-01-21
> Participants: dfotesco
> Source: `/v2/` documentation suite

## Executive Summary

Phase 8 transforms Claude Watch from a simple approval remote into a **full Claude Code companion** with support for questions, todos, sub-agents, session resume, context management, and quick undo. This is a significant UI/UX overhaul aligned with Anthropic brand guidelines.

---

## V1 vs V2 Comparison

### Current State (V1)

| Feature | Status | Notes |
|---------|--------|-------|
| Tool approval (Edit, Bash) | ✅ Done | Core functionality |
| Mode switching (Normal/Auto/Plan) | ✅ Done | Basic implementation |
| Push notifications | ✅ Done | APNs working |
| E2E encryption | ✅ Done | COMP3 complete |
| Session tracking | ✅ Done | COMP1 SessionStart hook |
| Watch complications | ✅ Done | Basic status |
| Voice commands | ✅ Done | Dictation |
| Quick commands (Go/Test/Fix/Stop) | ✅ Done | 4 commands |

### V2 Additions

| Feature | Flow | Priority | Complexity |
|---------|------|----------|------------|
| **Question Response** | F18 | P0 | Medium |
| **Todo Progress Display** | F20 | P2 | Low |
| **Sub-Agent Monitoring** | F19 | P2 | Medium |
| **Session Resume** | F15 | P0 | High |
| **Context Warning** | F16 | P1 | Medium |
| **Quick Undo** | F17 | P2 | Medium |
| **Background Task Alert** | F21 | P1 | Low |
| **Anthropic Brand Refresh** | - | P1 | Medium |
| **SF Symbols (no emojis)** | - | P1 | Low |

---

## New User Flows

### F15: Session Resume
**When:** User opens app with no active session
**Watch shows:** List of resumable sessions with context %
**User action:** Tap "Resume" on desired session
**Backend:** Server runs `claude --resume [id]`

### F16: Context Warning
**When:** Context tokens > 75% (warning), 85% (alert), 95% (critical)
**Watch shows:** Progress bar + "Compact Now" button
**User action:** Tap to trigger `/compact`
**Haptic:** .warning at 85%, .critical at 95%

### F17: Quick Undo
**When:** User wants to revert last change
**Watch shows:** Files affected + confirmation
**User action:** Tap "Undo" to rewind to latest checkpoint
**Limitation:** Only most recent checkpoint (full rewind = desktop)

### F18: Question Response
**When:** Claude uses `AskUserQuestion` tool
**Watch shows:** Question + options (2-4 choices)
**User action:** Tap option or use voice for "Other"
**Variants:** Single-select, multi-select

### F19: Sub-Agent Monitoring
**When:** Claude spawns sub-agent via `Task` tool
**Watch shows:** Nested display under main task
**User action:** View progress, stop agent
**Display:** Type (explore/bash/etc), progress %, current action

### F20: Todo Progress View
**When:** Claude uses `TodoWrite` tool
**Watch shows:** Read-only checklist with status
**States:** ✓ completed, ● in_progress, ○ pending
**Note:** No editing from watch

### F21: Background Task Alert
**When:** User presses Ctrl+B in terminal
**Watch shows:** Push notification
**User action:** View in Tasks list

---

## New Event Types (Server → Watch)

| Event | Trigger | Watch Handling |
|-------|---------|----------------|
| `QUESTION_ASKED` | AskUserQuestion tool | Show question card |
| `QUESTION_ANSWERED` | User selects option | Send to server |
| `TODO_UPDATE` | TodoWrite tool | Update progress view |
| `SUBAGENT_SPAWNED` | Task tool | Add to tasks list |
| `SUBAGENT_PROGRESS` | Agent makes progress | Update display |
| `SUBAGENT_COMPLETED` | Agent finishes | Show result |
| `SESSION_LIST` | App launch (no session) | Show resume list |
| `SESSION_RESUMED` | User resumes | Confirm + update |
| `CONTEXT_WARNING` | Threshold exceeded | Show alert |
| `BACKGROUND_TASK_CREATED` | Ctrl+B | Notification |
| `QUICK_UNDO_AVAILABLE` | Checkpoint created | Enable undo button |

---

## New UI Components

### Question Card
```
┌─────────────────────────────────────┐
│  [?] QUESTION                       │
├─────────────────────────────────────┤
│  Which testing framework?           │
│                                     │
│  ● Jest (Recommended)               │
│  ○ Vitest                           │
│  ○ Mocha                            │
│                                     │
│  [Other...] (voice)                 │
└─────────────────────────────────────┘
```

### Todo Progress Card
```
┌─────────────────────────────────────┐
│  [checklist] PROGRESS               │
├─────────────────────────────────────┤
│  ✓ Set up database                  │
│  ● Creating user model...           │
│  ○ Add authentication               │
│                                     │
│  1/3 complete                       │
└─────────────────────────────────────┘
```

### Context Warning Card
```
┌─────────────────────────────────────┐
│  [!] CONTEXT WARNING                │
├─────────────────────────────────────┤
│  Context usage at 85%               │
│  [████████████████░░░] 170K/200K    │
│                                     │
│  [Compact Now]  [Dismiss]           │
└─────────────────────────────────────┘
```

### Session Resume List
```
┌─────────────────────────────────────┐
│  [↻] RECENT SESSIONS                │
├─────────────────────────────────────┤
│  myproject/feature-auth             │
│  15 min ago • 72% context           │
│  [Resume]                           │
│                                     │
│  api-server/main                    │
│  2 hours ago • 45% context          │
│  [Resume]                           │
└─────────────────────────────────────┘
```

---

## Design System Updates

### Anthropic Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `--anthropic-dark` | `#141413` | Elevated backgrounds |
| `--anthropic-light` | `#faf9f5` | Primary text |
| `--anthropic-orange` | `#d97757` | CTAs, Auto mode, warnings |
| `--anthropic-blue` | `#6a9bcc` | Info, Normal mode, questions |
| `--anthropic-green` | `#788c5d` | Success, Plan mode, approve |
| `--anthropic-mid-gray` | `#b0aea5` | Secondary text |

### Mode Colors
- **Plan:** Green `#788c5d`
- **Normal:** Blue `#6a9bcc`
- **Auto-Accept:** Orange `#d97757`

### Typography
- **Headings:** Poppins Semibold
- **Body:** Lora Regular
- **Code:** SF Mono

### Icons
- **No emojis** - Use SF Symbols only
- All icons documented in `v2/claude_watch_design_screens_v2.md`

---

## Quick Commands (V2)

| Command | Icon | Action | NEW |
|---------|------|--------|-----|
| Go | `play.fill` | Resume | - |
| Test | `testtube.2` | Run tests | - |
| Fix | `wrench` | Fix errors | - |
| Stop | `stop.fill` | Interrupt | - |
| Resume | `arrow.counterclockwise` | `--continue` | ✓ |
| Compact | `arrow.down.circle` | `/compact` | ✓ |
| Undo | `arrow.uturn.backward` | Quick rewind | ✓ |

---

## Implementation Phases

### Phase 8A: Event Infrastructure (Foundation)
- [ ] Add new event types to WatchService.swift
- [ ] Update Cloudflare Worker to forward new events
- [ ] Update CLI hook to emit new events
- [ ] Test event flow end-to-end

### Phase 8B: Question Response (P0)
- [ ] Create QuestionView.swift component
- [ ] Add QUESTION_ASKED handler
- [ ] Implement option selection UI
- [ ] Add voice input for "Other"
- [ ] Send QUESTION_ANSWERED response

### Phase 8C: Session Resume (P0)
- [ ] Create SessionListView.swift
- [ ] Add SESSION_LIST handler
- [ ] Implement resume button action
- [ ] Update "no session" state UI

### Phase 8D: Context & Undo (P1)
- [ ] Create ContextWarningView.swift
- [ ] Add CONTEXT_WARNING handler
- [ ] Implement "Compact Now" action
- [ ] Create QuickUndoView.swift
- [ ] Add QUICK_UNDO_AVAILABLE handler

### Phase 8E: Todo & Sub-Agents (P2)
- [ ] Create TodoProgressView.swift
- [ ] Add TODO_UPDATE handler
- [ ] Create SubAgentRow.swift component
- [ ] Add SUBAGENT_* handlers
- [ ] Update Tasks view with nesting

### Phase 8F: Brand Refresh (P1)
- [ ] Update color constants to Anthropic palette
- [ ] Replace all emojis with SF Symbols
- [ ] Update typography to Poppins/Lora
- [ ] Apply to all existing views
- [ ] Test accessibility contrast

### Phase 8G: Quick Commands (P1)
- [ ] Add Resume command
- [ ] Add Compact command
- [ ] Add Undo command
- [ ] Update quick command grid (2x3 → 2x4?)

---

## Files Affected

### Watch App (SwiftUI)
- `WatchService.swift` - Add event handlers
- `MainView.swift` - Brand refresh, new navigation
- `QuestionView.swift` - NEW
- `TodoProgressView.swift` - NEW
- `SessionListView.swift` - NEW
- `ContextWarningView.swift` - NEW
- `QuickUndoView.swift` - NEW
- `SubAgentRow.swift` - NEW
- `TasksView.swift` - Update with nesting
- `QuickCommandsView.swift` - Add new commands
- `DesignSystem.swift` - NEW (centralize tokens)

### CLI (Node.js)
- `cc-watch.ts` - Emit new events
- Hook integration for AskUserQuestion, TodoWrite, Task tools

### Worker (Cloudflare)
- `index.ts` - Forward new event types

---

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| SwiftUI | watchOS 10+ | UI framework |
| CryptoKit | Native | E2E encryption (existing) |
| SF Symbols 5 | Xcode 15+ | Icons |

---

## Out of Scope (Phase 8)

- Todo editing from watch (read-only only)
- Full rewind menu (desktop only)
- Multi-watch support
- Analytics dashboard
- Monetization/paywall

---

## Success Criteria

- [ ] All 7 new flows (F15-F21) functional
- [ ] All new event types handled
- [ ] Brand colors applied consistently
- [ ] SF Symbols replace all emojis
- [ ] Question response works end-to-end
- [ ] Session resume works end-to-end
- [ ] Context warning triggers at thresholds
- [ ] Quick undo reverts last checkpoint
- [ ] No regressions in existing functionality

---

## Reference Documents

- `v2/claude_code_interaction_primitives_v2.md` - Complete primitive model
- `v2/claude_code_event_model_v2.json` - Event schema
- `v2/watch_remote_capability_map_v2.md` - Capability mapping
- `v2/watch_remote_figma_kit_requirements_v2.md` - Design tokens
- `v2/claude_watch_design_screens_v2.md` - Screen mockups

---

*Created by /discuss-phase skill*
