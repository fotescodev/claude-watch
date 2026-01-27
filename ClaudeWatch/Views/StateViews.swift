import SwiftUI
import WatchKit

// MARK: - Empty State
struct EmptyStateView: View {
    @ObservedObject private var service = WatchService.shared
    @ObservedObject private var activityStore = ActivityStore.shared
    @State private var showingPairing = false
    @State private var showingSettings = false

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        if service.isPaired {
            // Paired state - show useful status info
            pairedEmptyState
        } else {
            // Unpaired state - prompt to pair
            unpairedEmptyState
        }
    }

    /// When paired: show Session Dashboard with activity info
    /// V3 A3: Fresh Session - Green "Connected" status when no activity yet
    private var pairedEmptyState: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // V3 A3: Status header - "Connected" (green) when fresh session, "Idle" (gray) when has activity
                    HStack(spacing: 6) {
                        if activityStore.lastActivity == nil {
                            // Fresh session: Green dot + "Connected"
                            ClaudeStateDot(state: .success, size: 6)
                            Text("Connected")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ClaudeState.success.color)
                        } else {
                            // Has activity: Gray dot + "Idle"
                            ClaudeStateDot(state: .idle, size: 6)
                            Text("Idle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(ClaudeState.idle.color)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // F22: Session Dashboard Content
                    SessionDashboardContent(activityStore: activityStore)

                    // Bottom action buttons - History + Settings
                    HStack(spacing: 16) {
                        NavigationLink(destination: HistoryView()) {
                            VStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 16))
                                Text("History")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Claude.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Session history")

                        Button {
                            WKInterfaceDevice.current().play(.click)
                            showingSettings = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16))
                                Text("Settings")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(Claude.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    .padding(.top, 4)

                    // Pairing ID (subtle, at bottom)
                    Text(String(service.pairingId.prefix(8)))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Claude.textTertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .focusable()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
    }

    /// When not paired: show pairing prompt
    private var unpairedEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            // Claude face logo
            ClaudeFaceLogo(size: 50)

            // Title and subtitle
            VStack(spacing: 4) {
                Text("Claude Code")
                    .font(.headline)
                    .foregroundColor(Claude.textPrimary)

                Text("Watch Companion")
                    .font(.caption)
                    .foregroundColor(Claude.textSecondary)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                Button {
                    showingPairing = true
                } label: {
                    Text("Pair with Code")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .accessibilityLabel("Pair with Claude Code")

                Button {
                    service.loadDemoData()
                } label: {
                    Text("Try Demo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.glassCompat)
                .accessibilityLabel("Try demo mode")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingPairing) {
            PairingView(service: service)
        }
    }

    private var connectionColor: Color {
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }

    private var connectionText: String {
        switch service.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .reconnecting: return "Reconnecting..."
        case .disconnected: return "Disconnected"
        }
    }
}

// MARK: - Offline State
struct OfflineStateView: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        VStack(spacing: 12) {
            // V2: State header with colored dot
            HStack(spacing: 6) {
                ClaudeStateDot(state: .error, size: 6)
                Text("Error")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ClaudeState.error.color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            // Icon - yellow/orange exclamation triangle per design spec
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Claude.warning)

            // Title and subtitle per design spec
            VStack(spacing: 4) {
                Text("Connection Lost")
                    .font(.headline)
                    .foregroundColor(Claude.textPrimary)

                Text("Unable to reach session")
                    .font(.caption)
                    .foregroundColor(Claude.textSecondary)
            }

            Spacer()

            // Retry button only (no Demo per spec)
            Button {
                service.connect()
                WKInterfaceDevice.current().play(.click)
            } label: {
                Text("Retry")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminentCompat)
            .tint(Claude.orange)
            .accessibilityLabel("Retry connection")
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
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
            .glassEffectCompat(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Always-On Display View
struct AlwaysOnDisplayView: View {
    let connectionStatus: ConnectionStatus
    let pendingCount: Int
    let status: SessionStatus

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

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
                    .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
            }

            // Simplified status display
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: statusIconSize, weight: .light))
                    .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
                    .contentTransition(.symbolEffect(.replace))

                Text(statusText)
                    .font(.title3)
                    .foregroundColor(Claude.textPrimary)

                // Pending count (if any)
                if pendingCount > 0 {
                    Text("\(pendingCount) pending")
                        .font(.caption)
                        .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
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

// MARK: - F22: Session Dashboard Content

/// Dynamic content for the Session Dashboard
/// Shows last activity, session stats, or waiting state
struct SessionDashboardContent: View {
    @ObservedObject var activityStore: ActivityStore

    // Timer to refresh time ago text
    @State private var refreshTrigger = false
    private let refreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 8) {
            if let lastActivity = activityStore.lastActivity {
                // Has activity - show last activity card
                LastActivityCard(event: lastActivity)

                // Session stats row (if available)
                if let stats = activityStore.currentSessionStats {
                    SessionStatsRow(tasks: stats.tasks, approvals: stats.approvals)
                }

                // Idle warning (if idle for >5 minutes)
                if activityStore.isIdleFor(minutes: 5) {
                    IdleWarningText(minutes: Int((activityStore.timeSinceLastActivity ?? 0) / 60))
                }
            } else {
                // V3 A3: Fresh session - no activity yet
                // Shows Claude icon (32x32) with "Waiting for Claude..." text
                ClaudeFaceLogo(size: 32, animated: true)

                VStack(spacing: 4) {
                    Text("Waiting for Claude...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Claude.textPrimary)

                    Text("No activity yet")
                        .font(.system(size: 11))
                        .foregroundColor(Claude.textSecondary)
                }
            }
        }
        .id(refreshTrigger)  // Force refresh on timer
        .onReceive(refreshTimer) { _ in
            refreshTrigger.toggle()
        }
    }
}

/// Card showing the last activity event
struct LastActivityCard: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 10) {
            // Event icon
            Image(systemName: event.icon)
                .font(.system(size: 18))
                .foregroundColor(event.color)
                .frame(width: 24)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.truncatedTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Claude.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(.system(size: 9))
                            .foregroundColor(Claude.textTertiary)
                    }

                    Text(event.timeAgoText)
                        .font(.system(size: 9))
                        .foregroundColor(Claude.textTertiary)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Claude.surface1)
        )
    }
}

