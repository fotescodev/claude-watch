# ClaudeWatch Task Breakdown for Autonomous Execution

> **Purpose:** Structured tasks for agentic loop execution
> **Format:** Each task is self-contained with clear success criteria

---

## Task Index

| ID | Task | Priority | Dependencies | Est. Time |
|----|------|----------|--------------|-----------|
| T01 | Remove deprecated WKExtension API | CRITICAL | None | 15min |
| T02 | Replace deprecated text input controller | CRITICAL | None | 30min |
| T03 | Add state persistence (Codable) | CRITICAL | None | 30min |
| T04 | Create WatchService protocol for testability | HIGH | None | 30min |
| T05 | Add accessibility labels | HIGH | None | 45min |
| T06 | Add recording indicator UI | HIGH | None | 20min |
| T07 | Add AI consent dialog | HIGH | None | 30min |
| T08 | Fix widget data with App Groups | MEDIUM | T03 | 45min |
| T09 | Split MainView.swift into components | MEDIUM | None | 60min |
| T10 | Add Liquid Glass materials | MEDIUM | T09 | 30min |
| T11 | Add spring animations | LOW | T09 | 20min |
| T12 | Write unit tests | HIGH | T03, T04 | 60min |
| T13 | Write UI tests | MEDIUM | T05 | 45min |

---

## T01: Remove Deprecated WKExtension API

### Description
Replace `WKExtension.shared()` with modern APIs. This is deprecated in watchOS 10+ and will crash on watchOS 26.

### File
`ClaudeWatch/App/ClaudeWatchApp.swift`

### Current Code (to find)
```swift
WKExtension.shared().registerForRemoteNotifications()
```

### Target Code (to replace with)
```swift
WKApplication.shared().registerForRemoteNotifications()
```

### Acceptance Criteria
- [ ] No references to `WKExtension` exist in codebase
- [ ] App compiles without deprecation warnings for WKExtension
- [ ] Push notification registration still works

### Definition of Done
1. `grep -r "WKExtension" ClaudeWatch/` returns no results
2. `xcodebuild` completes with 0 WKExtension deprecation warnings
3. App launches without crash on watchOS 11+ simulator

### Unit Tests
```swift
// File: ClaudeWatchTests/AppDelegateTests.swift

import XCTest
@testable import ClaudeWatch

final class AppDelegateTests: XCTestCase {

    func testNoDeprecatedWKExtensionUsage() {
        // Verify WKExtension is not referenced
        let sourceFiles = try! FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "ClaudeWatch"),
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "swift" }

        for file in sourceFiles {
            let content = try! String(contentsOf: file)
            XCTAssertFalse(
                content.contains("WKExtension"),
                "Found deprecated WKExtension in \(file.lastPathComponent)"
            )
        }
    }
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/LaunchTests.swift

func testAppLaunchesWithoutCrash() {
    let app = XCUIApplication()
    app.launch()

    // App should reach main view without crashing
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
}
```

### Verification Command
```bash
grep -r "WKExtension" ClaudeWatch/ && echo "FAIL: WKExtension found" || echo "PASS: No WKExtension"
```

---

## T02: Replace Deprecated Text Input Controller

### Description
Replace `presentTextInputController` with SwiftUI TextField. The WatchKit method is deprecated.

### File
`ClaudeWatch/Views/MainView.swift`

### Current Code (to find)
```swift
WKExtension.shared().visibleInterfaceController?.presentTextInputController(
```

or any usage of `presentTextInputController`

### Target Code (to replace with)
```swift
// In VoiceInputSheet, replace with SwiftUI TextField:
TextField("Enter command...", text: $transcribedText)
    .textFieldStyle(.plain)
    .onSubmit {
        sendPrompt()
    }
```

### Acceptance Criteria
- [ ] No references to `presentTextInputController` in codebase
- [ ] VoiceInputSheet has a working TextField for text entry
- [ ] User can type and submit text commands

### Definition of Done
1. `grep -r "presentTextInputController" ClaudeWatch/` returns no results
2. VoiceInputSheet renders a TextField
3. Typing text and pressing return sends the prompt

### Unit Tests
```swift
// File: ClaudeWatchTests/MainViewTests.swift

func testNoDeprecatedTextInputController() {
    let mainViewSource = try! String(contentsOfFile: "ClaudeWatch/Views/MainView.swift")
    XCTAssertFalse(
        mainViewSource.contains("presentTextInputController"),
        "Found deprecated presentTextInputController"
    )
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/VoiceInputTests.swift

func testTextInputFieldExists() {
    let app = XCUIApplication()
    app.launch()

    // Open voice input sheet
    app.buttons["Voice Command"].tap()

    // TextField should exist
    XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 2))
}

func testCanTypeAndSubmitCommand() {
    let app = XCUIApplication()
    app.launch()

    app.buttons["Voice Command"].tap()

    let textField = app.textFields.firstMatch
    textField.tap()
    textField.typeText("continue")

    // Submit
    app.buttons["Send"].tap()

    // Sheet should dismiss
    XCTAssertFalse(textField.waitForExistence(timeout: 2))
}
```

### Verification Command
```bash
grep -r "presentTextInputController" ClaudeWatch/ && echo "FAIL" || echo "PASS"
```

---

## T03: Add State Persistence (Codable)

### Description
Make `WatchState` and related models `Codable` and persist to UserDefaults. State should survive app termination.

### Files
- `ClaudeWatch/Services/WatchService.swift`

### Changes Required

1. Add Codable conformance to all models:
```swift
enum SessionStatus: String, Codable {
    case idle, running, waiting, completed, failed
}

enum PermissionMode: String, Codable {
    case normal, autoAccept, plan
}

struct PendingAction: Identifiable, Codable {
    let id: String
    let type: String
    let title: String
    let description: String
    var filePath: String?
    var command: String?
    let timestamp: Date
    var status: String
}

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

2. Add save/restore methods to WatchService:
```swift
private let stateKey = "com.claudewatch.savedState"

func saveState() {
    guard let data = try? JSONEncoder().encode(state) else { return }
    UserDefaults.standard.set(data, forKey: stateKey)
}

