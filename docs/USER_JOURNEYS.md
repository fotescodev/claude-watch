# Remmy: User Journey Documentation

> **Version**: 1.0
> **Last Updated**: January 2026
> **Platform**: watchOS 10+
> **Purpose**: Wearable approval interface for Claude Code CLI

---

## Executive Summary

Remmy enables developers to approve or reject Claude Code's tool use requests directly from their Apple Watch. This document outlines the complete user journey from pairing through daily use, with design rationale for each interaction.

---

## 1. Pairing Flow

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PAIRING FLOW                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   WATCH                              MAC CLI                                │
│   ─────                              ───────                                │
│                                                                             │
│   ┌───────────────┐                                                         │
│   │  Not Paired   │                                                         │
│   │               │                                                         │
│   │  [Pair with   │                                                         │
│   │    Code]      │◄─── User taps                                           │
│   │               │                                                         │
│   │  [Try Demo]   │                                                         │
│   └───────────────┘                                                         │
│          │                                                                  │
│          ▼                                                                  │
│   ┌───────────────┐                                                         │
│   │  Preparing... │◄─── APNs token being registered                         │
│   │      ⟳        │                                                         │
│   └───────────────┘                                                         │
│          │                                                                  │
│          ▼                                                                  │
│   ┌───────────────┐                  ┌───────────────┐                      │
│   │  Pairing Code │                  │               │                      │
│   │               │                  │  $ npx remmy-cli│                    │
│   │   ABC-123     │ ──────────────►  │               │                      │
│   │               │   User reads     │  Enter code:  │                      │
│   │  Waiting...   │   code aloud     │  > ABC-123    │◄─── User types       │
│   └───────────────┘                  └───────────────┘                      │
│          │                                  │                               │
│          │◄─────────────────────────────────┘                               │
│          │         Cloud validates pairing                                  │
│          ▼                                                                  │
│   ┌───────────────┐                  ┌───────────────┐                      │
│   │   Connected   │                  │   Paired!     │                      │
│   │      ●        │◄────────────────►│   Session     │                      │
│   │   Listening...│                  │   active      │                      │
│   └───────────────┘                  └───────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### State Descriptions

| State | Watch Display | Duration | Exit Condition |
|-------|--------------|----------|----------------|
| Not Paired | "Pair with Code" button | Persistent | User taps button |
| Preparing | Spinner, "Preparing..." | 1-3 seconds | APNs token ready |
| Pairing Code | 6-character code (ABC-123) | 5 minutes | Code entered or expires |
| Connected | "Listening..." with progress UI | Session duration | User ends session |

### Design Decisions

**Q: Why does the watch show the code instead of the CLI?**
A: The watch is the "secure display" - showing the code on a device physically attached to the user prevents shoulder-surfing attacks. The CLI is on a potentially shared screen.

**Q: Why "Preparing..." before showing the code?**
A: APNs token registration must complete before pairing succeeds. Showing "Preparing..." prevents users from entering a code before the watch can receive push notifications.

**Q: What happens if pairing fails?**
A: The watch shows an error message with retry option. Common failures: network unavailable, code expired, code already used.

**Note**: The CLI was originally named `cc-watch`, now renamed to `remmy-cli`.

---

## 2. Idle/Connected State

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CONNECTED - IDLE STATE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────┐                                       │
│   │ ● Connected              [⚙️]   │◄─── Status bar: connection + settings │
│   │                                 │                                       │
│   │  ┌───────────────────────────┐  │                                       │
│   │  │ ● Listening...           │  │◄─── Dimmed dot (not pulsing)          │
│   │  │                          │  │                                       │
│   │  │ Activity will appear here│  │◄─── Placeholder text                  │
│   │  │                          │  │                                       │
│   │  │ ━━━━━━━━━━━━━━━━━━━━━━━━│  │◄─── Empty progress bar                │
│   │  │ 0%                   0/0 │  │                                       │
│   │  └───────────────────────────┘  │                                       │
│   │                                 │                                       │
│   │         ┌─────────┐             │                                       │
│   │         │ NORMAL  │ ►           │◄─── Mode selector                     │
│   │         └─────────┘             │                                       │
│   │                                 │                                       │
│   │          74fcd473               │◄─── Pairing ID (debug)                │
│   └─────────────────────────────────┘                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design Decisions

