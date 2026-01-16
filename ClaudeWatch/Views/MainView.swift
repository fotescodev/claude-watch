import SwiftUI
import WatchKit

// RALPH_TEST: Loop verification successful

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

    // Always-On Display support
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    // Dynamic Type support
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 12

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            // Always-On Display: Show simplified view
            if isLuminanceReduced {
                AlwaysOnDisplayView(
                    connectionStatus: service.connectionStatus,
                    pendingCount: service.state.pendingActions.count,
                    status: service.state.status
                )
            }
            // Content based on state
            else if service.useCloudMode && !service.isPaired && !service.isDemoMode {
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
                .accessibilityLabel("Settings and connection status")
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

// MARK: - Spring Animation Extensions
extension Animation {
    /// Standard spring animation for interactive button feedback
    static var buttonSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
    }

    /// Bouncy spring for attention-grabbing elements
    static var bouncySpring: Animation {
        .interpolatingSpring(stiffness: 200, damping: 15)
    }

    /// Gentle spring for subtle transitions
    static var gentleSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - Status Header
struct StatusHeader: View {
    @ObservedObject private var service = WatchService.shared
    let pulsePhase: CGFloat

    // Dynamic Type support - scale icon sizes with text
    @ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
    @ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var badgeFontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 8) {
            // Main status
            HStack(spacing: 8) {
                // Status icon with pulse
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: statusIconContainerSize, height: statusIconContainerSize)

                    if service.state.status == .running || service.state.status == .waiting {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: statusIconContainerSize, height: statusIconContainerSize)
                            .scaleEffect(1 + pulsePhase * 0.2)
                    }

                    Image(systemName: statusIcon)
                        .font(.system(size: statusIconSize, weight: .bold))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(Claude.textPrimary)

                    if !service.state.taskName.isEmpty {
                        Text(service.state.taskName)
                            .font(.caption2)
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Pending badge
                if !service.state.pendingActions.isEmpty {
                    Text("\(service.state.pendingActions.count)")
                        .font(.system(size: badgeFontSize, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: badgeSize, height: badgeSize)
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
                .fill(.ultraThinMaterial)
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

    // Dynamic Type support
    @ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: service.isPaired ? "tray" : "link.circle")
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundColor(Claude.textTertiary)
            }

            // Text
            Text(service.isPaired ? "All Clear" : "Not Paired")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Claude.textPrimary)

            Text(service.isPaired ? "No pending actions" : "Connect to Claude Code")
                .font(.footnote)
                .foregroundColor(Claude.textSecondary)

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(service.isPaired ? Claude.success : Claude.warning)
                    .frame(width: 6, height: 6)
                Text(service.isPaired ? "Connected" : "Awaiting pairing")
                    .font(.caption2)
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
                            .font(.caption.weight(.semibold))
                        Text("Pair with Code")
                            .font(.footnote.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Claude.orange)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel("Pair with Claude Code")
            } else {
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Load Demo")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel("Load demo data")
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

    // Dynamic Type support
    @ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 16) {
            // Icon (tap to load demo)
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: "wifi.slash")
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundColor(Claude.textTertiary)
            }
            .onTapGesture(count: 3) {
                // Triple-tap to load demo data
                service.loadDemoData()
            }

            // Text
            Text("Offline")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Claude.textPrimary)

            Text("Can't connect to Claude")
                .font(.footnote)
                .foregroundColor(Claude.textSecondary)

            // Buttons
            VStack(spacing: 10) {
                // Retry button
                Button {
                    service.connect()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Retry")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Claude.info)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry connection")

                // Demo button
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Demo Mode")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Enter demo mode")
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Claude.textPrimary)

                        Text("Attempt \(attempt) • \(Int(nextRetryIn))s")
                            .font(.caption2)
                            .foregroundColor(Claude.textSecondary)
                    } else {
                        Text("Connecting...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Claude.textPrimary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Action Queue
struct ActionQueue: View {
    @ObservedObject private var service = WatchService.shared

    // Spring animation state
    @State private var approveAllPressed = false

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
                            .font(.caption2)
                            .foregroundColor(Claude.textTertiary)
                    }
                }

                // Approve All button
                Button {
                    service.approveAll()
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Approve All (\(service.state.pendingActions.count))")
                        .font(.body.weight(.bold))
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
                        .scaleEffect(approveAllPressed ? 0.95 : 1.0)
                        .animation(.bouncySpring, value: approveAllPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in approveAllPressed = true }
                        .onEnded { _ in approveAllPressed = false }
                )
                .accessibilityLabel("Approve all \(service.state.pendingActions.count) pending actions")
            }
        }
    }
}

