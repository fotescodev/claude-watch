# Product Requirements Document: Claude Watch

**Product Name:** Claude Watch
**Version:** 1.0
**Last Updated:** January 2026
**Status:** Beta Development

---

## Executive Summary

Claude Watch is a watchOS companion application for Claude Code that enables developers to approve or reject AI-generated code changes directly from their Apple Watch. By bringing code review decisions to the wrist, developers can maintain workflow continuity without interrupting their current activity—whether in a meeting, commuting, or simply away from their desk.

The app bridges the gap between Claude Code's autonomous capabilities and the need for human oversight, providing a lightweight approval interface that preserves the developer's agency while minimizing context-switching friction.

---

## Problem Statement

### The Core Problem

When using Claude Code for software development tasks, developers frequently need to approve file edits, command executions, and other operations. This creates a workflow interruption:

1. **Context Switching**: Developers must return to their terminal to review and approve changes
2. **Blocked Progress**: Claude Code halts execution while waiting for human approval
3. **Lost Momentum**: The delay between action request and approval breaks development flow
4. **Physical Constraints**: Approvals can't happen when away from the development machine

### Why It Matters

Modern AI-assisted development promises to dramatically accelerate coding workflows, but only if the human-in-the-loop approval process doesn't become a bottleneck. Developers need a way to maintain oversight without sacrificing the productivity gains AI coding assistants provide.

---

## Target Users

### Primary Persona: The Mobile Developer

- **Role**: Full-stack or backend developer using Claude Code regularly
- **Behavior**: Frequently steps away from desk (meetings, breaks, errands)
- **Pain Point**: Misses approval requests, causing Claude Code to timeout
- **Apple Ecosystem**: Already owns Apple Watch, uses it for notifications

### Secondary Persona: The Remote Worker

- **Role**: Developer working from home or co-working spaces
- **Behavior**: Uses multiple devices and locations throughout the day
- **Pain Point**: Wants to keep Claude Code running while away from primary machine
- **Need**: Quick approve/reject without opening laptop

### Tertiary Persona: The Power User

- **Role**: Senior developer running multiple long-running tasks
- **Behavior**: Kicks off refactoring or migration tasks that take time
- **Pain Point**: Needs to monitor progress and intervene when necessary
- **Need**: Glanceable status + instant control from anywhere

---

## Goals and Objectives

### Business Goals

1. **Increase Claude Code Engagement**: Reduce approval timeout friction that causes task failures
2. **Expand Platform Presence**: First wearable interface for an AI coding assistant
3. **Demonstrate Innovation**: Showcase novel AI interaction paradigms

### User Goals

1. **Stay Informed**: Know what Claude Code is doing at a glance
2. **Maintain Control**: Approve or reject actions instantly
3. **Minimize Interruption**: Handle approvals in under 5 seconds
4. **Preserve Autonomy**: Choose between careful review and auto-approve modes

### Success Metrics

| Metric | Target | Rationale |
|--------|--------|-----------|
| Time to Approve | < 5 seconds | Single glance + tap interaction |
| Connection Reliability | 99% uptime | Trust requires reliability |
| Notification Delivery | < 2 second latency | Real-time responsiveness |
| User Retention (7-day) | > 60% | Ongoing utility validation |
| NPS Score | > 50 | User satisfaction benchmark |

---

## Core Features

### 1. Real-Time Status Display

**Description**: Live dashboard showing current Claude Code session state

**Capabilities**:
- Current task name and description
- Progress bar with percentage
- Session status (idle, running, waiting, completed, failed)
- Active model indicator (opus, sonnet, etc.)
- Pending action count badge

**User Value**: Instant awareness of Claude Code activity without opening laptop

---

### 2. Action Approval Queue

**Description**: Review and approve/reject pending Claude Code actions

**Supported Action Types**:
| Type | Icon | Example |
|------|------|---------|
| File Edit | Pencil | "Edit src/App.tsx" |
| File Create | Doc+ | "Create tests/auth.test.ts" |
| File Delete | Trash | "Delete old/legacy.js" |
| Bash Command | Terminal | "Run npm install" |
| Tool Use | Gear | "Execute MCP tool" |