**Q: Why show an empty progress bar instead of "Ready"?**
A: The progress-ready layout creates visual continuity. When Claude starts working, the same UI elements animate into the active state rather than a jarring layout change.

**Q: What are the approval modes?**
A: Three modes available via the mode selector:
- **Normal**: Each action requires explicit approval
- **Auto-Accept**: Automatically approves all actions (haptic confirmation only)
- **Voice**: Enables voice command input

**Q: Why show the pairing ID?**
A: Debug purposes only. Helps support identify connection issues. Shown in small, tertiary text to avoid distraction.

---

## 3. Active Session (Claude Working)

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ACTIVE SESSION - WORKING                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────┐                                       │
│   │ ● Connected              [⚙️]   │                                       │
│   │                                 │                                       │
│   │  ┌───────────────────────────┐  │                                       │
│   │  │ ● Fixing auth bug...     │  │◄─── Orange pulsing dot + activity     │
│   │  │                          │  │                                       │
│   │  │ ✓ Research existing code │  │◄─── Completed task (dimmed)           │
│   │  │ ● Update auth service    │  │◄─── In-progress task (orange)         │
│   │  │ ○ Add unit tests         │  │◄─── Pending task                      │
│   │  │                          │  │                                       │
│   │  │ ━━━━━━━━━━━━━━━━━━░░░░░░│  │◄─── Progress bar (orange)             │
│   │  │ 33%                  1/3 │  │                                       │
│   │  │                          │  │                                       │
│   │  │         [ ⏸ ]            │  │◄─── Pause button (red)                │
│   │  └───────────────────────────┘  │                                       │
│   │                                 │                                       │
│   │            ● Working            │◄─── Status indicator                  │
│   │                                 │                                       │
│   │         ┌─────────┐             │                                       │
│   │         │ NORMAL  │ ►           │                                       │
│   │         └─────────┘             │                                       │
│   └─────────────────────────────────┘                                       │
│                                                                             │
│   DATA SOURCE: TodoWrite hook captures Claude's task list in real-time      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Task Status Icons

| Icon | Status | Color | Description |
|------|--------|-------|-------------|
| ✓ | Completed | Green (dimmed text) | Task finished successfully |
| ● | In Progress | Orange | Currently being worked on |
| ○ | Pending | Primary text | Queued for execution |

### Design Decisions

**Q: How does the watch know what Claude is doing?**
A: A `TodoWrite` hook in Claude Code sends task updates via push notification to the cloud, which the watch polls every 3 seconds (with APNs as primary delivery).

**Q: Why limit to 3 visible tasks?**
A: Watch screen real estate. Showing "+2 more" preserves context without scrolling. Users can see full list on their Mac.

**Q: What does the pause button do?**
A: Sends an interrupt signal to Claude Code, pausing execution. Useful when user spots an issue and wants to intervene before Claude continues.

---