func restoreState() {
    guard let data = UserDefaults.standard.data(forKey: stateKey),
          let restored = try? JSONDecoder().decode(WatchState.self, from: data) else { return }
    self.state = restored
}
```

3. Call `saveState()` after state changes
4. Call `restoreState()` in `init()`

### Acceptance Criteria
- [ ] WatchState conforms to Codable
- [ ] PendingAction conforms to Codable
- [ ] SessionStatus conforms to Codable
- [ ] PermissionMode conforms to Codable
- [ ] State is saved to UserDefaults after changes
- [ ] State is restored on app launch

### Definition of Done
1. All models compile with Codable conformance
2. State persists across app restarts
3. Pending actions survive app termination

### Unit Tests
```swift
// File: ClaudeWatchTests/StatePersistenceTests.swift

import XCTest
@testable import ClaudeWatch

final class StatePersistenceTests: XCTestCase {

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.claudewatch.savedState")
    }

    func testWatchStateIsCodable() {
        let state = WatchState(
            taskName: "Test Task",
            taskDescription: "Description",
            progress: 0.5,
            status: .running,
            pendingActions: [],
            mode: .normal,
            model: "opus"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertNoThrow(try encoder.encode(state))

        let data = try! encoder.encode(state)
        let decoded = try! decoder.decode(WatchState.self, from: data)

        XCTAssertEqual(decoded.taskName, "Test Task")
        XCTAssertEqual(decoded.progress, 0.5)
        XCTAssertEqual(decoded.status, .running)
    }

    func testPendingActionIsCodable() {
        let action = PendingAction(
            id: "123",
            type: "file_edit",
            title: "Edit file",
            description: "Editing main.swift",
            filePath: "/path/to/file",
            command: nil,
            timestamp: Date(),
            status: "pending"
        )

        let encoder = JSONEncoder()
        XCTAssertNoThrow(try encoder.encode(action))
    }

    func testStatePersistsToUserDefaults() {
        let service = WatchService.shared
        service.state.taskName = "Persisted Task"
        service.state.progress = 0.75
        service.saveState()

        // Simulate app restart by creating new instance reading from UserDefaults
        let data = UserDefaults.standard.data(forKey: "com.claudewatch.savedState")
        XCTAssertNotNil(data)

        let restored = try! JSONDecoder().decode(WatchState.self, from: data!)
        XCTAssertEqual(restored.taskName, "Persisted Task")
        XCTAssertEqual(restored.progress, 0.75)
    }

    func testStateRestoredOnInit() {
        // Save state
        let state = WatchState(taskName: "Restored Task", progress: 0.25)
        let data = try! JSONEncoder().encode(state)
        UserDefaults.standard.set(data, forKey: "com.claudewatch.savedState")

        // Create service (should restore)
        let service = WatchService()
        service.restoreState()

        XCTAssertEqual(service.state.taskName, "Restored Task")
    }
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/PersistenceTests.swift

func testStateSurvivesAppRestart() {
    let app = XCUIApplication()
    app.launch()

    // Wait for initial state
    sleep(2)

    // Terminate and relaunch
    app.terminate()
    app.launch()

    // App should launch without crash and show restored state
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
}
```

### Verification Command
```bash
# Check Codable conformance compiles
xcodebuild -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build 2>&1 | grep -i "error" && echo "FAIL" || echo "PASS"
```

---

## T04: Create WatchService Protocol for Testability

### Description
Extract a protocol from WatchService to enable dependency injection and mocking in tests.

### Files
- `ClaudeWatch/Services/WatchService.swift` (modify)
- `ClaudeWatch/Services/WatchServiceProtocol.swift` (create)
- `ClaudeWatchTests/Mocks/MockWatchService.swift` (create)

### New File: WatchServiceProtocol.swift
```swift
import Foundation
import Combine

protocol WatchServiceProtocol: ObservableObject {
    var state: WatchState { get }
    var connectionStatus: ConnectionStatus { get }

    func connect()
    func disconnect()
    func approveAction(_ actionId: String)
    func rejectAction(_ actionId: String)
    func approveAllActions()
    func sendPrompt(_ text: String)
    func cycleMode()
    func setMode(_ mode: PermissionMode)
}
```

### New File: MockWatchService.swift
```swift
import Foundation
import Combine

@MainActor
final class MockWatchService: WatchServiceProtocol, ObservableObject {
    @Published var state = WatchState()
    @Published var connectionStatus: ConnectionStatus = .connected

    // Tracking properties for test verification
    var connectCalled = false
    var disconnectCalled = false
    var approvedActionIds: [String] = []
    var rejectedActionIds: [String] = []
    var sentPrompts: [String] = []
    var modeCycleCount = 0

    func connect() {
        connectCalled = true
        connectionStatus = .connected
    }

    func disconnect() {
        disconnectCalled = true
        connectionStatus = .disconnected
    }

    func approveAction(_ actionId: String) {
        approvedActionIds.append(actionId)
        state.pendingActions.removeAll { $0.id == actionId }
    }

    func rejectAction(_ actionId: String) {
        rejectedActionIds.append(actionId)
        state.pendingActions.removeAll { $0.id == actionId }
    }

    func approveAllActions() {
        approvedActionIds.append(contentsOf: state.pendingActions.map(\.id))
        state.pendingActions.removeAll()
    }

    func sendPrompt(_ text: String) {
        sentPrompts.append(text)
    }

    func cycleMode() {
        modeCycleCount += 1
        state.mode = state.mode.next()
    }

    func setMode(_ mode: PermissionMode) {
        state.mode = mode
    }

    // Test helpers
    func addPendingAction(_ action: PendingAction) {
        state.pendingActions.append(action)
    }

    func reset() {
        connectCalled = false
        disconnectCalled = false
        approvedActionIds = []
        rejectedActionIds = []
        sentPrompts = []
        modeCycleCount = 0
        state = WatchState()
    }
}
```

### Modify WatchService.swift
```swift
// Add protocol conformance
final class WatchService: WatchServiceProtocol, ObservableObject {
    // ... existing implementation
}
```

### Acceptance Criteria
- [ ] WatchServiceProtocol exists with all public methods
- [ ] WatchService conforms to WatchServiceProtocol
- [ ] MockWatchService exists and conforms to WatchServiceProtocol
- [ ] MockWatchService tracks all method calls for verification

### Definition of Done
1. Protocol file exists at `ClaudeWatch/Services/WatchServiceProtocol.swift`
2. Mock file exists at `ClaudeWatchTests/Mocks/MockWatchService.swift`
3. WatchService compiles with protocol conformance
4. MockWatchService can be used in tests

### Unit Tests
```swift
// File: ClaudeWatchTests/WatchServiceProtocolTests.swift

import XCTest
@testable import ClaudeWatch

final class WatchServiceProtocolTests: XCTestCase {

    func testWatchServiceConformsToProtocol() {
        let service: any WatchServiceProtocol = WatchService.shared
        XCTAssertNotNil(service)
    }

    func testMockWatchServiceConformsToProtocol() {
        let mock: any WatchServiceProtocol = MockWatchService()
        XCTAssertNotNil(mock)
    }

    func testMockTracksApproveAction() async {
        let mock = MockWatchService()
        mock.addPendingAction(PendingAction(
            id: "test-123",
            type: "file_edit",
            title: "Test",
            description: "Test action",
            timestamp: Date(),
            status: "pending"
        ))

        await MainActor.run {
            mock.approveAction("test-123")
        }

        XCTAssertEqual(mock.approvedActionIds, ["test-123"])
        XCTAssertTrue(mock.state.pendingActions.isEmpty)
    }

    func testMockTracksSendPrompt() async {
        let mock = MockWatchService()

        await MainActor.run {
            mock.sendPrompt("continue")
            mock.sendPrompt("run tests")
        }

        XCTAssertEqual(mock.sentPrompts, ["continue", "run tests"])
    }

    func testMockTracksModeChanges() async {
        let mock = MockWatchService()
        XCTAssertEqual(mock.state.mode, .normal)

        await MainActor.run {
            mock.cycleMode()
        }

        XCTAssertEqual(mock.modeCycleCount, 1)
        XCTAssertEqual(mock.state.mode, .autoAccept)
    }
}
```

### Verification Command
```bash
# Verify protocol file exists and compiles
test -f ClaudeWatch/Services/WatchServiceProtocol.swift && echo "Protocol file exists" || echo "FAIL: Protocol file missing"
```

---

## T05: Add Accessibility Labels

### Description
Add VoiceOver accessibility labels and hints to all interactive elements.

### File
`ClaudeWatch/Views/MainView.swift`

### Changes Required

Add to each element:

```swift
// 1. Settings button (around line 37)
Button { showingSettings = true } label: {
    Image(systemName: "gear")
}
.accessibilityLabel("Settings")
.accessibilityHint("Opens server URL configuration")

// 2. Approve All button (around line 180)
Button { service.approveAllActions() } label: {
    Text("Approve All")
}
.accessibilityLabel("Approve All Actions")
.accessibilityHint("Approves all \(service.state.pendingActions.count) pending actions at once")

// 3. Approve button in ActionCard (around line 232)
Button { service.approveAction(action.id) } label: {
    Image(systemName: "checkmark")
}
.accessibilityLabel("Approve")
.accessibilityHint("Approves \(action.title)")

// 4. Reject button in ActionCard (around line 249)
Button { service.rejectAction(action.id) } label: {
    Image(systemName: "xmark")
}
.accessibilityLabel("Reject")
.accessibilityHint("Rejects \(action.title)")

// 5. Quick action buttons (around line 293)
Button { service.sendPrompt(prompt) } label: {
    Text(prompt)
}
.accessibilityLabel(prompt)
.accessibilityHint("Sends '\(prompt)' command to Claude")

// 6. Voice button (around line 320)
Button { showingVoiceInput = true } label: {
    Image(systemName: "mic.fill")
}
.accessibilityLabel("Voice Command")
.accessibilityHint("Opens voice input to send a command")

// 7. Mode switcher (around line 344)
Button { service.cycleMode() } label: {
    Text(service.state.mode.displayName)
}
.accessibilityLabel("Current mode: \(service.state.mode.displayName)")
.accessibilityHint("Tap to switch to \(service.state.mode.next().displayName) mode")

// 8. Connection status indicator
Circle()
    .fill(connectionColor)
    .accessibilityLabel(service.connectionStatus == .connected ? "Connected" : "Disconnected")
    .accessibilityHidden(false)
```

### Acceptance Criteria
- [ ] Settings button has accessibility label
- [ ] Approve All button has accessibility label with count
- [ ] Each Approve button has accessibility label
- [ ] Each Reject button has accessibility label
- [ ] All quick action buttons have accessibility labels
- [ ] Voice button has accessibility label
- [ ] Mode switcher has accessibility label with current and next mode
- [ ] Connection indicator has accessibility label

### Definition of Done
1. All 8 element types have `.accessibilityLabel()`
2. Dynamic elements include contextual info (count, action name)
3. VoiceOver can navigate all interactive elements
4. No "Button" or "Image" generic labels

### Unit Tests
```swift
// File: ClaudeWatchTests/AccessibilityTests.swift

import XCTest
@testable import ClaudeWatch

final class AccessibilityTests: XCTestCase {

    func testAccessibilityLabelsExistInSource() {
        let source = try! String(contentsOfFile: "ClaudeWatch/Views/MainView.swift")

        // Check for required accessibility modifiers
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Settings\")"),
                      "Settings button missing accessibility label")
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Voice Command\")"),
                      "Voice button missing accessibility label")
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Approve\")"),
                      "Approve button missing accessibility label")
        XCTAssertTrue(source.contains(".accessibilityLabel(\"Reject\")"),
                      "Reject button missing accessibility label")
    }

    func testAccessibilityHintsExist() {
        let source = try! String(contentsOfFile: "ClaudeWatch/Views/MainView.swift")

        // Should have hints for context
        XCTAssertTrue(source.contains(".accessibilityHint("),
                      "No accessibility hints found")
    }
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/AccessibilityUITests.swift

