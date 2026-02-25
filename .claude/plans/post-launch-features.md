# Post-Launch Feature Plan

> **Status**: Approved plan for Workstream E expansion
> **Created**: 2026-02-25
> **Inputs**: 5 scoping agents + engineering lead + UX critic debate
> **Prerequisite**: TestFlight launch complete

---

## Executive Summary

Seven agents independently analyzed five proposed post-launch features. The engineering lead attacked feasibility; the UX critic attacked user value. They converged on the same priority order and killed two features entirely.

**Ship**: "Claude is Done" notification (F4), stall detection (F3 reframed), ApproveAll intent (F1 scoped)
**Kill**: Denial feedback sheet (F2), notification hook (F5 deferred)

---

## Phase 0: Hook Verification Sprint (half day)

> **Why first**: 4 unverified assumptions underpin 4 features. A half-day of testing produces go/no-go signals that could save a week of rework.

| Test | What to verify | Blocks |
|------|---------------|--------|
| `additionalContext` on deny | Does Claude Code's PreToolUse hook accept `additionalContext` in deny JSON? | F2 (killed, but validates deny path fix) |
| PostToolUse reliability | Does PostToolUse fire for every tool? What payload fields exist? | F3 (stall detection) |
| Stop vs TaskCompleted | Which hook fires when Claude finishes? What's the payload? | F4 ("Claude is Done") |
| Notification subtypes | What `type` values does the Notification hook emit? | F5 (deferred, but informs future) |

**Deliverable**: `hook-capabilities-verified.md` with go/no-go for each feature.

---

## Phase 1: Quick Wins (1 day)

### 1a. ApproveAll Siri Intent

> From F1 (Voice Control) — scoped to the only real gap.

- Add `ApproveAllRemmyIntent` to `RemmyShortcuts.swift` (~30 lines)
- Add tier safety gate to `ApproveRemmyIntent` — check `tier` before voice-approving dangerous tools (~10 lines)
- Existing voice infra (5 intents in `RemmyShortcuts.swift`) is already working; this fills the batch-approve gap

**Why**: Double-tap gesture already handles single approve. Voice is slower for single items. But "Hey Siri, approve all Remmy" for queued items has no equivalent.

### 1b. Fix Deny Path JSON

> From F2 analysis — not the reason picker UI, just structural correctness.

- Current deny path: bare `exit 2` with no structured output
- Fix to: proper JSON output (`{"decision": "deny"}`) matching the approve path's structure
- Enables future feedback if ever needed; costs 30 minutes

---

## Phase 2: APNs Infrastructure Port (half day)

> Prerequisite for F4. Also improves existing approval notification latency.

- Port `sendAPNs()` from legacy cloud worker (`MCPServer/server.py`) to current cloud worker
- The function already exists in legacy code; this is a port, not new development
- Immediately benefits existing approval-request notifications (currently polling-only from watch)
- Uses existing `deviceToken` stored during pairing

---

## Phase 3: "Claude is Done" — F4 (1-2 days)

> **Highest user impact feature.** Both reviewers ranked it #1.

**The problem**: After approving tools, users repeatedly raise their wrist to check "is Claude done yet?" This polling loop is the #1 UX friction after core approve/reject.

**The solution**: Push notification when Claude's task completes.

### Implementation

1. **Stop/TaskCompleted hook** (based on Phase 0 findings)
   - Hook script detects Claude completion
   - Sends signal to cloud worker endpoint

2. **Cloud worker endpoint** for completion signal
   - New `/session/{id}/completed` endpoint
   - Triggers APNs push to paired watch

3. **APNs push notification**
   - Distinct notification category (`TASK_COMPLETED`)
   - Completion haptic (not alert buzz) — different feel from approval requests
   - Shows task summary if available

4. **Watch notification handling**
   - New `UNNotificationCategory` registration
   - Updates `WorkingView` → completion state
   - Optional: "Start New Task" action button

### UX Decision
- Push notification, NOT polling-only. The UX critic's verdict: *"Ship it with APNs or don't ship it. Polling-only defeats the purpose."*

---

## Phase 4: Stall Detection — F3 Reframed (1 day)

> UX critic reframed F3 from "show every tool completion" to "detect when tools stop happening."

**Original proposal (killed)**: Per-tool-use ticker in WorkingView showing "Edited: auth.ts (5 sec ago)"