## 4. Approval Request Flow

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        APPROVAL REQUEST FLOW                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   BACKGROUND (watch not active)          FOREGROUND (app open)              │
│   ─────────────────────────────          ─────────────────────              │
│                                                                             │
│   ┌───────────────────────────┐          ┌───────────────────────────┐      │
│   │ ┌─────────────────────┐   │          │ ● Connected        [⚙️]   │      │
│   │ │ 🟣 Claude           │   │          │                           │      │
│   │ │ Edit: src/auth.ts   │   │          │  ┌─────────────────────┐  │      │
│   │ │                     │   │          │  │ 🟣 Edit: auth.ts    │  │      │
│   │ │ [Approve] [Reject]  │   │          │  │                     │  │      │
│   │ └─────────────────────┘   │          │  │  ┌─────┐  ┌─────┐   │  │      │
│   │                           │          │  │  │  ✗  │  │  ✓  │   │  │      │
│   │   ▲                       │          │  │  │ RED │  │GREEN│   │  │      │
│   │   │ Push notification     │          │  │  └─────┘  └─────┘   │  │      │
│   │   │ with actions          │          │  └─────────────────────┘  │      │
│   └───────────────────────────┘          │                           │      │
│                                          │   ▲                       │      │
│                                          │   │ Inline UI update      │      │
│                                          │   │ (NO banner)           │      │
│                                          └───────────────────────────┘      │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        AFTER USER ACTION                            │   │
│   ├─────────────────────────────────────────────────────────────────────┤   │
│   │                                                                     │   │
│   │   User taps APPROVE              User taps REJECT                   │   │
│   │   ───────────────────            ────────────────                   │   │
│   │                                                                     │   │
│   │   ┌─────────────────┐            ┌─────────────────┐                │   │
│   │   │ ✓ Approved      │            │ ✗ Rejected      │                │   │
│   │   │                 │            │                 │                │   │
│   │   │ [Haptic: ✓]     │            │ [Haptic: ✗]     │                │   │
│   │   └─────────────────┘            └─────────────────┘                │   │
│   │          │                              │                           │   │
│   │          ▼                              ▼                           │   │
│   │   Claude proceeds              Claude shows rejection               │   │
│   │   with action                  message, awaits input                │   │
│   │                                                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Approval Card Details

```
┌─────────────────────────────────────┐
│  ┌───┐                              │
│  │ 🟣 │  Edit: src/auth.ts          │◄─── Tool type icon + title
│  └───┘                              │
│                                     │
│  Adding JWT validation              │◄─── Description (optional)
│  to login endpoint                  │
│                                     │
│  ┌───────────┐    ┌───────────┐     │
│  │     ✗     │    │     ✓     │     │◄─── Large touch targets
│  │   REJECT  │    │  APPROVE  │     │     (44pt minimum)
│  │    RED    │    │   GREEN   │     │
│  └───────────┘    └───────────┘     │
│                                     │
└─────────────────────────────────────┘
```

### Tool Type Icons

| Tool | Icon | Color | Example Title |
|------|------|-------|---------------|
| Edit | 📝 | Purple | "Edit: src/auth.ts" |
| Write | 📄 | Blue | "Write: config.json" |
| Bash | 💻 | Orange | "Run: npm install" |
| Read | 👁 | Gray | "Read: package.json" |

### Design Decisions

**Q: Why no notification banner when app is in foreground?**
A: Redundant UX. The user is already looking at the app - showing a banner that overlays the same content creates visual noise. The approval appears inline instead.

**Q: Why are the buttons so large?**
A: Apple HIG recommends 44pt minimum touch targets. On a watch, motor precision is lower, and glancing interactions need high confidence.

**Q: What happens if multiple approvals queue up?**
A: They stack. The watch shows the oldest first with a badge count. User processes them sequentially - this prevents accidental bulk approvals.

**Q: Can users see the full file diff?**
A: Not on watch (screen limitation). The description provides context. For detailed review, user can check their Mac. The watch is for quick approve/reject decisions.

---

## 5. Completion State

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COMPLETION STATE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   DURING WORK                            100% COMPLETE                      │
│   ───────────                            ─────────────                      │
│                                                                             │
│   ┌───────────────────────────┐          ┌───────────────────────────┐      │
│   │ ● Fixing auth bug...      │          │ ● Complete               │      │
│   │   (orange, pulsing)       │    ──►   │   (green, solid)          │      │
│   │                           │          │                           │      │
│   │ ━━━━━━━━━━━━━━━░░░░░░░░░│          │ ━━━━━━━━━━━━━━━━━━━━━━━━━│      │
│   │ 66%                   2/3 │          │ 100%                  3/3 │      │
│   │      (orange bar)         │          │      (green bar)          │      │
│   │                           │          │                           │      │
│   │         ● Working         │          │         ● Complete        │      │
│   │         (orange)          │          │         (green)           │      │
│   └───────────────────────────┘          └───────────────────────────┘      │
│                                                                             │
│   VISUAL CHANGES AT COMPLETION:                                             │
│   ─────────────────────────────                                             │
│   • Header: "Working..." → "Complete" (green text)                          │
│   • Dot: Orange pulsing → Green solid                                       │
│   • Progress bar: Orange → Green                                            │
│   • Status: "Working" → "Complete" (green)                                  │
│   • All task icons show ✓ (completed)                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design Decisions

