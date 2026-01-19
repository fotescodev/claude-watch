# Project: Claude Watch

> **New Claude session?** Start with `/progress` to orient yourself.

## Session Workflow (GSD-Inspired)

```
┌─────────────────────────────────────────────────────────────────┐
│  SESSION START                                                  │
│  1. Run /progress → See current phase, tasks, blockers          │
│  2. Read .claude/state/SESSION_STATE.md → Handoff context       │
│                                                                 │
│  BEFORE NEW PHASE                                               │
│  3. Run /discuss-phase N → Capture decisions upfront            │
│  4. Creates .claude/plans/phase{N}-CONTEXT.md                   │
│                                                                 │
│  DURING IMPLEMENTATION                                          │
│  5. Use tasks.yaml for task tracking                            │
│  6. Commit atomically per task                                  │
│                                                                 │
│  BEFORE SHIPPING                                                │
│  7. Run /ship-check → Pre-submission validation                 │
│                                                                 │
│  SESSION END                                                    │
│  8. Update SESSION_STATE.md with handoff notes                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/progress` | Show current phase, tasks, blockers | Session start, orientation |
| `/discuss-phase N` | Capture implementation decisions | Before starting new phase |
| `/ship-check` | Pre-submission validation | Before TestFlight/App Store |
| `/build` | Build for simulator | Development |
| `/deploy-device` | Deploy to physical watch | Device testing |

### Key Files

| File | Purpose |
|------|---------|
| `.claude/state/SESSION_STATE.md` | Handoff persistence across sessions |
| `.claude/ralph/tasks.yaml` | Task definitions and progress |
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
│   │   └── ClaudeWatchApp.swift    # Main app with notification handling
│   ├── Views/                      # SwiftUI views
│   │   └── MainView.swift          # Single-screen UI
│   ├── Services/                   # Business logic
│   │   └── WatchService.swift      # WebSocket client + state management
│   └── Complications/              # Watch face widgets
│       └── ComplicationViews.swift # Complication providers
├── ClaudeWatch.xcodeproj/          # Xcode project
└── MCPServer/                      # Python MCP server
    └── server.py                   # WebSocket + MCP + APNs bridge
```

## Documentation Structure

```
inbox/ → plans/ → tasks.yaml → archive/
(ideas)  (refined)  (execute)   (done)
```

| Directory | Purpose |
|-----------|---------|
| `.claude/state/SESSION_STATE.md` | **Handoff persistence** - read at session start |
| `.claude/ralph/tasks.yaml` | **THE** source of truth for current work |
| `.claude/plans/` | Refined plans, roadmap, and phase CONTEXT files |
| `.claude/commands/` | Slash commands (`/progress`, `/ship-check`, etc.) |
| `.claude/context/` | Always-on context (personas, PRD, journeys) |
| `.claude/scope-creep/` | Future dreams (CarPlay, iOS app) - ignore |
| `.claude/inbox/` | Raw ideas, quick captures |
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
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

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
│  2. Shows code  │ ──────> │  3. npx cc-watch│
│     "ABC-123"   │         │  4. Enter code  │
│                 │         │  5. Paired!     │
└─────────────────┘         └─────────────────┘
```

```bash
# On Mac - after watch displays code:
npx cc-watch
# Enter the code FROM the watch INTO the CLI
```

**DO NOT** use the old flow (CLI shows code → enter on watch). That is obsolete.

## Server Commands
```bash
# Start MCP server (standalone mode)
cd MCPServer && python server.py --standalone --port 8787

# Test API
curl http://localhost:8788/state
```

## DO NOT
- Use UIKit APIs (watchOS uses WatchKit/SwiftUI)
- Create massive monolithic views
- Use force unwrapping (`!`) without justification
- Block the main thread with synchronous network calls
- Ignore notification permission states
- **NEVER disable or clear PreToolUse hooks in `.claude/settings.json`** - The watch approval hook uses session isolation via `CLAUDE_WATCH_SESSION_ACTIVE` env var. It stays registered but only activates when cc-watch is running. DO NOT TOUCH IT.

## Key Files
- `ClaudeWatchApp.swift` - App entry, notification setup
- `MainView.swift` - Primary UI
- `WatchService.swift` - WebSocket, state, API calls
- `ComplicationViews.swift` - Watch face widgets
- `MCPServer/server.py` - Python backend
