# Claude Watch: iOS Companion App Design

**Document Version:** 1.0
**Last Updated:** January 2026
**Author:** Design Lead
**Status:** Ready for Implementation

---

## Executive Summary

The iOS Companion App provides frictionless QR code pairing for Claude Watch, eliminating the tedious watch keyboard entry that causes 30% of users to abandon setup. The app leverages WatchConnectivity to automatically sync pairing credentials to the watch.

### Key Benefits

| Metric | Current (Watch-only) | With iOS Companion |
|--------|---------------------|-------------------|
| Pairing time | 45-60 seconds | 10-15 seconds |
| Pairing success rate | ~70% | 99%+ |
| User friction | High (keyboard) | Low (camera) |
| Setup abandonment | ~20% | < 5% |

---

## App Architecture

### Technical Stack

| Component | Technology |
|-----------|------------|
| Framework | SwiftUI |
| Minimum iOS | 17.0 |
| Watch Sync | WatchConnectivity |
| QR Scanning | AVFoundation |
| Storage | Keychain + App Groups |

### App Target Structure

```
ClaudeWatchCompanion/
├── App/
│   └── CompanionApp.swift         # App entry point
├── Views/
│   ├── WelcomeView.swift          # Onboarding landing
│   ├── QRScannerView.swift        # Camera scanner
│   ├── ManualEntryView.swift      # Fallback code entry
│   ├── SyncingView.swift          # Watch sync progress
│   └── ConnectedView.swift        # Success state
├── Services/
│   ├── ConnectivityManager.swift  # WatchConnectivity
│   ├── QRCodeParser.swift         # QR validation
│   └── KeychainManager.swift      # Secure storage
└── Resources/
    └── Assets.xcassets            # App icons, images
```

---

## Screen Designs

### 1. Welcome Screen

**Purpose:** Introduce the app and present pairing options

#### Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    Status Bar                               │
│                                                             │
│                                                             │
│                         ◯                                   │
│                    Claude Watch                             │
│                    ─────────────                            │
│                                                             │
│                                                             │
│              Pair your Apple Watch with                     │
│              Claude Code in seconds                         │
│                                                             │
│                                                             │
│                                                             │
│                      ┌─────────────────────────────┐        │
│                      │                             │        │
│                      │    📷 Scan QR Code          │        │
│                      │                             │        │
│                      └─────────────────────────────┘        │
│                                                             │
│                                                             │
│                      ───────── or ─────────                 │
│                                                             │
│                                                             │
│                      Enter code manually                    │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                    Already paired? Check status             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Specifications

| Element | Specification |
|---------|---------------|
| Logo | 80×80pt, centered |
| Title | 28pt, SF Pro Bold |
| Subtitle | 17pt, SF Pro Regular, secondary color |
| Primary Button | 50pt height, orange gradient, full width - 32pt margin |
| Secondary Link | 17pt, SF Pro Regular, orange tint |
| Footer Link | 15pt, SF Pro Regular, tertiary color |

#### Interactions

| Element | Action |
|---------|--------|
| "Scan QR Code" | Navigate to QRScannerView |
| "Enter code manually" | Navigate to ManualEntryView |
| "Check status" | Navigate to ConnectedView (if paired) |

---

### 2. QR Scanner Screen

**Purpose:** Scan QR code from Claude Code terminal

#### Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│  ✕                                                          │
│                                                             │
│                                                             │
│                                                             │
│        ┌───────────────────────────────────────┐            │
│        │                                       │            │
│        │                                       │            │
│        │                                       │            │
│        │          [Camera Viewfinder]          │            │
│        │                                       │            │
│        │         ┌─────────────────┐           │            │
│        │         │                 │           │            │
│        │         │   [QR Target]   │           │            │
│        │         │                 │           │            │
│        │         └─────────────────┘           │            │
│        │                                       │            │
│        │                                       │            │
│        │                                       │            │
│        └───────────────────────────────────────┘            │
│                                                             │
│                                                             │
│                Point camera at the QR code                  │
│                in your Claude Code terminal                 │
│                                                             │
│                                                             │
│        ──────────────────────────────────────────           │
│                                                             │
│                    Enter code manually                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Specifications

| Element | Specification |
|---------|---------------|
| Close button | 44×44pt tap target, top-left |
| Viewfinder | Full width - 32pt margin, 4:3 aspect ratio |
| QR target frame | Centered, 200×200pt, rounded corners |
| Frame color | Orange, 3pt stroke |
| Corner markers | Orange, 30pt length, 6pt stroke |
| Instruction text | 17pt, SF Pro Regular, centered |
| Fallback link | 15pt, SF Pro Regular, orange tint |