**Problems with original**:
- Creates staleness anxiety on a glance device
- Existing WorkingView (task checklist + progress bar + percentage) already answers "how far along?"
- Per-event updates are terminal-level information on a watch-level interface

**Reframed approach**: Stall detector

### Implementation

1. **PostToolUse hook** (if verified reliable in Phase 0) OR heartbeat approach
   - Track timestamp of last tool completion
   - Cloud worker maintains `lastToolActivity` per session

2. **Watch-side stall detection**
   - If no tool activity for 30+ seconds, show subtle "(stalled?)" indicator in WorkingView
   - If no activity for 60+ seconds, optional local notification

3. **Signal absence, not presence**
   - No UI changes during normal operation
   - Only fires when something appears wrong
   - High signal-to-noise ratio

---

## Killed Features

### F2: Denial Feedback Sheet — KILLED

**What**: After tapping Reject, show a sheet with reason options ("Too risky", "Wrong file", "Wrong approach", "Skip")

**Why killed** (UX critic):
- Current reject flow is ~500ms (tap → haptic → done). Sheet adds 1.5-4 seconds + second tap to 100% of rejections.
- If 90% tap Skip, the feature slows down everyone to serve 10%.
- The watch can communicate binary decisions well. It cannot communicate reasoning well.
- If Claude needs to know why, it should ask "why was this rejected?" in the **terminal**, not on a 44mm screen.

**If revisited**: Long-press on Reject → optional reason sheet. Never default path.

### F5: Notification Hook — DEFERRED

**What**: Hook into Claude Code's `Notification` event to detect permission errors, stalls, input waits.

**Why deferred**:
- Notification subtypes are unverified (Phase 0 prerequisite)
- Dedup with existing PreToolUse approval notifications is complex
- Notification fatigue risk: a bad session with cascading errors could push past the ~15-20/hr threshold where users disable all Remmy notifications, killing the core approval flow
- F4 (done notification) + stall detection cover the most important "Claude needs attention" cases

**If revisited**: Requires aggressive throttling (max 1 per type per 5 min), separate notification category (disableable independently), off by default.

---

## Updated Workstream E

| Task | Description | Status | Phase |
|------|-------------|--------|-------|
| E0 | Hook Verification Sprint | PENDING | 0 |
| E1 | ApproveAll Siri Intent + tier gate | PENDING | 1 |
| E1b | Fix deny path JSON | PENDING | 1 |
| E2 | APNs infrastructure port | PENDING | 2 |
| E3 | "Claude is Done" notification | PENDING | 3 |
| E4 | Stall detection | PENDING | 4 |
| ~~E5~~ | ~~Denial feedback sheet~~ | KILLED | — |
| ~~E6~~ | ~~Notification hook~~ | DEFERRED | — |

### Original E items (from MIGRATION_PROGRESS.md) — status unchanged
| Task | Description | Status |
|------|-------------|--------|
| E1-orig | Permission Learning ("Always Allow") | PENDING |
| E2-orig | Model Switching from Watch | PENDING |
| E3-orig | Real-Time Streaming | PENDING |
| E4-orig | Session Resume on Crash | PENDING |
| E5-orig | File Undo from Watch | PENDING |

---

## Estimated Total Effort

| Phase | Effort | Dependencies |
|-------|--------|-------------|
| Phase 0: Hook Verification | 0.5 day | Mac with Claude Code |
| Phase 1: Quick Wins | 1 day | Phase 0 results |
| Phase 2: APNs Port | 0.5 day | Legacy cloud worker access |
| Phase 3: Done Notification | 1-2 days | Phase 0 + Phase 2 |
| Phase 4: Stall Detection | 1 day | Phase 0 |
| **Total** | **4-5 days** | |

---

## Key Design Decisions

1. **Voice is not a primary interaction** — Double-tap gesture (Series 9+) is faster than Siri for single approvals. Voice only adds value for batch operations (ApproveAll).

2. **The watch is for decisions, not explanations** — Binary yes/no and simple selections. Reasoning belongs on the Mac keyboard.

3. **Signal absence, not presence** — Don't show every tool completion. Show when tools *stop* completing. High signal-to-noise on a glance device.

4. **Notifications are a privilege** — Each new notification type risks fatigue. F4 (done) is terminal (fires once). Everything else needs throttling or deferral.

5. **APNs is the backbone** — Polling-only features defeat the purpose of a wrist device. Port APNs first, then build on it.
