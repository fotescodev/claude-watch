# CarPlay Claude - MVP Specification

## Document Info
- **Version**: 1.0.0
- **Date**: 2025-01-17
- **Status**: Draft
- **Based on**: Claude Watch v1.0

---

## 1. Executive Summary

**CarPlay Claude** extends the existing Claude Watch ecosystem to provide hands-free, eyes-free code approval and interaction while driving. It leverages the same cloud infrastructure, pairing mechanism, and iOS companion app to deliver a seamless "start anywhere, continue anywhere" experience.

### Core Value Proposition
> "Start Claude Code in your terminal, scan a QR code, and control it from your Watch on the train, your car on the commute, or your phone anywhere else."

### MVP Scope
- Steering wheel button controls (◀◀ reject, ▶▶ approve)
- Voice interaction via Siri/call button
- Audio summaries of pending approvals
- Now Playing-style UI for quick glances
- Shared pairing with Watch via iOS companion app

---

## 2. Architecture Overview

### 2.1 System Context

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPER LAPTOP                                │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                         Claude Code (Terminal)                        │   │
│  │                                                                       │   │
│  │   $ claude                                                            │   │
│  │   Pairing code: ABC-123                                               │   │
│  │   Scan QR or enter code on your device                                │   │
│  │                                                                       │   │
│  │   ┌─────────────────┐                                                 │   │
│  │   │  MCP Server     │──────┐                                          │   │
│  │   │  (server.py)    │      │                                          │   │
│  │   └─────────────────┘      │                                          │   │
│  └────────────────────────────│──────────────────────────────────────────┘   │
└───────────────────────────────│──────────────────────────────────────────────┘
                                │
                                │ WebSocket / HTTPS
                                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUD RELAY                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │              claude-watch.fotescodev.workers.dev                      │   │
│  │                                                                       │   │
│  │   - Pairing code generation/validation                                │   │
│  │   - Session state sync                                                │   │
│  │   - APNs push notification relay                                      │   │
│  │   - Request/response queue                                            │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────│────────────────────────────────────────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
          ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  APPLE WATCH    │     │   iPHONE APP    │     │    CARPLAY      │
│                 │     │  (Companion)    │     │                 │
│  - Quick glance │     │                 │     │  - Voice-first  │
│  - Haptic       │     │  - QR Scanner   │     │  - Steering     │
│  - Tap approve  │     │  - Settings     │     │    wheel ctrl   │
│                 │     │  - Pairing mgr  │     │  - Audio cues   │
│                 │◀───▶│  - Shared state │◀───▶│                 │
│  WatchService   │     │  - App Groups   │     │  CarPlayScene   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │     │
                              │     │ App Group
                              │     │ (Shared UserDefaults)
                              ▼     ▼
                        ┌─────────────────┐
                        │ SharedService   │
                        │                 │
                        │ - pairingId     │
                        │ - deviceToken   │
                        │ - pendingActions│
                        │ - sessionState  │
                        └─────────────────┘
```

### 2.2 New Components (MVP)

| Component | Type | Purpose |
|-----------|------|---------|
| `ClaudeMobileApp` | iOS App | Companion app for Watch + CarPlay |
| `CarPlaySceneDelegate` | CarPlay | CarPlay scene management |
| `CarPlayService` | Service | CarPlay-specific state & audio |
| `SharedService` | Shared | App Group data sync |
| `QRScannerView` | SwiftUI | Camera-based QR pairing |

---

## 3. Pairing Flow

### 3.1 QR Code Pairing (New)

The iOS companion app adds QR code scanning for faster pairing:

```
┌─────────────────────────────────────────────────────────────────┐
│                     TERMINAL (Claude Code)                       │
│                                                                  │
│   $ claude                                                       │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                                                          │  │
│   │      ████████████████████████████                        │  │
│   │      ██ ▄▄▄▄▄ █▄▄ ▄█▀ █ ▄▄▄▄▄ ██                        │  │
│   │      ██ █   █ █▄▀▀██▄ █ █   █ ██                        │  │
│   │      ██ █▄▄▄█ █ ▄ ▀██▄█ █▄▄▄█ ██                        │  │
│   │      ██▄▄▄▄▄▄▄█ █▄▀ █▄█▄▄▄▄▄▄▄██                        │  │
│   │      ██████████████████████████                        │  │
│   │                                                          │  │
│   │      Pairing Code: ABC-123                               │  │
│   │      Scan QR with Claude Watch iOS app                   │  │
│   │                                                          │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ User scans QR
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      iPHONE APP                                  │
│                                                                  │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │                                                          │  │
│   │           ┌─────────────────────────────┐                │  │
│   │           │                             │                │  │
│   │           │      📷 Camera View         │                │  │
│   │           │                             │                │  │
│   │           │   [  Scanning for QR...  ]  │                │  │
│   │           │                             │                │  │
│   │           └─────────────────────────────┘                │  │
│   │                                                          │  │
│   │   ─────────── OR ───────────                             │  │
│   │                                                          │  │
│   │   Enter code manually: [ABC-123]                         │  │
│   │                                                          │  │
│   └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
                              │
                              │ Validates with cloud relay
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     PAIRING COMPLETE                             │
│                                                                  │
│   ✓ Watch: Paired via App Group                                  │
│   ✓ CarPlay: Paired via App Group                                │
│   ✓ Push notifications: Registered                               │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 3.2 QR Code Format