#### States

**Scanning:**
```
┌───────────────────────────────────────┐
│         ┌─────────────────┐           │
│         │                 │           │
│         │   Scanning...   │           │
│         │                 │           │
│         └─────────────────┘           │
└───────────────────────────────────────┘
```

**QR Detected:**
```
┌───────────────────────────────────────┐
│         ┌─────────────────┐           │
│         │       ✓         │           │
│         │     Found!      │           │
│         │                 │           │
│         └─────────────────┘           │
│                                       │
│   Frame animates green, scales up    │
└───────────────────────────────────────┘
```

**Error (Invalid QR):**
```
┌───────────────────────────────────────┐
│         ┌─────────────────┐           │
│         │       ⚠️        │           │
│         │  Invalid code   │           │
│         │   Try again     │           │
│         └─────────────────┘           │
│                                       │
│   Frame animates red, shakes         │
└───────────────────────────────────────┘
```

#### Animation Specifications

| Animation | Duration | Easing |
|-----------|----------|--------|
| Frame appear | 0.3s | Spring (bounce: 0.3) |
| Success pulse | 0.5s | Ease out |
| Error shake | 0.3s | Linear (3 cycles) |
| Transition to sync | 0.4s | Spring |

---

### 3. Manual Entry Screen

**Purpose:** Fallback for users who can't scan QR

#### Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│  ← Back                                                     │
│                                                             │
│                                                             │
│                    Enter Pairing Code                       │
│                                                             │
│                                                             │
│            ┌───────────────────────────────┐                │
│            │                               │                │
│            │      A B C - 1 2 3            │                │
│            │                               │                │
│            └───────────────────────────────┘                │
│                                                             │
│                                                             │
│            Run this command in your terminal:               │
│                                                             │
│            ┌───────────────────────────────┐                │
│            │  $ claude --watch --pair      │                │
│            │                           📋  │                │
│            └───────────────────────────────┘                │
│                                                             │
│                                                             │
│            ┌───────────────────────────────────┐            │
│            │                                   │            │
│            │            Connect                │            │
│            │                                   │            │
│            └───────────────────────────────────┘            │
│                                                             │
│                                                             │
│                    Need help? View docs                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Specifications

| Element | Specification |
|---------|---------------|
| Title | 22pt, SF Pro Bold |
| Input field | 56pt height, large font, centered text |
| Input format | XXX-XXX with auto-hyphen |
| Code block | SF Mono, 15pt, surface background |
| Copy button | 44×44pt, clipboard icon |
| Connect button | 50pt height, orange gradient |
| Help link | 15pt, SF Pro Regular, tertiary color |

#### Validation

| Rule | Visual Feedback |
|------|-----------------|
| Valid format (XXX-XXX) | Green checkmark, enable Connect |
| Invalid characters | Red border, shake animation |
| Empty | Disabled Connect button |

---

### 4. Syncing Screen

**Purpose:** Show WatchConnectivity sync progress

#### Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
│                         ✓                                   │
│                                                             │
│                    Code Verified!                           │
│                                                             │
│                      ABC-123                                │
│                                                             │
│                                                             │
│                                                             │
│            ┌───────────────────────────────┐                │
│            │                               │                │
│            │  📲 Syncing to Apple Watch... │                │
│            │                               │
│            │  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░  50%  │                │
│            │                               │                │
│            └───────────────────────────────┘                │
│                                                             │
│                                                             │
│                                                             │
│                 Keep this app open                          │
│                                                             │
│                                                             │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Specifications

| Element | Specification |
|---------|---------------|
| Success icon | 60pt, green checkmark, scale animation |
| Title | 22pt, SF Pro Bold |
| Code display | 17pt, SF Mono, secondary color |
| Sync card | Surface background, 16pt padding, 16pt radius |
| Progress bar | 8pt height, orange fill, gray track |
| Instruction | 15pt, SF Pro Regular, tertiary color |

#### Sync Stages

| Stage | Progress | Status Text |
|-------|----------|-------------|
| Verifying | 0-20% | "Verifying code..." |
| Connecting | 20-40% | "Connecting to server..." |
| Sending to Watch | 40-80% | "Syncing to Apple Watch..." |
| Watch Receiving | 80-95% | "Watch receiving..." |
| Complete | 100% | "Connected!" |

---

### 5. Connected Screen

**Purpose:** Confirm successful pairing and show status