**Q: Why turn everything green at 100%?**
A: Clear visual signal of completion. The color change is noticeable at a glance - users don't need to read text to know Claude finished.

**Q: What happens after completion?**
A: Currently: The view persists for ~3 seconds showing "Complete", then fades to the "Listening..." idle state.

**Q: Should there be a completion sound/haptic?**
A: Currently no automatic haptic at completion. Consideration: subtle success haptic when transitioning to complete state.

### Known Gap: Missing Outcome/Closure

> **See Section 11: Task Outcome Display (PLANNED)**

The current completion state shows *that* tasks finished but not *what* was accomplished. Users see "Complete" but don't see Claude's summary ("Success - fixed the authentication bug by updating JWT validation...").

This creates a **closure gap** - users approved actions and saw progress, but never see confirmation of the result. The planned Task Outcome feature addresses this by showing Claude's summary before returning to the listening state.

---

## 6. Session Interruption

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SESSION INTERRUPTION                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ACTIVE SESSION                   USER TAPS PAUSE                          │
│   ──────────────                   ───────────────                          │
│                                                                             │
│   ┌───────────────────────────┐    ┌───────────────────────────┐            │
│   │ ● Working on feature...   │    │ ● Paused                  │            │
│   │                           │    │                           │            │
│   │ ━━━━━━━━━━━━━━━░░░░░░░░░│    │ ━━━━━━━━━━━━━━━░░░░░░░░░│            │
│   │ 50%                   1/2 │    │ 50%                   1/2 │            │
│   │                           │    │                           │            │
│   │         ┌─────┐           │    │         ┌─────┐           │            │
│   │         │ ⏸  │           │    │         │ ▶  │           │            │
│   │         │ RED │  ─────────┼───►│         │GREEN│           │            │
│   │         └─────┘           │    │         └─────┘           │            │
│   │                           │    │                           │            │
│   │         ● Working         │    │         ● Paused          │            │
│   └───────────────────────────┘    └───────────────────────────┘            │
│                                                                             │
│   BUTTON STATES:                                                            │
│   ──────────────                                                            │
│                                                                             │
│   ┌─────────┐         ┌─────────┐                                           │
│   │   ⏸    │         │   ▶    │                                           │
│   │  PAUSE  │ ◄─────► │ RESUME  │                                           │
│   │   RED   │         │  GREEN  │                                           │
│   └─────────┘         └─────────┘                                           │
│   (when running)      (when paused)                                         │
│                                                                             │
│   MAC CLI BEHAVIOR:                                                         │
│   ─────────────────                                                         │
│   When paused, Claude Code shows:                                           │
│   "⏸️  Session paused from watch. Tap Resume on watch to continue."         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design Decisions

**Q: Why a single toggle button instead of separate Stop/Resume?**
A: Screen space. A single contextual button is clearer and prevents accidental double-taps.

**Q: What happens to queued approvals when paused?**
A: They remain in queue. Pausing stops Claude from requesting NEW approvals, but existing requests can still be processed.

**Q: Can the user end the session entirely from the watch?**
A: Yes, via Settings (gear icon). "End Session" disconnects the watch and terminates the remmy-cli session.

---

## 7. Connection States

### State Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONNECTION STATES                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌─────────────┐                                      │
│                        │ Disconnected│                                      │
│                        │     ●       │                                      │
│                        │    RED      │                                      │
│                        └──────┬──────┘                                      │
│                               │                                             │
│                               │ User initiates pairing                      │
│                               ▼                                             │
│                        ┌─────────────┐                                      │
│                        │ Connecting  │                                      │
│                        │     ●       │                                      │
│                        │   YELLOW    │                                      │
│                        └──────┬──────┘                                      │
│                               │                                             │
│              ┌────────────────┼────────────────┐                            │
│              │ Success        │                │ Failure                    │
│              ▼                │                ▼                            │
│       ┌─────────────┐         │         ┌─────────────┐                     │
│       │  Connected  │         │         │   Offline   │                     │
│       │     ●       │         │         │     ●       │                     │
│       │   GREEN     │         │         │    RED      │                     │
│       └──────┬──────┘         │         └──────┬──────┘                     │
│              │                │                │                            │
│              │ Connection     │                │ User taps Retry            │
│              │ drops          │                │                            │
│              ▼                │                │                            │
│       ┌─────────────┐         │                │                            │
│       │ Reconnecting│◄────────┴────────────────┘                            │
│       │     ●       │                                                       │
│       │   YELLOW    │                                                       │
│       │ Attempt 1/5 │                                                       │
│       └─────────────┘                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Status Bar Indicators