func testVoiceOverCanFindAllButtons() {
    let app = XCUIApplication()
    app.launch()

    // These should be findable by accessibility label
    XCTAssertTrue(app.buttons["Settings"].exists)
    XCTAssertTrue(app.buttons["Voice Command"].exists)
}

func testApproveButtonHasAccessibilityLabel() {
    let app = XCUIApplication()
    app.launch()

    // If there are pending actions, approve buttons should exist
    let approveButtons = app.buttons.matching(identifier: "Approve")
    // At minimum, the label should be queryable
    XCTAssertNotNil(approveButtons)
}
```

### Verification Command
```bash
grep -c "accessibilityLabel" ClaudeWatch/Views/MainView.swift | xargs -I {} test {} -ge 8 && echo "PASS: 8+ accessibility labels" || echo "FAIL: Need more accessibility labels"
```

---

## T06: Add Recording Indicator UI

### Description
Show a visible indicator when the microphone is active (required by App Store Guideline 2.5.14).

### File
`ClaudeWatch/Views/MainView.swift` (in VoiceInputSheet)

### Changes Required

Add state tracking:
```swift
struct VoiceInputSheet: View {
    @State private var isRecording = false
    // ... existing state
}
```

Add recording indicator view:
```swift
// Add at top of VoiceInputSheet body
if isRecording {
    HStack(spacing: 6) {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .modifier(PulseAnimation())
        Text("Recording")
            .font(.caption2)
            .foregroundColor(.red)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background(Color.red.opacity(0.15))
    .clipShape(Capsule())
    .accessibilityLabel("Recording in progress")
}
```

Add pulse animation modifier:
```swift
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
```

Set `isRecording = true` when mic starts, `false` when stops.

### Acceptance Criteria
- [ ] Red recording indicator appears when microphone is active
- [ ] Indicator pulses/animates to draw attention
- [ ] Indicator disappears when recording stops
- [ ] Indicator has accessibility label

### Definition of Done
1. Recording indicator visible during voice input
2. Animation is smooth and non-distracting
3. Complies with App Store Guideline 2.5.14

### Unit Tests
```swift
// File: ClaudeWatchTests/RecordingIndicatorTests.swift

func testRecordingIndicatorExistsInSource() {
    let source = try! String(contentsOfFile: "ClaudeWatch/Views/MainView.swift")

    XCTAssertTrue(source.contains("isRecording"), "isRecording state not found")
    XCTAssertTrue(source.contains("Recording"), "Recording label not found")
    XCTAssertTrue(source.contains("Color.red"), "Red indicator color not found")
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/RecordingIndicatorUITests.swift

func testRecordingIndicatorAppearsWhenRecording() {
    let app = XCUIApplication()
    app.launch()

    // Open voice input
    app.buttons["Voice Command"].tap()

    // Start recording (implementation-dependent)
    // The recording indicator should appear
    let recordingLabel = app.staticTexts["Recording"]
    // Note: May need to trigger actual recording in test
}
```

### Verification Command
```bash
grep -q "isRecording" ClaudeWatch/Views/MainView.swift && grep -q "Recording" ClaudeWatch/Views/MainView.swift && echo "PASS" || echo "FAIL"
```

---

## T07: Add AI Consent Dialog

### Description
Show a one-time consent dialog explaining that data is sent to Claude API (required by App Store Guideline 5.1.2(i)).

### Files
- `ClaudeWatch/Views/Sheets/ConsentSheet.swift` (create)
- `ClaudeWatch/App/ClaudeWatchApp.swift` (modify)

### New File: ConsentSheet.swift
```swift
import SwiftUI

struct ConsentSheet: View {
    @AppStorage("hasConsentedToAI") var hasConsented = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("Data Sharing Notice")
                    .font(.headline)

                Text("ClaudeWatch sends your voice commands and text input to Anthropic's Claude AI for processing.")
                    .font(.caption)
                    .multilineTextAlignment(.center)

                Text("Your data is:")
                    .font(.caption)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Transmitted securely (encrypted)", systemImage: "lock.fill")
                    Label("Not stored permanently by Anthropic", systemImage: "trash.fill")
                    Label("Used only to process your request", systemImage: "cpu.fill")
                }
                .font(.caption2)

                Button {
                    hasConsented = true
                    dismiss()
                } label: {
                    Text("I Understand & Agree")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    // Link to privacy policy
                } label: {
                    Text("View Privacy Policy")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
            .padding()
        }
        .interactiveDismissDisabled(!hasConsented)
    }
}
```

### Modify ClaudeWatchApp.swift
```swift
@main
struct ClaudeWatchApp: App {
    @AppStorage("hasConsentedToAI") var hasConsented = false

