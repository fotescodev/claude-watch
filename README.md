# Claude Watch

A WatchOS companion app for Claude Code - control your AI coding sessions from your wrist.

![WatchOS](https://img.shields.io/badge/watchOS-10.0+-orange)
![Swift](https://img.shields.io/badge/Swift-5.9+-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🎛️ Control Deck Interface
- **OLED-style status display** showing task name, progress, model, and connection status
- **Action buttons**: Accept, Approve, Discard, Retry - all with haptic feedback
- **YOLO Mode toggle**: Auto-approve all actions with one tap
- **Digital Crown model switching**: Rotate to switch between Opus, Sonnet, and Haiku

### 📋 Actions Management
- View all pending actions in a scrollable list
- Swipe to accept or discard individual actions
- Approve all pending actions at once
- Real-time updates from Claude Code sessions

### 🎤 Voice Input
- Dictate prompts directly from your watch
- Quick prompt suggestions for common actions
- Recent prompts history

### ⌚ Watch Face Complications
- **Circular**: Progress ring with pending action count
- **Rectangular**: Full status with task name, progress bar, and model
- **Corner**: Compact progress gauge
- **Inline**: Text-based status for modular faces

### 📳 Haptic Feedback
- Distinct haptic patterns for different actions
- Celebration pattern when tasks complete
- Alert pattern for pending actions requiring attention

## Architecture

```
ClaudeWatch/
├── App/
│   └── ClaudeWatchApp.swift       # App entry point
├── Models/
│   ├── SessionState.swift          # Data models
│   └── SessionManager.swift        # State management
├── Views/
│   ├── ContentView.swift           # Main tab navigation
│   ├── ControlDeckView.swift       # Main control interface
│   ├── ActionsListView.swift       # Pending actions list
│   ├── QuickPromptsView.swift      # Prompt suggestions
│   ├── VoiceInputView.swift        # Voice dictation
│   ├── ModelPickerView.swift       # Model selection
│   └── SettingsView.swift          # App settings
├── Services/
│   ├── WatchConnectivityService.swift  # iPhone/Mac communication
│   └── HapticService.swift         # Haptic feedback
├── Complications/
│   ├── ComplicationController.swift    # ClockKit complications
│   └── ComplicationViews.swift     # WidgetKit widgets
└── Assets.xcassets/                # App icons and colors
```

## Setup

### Requirements
- Xcode 15.0+
- watchOS 10.0+
- iOS 17.0+ (for companion app)

### Installation

1. Open Xcode and create a new WatchOS App project
2. Copy all files from `ClaudeWatch/` into your project
3. Update the bundle identifier in `Info.plist`
4. Add required capabilities:
   - WatchConnectivity
   - Background Modes (if needed)
5. Build and run on your Apple Watch

### Connecting to Claude Code

The app communicates with Claude Code via WatchConnectivity. For full functionality, you'll need a companion iOS/macOS app that bridges to Claude Code CLI.

**Message Protocol:**

```swift
// Watch → Phone/Mac
["action": "accept"]           // Accept current changes
["action": "discard"]          // Discard current changes
["action": "approve"]          // Approve current action
["action": "retry"]            // Retry current action
["action": "approveAll"]       // Approve all pending
["action": "toggleYolo", "enabled": true]
["action": "changeModel", "model": "opus"]
["action": "sendPrompt", "prompt": "Fix the bug"]

// Phone/Mac → Watch
["type": "taskUpdate", "name": "REFACTOR", "progress": 0.6]
["type": "actionPending", "description": "Edit file.swift"]
["type": "statusUpdate", ...]
```

## UI Preview

### Control Deck (Main Screen)
```
┌─────────────────────────┐
│ TASK: CODE REFACTOR 60% │
│ ▓▓▓▓▓▓▓▓░░░░░░         │
│ MODEL: OPUS 4.5  SUB:85%│
│ ● CONNECTED        YOLO │
├─────────────────────────┤
│ [✓ ACCEPT] [👍 APPROVE] │
│ [✗ DISCARD] [↻ RETRY]   │
├─────────────────────────┤
│ ⚡ YOLO MODE         OFF │
└─────────────────────────┘
```

### Actions List
```
┌─────────────────────────┐
│ PENDING              [3]│
├─────────────────────────┤
│ ✏️ FILE_EDIT            │
│ Update SessionManager   │
│ Models/Session...swift  │
├─────────────────────────┤
│ 🖥️ BASH                 │
│ Run swift build         │
├─────────────────────────┤
│   [✓ APPROVE ALL]       │
└─────────────────────────┘
```

## Customization

### Adding Quick Prompts
Edit `SessionManager.swift`:
```swift
let quickPrompts: [QuickPrompt] = [
    QuickPrompt(text: "Your prompt", icon: "star", category: .action),
    // Add more...
]
```

### Haptic Patterns
Customize patterns in `HapticService.swift`:
```swift
func customAction() {
    device.play(.success)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.device.play(.click)
    }
}
```

## Contributing

Contributions welcome! Please read our contributing guidelines before submitting PRs.

## License

MIT License - see LICENSE file for details.

---

*Inspired by the vibecoding community's hardware control deck concept.*
