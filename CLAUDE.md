# Project: Claude Watch

> **New Claude session?** Start with `/session-start` to orient yourself.
>
> **Before proposing solutions:** Read `.claude/ARCHITECTURE.md` first.

## Working Mode

**Always declare the working mode before starting any task. Default is RIGOR.**

| Mode | When to Use | My Behavior |
|------|-------------|-------------|
| **RIGOR** | Bug fixes, baseline verification, pre-ship, anything that gates the next step | One file/step at a time. Verify after each change before moving forward. Zero failures before declaring done. Surface every unexpected result immediately. No forward progress until current step is explicitly clean. |
| **VELOCITY** | Exploration, prototyping, drafting, spike work | Batch changes. Run once at end. Flag remaining issues and continue. |

**How to declare:** Say "RIGOR mode" or "VELOCITY mode" at the start of a task.
If no mode is declared, I will ask before starting.

> Why this matters: I naturally optimize for speed and task completion. Without an explicit
> mode, I will make tradeoffs that favour throughput over correctness — batching changes,
> asserting rather than verifying, and moving forward when "mostly done." RIGOR mode
> overrides those defaults and holds a higher quality bar throughout.

---

## Prompting Protocols

These protocols override my default behaviours. Apply them by adding them to your task instruction.

### 1. Pre-Task Acceptance Criteria
Before I start any non-trivial task, require me to state what done looks like.
> *"Before you touch anything — write the 3 conditions that would make this task complete. I will approve them before you begin."*

Calibrates the target before work starts. RIGOR/VELOCITY controls pace. Acceptance criteria control destination. Both are needed.

### 2. Pre-Mortem
Ask what could go wrong before I start, not after.
> *"What are the top 3 ways this task could fail or go wrong?"*

Forces risks to the surface before they become problems. What I don't surface is your signal to probe harder.

### 3. Flag Unverified Claims
I state confident-sounding things regardless of how certain I actually am.
Add this to any task where accuracy matters:
> *"Flag any claim you have not directly verified with [UNVERIFIED]."*

Distinguishes what I know from what I am asserting. The single most common source of 6/10 work is unverified assertions presented as facts.

### 4. Adversarial Review Agent
After implementation, spawn a fresh agent with zero context of how the work was done.
> *"Here is the output. Here is what done was supposed to look like. Find everything wrong with it. Do not suggest fixes — only find problems."*

The implementing agent is compromised by its own context. A fresh agent sees what was rationalized away. Use the multi-agent infrastructure already in this project.

### 5. Negative Constraints
Tell me what I cannot do, not just what I should do.
> *"Fix the failing tests. You may not skip tests, mark them as expected failures, or modify files outside the tests/ directory."*

Closes off shortcuts before I find them. More powerful than positive instructions for correctness-critical tasks.

### 6. What Didn't You Do
After completion, ask what I considered and rejected.
> *"What approaches did you consider but decide against — and why?"*

The paths not taken are often where the real answer lives. I discard options silently. This makes them visible.

### 7. Confidence Levels
After any non-trivial recommendation or diagnosis, ask:
> *"How confident are you in that from 1–10, and what is the main source of uncertainty?"*

Same as the quality self-rating but applied to individual claims. Surfaces the weak links before they become decisions.

### 8. Watch as Quality Gate (unique to this project)
The Apple Watch approval infrastructure can gate any checkpoint — not just tool calls.
Before starting a multi-step task, define which steps require watch approval before proceeding.
This makes RIGOR mode physical: each gate requires an explicit human decision, not just a passive non-interruption.

### 9. MEMORY.md — Interaction Patterns, Not Just Technical Notes
Record my failure patterns, not just technical learnings.
Examples of what belongs here:
- "Claude dismisses low-count test failures as pre-existing without verification — require explicit proof."
- "Claude batches multi-file changes by default — confirm one-file-at-a-time before any multi-file task."

These load every session and shape my behaviour before I read the task. Correction upstream is more reliable than correction in-session.

---

### Key Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/session-start` | Show current phase, tasks, blockers | Session start, orientation |
| `/ship-check` | Pre-submission validation | Before TestFlight/App Store |
| `/build` | Build for simulator | Development |
| `/deploy-device` | Deploy to physical watch | Device testing |

### Key Files

| File | Purpose |
|------|---------|
| `.claude/ARCHITECTURE.md` | **System skeleton** - READ BEFORE PROPOSING SOLUTIONS |
| `.claude/AGENT_GUIDE.md` | Reading order by task type |
| `.claude/state/SESSION_STATE.md` | Handoff persistence across sessions |
| `.claude/DATA_FLOW.md` | Detailed API endpoint reference |
| `.claude/plans/phase{N}-CONTEXT.md` | Pre-implementation decisions |

## Quick Reference
- **Platform**: watchOS 10.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Architecture**: App + Services + Views
- **Minimum Deployment**: watchOS 10.0
- **Package Manager**: Xcode native

## Project Overview
Claude Watch is a watchOS app that provides a wearable interface for Claude Code. It enables developers to approve/reject code changes directly from their Apple Watch via:
- WebSocket real-time communication
- Actionable push notifications (APNs)
- Voice commands
- Watch face complications

