# Project: Claude Watch

> **New Claude session?** Read `.claude/ONBOARDING.md` first.

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
| `.claude/ralph/tasks.yaml` | **THE** source of truth for current work |
| `.claude/plans/` | Refined plans and roadmap items |
| `.claude/context/` | Always-on context (personas, PRD, journeys) |
| `.claude/inbox/` | Raw ideas, quick captures |
| `.claude/archive/` | Completed or obsolete content |
| `docs/` | User-facing guides only |

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

## Testing Commands
```bash
# Build for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# Run on device (requires provisioning)
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS'
```

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

## Key Files
- `ClaudeWatchApp.swift` - App entry, notification setup
- `MainView.swift` - Primary UI
- `WatchService.swift` - WebSocket, state, API calls
- `ComplicationViews.swift` - Watch face widgets
- `MCPServer/server.py` - Python backend