    var body: some Scene {
        WindowGroup {
            MainView()
                .sheet(isPresented: .constant(!hasConsented)) {
                    ConsentSheet()
                }
        }
    }
}
```

### Acceptance Criteria
- [ ] Consent dialog appears on first launch
- [ ] Dialog cannot be dismissed without accepting
- [ ] Consent state persists across launches
- [ ] Dialog explains Claude API data sharing
- [ ] Link to privacy policy exists

### Definition of Done
1. First launch shows consent dialog
2. Second launch does not show dialog
3. Dialog clearly mentions "Anthropic" and "Claude"
4. User must tap "I Understand & Agree" to proceed

### Unit Tests
```swift
// File: ClaudeWatchTests/ConsentTests.swift

func testConsentSheetExists() {
    XCTAssertTrue(FileManager.default.fileExists(atPath: "ClaudeWatch/Views/Sheets/ConsentSheet.swift"))
}

func testConsentStateDefaultsToFalse() {
    UserDefaults.standard.removeObject(forKey: "hasConsentedToAI")
    let hasConsented = UserDefaults.standard.bool(forKey: "hasConsentedToAI")
    XCTAssertFalse(hasConsented)
}

func testConsentStatePersists() {
    UserDefaults.standard.set(true, forKey: "hasConsentedToAI")
    let hasConsented = UserDefaults.standard.bool(forKey: "hasConsentedToAI")
    XCTAssertTrue(hasConsented)
}
```

### Integration Tests
```swift
// File: ClaudeWatchUITests/ConsentUITests.swift