```
claude-watch://pair?code=ABC-123&server=wss://claude-watch.fotescodev.workers.dev
```

| Field | Description |
|-------|-------------|
| `code` | 6-char pairing code (alphanumeric) |
| `server` | Cloud relay URL (optional, for enterprise) |

### 3.3 Shared Pairing State

All paired devices share state via App Groups:

```swift
// App Group: group.com.claudewatch.shared
struct SharedPairingState: Codable {
    var pairingId: String
    var cloudServerURL: String
    var deviceToken: String?
    var pairedAt: Date
    var lastSync: Date

    // Which interfaces are active
    var watchActive: Bool
    var carPlayActive: Bool
    var phoneActive: Bool
}
```

---

## 4. CarPlay Interface

### 4.1 Template Strategy

CarPlay apps must use Apple's template system. For Claude, we use:

| Template | Use Case |
|----------|----------|
| `CPNowPlayingTemplate` | Primary UI - approval queue as "tracks" |
| `CPListTemplate` | Approval detail view |
| `CPVoiceControlTemplate` | Voice interaction |
| `CPAlertTemplate` | Urgent approval requests |

### 4.2 Now Playing UI (Primary)

```
┌─────────────────────────────────────────────────────────────────┐
│                        CAR HEAD UNIT                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │   ◀◀              Claude Code              ▶▶            │  │
│  │                                                           │  │
│  │              ┌─────────────────────────┐                  │  │
│  │              │                         │                  │  │
│  │              │    🔶  Edit App.tsx      │                  │  │
│  │              │                         │                  │  │
│  │              │    +47 / -23 lines      │                  │  │
│  │              │    src/app/App.tsx      │                  │  │
│  │              │                         │                  │  │
│  │              └─────────────────────────┘                  │  │
│  │                                                           │  │
│  │           ┌─────────┐          ┌─────────┐               │  │
│  │           │ REJECT  │          │ APPROVE │               │  │
│  │           │   ◀◀    │          │   ▶▶    │               │  │
│  │           └─────────┘          └─────────┘               │  │
│  │                                                           │  │
│  │   1 of 3 pending          🎤 "Hey Siri, approve"         │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│   [◀◀]  [▶▶]  [☎️]  [🔊]     ← STEERING WHEEL BUTTONS          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.3 Steering Wheel Button Mapping

```swift
// CarPlayService.swift
func configureRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()

    // ◀◀ Previous Track → REJECT current approval
    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
        guard let action = self?.currentAction else { return .noActionableNowPlayingItem }
        self?.rejectAction(action.id)
        self?.playAudioFeedback(.rejected)
        return .success
    }

    // ▶▶ Next Track → APPROVE current approval
    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
        guard let action = self?.currentAction else { return .noActionableNowPlayingItem }
        self?.approveAction(action.id)
        self?.playAudioFeedback(.approved)
        return .success
    }

    // ▶️ Play/Pause → Read current approval aloud
    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
        self?.toggleAudioNarration()
        return .success
    }
}
```

### 4.4 Audio Feedback System

```swift
enum AudioCue {
    case newApproval          // Chime + "New approval waiting"
    case approved             // Success tone + "Approved"
    case rejected             // Distinct tone + "Rejected"
    case allComplete          // Happy chime + "All approvals complete"
    case connectionLost       // Warning tone + "Connection lost"
    case voicePromptStart     // Beep
    case voicePromptEnd       // Beep beep
}

