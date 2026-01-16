# Implementation Todo List

## CRITICAL BLOCKERS (Must fix before TestFlight)

### 1. Remove Deprecated WKExtension APIs

**File:** `ClaudeWatch/App/ClaudeWatchApp.swift` (Line 68)
```swift
// REMOVE:
WKExtension.shared().registerForRemoteNotifications()

// REPLACE WITH:
DispatchQueue.main.async {
    WKApplication.shared().registerForRemoteNotifications()
}
```

**File:** `ClaudeWatch/Views/MainView.swift` (Line 439)
```swift
// REMOVE entire presentTextInputController() function

// REPLACE WITH SwiftUI TextField in VoiceInputSheet:
TextField("Enter command", text: $transcribedText)
    .textFieldStyle(.roundedBorder)
```

### 2. Set Development Team

**File:** `ClaudeWatch.xcodeproj/project.pbxproj`
- Find all instances of `DEVELOPMENT_TEAM = ""`
- Replace with your Apple Team ID

### 3. Add App Icons

**Directory:** `ClaudeWatch/Assets.xcassets/AppIcon.appiconset/`

Create PNG files (no transparency, RGB color space):
- 48x48.png (24pt @2x notification)
- 55x55.png (27.5pt @2x notification)
- 58x58.png (29pt @2x companion)
- 66x66.png (33pt @2x notification)
- 80x80.png (40pt @2x launcher)
- 87x87.png (29pt @3x companion)
- 88x88.png (44pt @2x launcher)
- 92x92.png (46pt @2x launcher)
- 100x100.png (50pt @2x launcher)
- 102x102.png (51pt @2x launcher)
- 108x108.png (54pt @2x launcher)
- 172x172.png (86pt @2x quick look)
- 196x196.png (98pt @2x quick look)
- 216x216.png (108pt @2x quick look)
- 234x234.png (117pt @2x quick look)
- 258x258.png (129pt @2x quick look)
- 1024x1024.png (marketing)

### 4. Create Privacy Policy

Host at: `https://yoursite.com/claudewatch/privacy`

Required sections:
- Data Collection (voice input, usage analytics)
- Third-Party Services (Anthropic/Claude API)
- Data Retention (how long stored)
- User Rights (deletion requests)
- Contact Information

### 5. Add Recording Indicator

**File:** `ClaudeWatch/Views/MainView.swift`

In VoiceInputSheet, add visual indicator:
```swift
if isRecording {
    HStack {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
        Text("Recording...")
            .font(.caption)
            .foregroundColor(.red)
    }
    .transition(.opacity)
}
```

### 6. Add AI Data Disclosure

Create new file: `ClaudeWatch/Views/Sheets/ConsentSheet.swift`

```swift
struct ConsentSheet: View {
    @AppStorage("hasConsented") var hasConsented = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Data Sharing Notice")
                .font(.headline)

            Text("ClaudeWatch sends your voice commands to Anthropic's Claude API for processing. Your data is transmitted securely and not stored permanently.")
                .font(.caption)
                .multilineTextAlignment(.center)

            Button("I Understand") {
                hasConsented = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

## HIGH PRIORITY (Before App Store submission)

### 7. Add Accessibility Labels

**File:** `ClaudeWatch/Views/MainView.swift`

```swift
// Settings button (line 37-44)
.accessibilityLabel("Settings")
.accessibilityHint("Opens server configuration")

// Approve All button (line 180-196)
.accessibilityLabel("Approve All")
.accessibilityHint("Approves all \(service.state.pendingActions.count) pending actions")

// Approve button (line 232-247)
.accessibilityLabel("Approve")
.accessibilityHint("Approves: \(action.title)")

// Reject button (line 249-265)
.accessibilityLabel("Reject")
.accessibilityHint("Rejects: \(action.title)")

// Quick action buttons (line 293-307)
.accessibilityLabel(prompt)
.accessibilityHint("Sends '\(prompt)' to Claude")

// Voice button (line 320-336)
.accessibilityLabel("Voice Command")
.accessibilityHint("Opens voice input")

// Mode switcher (line 344-372)
.accessibilityLabel("Mode: \(service.state.mode.displayName)")
.accessibilityHint("Tap to switch to \(service.state.mode.next().displayName)")
```

**File:** `ClaudeWatch/Complications/ComplicationViews.swift`

```swift
// Circular widget (line 92)
.accessibilityLabel(entry.pendingCount > 0 ? "Pending Actions" : "Ready")