| State | Icon | Color | Label |
|-------|------|-------|-------|
| Connected | ● | Green | "Connected" |
| Connecting | ● | Yellow | "Connecting..." |
| Reconnecting | ● | Yellow | "Reconnecting... (Attempt 2)" |
| Disconnected | ● | Red | "Disconnected" |
| Offline | ● | Red | "Offline" |

### Design Decisions

**Q: How long before giving up on reconnection?**
A: 5 attempts with exponential backoff (2s, 4s, 8s, 16s, 32s). After 5 failures, shows "Offline" with manual retry button.

**Q: What's the difference between Disconnected and Offline?**
A: **Disconnected** = never connected or session ended normally. **Offline** = was connected but lost connection and couldn't recover.

---

## 8. Always-On Display (AOD)

### Journey Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ALWAYS-ON DISPLAY                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ACTIVE DISPLAY                       ALWAYS-ON (wrist down)               │
│   ──────────────                       ───────────────────────              │
│                                                                             │
│   ┌───────────────────────────┐        ┌───────────────────────────┐        │
│   │ ● Fixing auth bug...      │        │                           │        │
│   │                           │        │       ● Connected         │        │
│   │ ✓ Research existing code  │        │                           │        │
│   │ ● Update auth service     │  ──►   │          ▶               │        │
│   │ ○ Add unit tests          │        │        Active             │        │
│   │                           │        │                           │        │
│   │ ━━━━━━━━━━━━━━━░░░░░░░░░│        │       3 pending           │        │
│   │ 33%                   1/3 │        │                           │        │
│   └───────────────────────────┘        └───────────────────────────┘        │
│                                                                             │
│   FULL COLOR                           DIMMED, SIMPLIFIED                   │
│   - All UI elements                    - Connection status only             │
│   - Pulsing animations                 - Status icon (▶/⏸/✓)               │
│   - Progress details                   - Pending count if any               │
│                                        - No animations (battery)            │
│                                                                             │
│   AOD STATES:                                                               │
│   ───────────                                                               │
│                                                                             │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│   │     ✓      │  │     ▶      │  │     ⏸      │  │     ✋      │        │
│   │   Ready     │  │   Active    │  │   Paused    │  │  Pending    │        │
│   │             │  │             │  │             │  │  3 items    │        │
│   └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Design Decisions

**Q: Why simplify for AOD?**
A: Apple HIG requires reduced luminance and complexity for battery life. The simplified view shows just enough to know "is something happening" at a glance.

**Q: Should pending approvals wake the display?**
A: No. Push notifications handle waking. The AOD just shows current state for passive glances.

---

## 9. Error States

### Error Handling Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ERROR STATES                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ERROR TYPE              DISPLAY                    RECOVERY               │
│   ──────────              ───────                    ────────               │
│                                                                             │
│   Network Unavailable     ┌─────────────────┐        Automatic retry        │
│                           │    📡           │        when network           │
│                           │   Offline       │        returns                │
│                           │                 │                               │
│                           │   [Retry]       │                               │
│                           └─────────────────┘                               │
│                                                                             │
│   Pairing Expired         ┌─────────────────┐        User must              │
│                           │    ⏰           │        initiate new           │
│                           │  Code Expired   │        pairing                │
│                           │                 │                               │
│                           │  [Try Again]    │                               │
│                           └─────────────────┘                               │
│                                                                             │
│   Server Error            ┌─────────────────┐        Automatic retry        │
│                           │    ⚠️           │        with backoff           │
│                           │  Server Error   │                               │
│                           │   (500)         │                               │
│                           │   [Retry]       │                               │
│                           └─────────────────┘                               │
│                                                                             │
│   Session Ended           ┌─────────────────┐        Re-pair or             │
│   (from Mac)              │    🔌           │        wait for new           │
│                           │ Session Ended   │        session                │
│                           │                 │                               │
│                           │ [Pair Again]    │                               │
│                           └─────────────────┘                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Accessibility Considerations