class CarPlayAudioManager {
    private let synthesizer = AVSpeechSynthesizer()

    /// Narrate pending action for eyes-free understanding
    func narrateAction(_ action: PendingAction) {
        let text = buildNarration(action)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52  // Slightly faster than default
        synthesizer.speak(utterance)
    }

    private func buildNarration(_ action: PendingAction) -> String {
        switch action.type {
        case "file_edit":
            return "Claude wants to edit \(action.title). \(action.description). Press next to approve or previous to reject."
        case "file_create":
            return "Claude wants to create a new file: \(action.title). Press next to approve or previous to reject."
        case "bash":
            return "Claude wants to run a command: \(action.command ?? action.title). Press next to approve or previous to reject."
        default:
            return "\(action.title). \(action.description). Press next to approve or previous to reject."
        }
    }
}
```

---

## 5. Voice Interaction

### 5.1 Siri Integration (SiriKit)

```swift
// Intents.intentdefinition
// Custom intents for voice control

intent ClaudeApproveIntent {
    description: "Approve the current pending action"
    category: .generic

    response {
        success: "Approved. {actionTitle}"
        failure: "No pending approvals"
    }
}

intent ClaudeRejectIntent {
    description: "Reject the current pending action"
    category: .generic

    parameter reason: String {
        description: "Optional reason for rejection"
    }

    response {
        success: "Rejected. {actionTitle}"
        failure: "No pending approvals"
    }
}

intent ClaudeStatusIntent {
    description: "Get current Claude Code status"
    category: .generic

    response {
        success: "{pendingCount} pending approvals. {currentTask}"
        idle: "Claude is idle. No pending approvals."
    }
}

intent ClaudeTalkIntent {
    description: "Send a voice message to Claude Code"
    category: .generic

    parameter message: String {
        description: "The message to send"
    }

    response {
        success: "Message sent to Claude"
    }
}
```

### 5.2 Voice Commands

| Trigger | Intent | Action |
|---------|--------|--------|
| "Hey Siri, approve Claude" | `ClaudeApproveIntent` | Approve current |
| "Hey Siri, reject Claude" | `ClaudeRejectIntent` | Reject current |
| "Hey Siri, approve all Claude changes" | `ClaudeApproveAllIntent` | Approve all pending |
| "Hey Siri, what's Claude doing?" | `ClaudeStatusIntent` | Read status |
| "Hey Siri, tell Claude [message]" | `ClaudeTalkIntent` | Send voice prompt |

### 5.3 Call Button → Voice Session

When the user presses the call button on the steering wheel:

```swift
// CarPlaySceneDelegate.swift
func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
) {
    // Register for phone button press via Siri
    // The call button triggers Siri, which can invoke our intents

    // Alternatively, use CPVoiceControlTemplate for custom voice UI
    let voiceTemplate = CPVoiceControlTemplate(voiceControlStates: [
        CPVoiceControlState(
            identifier: "listening",
            titleVariants: ["Listening..."],
            image: UIImage(systemName: "mic.fill")!,
            repeats: false
        ),
        CPVoiceControlState(
            identifier: "processing",
            titleVariants: ["Processing..."],
            image: UIImage(systemName: "waveform")!,
            repeats: true
        )
    ])
}
```

---

## 6. iOS Companion App

### 6.1 App Structure

```
ClaudeMobile/
├── App/
│   ├── ClaudeMobileApp.swift        # @main entry
│   └── AppDelegate.swift            # Push notification handling
├── Scenes/
│   ├── CarPlay/
│   │   ├── CarPlaySceneDelegate.swift
│   │   └── CarPlayService.swift
│   └── Phone/
│       └── PhoneSceneDelegate.swift
├── Views/
│   ├── HomeView.swift               # Main dashboard
│   ├── QRScannerView.swift          # Camera QR scanning
│   ├── PairingView.swift            # Manual code entry
│   ├── SettingsView.swift           # App settings
│   └── ApprovalListView.swift       # Pending approvals
├── Services/
│   ├── SharedService.swift          # App Group sync
│   ├── CloudService.swift           # API client
│   └── AudioService.swift           # TTS & audio cues
├── Intents/
│   ├── Intents.intentdefinition
│   └── IntentHandler.swift
└── Extensions/
    └── WatchConnectivity/           # Watch sync (future)