// All images
.accessibilityHidden(true) // Hide decorative images
```

### 8. Fix Widget Data Sharing

**Step 1:** Add App Group capability in Xcode
- Target: ClaudeWatch
- Capability: App Groups
- Group: `group.com.anthropic.claudewatch`

**Step 2:** Update WatchService to save state
```swift
private func saveToAppGroup() {
    let defaults = UserDefaults(suiteName: "group.com.anthropic.claudewatch")
    defaults?.set(state.taskName, forKey: "taskName")
    defaults?.set(state.progress, forKey: "progress")
    defaults?.set(state.pendingActions.count, forKey: "pendingCount")
    defaults?.set(state.mode.rawValue, forKey: "mode")
    defaults?.set(connectionStatus == .connected, forKey: "isConnected")
}
```

**Step 3:** Update ClaudeProvider to read from App Group
```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeEntry>) -> Void) {
    let defaults = UserDefaults(suiteName: "group.com.anthropic.claudewatch")

    let entry = ClaudeEntry(
        date: Date(),
        taskName: defaults?.string(forKey: "taskName") ?? "IDLE",
        progress: defaults?.double(forKey: "progress") ?? 0,
        pendingCount: defaults?.integer(forKey: "pendingCount") ?? 0,
        model: "OPUS",
        isConnected: defaults?.bool(forKey: "isConnected") ?? false
    )

    let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
    completion(timeline)
}
```

### 9. Add State Persistence

**File:** `ClaudeWatch/Services/WatchService.swift`

Make WatchState Codable:
```swift
struct WatchState: Codable {
    var taskName: String = ""
    var taskDescription: String = ""
    var progress: Double = 0
    var status: SessionStatus = .idle
    var pendingActions: [PendingAction] = []
    var mode: PermissionMode = .normal
    var model: String = "opus"
}
```

Add save/restore:
```swift
private func saveState() {
    if let data = try? JSONEncoder().encode(state) {
        UserDefaults.standard.set(data, forKey: "savedWatchState")
    }
}

private func restoreState() {
    if let data = UserDefaults.standard.data(forKey: "savedWatchState"),
       let saved = try? JSONDecoder().decode(WatchState.self, from: data) {
        state = saved
    }
}
```

---

## MEDIUM PRIORITY (Polish)

### 10. Liquid Glass Migration

Replace all opacity backgrounds:

```swift
// MainView.swift line 93
.fill(Color.green.opacity(0.2))  →  .background(.liquidGlass)

// MainView.swift line 118
.background(Color(service.state.mode.color).opacity(0.3))  →  .background(.liquidGlass)

// MainView.swift line 191
.background(Color.green.opacity(0.2))  →  .background(.liquidGlass)

// MainView.swift line 260
.background(Color.red.opacity(0.2))  →  .background(.liquidGlass)

// MainView.swift line 303
.background(Color.gray.opacity(0.15))  →  .background(.liquidGlass)

// MainView.swift line 331
.background(Color.blue.opacity(0.2))  →  .background(.liquidGlass)

// MainView.swift line 473
.background(Color.gray.opacity(0.1))  →  .background(.liquidGlass)
```

### 11. Add Spring Animations

```swift
// For all buttons, add:
@State private var isPressed = false

Button { ... }
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { _ in isPressed = false }
    )
```

### 12. Split MainView.swift

Create these files:
- `Views/Components/StatusHeader.swift` (lines 52-156)
- `Views/Components/PendingActionsSection.swift` (lines 158-199)
- `Views/Components/ActionCard.swift` (lines 201-278)
- `Views/Components/QuickActionsBar.swift` (lines 280-312)
- `Views/Components/VoiceButton.swift` (lines 314-339)
- `Views/Components/ModeSwitcher.swift` (lines 341-390)
- `Views/Sheets/VoiceInputSheet.swift` (lines 392-449)
- `Views/Sheets/SettingsSheet.swift` (lines 451-503)

---

## LOW PRIORITY (Nice to have)

### 13. Novel Features

- [ ] Digital Crown timeline scrubber
- [ ] Shake to reject gesture
- [ ] Smart contextual suggestions
- [ ] "Waiting time" complication
- [ ] Custom haptic patterns per action type

### 14. Tests

- [ ] WatchServiceTests.swift
- [ ] DataModelTests.swift
- [ ] MainViewUITests.swift
- [ ] AccessibilityTests.swift

### 15. Documentation

- [ ] Update README with setup instructions
- [ ] Add CONTRIBUTING.md
- [ ] Create demo video

---

## Verification Checklist

Before each phase, verify:

### Phase 1 (Foundation)
- [ ] App builds without warnings
- [ ] App runs on physical watch
- [ ] WebSocket connects
- [ ] Actions can be approved

### Phase 2 (Compliance)
- [ ] Privacy policy accessible
- [ ] Recording indicator visible
- [ ] AI consent shown on first launch
- [ ] VoiceOver reads all buttons

### Phase 3 (Polish)
- [ ] Liquid Glass materials render
- [ ] Animations feel smooth
- [ ] Code compiles with Xcode 26

### Phase 4 (Testing)
- [ ] 75%+ test coverage
- [ ] No crashes in 100 sessions
- [ ] Works on 40mm, 45mm, 49mm

### Phase 5 (Beta)
- [ ] TestFlight build accepted
- [ ] 50+ testers active
- [ ] Crash-free rate > 99%

### Phase 6 (Submission)
- [ ] All screenshots uploaded
- [ ] Description approved
- [ ] Build processed
- [ ] Submitted for review