## Project Structure
```
claude-watch/
├── ClaudeWatch/                    # watchOS App
│   ├── App/                        # Entry point + AppDelegate
│   ├── Views/                      # SwiftUI views
│   ├── Services/                   # Business logic
│   └── Complications/              # Watch face widgets
├── MCPServer/                      # Python backend
│   ├── server.py                   # Legacy standalone server
│   └── bridge/                     # SDK-URL bridge (advanced, 346 tests)
│       ├── main.py                 # Bridge entrypoint
│       ├── ndjson_server.py        # NDJSON WebSocket server
│       ├── api.py                  # Watch-facing REST API
│       ├── cloud_client.py         # Cloud worker relay
│       └── tests/                  # 346 tests
├── remmy-cli/                      # TypeScript CLI
│   ├── hooks/                      # watch-approval-cloud.py (hook script)
│   └── src/                        # 143 tests
├── ClaudeWatch.xcodeproj/          # Xcode project
└── .claude/                        # Agent & developer docs
```

## Documentation Structure

```
plans/ → MIGRATION_PROGRESS.md → archive/
(ideas + specs)    (execute)        (done)
```

| Directory | Purpose |
|-----------|---------|
| `.claude/state/SESSION_STATE.md` | **Handoff persistence** - read at session start |
| `.claude/plans/MIGRATION_PROGRESS.md` | **THE** source of truth for current work |
| `.claude/plans/` | Ideas, specs, roadmap, and phase CONTEXT files |
| `.claude/commands/` | Slash commands (`/session-start`, `/ship-check`, etc.) |
| `.claude/context/PRD.md` | Product requirements document |
| `.claude/archive/` | Completed or obsolete content |
| `docs/` | User-facing guides only |
| `docs/solutions/` | **Documented fixes** - check [INDEX.md](docs/solutions/INDEX.md) when debugging |

## Coding Standards

### Swift Style
- Use Swift 5.9+ features (macros, parameter packs where applicable)
- Prefer `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

### SwiftUI Patterns
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Use `@Observable` macro for view models (iOS 17+/watchOS 10+)
- Keep views focused and under 100 lines where possible

### WatchOS-Specific Patterns
- Use `@WKApplicationDelegateAdaptor` for AppDelegate
- Handle `UNUserNotificationCenter` for push notifications
- Use `WKExtension` for system APIs
- Keep UI minimal - single glance interactions
- Leverage haptic feedback (`WKInterfaceDevice`)

### Notification Handling
- Register notification categories with actions
- Handle both foreground and background delivery
- Use `UNNotificationAction` for approve/reject actions
- Support `UNNotificationCategory` for action grouping
- **Silent push** (`content-available: 1`) needs `didReceiveRemoteNotification`, NOT `willPresent`
  - See: `docs/solutions/integration-issues/watchos-silent-push-ui-update.md`

## Testing Commands
```bash
# Build for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'

# Run on device (requires provisioning)
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS'
```

## Pairing Flow (IMPORTANT)

**The watch shows the code, the CLI receives it:**

```
┌─────────────────┐         ┌─────────────────┐
│   Apple Watch   │         │    Mac CLI      │
│                 │         │                 │
│  1. Tap "Pair"  │         │                 │
│  2. Shows code  │ ──────> │  3. remmy-cli   │
│     "ABC-123"   │         │  4. Enter code  │
│                 │         │  5. Paired!     │
└─────────────────┘         └─────────────────┘
```

```bash
# On Mac - after watch displays code:
remmy-cli
# Enter the code FROM the watch INTO the CLI
```

**DO NOT** use the old flow (CLI shows code → enter on watch). That is obsolete.

## Watch Approval Mode (IMPORTANT)

When `CLAUDE_WATCH_SESSION_ACTIVE=1` is set (by remmy-cli), the user is approving from their Apple Watch.

### AskUserQuestion → Watch Flow

The hook intercepts `AskUserQuestion` and routes it to the watch. The user selects an option on the watch. The hook then **denies** the tool and writes the answer to `/tmp/remmy-question-answer.json`.

**CRITICAL: After any `AskUserQuestion` denial by hook, you MUST read `/tmp/remmy-question-answer.json` to get the user's answer and proceed with it. Do NOT re-ask the question.**

```json
// /tmp/remmy-question-answer.json format:
{"question": "...", "answer": "Selected Option", "questionId": "...", "timestamp": ...}
```

### Question Guidelines

- Keep questions short — the watch screen is tiny
- Limit to 2-3 options (the watch shows them as tappable buttons)
- The watch **cannot** handle free-text input — only option selection
- For open-ended inputs (naming, etc.), use a sensible default: "I'll name it `UserService`. OK?" with Yes/No options
- If the user selects "Handle on Mac", the question falls through to the terminal

## CLI Commands
```bash
# Default flow: pair + install hook + launch Claude
cd remmy-cli && bun run dev

# Run tests
cd remmy-cli && bun run test

# Start bridge server (advanced mode)
cd MCPServer && python -m bridge.main
```

## DO NOT
- Use UIKit APIs (watchOS uses WatchKit/SwiftUI)
- Create massive monolithic views
- Use force unwrapping (`!`) without justification
- Block the main thread with synchronous network calls
- Ignore notification permission states
- **NEVER disable or clear PreToolUse hooks in `.claude/settings.json`** - The watch approval hook uses session isolation via `CLAUDE_WATCH_SESSION_ACTIVE` env var. It stays registered but only activates when remmy-cli is running. DO NOT TOUCH IT.

## Key Files
- `ClaudeWatchApp.swift` - App entry, notification setup
- `MainView.swift` - Primary UI
- `WatchService.swift` - WebSocket, state, API calls
- `ComplicationViews.swift` - Watch face widgets
- `remmy-cli/hooks/watch-approval-cloud.py` - PreToolUse hook (bundled)
- `remmy-cli/src/lib/hooks-config.ts` - Hook installation + registration
- `remmy-cli/src/lib/claude-launcher.ts` - Spawns Claude with env var
- `remmy-cli/src/commands/default.ts` - CLI default command (pair + hook + launch)