**Interaction Model**:
- Primary action displayed with full details
- Secondary actions shown in compact cards
- Green "Approve" button (left)
- Red "Reject" button (right)
- "Approve All" button when 2+ actions pending

**User Value**: Review and act on each change before it happens

---

### 3. Permission Mode Control

**Description**: Toggle between approval policies (mirrors Claude Code's Shift+Tab)

**Modes**:
| Mode | Color | Behavior |
|------|-------|----------|
| Normal | Blue | Approve each action individually |
| Auto-Accept | Red | Automatically approve all actions |
| Plan | Purple | Read-only planning, no execution |

**Interaction**: Tap mode indicator to cycle through modes

**User Value**: Match approval strictness to task risk level

---

### 4. Quick Commands

**Description**: Send voice commands or preset actions to Claude Code

**Preset Commands**:
- **Go**: Resume/start task
- **Test**: Run test suite
- **Fix**: Attempt auto-fix
- **Stop**: Halt current execution

**Voice Input**: Dictate custom prompts via watchOS text input

**User Value**: Control Claude Code without typing

---

### 5. Watch Face Complications

**Description**: Glanceable widgets for watch face integration

**Widget Types**:
| Family | Content |
|--------|---------|
| Circular | Progress ring + pending count |
| Rectangular | Task name + progress bar + status |
| Corner | Arc progress + percentage |
| Inline | Task name + percentage badge |

**Update Frequency**: Every 60 seconds

**User Value**: See Claude Code status without launching app

---

### 6. Push Notifications

**Description**: Actionable notifications for approval requests

**Notification Actions**:
- Approve (green, foreground)
- Reject (red, destructive)
- Approve All (green, foreground)

**Notification Content**:
- Action type and title
- File path or command
- Task context

**User Value**: Approve directly from notification without opening app

---

## User Flows

### Flow 1: New Action Approval

```
1. User is away from desk
2. Claude Code needs file edit approval
3. Watch vibrates with notification
4. User glances at watch
5. Sees "Edit App.tsx" with description
6. Taps green "Approve" button
7. Haptic confirmation
8. Claude Code continues execution
```

**Time to Complete**: 3-5 seconds

---

### Flow 2: Bulk Approval

```
1. Claude Code has queued 5 actions
2. User opens Claude Watch app
3. Sees "5 Pending" badge
4. Reviews primary action card
5. Taps "Approve All" button
6. All actions approved simultaneously
7. Badge clears to "All Clear"
```

**Time to Complete**: 5-8 seconds

---

### Flow 3: Mode Switch to YOLO

```
1. User running trusted migration script
2. Wants auto-approve for speed
3. Taps mode indicator (currently "Normal")
4. Mode cycles to "Auto-Accept" (red)
5. Strong haptic feedback (warning)
6. All pending actions auto-approved
7. Future actions auto-approved until changed
```

**Time to Complete**: 2 seconds

---

### Flow 4: Voice Command

```
1. User wants to check test status
2. Taps microphone button
3. Voice input UI appears
4. Says "Run the test suite"
5. Command sent to Claude Code
6. Progress updates on watch
7. Notification when tests complete
```

**Time to Complete**: 10-15 seconds

---

### Flow 5: Initial Pairing (Cloud Mode)

```
1. User installs Claude Watch app
2. Opens app, sees "Not Connected"
3. Taps Settings → "Pair with Claude Code"
4. In Claude Code terminal, runs pair command
5. Gets 6-character code (e.g., "ABC-123")
6. Enters code on watch
7. "Connected" status appears
8. Ready to receive approvals
```

**Time to Complete**: 30-60 seconds (one-time setup)

---

## Functional Requirements

### FR-1: Connection Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | App SHALL support WebSocket connection to local Python server | P0 |
| FR-1.2 | App SHALL support cloud relay via Cloudflare Worker | P0 |
| FR-1.3 | App SHALL automatically reconnect with exponential backoff | P0 |
| FR-1.4 | App SHALL monitor network reachability changes | P1 |
| FR-1.5 | App SHALL display connection status (disconnected, connecting, connected, reconnecting) | P0 |
| FR-1.6 | App SHALL support switching between WebSocket and cloud modes | P1 |

### FR-2: Action Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | App SHALL display pending actions with type, title, and description | P0 |
| FR-2.2 | App SHALL allow approval of individual actions | P0 |
| FR-2.3 | App SHALL allow rejection of individual actions | P0 |
| FR-2.4 | App SHALL allow bulk approval of all pending actions | P1 |
| FR-2.5 | App SHALL update action list in real-time | P0 |
| FR-2.6 | App SHALL provide haptic feedback on action response | P1 |

### FR-3: State Synchronization

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | App SHALL receive full state on connection establishment | P0 |
| FR-3.2 | App SHALL update progress bar in real-time | P0 |
| FR-3.3 | App SHALL display current task name and status | P0 |
| FR-3.4 | App SHALL persist pairing credentials across app launches | P0 |
| FR-3.5 | App SHALL sync permission mode with server | P1 |

### FR-4: Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | App SHALL register for remote push notifications | P0 |
| FR-4.2 | App SHALL display actionable notifications with Approve/Reject | P0 |
| FR-4.3 | App SHALL handle notification actions when app is backgrounded | P0 |
| FR-4.4 | App SHALL request notification permissions on first launch | P0 |

### FR-5: Watch Complications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | App SHALL provide circular complication with progress ring | P2 |
| FR-5.2 | App SHALL provide rectangular complication with task details | P2 |
| FR-5.3 | App SHALL update complications periodically | P2 |
| FR-5.4 | App SHALL show pending count in complications | P2 |

---

## Non-Functional Requirements

### NFR-1: Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1.1 | App launch time | < 2 seconds |
| NFR-1.2 | Action approval latency | < 1 second |
| NFR-1.3 | WebSocket message delivery | < 500ms |
| NFR-1.4 | UI frame rate | 60 fps |
| NFR-1.5 | Memory usage | < 50MB |

### NFR-2: Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-2.1 | Connection recovery success rate | > 99% |
| NFR-2.2 | Message delivery guarantee | At least once |
| NFR-2.3 | Reconnection max attempts | 10 (with backoff) |
| NFR-2.4 | Reconnection backoff max | 60 seconds |

### NFR-3: Battery

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-3.1 | Background power usage | Minimal (stop polling) |
| NFR-3.2 | Active session battery impact | < 5% per hour |
| NFR-3.3 | Complication refresh impact | Negligible |

### NFR-4: Security

| ID | Requirement | Priority |
|----|-------------|----------|
| NFR-4.1 | Pairing codes SHALL expire after 10 minutes | P0 |
| NFR-4.2 | Cloud relay SHALL use HTTPS | P0 |
| NFR-4.3 | Device tokens SHALL be stored securely | P0 |
| NFR-4.4 | No sensitive code content transmitted to watch | P0 |

### NFR-5: Usability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-5.1 | Primary action approval | Single tap |
| NFR-5.2 | Information density | Glanceable in 2s |
| NFR-5.3 | Haptic feedback | Context-appropriate |
| NFR-5.4 | Minimum tap target size | 44pt |

---

## Technical Architecture

### System Components

```
┌──────────────────────────────────────────────────────────────────┐
│                        DEVELOPER'S MACHINE                        │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │ Claude Code │───▶│  MCP Protocol   │───▶│  Python Server  │  │
│  │   (CLI)     │    │  (stdio/JSON)   │    │  (WebSocket)    │  │
│  └─────────────┘    └─────────────────┘    └────────┬────────┘  │
└─────────────────────────────────────────────────────┼────────────┘
                                                      │
                    ┌─────────────────────────────────┼───────────┐
                    │              NETWORK            │           │
                    │  ┌──────────────────────────────▼────────┐  │
                    │  │           Option A: WebSocket         │  │
                    │  │        (Local/Development Mode)       │  │
                    │  └──────────────────────────────┬────────┘  │
                    │                                 │           │
                    │  ┌──────────────────────────────▼────────┐  │
                    │  │        Option B: Cloud Relay          │  │
                    │  │      (Cloudflare Worker + KV)         │  │
                    │  └──────────────────────────────┬────────┘  │
                    │                                 │           │
                    │  ┌──────────────────────────────▼────────┐  │
                    │  │          Option C: APNs               │  │
                    │  │    (Push Notifications - Future)      │  │
                    │  └──────────────────────────────┬────────┘  │
                    └─────────────────────────────────┼───────────┘
                                                      │
┌─────────────────────────────────────────────────────▼────────────┐
│                          APPLE WATCH                              │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
│  │  SwiftUI    │◀──▶│  WatchService   │◀──▶│  Notifications  │  │
│  │   Views     │    │  (State Mgmt)   │    │  (UNUserNotif)  │  │
│  └─────────────┘    └─────────────────┘    └─────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Watch App | Swift 5.9 + SwiftUI | Native watchOS development |
| State Management | @Observable macro | Modern Swift concurrency |
| Networking | URLSession WebSocket | Native WebSocket support |
| Persistence | @AppStorage | Simple key-value storage |
| Server | Python + aiohttp | Async WebSocket + REST |
| Cloud Relay | Cloudflare Workers | Edge computing + KV storage |
| Protocol | MCP (Model Context Protocol) | Claude Code integration |

### Data Models

**Core Entities**:
- `WatchState`: Current session state (task, progress, status, pending actions)
- `PendingAction`: Individual action requiring approval
- `PermissionMode`: Current approval policy
- `ConnectionStatus`: Network connection state

**Message Types**:
- `state_sync`: Full state on connect
- `action_requested`: New action needs approval
- `action_response`: User's approval/rejection
- `progress_update`: Task progress change
- `mode_changed`: Permission mode update

---

## Constraints and Assumptions

### Constraints

1. **watchOS Limitations**: No background WebSocket connections; must use polling or push
2. **Screen Size**: 40-45mm display limits information density
3. **Battery**: Aggressive power management required
4. **Network**: Watch may have limited connectivity (Bluetooth relay only)
5. **Input**: Limited to taps, crown, and voice; no keyboard

### Assumptions

1. User has Apple Watch Series 4 or later (watchOS 10 compatible)
2. User has iPhone paired with watch for notifications
3. Developer machine and watch on same network (WebSocket mode)
4. User has reliable internet for cloud mode
5. Claude Code version supports MCP protocol

### Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| watchOS | 10.0+ | Platform |
| Xcode | 15.0+ | Build toolchain |
| Python | 3.9+ | Server runtime |
| websockets | Latest | WebSocket library |
| aiohttp | Latest | HTTP server |

---

## Release Phases

### Phase 1: MVP (Current)

- [x] WebSocket real-time connection
- [x] Action approval/rejection
- [x] Mode cycling
- [x] Basic UI with status display
- [x] Connection recovery

### Phase 2: Cloud Ready

- [x] Cloudflare Worker relay
- [x] 6-character pairing flow
- [x] Polling-based updates
- [ ] APNs push notification delivery

### Phase 3: Polish

- [ ] Watch face complications (all families)
- [ ] Voice command improvements
- [ ] Settings refinements
- [ ] App Store submission

### Phase 4: Future

- [ ] Multi-session support
- [ ] Diff preview on watch
- [ ] Siri Shortcuts integration
- [ ] Widget configuration options

---

## Appendix A: Competitive Analysis

| Product | Platform | Capability | Limitation |
|---------|----------|------------|------------|
| Claude Watch | watchOS | Full approval workflow | Apple-only |
| GitHub Mobile | iOS/Android | PR review, notifications | No AI agent integration |
| Linear Mobile | iOS/Android | Issue management | No code approval |
| Slack | Cross-platform | Notifications only | No action capability |

**Differentiation**: Claude Watch is the first wearable interface designed specifically for AI coding assistant approval workflows.

---

## Appendix B: User Research Insights

*(To be populated with user feedback from beta testing)*

1. Key pain points
2. Feature requests
3. Usability findings
4. Satisfaction scores

---

## Appendix C: Glossary

| Term | Definition |
|------|------------|
| MCP | Model Context Protocol - Interface for Claude Code tools |
| APNs | Apple Push Notification service |
| YOLO Mode | Auto-accept all actions without review |
| Plan Mode | Read-only mode where no actions execute |
| Complication | watchOS term for watch face widget |
| Pairing | One-time connection setup between watch and server |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 2026 | Claude | Initial PRD derived from implementation |

---

*This PRD was derived from the existing Claude Watch implementation and documents the product as built.*