### Supported Features

| Feature | Implementation | Notes |
|---------|---------------|-------|
| VoiceOver | Full support | All elements labeled |
| Dynamic Type | Scaled metrics | Text scales appropriately |
| Reduce Motion | Disable animations | Pulsing dot becomes solid |
| High Contrast | Enhanced colors | Tertiary colors boosted |
| Bold Text | System support | Inherits from system |

### Touch Targets

All interactive elements meet 44pt minimum:
- Approve/Reject buttons: 44pt+ height
- Mode selector: Full width tap area
- Settings button: 44pt circular
- Pause/Resume: 36pt (centered, easy to hit)

---

## Appendix: Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA FLOW                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   MAC (Claude Code)                CLOUD                    WATCH           │
│   ─────────────────                ─────                    ─────           │
│                                                                             │
│   ┌─────────────┐                                                           │
│   │ TodoWrite   │──── Progress ────►┌─────────────┐                         │
│   │ Hook        │     updates       │  Cloudflare │◄──── Poll every 3s     │
│   └─────────────┘                   │   Worker    │                         │
│                                     │             │────── Push (APNs) ────► │
│   ┌─────────────┐                   │  + Durable  │                         │
│   │ PreToolUse  │──── Approval ────►│   Objects   │                         │
│   │ Hook        │     requests      │             │◄──── Approve/Reject ───│
│   └─────────────┘                   └─────────────┘                         │
│         ▲                                 │                                 │
│         │                                 │                                 │
│         └────────── Response ─────────────┘                                 │
│                                                                             │
│   LATENCY TARGETS:                                                          │
│   ────────────────                                                          │
│   • Approval request → Watch: < 500ms (APNs)                                │
│   • Watch response → Claude: < 300ms                                        │
│   • Progress update → Watch: < 3s (polling) or < 500ms (push)               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 11. Task Outcome Display (PLANNED)

> **Status**: Planned Feature
> **Priority**: High - Critical for user closure
> **Problem**: Users don't get closure when Claude finishes a task

### The Closure Gap

Currently, when Claude completes a task, the watch shows "Complete" briefly then returns to "Listening...". The user doesn't see **what was accomplished** - the summary Claude provides ("Success - here's what I did...").

```
CURRENT FLOW (Missing Closure)
──────────────────────────────

  Claude finishes task
         │
         ▼
  ┌─────────────────┐       ┌─────────────────┐
  │ ● Complete      │       │ ● Listening...  │
  │                 │ ─3s─► │                 │
  │ 100%        2/2 │       │ Activity will   │
  └─────────────────┘       │ appear here...  │
                            └─────────────────┘
                                    │
                                    ▼
                            User wonders:
                            "What did Claude actually do?"
                            "Did it work?"
                            "What changed?"
```

### Proposed: Task Outcome Journey

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TASK OUTCOME (PLANNED)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   WORKING                    COMPLETE                    OUTCOME            │
│   ───────                    ────────                    ───────            │
│                                                                             │
│   ┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐ │
│   │ ● Working...    │        │ ✓ Complete      │        │ ✓ Done          │ │
│   │                 │        │                 │        │                 │ │
│   │ ○ Fix auth bug  │  ──►   │ ✓ Fix auth bug  │  ──►   │ Fixed auth bug  │ │
│   │ ○ Add tests     │        │ ✓ Add tests     │        │ in src/auth.ts  │ │
│   │                 │        │                 │        │                 │ │
│   │ ━━━━━━━░░░░░░░│        │ ━━━━━━━━━━━━━━│        │ • Updated JWT   │ │
│   │ 50%         1/2 │        │ 100%        2/2 │        │ • Added 3 tests │ │
│   └─────────────────┘        └─────────────────┘        │                 │ │
│                                     │                   │ 2 files changed │ │
│                                     │                   └─────────────────┘ │
│                                     │                          │            │
│                                     ▼                          │            │
│                              Brief moment                      │            │
│                              (1-2 seconds)                     ▼            │
│                                                                             │
│                                                         Persists until:     │
│                                                         • User dismisses    │
│                                                         • New task starts   │
│                                                         • 30s timeout       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Outcome Display Design