#### Visual Design

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                                                             │
│                                                             │
│                         ✓                                   │
│                                                             │
│                     Connected!                              │
│                                                             │
│                                                             │
│             Your Apple Watch is now paired                  │
│             with Claude Code                                │
│                                                             │
│                                                             │
│                                                             │
│            ┌───────────────────────────────────┐            │
│            │                                   │            │
│            │    ⌚ Claude Watch                │            │
│            │                                   │            │
│            │    Status: Connected              │            │
│            │    Paired: Today, 10:32 AM        │            │
│            │    Code: ABC-123                  │            │
│            │                                   │            │
│            └───────────────────────────────────┘            │
│                                                             │
│                                                             │
│            ┌───────────────────────────────────┐            │
│            │            Done                   │            │
│            └───────────────────────────────────┘            │
│                                                             │
│                    Pair a different device                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### Specifications

| Element | Specification |
|---------|---------------|
| Success icon | 80pt, animated green checkmark |
| Title | 28pt, SF Pro Bold |
| Subtitle | 17pt, SF Pro Regular, secondary color |
| Status card | Surface background, 16pt padding |
| Watch icon | 32pt, system watch.fill |
| Status label | Green dot + "Connected" text |
| Done button | 50pt height, orange gradient |
| Re-pair link | 15pt, SF Pro Regular, orange tint |

#### Status States

**Connected:**
```
│    ⌚ Claude Watch                │
│                                   │
│    ● Connected                    │
│    Paired: Today, 10:32 AM        │
```

**Disconnected:**
```
│    ⌚ Claude Watch                │
│                                   │
│    ○ Disconnected                 │
│    Last connected: 2 hours ago    │
│                                   │
│    ┌──────────────────────────┐   │
│    │    Reconnect             │   │
│    └──────────────────────────┘   │
```

---

## Navigation Flow

```
┌─────────────┐
│   Welcome   │
│   Screen    │
└──────┬──────┘
       │
       ├──────────────────────────────────┐
       │                                  │
       ▼                                  ▼
┌─────────────┐                   ┌─────────────┐
│  QR Scanner │                   │Manual Entry │
│   Screen    │                   │   Screen    │
└──────┬──────┘                   └──────┬──────┘
       │                                  │
       │   (QR detected)                  │   (Connect tapped)
       │                                  │
       ▼                                  ▼
       └──────────────┬───────────────────┘
                      │
                      ▼
              ┌─────────────┐
              │   Syncing   │
              │   Screen    │
              └──────┬──────┘
                     │
                     │   (Sync complete)
                     │
                     ▼
              ┌─────────────┐
              │  Connected  │
              │   Screen    │
              └─────────────┘
                     │
                     │   (Done tapped)
                     │
                     ▼
              ┌─────────────┐
              │   Welcome   │
              │  (updated)  │
              └─────────────┘
```

---

## Technical Implementation

### WatchConnectivity Manager

```swift
import WatchConnectivity

@Observable
final class ConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = ConnectivityManager()

    var isWatchPaired = false
    var isWatchAppInstalled = false
    var syncProgress: Double = 0
    var syncStatus: SyncStatus = .idle

    enum SyncStatus {
        case idle
        case verifying
        case connecting
        case syncing
        case complete
        case error(String)
    }

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendPairingCredentials(code: String, deviceToken: String) async throws {
        guard WCSession.default.isWatchAppInstalled else {
            throw ConnectivityError.watchAppNotInstalled
        }

        syncStatus = .syncing
        syncProgress = 0.4

        let context: [String: Any] = [
            "pairingCode": code,
            "deviceToken": deviceToken,
            "timestamp": Date().timeIntervalSince1970
        ]

        try WCSession.default.updateApplicationContext(context)

        // Progress updates
        for progress in stride(from: 0.4, to: 1.0, by: 0.1) {
            try await Task.sleep(nanoseconds: 200_000_000)
            syncProgress = progress
        }

        syncStatus = .complete
    }

    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
```

### QR Code Parser

```swift
import AVFoundation

struct QRCodeParser {
    enum ParseError: Error {
        case invalidFormat
        case invalidScheme
        case missingCode
    }

    /// Parses QR code content
    /// Expected formats:
    /// - claude-watch://pair?code=ABC123
    /// - ABC-123 (raw code)
    static func parse(_ content: String) throws -> String {
        // Try URL format first
        if let url = URL(string: content),
           url.scheme == "claude-watch",
           url.host == "pair" {
            guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value else {
                throw ParseError.missingCode
            }
            return code
        }

        // Try raw code format (XXX-XXX or XXXXXX)
        let cleanCode = content.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleanCode.count == 6 else {
            throw ParseError.invalidFormat
        }

        // Format as XXX-XXX
        let index = cleanCode.index(cleanCode.startIndex, offsetBy: 3)
        return "\(cleanCode[..<index])-\(cleanCode[index...])"
    }

    static func isValid(_ code: String) -> Bool {
        let pattern = "^[A-Z0-9]{3}-[A-Z0-9]{3}$"
        return code.range(of: pattern, options: .regularExpression) != nil
    }
}
```