```

### 6.2 Info.plist Additions

```xml
<!-- CarPlay entitlement -->
<key>com.apple.developer.carplay-driving-task</key>
<true/>

<!-- Camera for QR scanning -->
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan QR codes for pairing with Claude Code</string>

<!-- Siri -->
<key>NSSiriUsageDescription</key>
<string>Siri is used for hands-free control of Claude Code approvals</string>

<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>           <!-- For audio narration -->
    <string>remote-notification</string>
    <string>voip</string>            <!-- For voice interaction -->
</array>

<!-- App Groups -->
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.claudewatch.shared</string>
</array>

<!-- CarPlay scene -->
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
                <key>UISceneConfigurationName</key>
                <string>CarPlay</string>
            </dict>
        </array>
    </dict>
</dict>
```

### 6.3 QR Scanner View

```swift
import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @StateObject private var scanner = QRScanner()
    @State private var showManualEntry = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: scanner.session)
                .ignoresSafeArea()

            // Scanning overlay
            VStack {
                Spacer()

                // Viewfinder
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 250, height: 250)
                    .overlay(
                        Text("Point at QR code")
                            .foregroundColor(.white)
                            .padding(.top, 270)
                    )

                Spacer()

                // Manual entry button
                Button("Enter Code Manually") {
                    showManualEntry = true
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            scanner.start()
        }
        .onDisappear {
            scanner.stop()
        }
        .onChange(of: scanner.scannedCode) { _, code in
            if let code = code {
                handleScannedCode(code)
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualPairingView()
        }
    }

    private func handleScannedCode(_ code: String) {
        // Parse QR code URL
        guard let url = URL(string: code),
              url.scheme == "claude-watch",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let pairingCode = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            scanner.scannedCode = nil  // Reset and continue scanning
            return
        }

        // Complete pairing
        Task {
            do {
                try await SharedService.shared.completePairing(code: pairingCode)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Show error, reset scanner
                scanner.scannedCode = nil
            }
        }
    }
}
```

---

## 7. Data Models

### 7.1 Shared Models (Watch + CarPlay + Phone)

```swift
// SharedModels.swift - in shared framework or duplicated

/// Approval request from Claude Code
struct PendingAction: Codable, Identifiable {
    let id: String
    let type: ActionType
    let title: String
    let description: String
    let filePath: String?
    let command: String?
    let timestamp: Date

    // CarPlay-specific metadata
    var riskLevel: RiskLevel = .low
    var estimatedImpact: String?

    enum ActionType: String, Codable {
        case fileEdit = "file_edit"
        case fileCreate = "file_create"
        case fileDelete = "file_delete"
        case bash = "bash"
        case toolUse = "tool_use"
    }

    enum RiskLevel: String, Codable {
        case low       // Auto-approvable suggestion
        case medium    // Quick voice approval OK
        case high      // "Review when parked" warning
    }
}

/// Session state synced across all devices
struct SessionState: Codable {
    var taskName: String = ""
    var taskDescription: String = ""
    var progress: Double = 0
    var status: SessionStatus = .idle
    var pendingActions: [PendingAction] = []
    var model: String = "opus"
    var mode: PermissionMode = .normal

    enum SessionStatus: String, Codable {
        case idle, running, waiting, completed, failed
    }

    enum PermissionMode: String, Codable {
        case normal = "normal"
        case autoAccept = "auto_accept"
        case plan = "plan"
    }
}

/// Connection state for any interface
enum ConnectionStatus: Codable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
}
```

### 7.2 CarPlay-Specific Models

```swift
// CarPlayModels.swift