func testConsentDialogAppearsOnFirstLaunch() {
    let app = XCUIApplication()
    app.launchArguments = ["-hasConsentedToAI", "NO"]
    app.launch()

    // Consent dialog should be visible
    XCTAssertTrue(app.staticTexts["Data Sharing Notice"].waitForExistence(timeout: 3))
}

func testConsentDialogNotShownAfterAccepting() {
    let app = XCUIApplication()
    app.launchArguments = ["-hasConsentedToAI", "YES"]
    app.launch()

    // Consent dialog should NOT be visible
    XCTAssertFalse(app.staticTexts["Data Sharing Notice"].exists)
}

func testMustAcceptToProceeed() {
    let app = XCUIApplication()
    app.launchArguments = ["-hasConsentedToAI", "NO"]
    app.launch()

    // Try to dismiss by swiping (should fail)
    app.swipeDown()

    // Dialog should still be visible
    XCTAssertTrue(app.staticTexts["Data Sharing Notice"].exists)
}
```

### Verification Command
```bash
test -f ClaudeWatch/Views/Sheets/ConsentSheet.swift && echo "PASS: ConsentSheet exists" || echo "FAIL: ConsentSheet missing"
```

---

## T08: Fix Widget Data with App Groups

### Description
Enable real data sharing between the app and complications using App Groups.

### Dependencies
- T03 (State Persistence) must be completed first

### Files
- `ClaudeWatch/Services/WatchService.swift` (modify)
- `ClaudeWatch/Complications/ComplicationViews.swift` (modify)
- `ClaudeWatch.xcodeproj/project.pbxproj` (add capability)
- `ClaudeWatch/ClaudeWatch.entitlements` (create)

### Step 1: Create Entitlements File
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.anthropic.claudewatch</string>
    </array>
</dict>
</plist>
```

### Step 2: Modify WatchService.swift
```swift
private let appGroupID = "group.com.anthropic.claudewatch"

func saveStateToAppGroup() {
    guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

    defaults.set(state.taskName, forKey: "taskName")
    defaults.set(state.progress, forKey: "progress")
    defaults.set(state.pendingActions.count, forKey: "pendingCount")
    defaults.set(state.mode.rawValue, forKey: "mode")
    defaults.set(state.model, forKey: "model")
    defaults.set(connectionStatus == .connected, forKey: "isConnected")
    defaults.set(Date(), forKey: "lastUpdate")
}
```

Call `saveStateToAppGroup()` whenever state changes.

### Step 3: Modify ComplicationViews.swift
```swift
struct ClaudeProvider: TimelineProvider {
    private let appGroupID = "group.com.anthropic.claudewatch"

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupID)

        let entry = ClaudeEntry(
            date: Date(),
            taskName: defaults?.string(forKey: "taskName") ?? "IDLE",
            progress: defaults?.double(forKey: "progress") ?? 0,
            pendingCount: defaults?.integer(forKey: "pendingCount") ?? 0,
            model: defaults?.string(forKey: "model") ?? "OPUS",
            isConnected: defaults?.bool(forKey: "isConnected") ?? false
        )

        // Refresh every 60 seconds
        let refreshDate = Date().addingTimeInterval(60)
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}
```

### Acceptance Criteria
- [ ] Entitlements file exists with App Group
- [ ] WatchService saves state to App Group UserDefaults
- [ ] ComplicationViews reads from App Group UserDefaults
- [ ] Complications show real task name
- [ ] Complications show real progress
- [ ] Complications show real pending count

### Definition of Done
1. Widget shows actual task name (not hardcoded)
2. Widget shows actual progress percentage
3. Widget updates within 60 seconds of state change
4. Works when app is in background

### Unit Tests
```swift
// File: ClaudeWatchTests/AppGroupTests.swift

func testCanWriteToAppGroup() {
    let defaults = UserDefaults(suiteName: "group.com.anthropic.claudewatch")
    XCTAssertNotNil(defaults, "App Group UserDefaults should be accessible")

    defaults?.set("Test Task", forKey: "taskName")
    XCTAssertEqual(defaults?.string(forKey: "taskName"), "Test Task")
}

func testCanReadFromAppGroup() {
    let defaults = UserDefaults(suiteName: "group.com.anthropic.claudewatch")
    defaults?.set(0.75, forKey: "progress")
    defaults?.set(3, forKey: "pendingCount")

    XCTAssertEqual(defaults?.double(forKey: "progress"), 0.75)
    XCTAssertEqual(defaults?.integer(forKey: "pendingCount"), 3)
}
```

### Verification Command
```bash
test -f ClaudeWatch/ClaudeWatch.entitlements && grep -q "application-groups" ClaudeWatch/ClaudeWatch.entitlements && echo "PASS" || echo "FAIL"
```

---

## T09: Split MainView.swift into Components

### Description
Refactor the 526-line MainView.swift into focused, testable components.

### Current Structure
```
MainView.swift (526 lines)
├── MainView
├── StatusHeader
├── PendingActionsSection
├── ActionCard
├── QuickActionsBar
├── VoiceButton
├── ModeSwitcher
├── VoiceInputSheet
└── SettingsSheet
```

### Target Structure
```
Views/
├── MainView.swift (~50 lines)
├── Components/
│   ├── StatusHeader.swift
│   ├── PendingActionsSection.swift
│   ├── ActionCard.swift
│   ├── QuickActionsBar.swift
│   ├── VoiceButton.swift
│   └── ModeSwitcher.swift
└── Sheets/
    ├── VoiceInputSheet.swift
    ├── SettingsSheet.swift
    └── ConsentSheet.swift (from T07)
```

### Extraction Instructions

For each component:
1. Create new file with same struct name
2. Add `import SwiftUI`
3. Add `@EnvironmentObject var service: WatchService` if needed
4. Move the struct to new file
5. Update MainView.swift to use the extracted component