// MARK: - Primary Action Card
struct PrimaryActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18

    // Spring animation states for buttons
    @State private var rejectPressed = false
    @State private var approvePressed = false

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
                        .frame(width: iconContainerSize, height: iconContainerSize)

                    Image(systemName: action.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    if let path = action.filePath {
                        Text(truncatePath(path))
                            .font(.caption2.monospaced())
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
                            .font(.subheadline.weight(.bold))
                        Text("Reject")
                            .font(.body.weight(.bold))
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
                    .scaleEffect(rejectPressed ? 0.92 : 1.0)
                    .animation(.buttonSpring, value: rejectPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in rejectPressed = true }
                        .onEnded { _ in rejectPressed = false }
                )
                .accessibilityLabel("Reject \(action.title)")

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
                            .font(.subheadline.weight(.bold))
                        Text("Approve")
                            .font(.body.weight(.bold))
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
                    .scaleEffect(approvePressed ? 0.92 : 1.0)
                    .animation(.buttonSpring, value: approvePressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in approvePressed = true }
                        .onEnded { _ in approvePressed = false }
                )
                .accessibilityLabel("Approve \(action.title)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
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

    // Dynamic Type support
    @ScaledMetric(relativeTo: .footnote) private var iconContainerSize: CGFloat = 28
    @ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor.opacity(0.2))
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: action.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            Text(action.title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Claude.info)

                    Text("Voice Command")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Claude.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Claude.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open voice command input")
        }
    }
}

// MARK: - Command Button
struct CommandButton: View {
    @ObservedObject private var service = WatchService.shared
    let icon: String
    let label: String
    let prompt: String

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52

    // Spring animation state
    @State private var isPressed = false

