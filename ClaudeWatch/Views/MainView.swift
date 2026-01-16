import SwiftUI
import WatchKit

// MARK: - Design System (watchOS Native)
private enum Claude {
    // Primary & Accent - Orange as Claude identity
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)        // #FF9500
    static let orangeLight = Color(red: 1.0, green: 0.702, blue: 0.251) // #FFB340
    static let orangeDark = Color(red: 0.8, green: 0.467, blue: 0.0)    // #CC7700

    // Semantic colors (Apple system colors)
    static let success = Color(red: 0.204, green: 0.780, blue: 0.349)   // #34C759
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)      // #FF3B30
    static let warning = Color(red: 1.0, green: 0.584, blue: 0.0)       // #FF9500
    static let info = Color(red: 0.0, green: 0.478, blue: 1.0)          // #007AFF

    // Surface colors
    static let background = Color.black
    static let surface1 = Color(red: 0.110, green: 0.110, blue: 0.118)  // #1C1C1E
    static let surface2 = Color(red: 0.173, green: 0.173, blue: 0.180)  // #2C2C2E
    static let surface3 = Color(red: 0.227, green: 0.227, blue: 0.235)  // #3A3A3C

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textTertiary = Color(white: 0.4)
}

// MARK: - Main View
struct MainView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingVoiceInput = false
    @State private var showingSettings = false
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            // Content based on state
            if service.useCloudMode && !service.isPaired && !service.isDemoMode {
                PairingView(service: service)
            } else if service.connectionStatus == .disconnected && !service.isDemoMode {
                OfflineStateView()
            } else if case .reconnecting = service.connectionStatus {
                // Show reconnecting indicator over main content
                VStack {
                    ReconnectingView(status: service.connectionStatus)
                    Spacer()
                }
            } else if service.state.pendingActions.isEmpty && service.state.status == .idle {
                EmptyStateView()
            } else {
                mainContentView
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: connectionIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(connectionColor)
                }
            }
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputSheet()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .onAppear {
            if !service.isDemoMode {
                if service.useCloudMode {
                    // Cloud mode - start polling if paired
                    if service.isPaired {
                        service.startPolling()
                    }
                } else {
                    // WebSocket mode
                    service.connect()
                }
            }
            startPulse()
        }
    }

    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Status header
                StatusHeader(pulsePhase: pulsePhase)

                // Pending actions
                if !service.state.pendingActions.isEmpty {
                    ActionQueue()
                }

                // Quick commands (only when not showing pending)
                if service.state.pendingActions.isEmpty {
                    CommandGrid(showingVoiceInput: $showingVoiceInput)
                }

                // Mode selector
                ModeSelector()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 12)
        }
    }

    private var connectionIcon: String {
        switch service.connectionStatus {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.trianglehead.2.clockwise"
        case .reconnecting: return "arrow.clockwise"
        case .disconnected: return "wifi.slash"
        }
    }

    private var connectionColor: Color {
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulsePhase = 1
        }
    }
}

// MARK: - Status Header
struct StatusHeader: View {
    @ObservedObject private var service = WatchService.shared
    let pulsePhase: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            // Main status
            HStack(spacing: 8) {
                // Status icon with pulse
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 32, height: 32)

                    if service.state.status == .running || service.state.status == .waiting {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(1 + pulsePhase * 0.2)
                    }

                    Image(systemName: statusIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Claude.textPrimary)

                    if !service.state.taskName.isEmpty {
                        Text(service.state.taskName)
                            .font(.system(size: 11))
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Pending badge
                if !service.state.pendingActions.isEmpty {
                    Text("\(service.state.pendingActions.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Claude.orange)
                        .clipShape(Circle())
                }
            }

            // Progress bar (when running)
            if service.state.status == .running || service.state.status == .waiting {
                ProgressView(value: service.state.progress)
                    .tint(Claude.orange)
                    .scaleEffect(y: 1.5)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Claude.surface1)
        )
    }

    private var statusIcon: String {
        switch service.state.status {
        case .idle: return "checkmark"
        case .running: return "play.fill"
        case .waiting: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var statusText: String {
        if !service.state.pendingActions.isEmpty {
            return "Pending"
        }
        switch service.state.status {
        case .idle: return "Ready"
        case .running: return "Active"
        case .waiting: return "Waiting"
        case .completed: return "Done"
        case .failed: return "Error"
        }
    }

    private var statusColor: Color {
        if !service.state.pendingActions.isEmpty {
            return Claude.orange
        }
        switch service.state.status {
        case .idle: return Claude.success
        case .running: return Claude.orange
        case .waiting: return Claude.warning
        case .completed: return Claude.success
        case .failed: return Claude.danger
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingPairing = false

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Claude.surface1)
                    .frame(width: 80, height: 80)

                Image(systemName: service.isPaired ? "tray" : "link.circle")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Claude.textTertiary)
            }

            // Text
            Text(service.isPaired ? "All Clear" : "Not Paired")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Claude.textPrimary)

            Text(service.isPaired ? "No pending actions" : "Connect to Claude Code")
                .font(.system(size: 13))
                .foregroundColor(Claude.textSecondary)

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(service.isPaired ? Claude.success : Claude.warning)
                    .frame(width: 6, height: 6)
                Text(service.isPaired ? "Connected" : "Awaiting pairing")
                    .font(.system(size: 11))
                    .foregroundColor(Claude.textTertiary)
            }
            .padding(.top, 8)

            // Pair button (when not paired) or Demo button
            if !service.isPaired && service.useCloudMode {
                Button {
                    showingPairing = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Pair with Code")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Claude.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else {
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Load Demo")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingPairing) {
            PairingView(service: service)
        }
    }
}