/// Now Playing info for CarPlay display
struct NowPlayingInfo {
    var title: String           // Action title
    var artist: String          // "Claude Code"
    var album: String           // Task name
    var artwork: UIImage?       // Action type icon
    var duration: TimeInterval  // Time since action was created
    var elapsedTime: TimeInterval
    var playbackRate: Float     // 0 = paused (narration off), 1 = playing

    var queueIndex: Int         // Current action index
    var queueCount: Int         // Total pending actions
}

/// Voice session state
struct VoiceSession {
    var isActive: Bool = false
    var transcript: String = ""
    var isProcessing: Bool = false
    var lastResponse: String?
}

/// Audio preferences
struct AudioPreferences: Codable {
    var narrationEnabled: Bool = true
    var narrationSpeed: Float = 1.0
    var soundEffectsEnabled: Bool = true
    var autoNarrateNewApprovals: Bool = true
    var voiceId: String = "com.apple.voice.compact.en-US.Samantha"
}
```

---

## 8. API Additions

### 8.1 Cloud Relay Extensions

```
POST /pair/complete
  - Existing endpoint
  - Add: Accept device type (watch/phone/carplay)

GET /requests/{pairingId}
  - Existing endpoint
  - Add: Include risk_level in response

POST /respond/{requestId}
  - Existing endpoint
  - Add: Accept source device type for analytics

NEW: POST /voice/prompt
  - Send voice transcription to Claude Code
  - Body: { "pairingId": "...", "text": "...", "source": "carplay" }
  - Returns: { "success": true, "promptId": "..." }

NEW: GET /voice/response/{promptId}
  - Poll for Claude's response to voice prompt
  - Returns: { "status": "pending|complete", "response": "..." }
```

### 8.2 MCP Server Extensions

```python
# server.py additions

# New tool for risk assessment
"watch_assess_risk": {
    "description": "Assess risk level of an action for CarPlay display",
    "parameters": {
        "action_type": {"type": "string"},
        "file_path": {"type": "string"},
        "lines_changed": {"type": "integer"},
        "is_destructive": {"type": "boolean"},
    },
    "handler": self._handle_assess_risk
}

async def _handle_assess_risk(self, action_type, file_path, lines_changed, is_destructive):
    """Determine if action should show 'review when parked' warning"""

    # High risk: destructive operations, large changes, sensitive files
    if is_destructive or lines_changed > 100:
        return {"risk_level": "high", "reason": "Large or destructive change"}

    sensitive_patterns = [".env", "credentials", "secret", "key", "password"]
    if any(p in file_path.lower() for p in sensitive_patterns):
        return {"risk_level": "high", "reason": "Sensitive file"}

    # Medium risk: moderate changes
    if lines_changed > 20:
        return {"risk_level": "medium", "reason": "Moderate change"}

    # Low risk: small, safe changes
    return {"risk_level": "low", "reason": "Small, safe change"}
```

---

## 9. Implementation Phases

### Phase 1: iOS Companion App Foundation (Week 1-2)
- [ ] Create iOS app project with App Groups
- [ ] Implement QR scanner view
- [ ] Port SharedService from WatchService patterns
- [ ] Basic pairing flow (QR + manual)
- [ ] Push notification handling
- [ ] Settings UI

### Phase 2: CarPlay Integration (Week 3-4)
- [ ] CarPlay scene delegate
- [ ] CPNowPlayingTemplate implementation
- [ ] MPRemoteCommandCenter setup (steering wheel)
- [ ] Basic approve/reject via ◀◀/▶▶
- [ ] Audio feedback (tones)
- [ ] Connection status display

### Phase 3: Voice & Audio (Week 5-6)
- [ ] AVSpeechSynthesizer narration
- [ ] SiriKit intents (approve, reject, status)
- [ ] Voice prompt flow (talk to Claude)
- [ ] Audio cue system
- [ ] Narration preferences

### Phase 4: Polish & Testing (Week 7-8)
- [ ] CarPlay Simulator testing
- [ ] Real vehicle testing
- [ ] Watch ↔ CarPlay state sync
- [ ] Edge cases (connection loss, etc.)
- [ ] App Store submission prep

---

## 10. Testing Strategy

### 10.1 Simulator Testing

```bash
# CarPlay Simulator (included in Xcode Additional Tools)
# Hardware/CarPlay Simulator