/// Row showing session statistics
struct SessionStatsRow: View {
    let tasks: Int
    let approvals: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
                .font(.system(size: 10))
                .foregroundColor(Claude.textTertiary)

            Text("\(tasks) task\(tasks == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(Claude.textSecondary)

            Text("•")
                .font(.system(size: 10))
                .foregroundColor(Claude.textTertiary)

            Image(systemName: "hand.raised")
                .font(.system(size: 10))
                .foregroundColor(Claude.textTertiary)

            Text("\(approvals) approval\(approvals == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundColor(Claude.textSecondary)
        }
    }
}

/// Warning text shown when session has been idle
struct IdleWarningText: View {
    let minutes: Int

    var body: some View {
        Text("Session idle for \(minutes) min")
            .font(.system(size: 9))
            .foregroundColor(Claude.warning)
    }
}

// MARK: - Previews
#Preview("Empty State - Paired") {
    EmptyStateView()
}

#Preview("Offline State") {
    OfflineStateView()
}

#Preview("Reconnecting") {
    ReconnectingView(status: .reconnecting(attempt: 2, nextRetryIn: 5))
}

#Preview("Always-On Display") {
    AlwaysOnDisplayView(
        connectionStatus: .connected,
        pendingCount: 3,
        status: .waiting
    )
}

#Preview("Last Activity Card") {
    LastActivityCard(event: ActivityEvent(
        type: .taskCompleted,
        title: "Fixed authentication bug",
        subtitle: "3 files changed"
    ))
    .padding()
}

#Preview("Session Stats Row") {
    VStack(spacing: 16) {
        SessionStatsRow(tasks: 3, approvals: 8)
        SessionStatsRow(tasks: 1, approvals: 1)
    }
    .padding()
}

#Preview("Idle Warning") {
    IdleWarningText(minutes: 12)
        .padding()
}