### Example: StatusHeader.swift
```swift
import SwiftUI

struct StatusHeader: View {
    @EnvironmentObject var service: WatchService

    var body: some View {
        // Content from lines 52-156 of MainView.swift
    }

    private var connectionColor: Color {
        // ...
    }
}

#Preview {
    StatusHeader()
        .environmentObject(WatchService.shared)
}
```

### Acceptance Criteria
- [ ] MainView.swift is under 100 lines
- [ ] Each component is in its own file
- [ ] Each component has a Preview
- [ ] All components compile
- [ ] App looks identical to before

### Definition of Done
1. 8 new files created in Views/Components/ and Views/Sheets/
2. MainView.swift is under 100 lines
3. App compiles without errors
4. UI renders identically to before refactor

### Unit Tests
```swift
// File: ClaudeWatchTests/FileStructureTests.swift

func testComponentFilesExist() {
    let expectedFiles = [
        "ClaudeWatch/Views/Components/StatusHeader.swift",
        "ClaudeWatch/Views/Components/PendingActionsSection.swift",
        "ClaudeWatch/Views/Components/ActionCard.swift",
        "ClaudeWatch/Views/Components/QuickActionsBar.swift",
        "ClaudeWatch/Views/Components/VoiceButton.swift",
        "ClaudeWatch/Views/Components/ModeSwitcher.swift",
        "ClaudeWatch/Views/Sheets/VoiceInputSheet.swift",
        "ClaudeWatch/Views/Sheets/SettingsSheet.swift",
    ]

    for file in expectedFiles {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: file),
            "Missing file: \(file)"
        )
    }
}

func testMainViewIsSmall() {
    let content = try! String(contentsOfFile: "ClaudeWatch/Views/MainView.swift")
    let lineCount = content.components(separatedBy: "\n").count
    XCTAssertLessThan(lineCount, 100, "MainView.swift should be under 100 lines, got \(lineCount)")
}
```

### Verification Command
```bash
wc -l ClaudeWatch/Views/MainView.swift | awk '{if ($1 < 100) print "PASS: "$1" lines"; else print "FAIL: "$1" lines (should be <100)"}'
```

---

## T10: Add Liquid Glass Materials

### Description
Replace opacity-based backgrounds with iOS 26 Liquid Glass materials.

### Dependencies
- T09 (Split MainView) should be done first for easier editing

### Files to Modify
All component files in `Views/Components/` and `Views/Sheets/`

### Replacements

| Find | Replace With |
|------|--------------|
| `.background(Color.green.opacity(0.2))` | `.background(.regularMaterial)` |
| `.background(Color.red.opacity(0.2))` | `.background(.regularMaterial)` |
| `.background(Color.gray.opacity(0.15))` | `.background(.thinMaterial)` |
| `.background(Color.blue.opacity(0.2))` | `.background(.regularMaterial)` |
| `.background(Color(...).opacity(...))` | `.background(.regularMaterial)` |

### Notes
- Use `.regularMaterial` for primary surfaces
- Use `.thinMaterial` for subtle backgrounds
- Use `.ultraThinMaterial` for overlays
- These will automatically become Liquid Glass on iOS 26+

### Acceptance Criteria
- [ ] No `.opacity()` backgrounds remain
- [ ] All backgrounds use SwiftUI materials
- [ ] UI looks good on iOS 15+ (materials are backward compatible)

### Definition of Done
1. Zero instances of `.background(Color.*.opacity(` in codebase
2. All backgrounds use `.regularMaterial`, `.thinMaterial`, or `.ultraThinMaterial`
3. Visual appearance is consistent across components

### Unit Tests
```swift
// File: ClaudeWatchTests/LiquidGlassTests.swift

func testNoOpacityBackgroundsExist() {
    let viewsDir = URL(fileURLWithPath: "ClaudeWatch/Views")
    let files = try! FileManager.default.contentsOfDirectory(
        at: viewsDir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ).flatMap { url -> [URL] in
        if url.hasDirectoryPath {
            return try! FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
        }
        return [url]
    }.filter { $0.pathExtension == "swift" }

    for file in files {
        let content = try! String(contentsOf: file)
        XCTAssertFalse(
            content.contains(".opacity("),
            "Found .opacity() in \(file.lastPathComponent) - use materials instead"
        )
    }
}

func testMaterialsAreUsed() {
    let viewsDir = "ClaudeWatch/Views"
    let result = shell("grep -r 'Material' \(viewsDir) | wc -l")
    let count = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    XCTAssertGreaterThan(count, 5, "Should have multiple Material usages")
}
```

### Verification Command
```bash
grep -r "\.opacity(" ClaudeWatch/Views/ | grep -v "//" | wc -l | xargs -I {} test {} -eq 0 && echo "PASS: No opacity backgrounds" || echo "FAIL: Found opacity backgrounds"
```

---

## T11: Add Spring Animations

### Description
Add spring animations to all interactive elements for a polished feel.

### Dependencies
- T09 (Split MainView) should be done first

### Pattern to Apply

For every `Button`:
```swift
struct AnimatedButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
```

Or apply directly:
```swift
Button { ... } label: { ... }
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
```

### Elements to Animate
1. Approve button (ActionCard)
2. Reject button (ActionCard)
3. Approve All button
4. Quick action buttons
5. Voice button
6. Mode switcher button
7. Settings button

### Acceptance Criteria
- [ ] All buttons have scale animation on press
- [ ] Animation uses spring physics
- [ ] Animation duration is ~0.3s
- [ ] No jank or stuttering

### Definition of Done
1. 7+ buttons have spring animations
2. Animations feel responsive and smooth
3. No performance degradation

### Unit Tests
```swift
// File: ClaudeWatchTests/AnimationTests.swift

func testSpringAnimationsExist() {
    let viewsDir = "ClaudeWatch/Views"
    let result = shell("grep -r 'spring(response' \(viewsDir) | wc -l")
    let count = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    XCTAssertGreaterThanOrEqual(count, 5, "Should have spring animations")
}

func testScaleEffectUsed() {
    let viewsDir = "ClaudeWatch/Views"
    let result = shell("grep -r 'scaleEffect' \(viewsDir) | wc -l")
    let count = Int(result.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    XCTAssertGreaterThanOrEqual(count, 5, "Should have scale effects for animations")
}
```