    var body: some View {
        Button {
            service.sendPrompt(prompt)
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(Claude.orange)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Claude.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.buttonSpring, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(label) command, sends \(prompt)")
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @ObservedObject private var service = WatchService.shared

    // Dynamic Type support
    @ScaledMetric(relativeTo: .footnote) private var modeIconContainerSize: CGFloat = 28
    @ScaledMetric(relativeTo: .footnote) private var modeIconSize: CGFloat = 12

    // Spring animation state
    @State private var isPressed = false

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
                        .frame(width: modeIconContainerSize, height: modeIconContainerSize)

                    Image(systemName: service.state.mode.icon)
                        .font(.system(size: modeIconSize, weight: .bold))
                        .foregroundColor(modeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.state.mode.displayName)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(modeColor)

                    Text(service.state.mode.description)
                        .font(.caption2)
                        .foregroundColor(Claude.textSecondary)
                }

                Spacer()

                // Next mode hint
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Claude.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(modeBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(modeColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.buttonSpring, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Current mode: \(service.state.mode.displayName). Tap to change mode")
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
    @State private var showSentConfirmation = false
    @State private var isRecording = false

    // Quick suggestions for common commands
    private let suggestions = ["Continue", "Run tests", "Fix errors", "Commit"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Recording indicator banner
                if isRecording {
                    RecordingBanner(recordingState: .recording)
                }

                // Header with recording indicator
                HStack(spacing: 8) {
                    Text("Voice Command")
                        .font(.body.weight(.bold))
                        .foregroundColor(Claude.textPrimary)

                    if isRecording {
                        RecordingIndicator(isRecording: true)
                    }
                }

                // Text input with dictation support (watchOS 10+ native)
                TextField("Tap to speak...", text: $transcribedText)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: transcribedText) { oldValue, newValue in
                        // Detect dictation activity (text changing indicates recording)
                        if newValue.count > oldValue.count && !isRecording {
                            isRecording = true
                            WKInterfaceDevice.current().play(.start)
                        }
                    }
                    .onSubmit {
                        // Recording stopped when text is submitted
                        if isRecording {
                            isRecording = false
                            WKInterfaceDevice.current().play(.stop)
                        }
                    }

                // Quick suggestion chips
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            transcribedText = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(Claude.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quick suggestion: \(suggestion)")
                    }
                }

                // Sending/Sent status feedback
                if service.isSendingPrompt {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Claude.info))
                            .scaleEffect(0.7)
                        Text("Sending...")
                            .font(.caption)
                            .foregroundColor(Claude.textSecondary)
                    }
                } else if showSentConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(Claude.success)
                        Text("Sent")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Claude.success)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Claude.danger)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Claude.danger.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel voice command")

                    if !transcribedText.isEmpty && !showSentConfirmation {
                        Button {
                            service.sendPrompt(transcribedText)
                            showSentConfirmation = true
                            WKInterfaceDevice.current().play(.success)
                            Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                dismiss()
                            }
                        } label: {
                            Text("Send")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Claude.success)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send voice command")
                    }
                }
            }
            .padding()
        }
        .background(Claude.background)
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var showingPairing = false
    @State private var showingPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                    Text("Connection")
                        .font(.body.weight(.bold))
                }
                .foregroundColor(Claude.textPrimary)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(service.connectionStatus.displayName)
                        .font(.footnote.weight(.semibold))
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
                                .font(.footnote.weight(.semibold))
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
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Exit demo mode and disconnect")
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
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Claude.success)
                            }

                            // Unpair button
                            Button {
                                service.unpair()
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("Unpair")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Claude.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Claude.danger.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Unpair from Claude Code")
                        } else {
                            // Pair button
                            Button {
                                showingPairing = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption.weight(.semibold))
                                    Text("Pair with Code")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Pair with Claude Code")
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Server URL input (WebSocket mode)
                if !service.useCloudMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Claude.textSecondary)

                        TextField("ws://...", text: $serverURL)
                            .font(.footnote)
                            .textContentType(.URL)
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Claude.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.danger.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel and close settings")

                        Button {
                            service.serverURLString = serverURL
                            service.connect()
                            WKInterfaceDevice.current().play(.success)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.success)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Save server URL and connect")
                    }
                }

                // About section
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption.weight(.semibold))
                        Text("About")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundColor(Claude.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Version
                    HStack {
                        Text("Version")
                            .font(.caption)
                            .foregroundColor(Claude.textSecondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Claude.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                    // Privacy Consent (review in app)
                    Button {
                        showingPrivacy = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundColor(Claude.orange)
                            Text("Privacy & Consent")
                                .font(.caption)
                                .foregroundColor(Claude.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(Claude.textTertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review privacy settings and consent")

                    // Privacy Policy
                    if let privacyURL = URL(string: "https://claude-watch.example.com/privacy") {
                        Link(destination: privacyURL) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(Claude.info)
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Support
                    if let supportURL = URL(string: "https://claude-watch.example.com/support") {
                        Link(destination: supportURL) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption)
                                    .foregroundColor(Claude.info)
                                Text("Support")
                                    .font(.caption)
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
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
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.info)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done, close settings")
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
        .sheet(isPresented: $showingPrivacy) {
            PrivacyInfoView()
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

// MARK: - Always-On Display View
struct AlwaysOnDisplayView: View {
    let connectionStatus: ConnectionStatus
    let pendingCount: Int
    let status: SessionStatus

    // Dynamic Type support
    @ScaledMetric(relativeTo: .title) private var statusIconSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 16) {
            // Connection status indicator (always visible per HIG)
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 10, height: 10)

                Text(connectionStatus.displayName)
                    .font(.headline)
                    .foregroundColor(Claude.textSecondary)
            }

            // Simplified status display
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: statusIconSize, weight: .light))
                    .foregroundColor(Claude.textSecondary)

                Text(statusText)
                    .font(.title3)
                    .foregroundColor(Claude.textPrimary)

                // Pending count (if any)
                if pendingCount > 0 {
                    Text("\(pendingCount) pending")
                        .font(.caption)
                        .foregroundColor(Claude.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectionColor: Color {
        switch connectionStatus {
        case .connected: return Claude.textSecondary  // Dimmed green for AOD
        case .connecting, .reconnecting: return Claude.textTertiary
        case .disconnected: return Claude.textTertiary
        }
    }

    private var statusIcon: String {
        if pendingCount > 0 {
            return "hand.raised"
        }
        switch status {
        case .idle: return "checkmark"
        case .running: return "play"
        case .waiting: return "clock"
        case .completed: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var statusText: String {
        if pendingCount > 0 {
            return "Pending"
        }
        switch status {
        case .idle: return "Ready"
        case .running: return "Active"
        case .waiting: return "Waiting"
        case .completed: return "Done"
        case .failed: return "Error"
        }
    }
}

#Preview {
    MainView()
}