// MARK: - Offline State
struct OfflineStateView: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        VStack(spacing: 16) {
            // Icon (tap to load demo)
            ZStack {
                Circle()
                    .fill(Claude.surface1)
                    .frame(width: 80, height: 80)

                Image(systemName: "wifi.slash")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Claude.textTertiary)
            }
            .onTapGesture(count: 3) {
                // Triple-tap to load demo data
                service.loadDemoData()
            }

            // Text
            Text("Offline")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Claude.textPrimary)

            Text("Can't connect to Claude")
                .font(.system(size: 13))
                .foregroundColor(Claude.textSecondary)

            // Buttons
            VStack(spacing: 10) {
                // Retry button
                Button {
                    service.connect()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Retry")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Claude.info)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Demo button
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Demo Mode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Reconnecting State
struct ReconnectingView: View {
    let status: ConnectionStatus

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Claude.warning))
                    .scaleEffect(0.8)

                VStack(alignment: .leading, spacing: 2) {
                    if case .reconnecting(let attempt, let nextRetryIn) = status {
                        Text("Reconnecting...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)

                        Text("Attempt \(attempt) • \(Int(nextRetryIn))s")
                            .font(.system(size: 11))
                            .foregroundColor(Claude.textSecondary)
                    } else {
                        Text("Connecting...")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Claude.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Action Queue
struct ActionQueue: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        VStack(spacing: 8) {
            // Primary action card
            if let action = service.state.pendingActions.first {
                PrimaryActionCard(action: action)
            }

            // Additional pending items
            if service.state.pendingActions.count > 1 {
                VStack(spacing: 6) {
                    ForEach(service.state.pendingActions.dropFirst().prefix(2)) { action in
                        CompactActionCard(action: action)
                    }

                    if service.state.pendingActions.count > 3 {
                        Text("+\(service.state.pendingActions.count - 3) more")
                            .font(.system(size: 11))
                            .foregroundColor(Claude.textTertiary)
                    }
                }

                // Approve All button
                Button {
                    service.approveAll()
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Approve All (\(service.state.pendingActions.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Claude.success, Claude.success.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Primary Action Card
struct PrimaryActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction

    var body: some View {
        VStack(spacing: 12) {
            // Action info
            HStack(spacing: 10) {
                // Type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [typeColor, typeColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: action.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    if let path = action.filePath {
                        Text(truncatePath(path))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                // Reject
                Button {
                    Task {
                        if service.useCloudMode && service.isPaired {
                            try? await service.respondToCloudRequest(action.id, approved: false)
                        } else {
                            service.rejectAction(action.id)
                        }
                    }
                    WKInterfaceDevice.current().play(.failure)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Reject")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Claude.danger, Claude.danger.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Approve
                Button {
                    Task {
                        if service.useCloudMode && service.isPaired {
                            try? await service.respondToCloudRequest(action.id, approved: true)
                        } else {
                            service.approveAction(action.id)
                        }
                    }
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Approve")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Claude.success, Claude.success.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Claude.surface1)
        )
    }

    private var typeColor: Color {
        switch action.type {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return path
    }
}

// MARK: - Compact Action Card
struct CompactActionCard: View {
    let action: PendingAction

    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                Image(systemName: action.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            Text(action.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Claude.surface1)
        )
    }

    private var typeColor: Color {
        switch action.type {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }
}

// MARK: - Command Grid
struct CommandGrid: View {
    @ObservedObject private var service = WatchService.shared
    @Binding var showingVoiceInput: Bool

    private let commands: [(String, String, String)] = [
        ("play.fill", "Go", "Continue"),
        ("bolt.fill", "Test", "Run tests"),
        ("wrench.fill", "Fix", "Fix errors"),
        ("stop.fill", "Stop", "Stop"),
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Command buttons in 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(commands, id: \.1) { icon, label, prompt in
                    CommandButton(icon: icon, label: label, prompt: prompt)
                }
            }

            // Voice command button
            Button {
                showingVoiceInput = true
                WKInterfaceDevice.current().play(.click)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Claude.info)

                    Text("Voice Command")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Claude.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Claude.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Claude.surface1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Command Button
struct CommandButton: View {
    @ObservedObject private var service = WatchService.shared
    let icon: String
    let label: String
    let prompt: String

    var body: some View {
        Button {
            service.sendPrompt(prompt)
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Claude.orange)

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Claude.surface1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        Button {
            service.cycleMode()
            WKInterfaceDevice.current().play(.click)
        } label: {
            HStack(spacing: 10) {
                // Mode icon
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.2))
                        .frame(width: 28, height: 28)

                    Image(systemName: service.state.mode.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(modeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.state.mode.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(modeColor)

                    Text(service.state.mode.description)
                        .font(.system(size: 10))
                        .foregroundColor(Claude.textSecondary)
                }

                Spacer()

                // Next mode hint
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Claude.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(modeBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(modeColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var modeColor: Color {
        switch service.state.mode {
        case .normal: return Claude.info
        case .autoAccept: return Claude.danger
        case .plan: return Color.purple
        }
    }

    private var modeBackground: Color {
        switch service.state.mode {
        case .normal: return Claude.surface1
        case .autoAccept: return Claude.danger.opacity(0.1)
        case .plan: return Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var transcribedText = ""
    @State private var isListening = false
    @State private var showSentConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Voice Command")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Claude.textPrimary)

            // Microphone visualization
            ZStack {
                // Outer rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Claude.info.opacity(isListening ? 0.4 : 0.1), lineWidth: 1.5)
                        .frame(width: CGFloat(44 + i * 14), height: CGFloat(44 + i * 14))
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.6).delay(Double(i) * 0.1).repeatForever(autoreverses: true), value: isListening)
                }

                // Center mic
                ZStack {
                    Circle()
                        .fill(Claude.info.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Claude.info)
                }
            }
            .frame(height: 80)

            // Transcribed text or prompt
            Text(transcribedText.isEmpty ? "Tap to speak..." : transcribedText)
                .font(.system(size: 13))
                .foregroundColor(transcribedText.isEmpty ? Claude.textTertiary : Claude.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(minHeight: 40)

            // Sending/Sent status feedback
            if service.isSendingPrompt {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Claude.info))
                        .scaleEffect(0.7)
                    Text("Sending...")
                        .font(.system(size: 12))
                        .foregroundColor(Claude.textSecondary)
                }
            } else if showSentConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Claude.success)
                    Text("Sent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Claude.success)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Claude.danger)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Claude.danger.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !transcribedText.isEmpty && !showSentConfirmation {
                    Button {
                        service.sendPrompt(transcribedText)
                        showSentConfirmation = true
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            dismiss()
                        }
                    } label: {
                        Text("Send")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Claude.success)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Claude.background)
        .onAppear {
            presentTextInputController()
        }
    }

    private func presentTextInputController() {
        isListening = true
        WKExtension.shared().visibleInterfaceController?.presentTextInputController(
            withSuggestions: ["Continue", "Run tests", "Fix errors", "Explain", "Commit", "Undo"],
            allowedInputMode: .allowEmoji
        ) { results in
            isListening = false
            if let result = results?.first as? String {
                transcribedText = result
            }
        }
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var showingPairing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Connection")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(Claude.textPrimary)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(service.connectionStatus.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusColor)
                }
                .padding(.vertical, 4)

                // Demo Mode Section
                if service.isDemoMode {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(Claude.warning)
                            Text("Demo Mode Active")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Claude.warning)
                        }

                        Button {
                            service.isDemoMode = false
                            service.state = WatchState()
                            service.connectionStatus = .disconnected
                            service.pairingId = ""  // Reset pairing to show PairingView
                            WKInterfaceDevice.current().play(.click)
                            dismiss()
                        } label: {
                            Text("Exit Demo Mode")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }

                // Cloud Mode Section
                if service.useCloudMode && !service.isDemoMode {
                    VStack(spacing: 12) {
                        if service.isPaired {
                            // Show paired status
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Claude.success)
                                Text("Paired")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Claude.success)
                            }

                            // Unpair button
                            Button {
                                service.unpair()
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("Unpair")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Claude.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Claude.danger.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            // Pair button
                            Button {
                                showingPairing = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Pair with Code")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Server URL input (WebSocket mode)
                if !service.useCloudMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Claude.textSecondary)

                        TextField("ws://...", text: $serverURL)
                            .font(.system(size: 13))
                            .textContentType(.URL)
                            .padding(10)
                            .background(Claude.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Claude.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.danger.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            service.serverURLString = serverURL
                            service.connect()
                            WKInterfaceDevice.current().play(.success)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.success)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // About section
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text("About")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Claude.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Version
                    HStack {
                        Text("Version")
                            .font(.system(size: 12))
                            .foregroundColor(Claude.textSecondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Claude.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Privacy Policy
                    if let privacyURL = URL(string: "https://claude-watch.example.com/privacy") {
                        Link(destination: privacyURL) {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .font(.system(size: 12))
                                    .foregroundColor(Claude.info)
                                Text("Privacy Policy")
                                    .font(.system(size: 12))
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Claude.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Support
                    if let supportURL = URL(string: "https://claude-watch.example.com/support") {
                        Link(destination: supportURL) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Claude.info)
                                Text("Support")
                                    .font(.system(size: 12))
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Claude.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.top, 8)

                // Done button for cloud mode
                if service.useCloudMode {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.info)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Claude.background)
        .onAppear {
            serverURL = service.serverURLString
        }
        .sheet(isPresented: $showingPairing) {
            PairingView(service: service)
        }
    }

    private var statusColor: Color {
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }
}

#Preview {
    MainView()
}