### QR Scanner View

```swift
import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @State private var scanResult: ScanResult?
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    enum ScanResult {
        case success(String)
        case error(String)
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(onCodeScanned: handleScan)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Close button
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    Spacer()
                }

                Spacer()

                // Target frame
                QRTargetFrame(result: scanResult)
                    .frame(width: 200, height: 200)

                Spacer()

                // Instructions
                VStack(spacing: 16) {
                    Text("Point camera at the QR code")
                        .font(.headline)
                    Text("in your Claude Code terminal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Divider()

                    Button("Enter code manually") {
                        // Navigate to manual entry
                    }
                    .foregroundStyle(Claude.orange)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .onChange(of: scanResult) { _, result in
            if case .success(let code) = result {
                // Navigate to syncing
            }
        }
    }

    private func handleScan(_ content: String) {
        do {
            let code = try QRCodeParser.parse(content)
            scanResult = .success(code)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            scanResult = .error("Invalid QR code")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
```

---

## Accessibility

### VoiceOver Labels

| Screen | Element | Label |
|--------|---------|-------|
| Welcome | Scan button | "Scan QR code to pair Apple Watch" |
| Scanner | Viewfinder | "Camera viewfinder. Point at QR code in terminal." |
| Scanner | Target frame | "QR code target area" |
| Manual | Code input | "Pairing code. 6 characters." |
| Syncing | Progress | "Syncing to Apple Watch. [X] percent complete." |
| Connected | Status | "Connected to Apple Watch. Paired [time]." |

### Dynamic Type

All text scales with system settings:
- Minimum: Default sizes
- Maximum: 2x scale with layout adjustments

### Reduce Motion

- Disable scanner frame animations
- Use instant transitions
- Remove success/error animations

---

## Design Tokens (iOS)

### Colors (Matches watchOS)

| Token | Value |
|-------|-------|
| Primary | `#FF9500` (Orange) |
| Success | `#34C759` (Green) |
| Error | `#FF3B30` (Red) |
| Background | System background |
| Surface | System grouped background |

### Typography

| Style | iOS Equivalent |
|-------|----------------|
| Large Title | .largeTitle |
| Title | .title2 |
| Body | .body |
| Caption | .footnote |
| Code | .monospaced |

### Spacing

| Token | Value |
|-------|-------|
| xs | 4pt |
| sm | 8pt |
| md | 16pt |
| lg | 24pt |
| xl | 32pt |

---

## App Store Requirements

### App Icon

Sizes required:
- 1024×1024 (Marketing)
- 180×180 (@3x iPhone)
- 120×120 (@2x iPhone)
- 167×167 (iPad Pro)
- 152×152 (iPad)

Design: Orange gradient background with white watch outline

### Screenshots

Required for App Store:
1. Welcome screen (6.5" iPhone)
2. QR Scanner in action
3. Syncing progress
4. Connected confirmation
5. Watch face showing complication

### App Store Description

```
Claude Watch Companion

Pair your Apple Watch with Claude Code instantly using your iPhone camera.

FEATURES:
• Scan QR code from terminal - no typing required
• Automatic sync to Apple Watch via WatchConnectivity
• View pairing status and manage connection
• Re-pair or update credentials anytime

REQUIREMENTS:
• iPhone with iOS 17.0 or later
• Apple Watch with Claude Watch app installed
• Claude Code running on your Mac

This companion app makes setup instant. No more typing codes on tiny watch keyboards!
```

---

## Implementation Checklist

### Phase 1: Core Functionality
- [ ] Create iOS app target in Xcode project
- [ ] Implement WelcomeView
- [ ] Implement QRScannerView with AVFoundation
- [ ] Implement ManualEntryView
- [ ] Implement SyncingView
- [ ] Implement ConnectedView

### Phase 2: WatchConnectivity
- [ ] Create ConnectivityManager
- [ ] Implement WCSessionDelegate
- [ ] Handle applicationContext updates
- [ ] Add error handling for watch not paired/installed

### Phase 3: Polish
- [ ] Add animations and transitions
- [ ] Implement accessibility labels
- [ ] Support Dynamic Type
- [ ] Add haptic feedback
- [ ] Create app icons

### Phase 4: Testing
- [ ] Test QR scanning in various lighting
- [ ] Test WatchConnectivity sync
- [ ] Test error states
- [ ] Test on multiple iPhone sizes
- [ ] Test with VoiceOver

---

*Document maintained by Design Lead. Update when iOS app design changes.*
