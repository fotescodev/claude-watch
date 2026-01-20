import SwiftUI
import WatchKit

// MARK: - Empty State
struct EmptyStateView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingPairing = false

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

    /// When paired: show waiting-for-activity state with session history
    private var pairedEmptyState: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Current status: Listening...
                VStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 6, height: 6)

                        Text("Listening...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Claude.textSecondary)

                        Spacer()
                    }

                    if service.sessionHistory.isEmpty {
                        Text("Activity will appear here")
                            .font(.system(size: 10))
                            .foregroundColor(Claude.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Claude.surface1)
                )

                // Session History
                if !service.sessionHistory.isEmpty {
                    ForEach(service.sessionHistory) { session in
                        SessionHistoryRow(session: session) {
                            WKInterfaceDevice.current().play(.click)
                            service.toggleSessionExpanded(session.id)
                        }
                    }
                }

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

    /// A single row in session history
    struct SessionHistoryRow: View {
        let session: CompletedSession
        let onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    // Header row
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(Claude.textSecondary)

                        Text(session.taskCountText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Claude.textPrimary)

                        Spacer()

                        Text(session.relativeTimeText)
                            .font(.system(size: 9))
                            .foregroundColor(Claude.textTertiary)

                        Image(systemName: session.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(Claude.textTertiary)
                    }

                    // Expanded task list
                    if session.isExpanded {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(session.tasks) { task in
                                HStack(spacing: 4) {
                                    Text("·")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Claude.textTertiary)
                                    Text(task.content)
                                        .font(.system(size: 9))
                                        .foregroundColor(Claude.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            // Duration
                            Text("Took \(session.durationText)")
                                .font(.system(size: 8))
                                .foregroundColor(Claude.textTertiary)
                                .padding(.top, 2)
                        }
                        .padding(.leading, 16)
                        .padding(.top, 2)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Claude.surface1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// When not paired: show pairing prompt
    private var unpairedEmptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            // Icon
            Image(systemName: "link.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Claude.textTertiaryContrast(colorSchemeContrast))

            // Title
            Text("Not Paired")
                .font(.headline)
                .foregroundColor(Claude.textPrimary)

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

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Icon - compact 40pt (triple-tap to load demo)
            Image(systemName: "wifi.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Claude.textTertiaryContrast(colorSchemeContrast))
                .onTapGesture(count: 3) {
                    service.loadDemoData()
                }

            // Title only - no subtitle
            Text("Offline")
                .font(.headline)
                .foregroundColor(Claude.textPrimary)

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                // Full-width Retry button
                Button {
                    service.connect()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .accessibilityLabel("Retry connection")

                // Demo as text link
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Demo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.glassCompat)
                .accessibilityLabel("Enter demo mode")
            }
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