### Verification Command
```bash
grep -r "spring(response" ClaudeWatch/Views/ | wc -l | xargs -I {} test {} -ge 5 && echo "PASS" || echo "FAIL: Need more spring animations"
```

---

## T12: Write Unit Tests

### Description
Create comprehensive unit tests for core functionality.

### Dependencies
- T03 (State Persistence)
- T04 (WatchService Protocol)

### Test Files to Create

```
ClaudeWatchTests/
├── Models/
│   ├── WatchStateTests.swift
│   ├── PendingActionTests.swift
│   └── PermissionModeTests.swift
├── Services/
│   ├── WatchServiceTests.swift
│   └── StatePersistenceTests.swift
├── Mocks/
│   └── MockWatchService.swift
└── Helpers/
    └── TestHelpers.swift
```

### WatchStateTests.swift
```swift
import XCTest
@testable import ClaudeWatch

final class WatchStateTests: XCTestCase {

    func testDefaultState() {
        let state = WatchState()
        XCTAssertEqual(state.taskName, "")
        XCTAssertEqual(state.progress, 0)
        XCTAssertEqual(state.status, .idle)
        XCTAssertTrue(state.pendingActions.isEmpty)
        XCTAssertEqual(state.mode, .normal)
    }

    func testStateEncoding() {
        let state = WatchState(
            taskName: "Test",
            progress: 0.5,
            status: .running
        )

        XCTAssertNoThrow(try JSONEncoder().encode(state))
    }

    func testStateDecoding() {
        let json = """
        {"taskName":"Test","progress":0.5,"status":"running","pendingActions":[],"mode":"normal","model":"opus"}
        """
        let data = json.data(using: .utf8)!

        XCTAssertNoThrow(try JSONDecoder().decode(WatchState.self, from: data))
    }

    func testStateRoundTrip() {
        let original = WatchState(
            taskName: "Round Trip Test",
            progress: 0.75,
            status: .waiting,
            mode: .autoAccept
        )

        let data = try! JSONEncoder().encode(original)
        let decoded = try! JSONDecoder().decode(WatchState.self, from: data)

        XCTAssertEqual(decoded.taskName, original.taskName)
        XCTAssertEqual(decoded.progress, original.progress)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.mode, original.mode)
    }
}
```

### PermissionModeTests.swift
```swift
import XCTest
@testable import ClaudeWatch

final class PermissionModeTests: XCTestCase {

    func testModeCycling() {
        XCTAssertEqual(PermissionMode.normal.next(), .autoAccept)
        XCTAssertEqual(PermissionMode.autoAccept.next(), .plan)
        XCTAssertEqual(PermissionMode.plan.next(), .normal)
    }

    func testModeDisplayNames() {
        XCTAssertFalse(PermissionMode.normal.displayName.isEmpty)
        XCTAssertFalse(PermissionMode.autoAccept.displayName.isEmpty)
        XCTAssertFalse(PermissionMode.plan.displayName.isEmpty)
    }

    func testModeIsCodable() {
        for mode in [PermissionMode.normal, .autoAccept, .plan] {
            let data = try! JSONEncoder().encode(mode)
            let decoded = try! JSONDecoder().decode(PermissionMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}
```

### WatchServiceTests.swift
```swift
import XCTest
@testable import ClaudeWatch

@MainActor
final class WatchServiceTests: XCTestCase {
    var mockService: MockWatchService!

    override func setUp() {
        mockService = MockWatchService()
    }

    override func tearDown() {
        mockService.reset()
    }

    func testApproveActionRemovesFromPending() {
        let action = PendingAction(
            id: "test-1",
            type: "file_edit",
            title: "Edit",
            description: "Test",
            timestamp: Date(),
            status: "pending"
        )
        mockService.addPendingAction(action)
        XCTAssertEqual(mockService.state.pendingActions.count, 1)

        mockService.approveAction("test-1")

        XCTAssertTrue(mockService.state.pendingActions.isEmpty)
        XCTAssertEqual(mockService.approvedActionIds, ["test-1"])
    }

    func testRejectActionRemovesFromPending() {
        let action = PendingAction(
            id: "test-2",
            type: "bash",
            title: "Run",
            description: "Test",
            timestamp: Date(),
            status: "pending"
        )
        mockService.addPendingAction(action)

        mockService.rejectAction("test-2")

        XCTAssertTrue(mockService.state.pendingActions.isEmpty)
        XCTAssertEqual(mockService.rejectedActionIds, ["test-2"])
    }

    func testApproveAllClearsAllPending() {
        mockService.addPendingAction(PendingAction(id: "1", type: "a", title: "A", description: "", timestamp: Date(), status: "pending"))
        mockService.addPendingAction(PendingAction(id: "2", type: "b", title: "B", description: "", timestamp: Date(), status: "pending"))
        mockService.addPendingAction(PendingAction(id: "3", type: "c", title: "C", description: "", timestamp: Date(), status: "pending"))

        mockService.approveAllActions()

        XCTAssertTrue(mockService.state.pendingActions.isEmpty)
        XCTAssertEqual(mockService.approvedActionIds.sorted(), ["1", "2", "3"])
    }

    func testCycleModeGoesInOrder() {
        XCTAssertEqual(mockService.state.mode, .normal)

        mockService.cycleMode()
        XCTAssertEqual(mockService.state.mode, .autoAccept)

        mockService.cycleMode()
        XCTAssertEqual(mockService.state.mode, .plan)

        mockService.cycleMode()
        XCTAssertEqual(mockService.state.mode, .normal)
    }

    func testSendPromptTracked() {
        mockService.sendPrompt("continue")
        mockService.sendPrompt("run tests")

        XCTAssertEqual(mockService.sentPrompts, ["continue", "run tests"])
    }

    func testConnectSetsStatus() {
        mockService.connectionStatus = .disconnected

        mockService.connect()

        XCTAssertTrue(mockService.connectCalled)
        XCTAssertEqual(mockService.connectionStatus, .connected)
    }

    func testDisconnectSetsStatus() {
        mockService.connectionStatus = .connected

        mockService.disconnect()

        XCTAssertTrue(mockService.disconnectCalled)
        XCTAssertEqual(mockService.connectionStatus, .disconnected)
    }
}
```