# Test scenarios:
# 1. Connect iPhone to CarPlay Simulator via USB
# 2. Launch Claude Mobile app
# 3. Verify CarPlay scene appears
# 4. Test button mappings via simulator controls
```

### 10.2 Unit Tests

```swift
// CarPlayServiceTests.swift

func testSteeringWheelApprove() async {
    let service = CarPlayService()
    service.state.pendingActions = [mockAction]

    // Simulate next track command
    let result = service.handleNextTrackCommand()

    XCTAssertEqual(result, .success)
    XCTAssertTrue(service.state.pendingActions.isEmpty)
}

func testAudioNarration() {
    let audio = CarPlayAudioManager()
    let action = PendingAction(
        id: "1",
        type: .fileEdit,
        title: "Edit App.tsx",
        description: "Update main component",
        filePath: "src/App.tsx"
    )

    let narration = audio.buildNarration(action)

    XCTAssertTrue(narration.contains("Claude wants to edit"))
    XCTAssertTrue(narration.contains("App.tsx"))
}
```

### 10.3 Integration Tests

```swift
// CarPlayIntegrationTests.swift

func testPairingFlowThroughToCarPlay() async throws {
    // 1. Scan QR code
    let qrCode = "claude-watch://pair?code=ABC-123"
    try await SharedService.shared.handleQRCode(qrCode)

    // 2. Verify pairing stored in App Group
    XCTAssertTrue(SharedService.shared.isPaired)

    // 3. Verify CarPlay receives state
    let carPlay = CarPlayService()
    await carPlay.syncState()
    XCTAssertEqual(carPlay.connectionStatus, .connected)
}
```

---

## 11. Security Considerations

### 11.1 Driving Safety

```swift
// Safety warnings for high-risk actions
func shouldShowParkWarning(_ action: PendingAction) -> Bool {
    switch action.riskLevel {
    case .high:
        return true  // "Review when parked"
    case .medium, .low:
        return false
    }
}

// Limit interaction time
let maxInteractionTime: TimeInterval = 2.0  // Apple HIG requirement
```

### 11.2 Data Security

- All API communication over HTTPS
- Pairing codes expire after 5 minutes
- Device tokens stored in Keychain (not UserDefaults)
- No code diffs transmitted to car (only summaries)

---

## 12. Future Enhancements (Post-MVP)

1. **Android Auto Support** - Same architecture, different templates
2. **Multi-session Support** - Control multiple Claude Code instances
3. **Commute Mode** - Queue approvals for the drive
4. **AI Narration** - Use Claude to summarize changes
5. **Diff Preview** - Show code diff on parked CarPlay screen
6. **Apple Watch ↔ CarPlay Handoff** - Seamless transition
7. **Shortcuts Integration** - "When I connect to CarPlay, enable Claude Auto Mode"

---

## 13. Success Metrics

| Metric | Target |
|--------|--------|
| Pairing success rate | > 95% |
| Approval latency (button → server) | < 500ms |
| Audio narration clarity | User testing |
| Crash-free sessions | > 99.5% |
| CarPlay session duration | Track for optimization |

---

## Appendix A: File Structure

```
claude-watch/
├── ClaudeWatch/                    # Existing watchOS app
│   └── ...
├── ClaudeMobile/                   # NEW: iOS companion app
│   ├── ClaudeMobile.xcodeproj
│   ├── App/
│   ├── Scenes/
│   │   ├── CarPlay/
│   │   └── Phone/
│   ├── Views/
│   ├── Services/
│   ├── Intents/
│   └── Resources/
├── Shared/                         # NEW: Shared framework
│   ├── Models/
│   ├── Services/
│   └── Extensions/
├── MCPServer/                      # Existing server
│   └── server.py                   # Add risk assessment
└── docs/
    └── CARPLAY_MVP_SPEC.md         # This document
```

---

## Appendix B: References

- [Apple CarPlay Developer Guide](https://developer.apple.com/carplay/)
- [WWDC25 - Turbocharge your app for CarPlay](https://developer.apple.com/videos/play/wwdc2025/216/)
- [MPRemoteCommandCenter Documentation](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter)
- [SiriKit Programming Guide](https://developer.apple.com/documentation/sirikit)
- [App Groups Documentation](https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps)