```
┌─────────────────────────────────────┐
│ ✓ Done                        [⚙️]  │
│                                     │
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │  Fixed authentication bug     │  │◄─── Summary from Claude
│  │  in src/auth.ts              │  │
│  │                               │  │
│  │  • Updated JWT validation     │  │◄─── Key changes
│  │  • Added error handling       │  │
│  │  • Created 3 unit tests       │  │
│  │                               │  │
│  │  ─────────────────────────── │  │
│  │  2 files · 47 lines · 23s     │  │◄─── Stats
│  │                               │  │
│  └───────────────────────────────┘  │
│                                     │
│           [OK, Got it]              │◄─── Dismiss button
│                                     │
└─────────────────────────────────────┘
```

### Implementation Requirements

| Component | Description | Status |
|-----------|-------------|--------|
| **PostResponse Hook** | Capture Claude's final summary | Not started |
| **Cloud Endpoint** | `/outcome` to receive summaries | Not started |
| **SessionProgress.outcome** | Field to store summary | ✓ Added |
| **Outcome UI View** | Display component | Not started |
| **Transition Logic** | Complete → Outcome → Listening | Not started |

### Data Source Options

1. **Explicit Hook** (Preferred)
   - New `PostResponse` hook captures Claude's summary
   - Looks for patterns: "Success", "Done", "Completed"
   - Sends structured outcome to cloud

2. **TodoWrite Enhancement**
   - Add `outcome` field to TodoWrite payload
   - Claude includes summary when marking final task complete

3. **Inferred from Tasks**
   - Generate summary from completed task names
   - Less informative but works immediately

### Design Decisions (To Be Made)

**Q: How long should the outcome persist?**
A: Options: Until dismissed, 30s timeout, or until new task starts. Recommendation: Until dismissed or new task, with 60s max timeout.

**Q: Should outcome include file diff summary?**
A: Ideal but complex. Start with text summary, add file stats if available.

**Q: What if Claude doesn't provide a summary?**
A: Fall back to generated summary from task names: "Completed: Fix auth bug, Add tests"

### Why This Matters

> "Without seeing the outcome, I feel like I don't get closure as a user."

The watch currently shows the *process* (tasks in progress) but not the *result* (what was achieved). This creates cognitive dissonance - the user approved actions, saw progress, but never sees confirmation of success.

**User Psychology:**
- **Process** = "Claude is working on X" ✓ (currently shown)
- **Approval** = "Claude wants to do Y" ✓ (currently shown)
- **Outcome** = "Claude accomplished Z" ✗ (missing!)

The outcome display completes the feedback loop and provides the satisfying "done" moment users need.

---

## Questions This Document Anticipates

1. **Why a watch app instead of phone notifications?**
   - Faster glance interaction (wrist vs pocket)
   - Haptic feedback confirmation
   - Works when phone is charging/away
   - Developer workflow: hands on keyboard, glance at wrist

2. **What's the security model?**
   - Pairing code shown on watch (physically attached to user)
   - Session-scoped (ends when CLI exits)
   - No sensitive data stored on watch
   - APNs for secure push delivery

3. **How does this fit with existing Claude Code UX?**
   - Complements, doesn't replace terminal prompts
   - Same approve/reject model, different input surface
   - Opt-in via `npx remmy-cli` (formerly `cc-watch`)

4. **Battery impact?**
   - Polling every 3s only when paired
   - APNs preferred (lower power)
   - AOD simplified to reduce draw
   - Typical session: minimal impact

5. **What about offline scenarios?**
   - Watch requires network for cloud relay
   - Graceful degradation to "Offline" state
   - Auto-reconnect when network returns

---

*Document prepared for Anthropic Design Review*