### Acceptance Criteria
- [ ] WatchStateTests covers encoding/decoding
- [ ] PermissionModeTests covers cycling and encoding
- [ ] WatchServiceTests covers all actions
- [ ] MockWatchService enables isolated testing
- [ ] 75%+ code coverage on models and services

### Definition of Done
1. All test files created
2. `xcodebuild test` passes
3. Code coverage report shows 75%+

### Verification Command
```bash
xcodebuild test -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' 2>&1 | tail -20
```

---

## T13: Write UI Tests

### Description
Create UI tests for critical user flows.

### Dependencies
- T05 (Accessibility Labels) - needed for finding elements

### Test File
`ClaudeWatchUITests/ClaudeWatchUITests.swift`

```swift
import XCTest

final class ClaudeWatchUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasConsentedToAI", "YES"]
    }

    // MARK: - Launch Tests

    func testAppLaunches() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    func testMainViewElementsExist() throws {
        app.launch()

        // Core elements should exist
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Voice Command"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings Tests

    func testOpenSettings() throws {
        app.launch()

        app.buttons["Settings"].tap()

        // Settings sheet should appear with URL field
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 2))
    }

    func testCloseSettings() throws {
        app.launch()
        app.buttons["Settings"].tap()

        // Swipe down to dismiss
        app.swipeDown()

        // Should be back to main view
        XCTAssertTrue(app.buttons["Voice Command"].waitForExistence(timeout: 2))
    }

    // MARK: - Voice Input Tests

    func testOpenVoiceInput() throws {
        app.launch()

        app.buttons["Voice Command"].tap()

        // Voice input sheet should appear
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 2))
    }

    func testCanTypeInVoiceInput() throws {
        app.launch()
        app.buttons["Voice Command"].tap()

        let textField = app.textFields.firstMatch
        textField.tap()
        textField.typeText("test command")

        XCTAssertEqual(textField.value as? String, "test command")
    }

    // MARK: - Mode Cycling Tests

    func testModeCycling() throws {
        app.launch()

        // Find mode button (text changes based on mode)
        let modeButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'mode' OR label CONTAINS 'Normal' OR label CONTAINS 'Auto' OR label CONTAINS 'Plan'")).firstMatch

        if modeButton.waitForExistence(timeout: 3) {
            let initialLabel = modeButton.label
            modeButton.tap()

            // Mode should change
            sleep(1)
            XCTAssertNotEqual(modeButton.label, initialLabel)
        }
    }

    // MARK: - Consent Dialog Tests

    func testConsentDialogAppears() throws {
        app.launchArguments = ["-hasConsentedToAI", "NO"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Data Sharing Notice"].waitForExistence(timeout: 3))
    }

    func testConsentCannotBeDismissedWithoutAccepting() throws {
        app.launchArguments = ["-hasConsentedToAI", "NO"]
        app.launch()

        // Try to dismiss
        app.swipeDown()

        // Should still be visible
        XCTAssertTrue(app.staticTexts["Data Sharing Notice"].exists)
    }

    func testAcceptingConsentDismissesDialog() throws {
        app.launchArguments = ["-hasConsentedToAI", "NO"]
        app.launch()

        app.buttons["I Understand & Agree"].tap()

        // Dialog should dismiss
        XCTAssertFalse(app.staticTexts["Data Sharing Notice"].waitForExistence(timeout: 2))
    }

    // MARK: - Accessibility Tests

    func testAllButtonsHaveAccessibilityLabels() throws {
        app.launch()

        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertFalse(
                button.label.isEmpty,
                "Button has empty accessibility label"
            )
            XCTAssertFalse(
                button.label == "Button",
                "Button has generic 'Button' label"
            )
        }
    }
}
```

### Acceptance Criteria
- [ ] App launch test passes
- [ ] Settings open/close test passes
- [ ] Voice input open/type test passes
- [ ] Mode cycling test passes
- [ ] Consent dialog tests pass
- [ ] Accessibility audit test passes

### Definition of Done
1. All UI tests pass
2. Tests run on watchOS Simulator
3. No flaky tests (run 3x to verify)

### Verification Command
```bash
xcodebuild test -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' -only-testing:ClaudeWatchUITests 2>&1 | grep -E "(Test Suite|Passed|Failed)"
```

---

## Execution Order

```
Phase 1: Critical Fixes (No Dependencies)
├── T01: Remove WKExtension ────────────┐
├── T02: Replace text input ────────────┼── Can run in parallel
├── T03: Add state persistence ─────────┤
└── T04: Create WatchService protocol ──┘

Phase 2: Compliance (Some Dependencies)
├── T05: Add accessibility labels ──────┐
├── T06: Add recording indicator ───────┼── Can run in parallel
├── T07: Add AI consent dialog ─────────┘
└── T08: Fix widget data ─────────────────── Depends on T03

Phase 3: Polish (After Split)
├── T09: Split MainView.swift ────────────── Must be first in phase
├── T10: Add Liquid Glass ────────────────── Depends on T09
└── T11: Add spring animations ───────────── Depends on T09

Phase 4: Testing (After Core Complete)
├── T12: Write unit tests ────────────────── Depends on T03, T04
└── T13: Write UI tests ──────────────────── Depends on T05
```

---

## Agent Execution Notes

### For Each Task:
1. Read the task completely
2. Verify dependencies are complete
3. Make changes to specified files
4. Run verification command
5. Run unit tests if provided
6. Run integration tests if provided
7. Commit with message: `feat(T##): <task description>`

### Success Criteria:
- Verification command returns "PASS"
- All unit tests pass
- All integration tests pass
- No compiler errors
- No new warnings

### Failure Recovery:
- If verification fails, read error and fix
- If tests fail, debug and fix
- If stuck, skip to next task and return later
- Document blockers in commit message
