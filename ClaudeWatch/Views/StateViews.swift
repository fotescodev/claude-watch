import SwiftUI
import WatchKit

// MARK: - Empty State
struct EmptyStateView: View {
    var service = WatchService.shared
    var activityStore = ActivityStore.shared
    @State private var showingPairing = false

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
    /// V3 A3: Fresh Session - Gray "Idle" status, "Ready" text
    /// V3 A5: Long Idle - Gray "Idle" status after 5+ minutes of inactivity
    private var pairedEmptyState: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // V3: Always "Idle" with gray dot for empty/fresh session
                HStack(spacing: 6) {
                    ClaudeStateDot(state: .idle, size: 6)
                    Text("Idle")
                        .font(.claudeCaptionBold)
                        .foregroundStyle(ClaudeState.idle.color)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Spacer(minLength: 8)

                // F22: Session Dashboard Content
                SessionDashboardContent(activityStore: activityStore)

                Spacer(minLength: 8)

                // V3: Icon-only footer button (history only - settings via long press)
                NavigationLink(destination: HistoryView()) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.claudeIconButton)
                        .foregroundStyle(Claude.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Session history")
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 8)
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
                    .foregroundStyle(Claude.textPrimary)

                Text("Watch Companion")
                    .font(.caption)
                    .foregroundStyle(Claude.textSecondary)
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
                        .foregroundStyle(Claude.orange)
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
}

// MARK: - Offline State
struct OfflineStateView: View {
    var service = WatchService.shared

    var body: some View {
        VStack(spacing: 12) {
            // V2: State header with colored dot
            HStack(spacing: 6) {
                ClaudeStateDot(state: .error, size: 6)
                Text("Error")
                    .font(.claudeCaptionBold)
                    .foregroundStyle(ClaudeState.error.color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()

            // Icon - yellow/orange exclamation triangle per design spec
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.claudeIconDisplay)
                .foregroundStyle(Claude.warning)

            // Title and subtitle per design spec
            VStack(spacing: 4) {
                Text("Connection Lost")
                    .font(.headline)
                    .foregroundStyle(Claude.textPrimary)

                Text("Unable to reach session")
                    .font(.caption)
                    .foregroundStyle(Claude.textSecondary)
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
                            .foregroundStyle(Claude.textPrimary)

                        Text("Attempt \(attempt) • \(Int(nextRetryIn))s")
                            .font(.caption2)
                            .foregroundStyle(Claude.textSecondary)
                    } else {
                        Text("Connecting...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Claude.textPrimary)
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
                    .foregroundStyle(Claude.textSecondaryContrast(colorSchemeContrast))
            }

            // Simplified status display
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.system(size: statusIconSize, weight: .light))
                    .foregroundStyle(Claude.textSecondaryContrast(colorSchemeContrast))
                    .contentTransition(.symbolEffect(.replace))

                Text(statusText)
                    .font(.title3)
                    .foregroundStyle(Claude.textPrimary)

                // Pending count (if any)
                if pendingCount > 0 {
                    Text("\(pendingCount) pending")
                        .font(.caption)
                        .foregroundStyle(Claude.textSecondaryContrast(colorSchemeContrast))
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
/// V3 A4: Activity state with Claude icon + last activity card
struct SessionDashboardContent: View {
    var activityStore: ActivityStore

    var body: some View {
        // TimelineView re-evaluates content every 30s to refresh time-ago text
        // without destroying and recreating the view tree
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            ZStack {
                if let lastActivity = activityStore.lastActivity {
                    // V3 A4: Brand glow behind entire content (icon + card)
                    AmbientGlow.brand()
                        .scaleEffect(0.45)
                        .offset(y: 20)

                    VStack(spacing: 6) {
                        // Claude icon 32pt
                        ClaudeFaceLogo(size: 32)

                        // Has activity - show last activity card with stats inside
                        LastActivityCard(
                            event: lastActivity,
                            stats: activityStore.currentSessionStats
                        )
                    }
                } else {
                    // V3 A3: Fresh session - Claude icon with brand glow, "Ready" text
                    AmbientGlow.brand()
                        .scaleEffect(0.5)
                        .offset(y: 15)

                    VStack(spacing: 6) {
                        ClaudeFaceLogo(size: 44)

                        Text("Ready")
                            .font(.claudeHeadline)
                            .foregroundStyle(Claude.anthropicOrange)
                    }
                }
            }
        }
    }
}

/// Card showing the last activity event
/// V3 A4: Centered layout with large title, time, and stats inside card
/// Uses gradient fill from design: #ffffff12 top to #ffffff08 bottom
struct LastActivityCard: View {
    let event: ActivityEvent
    var stats: (tasks: Int, approvals: Int)?

    var body: some View {
        VStack(spacing: 6) {
            // Large centered title (17pt semibold, white)
            Text(event.truncatedTitle)
                .font(.claudeTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Time ago (13pt, #9A9A9F)
            Text(event.timeAgoText)
                .font(.claudeSubheadline)
                .foregroundStyle(Claude.textMuted)

            // Stats row inside card (11pt medium, #6E6E73)
            if let stats = stats {
                Text("\(stats.tasks) task\(stats.tasks == 1 ? "" : "s")  •  \(stats.approvals) approval\(stats.approvals == 1 ? "" : "s")")
                    .font(.claudeFootnoteMedium)
                    .foregroundStyle(Claude.textDisabled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),  // #ffffff12 ≈ 7%
                            Color.white.opacity(0.03)   // #ffffff08 ≈ 3%
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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
                .font(.claudeMicro)
                .foregroundStyle(Claude.textTertiary)

            Text("\(tasks) task\(tasks == 1 ? "" : "s")")
                .font(.claudeMicro)
                .foregroundStyle(Claude.textSecondary)

            Text("•")
                .font(.claudeMicro)
                .foregroundStyle(Claude.textTertiary)

            Image(systemName: "hand.raised")
                .font(.claudeMicro)
                .foregroundStyle(Claude.textTertiary)

            Text("\(approvals) approval\(approvals == 1 ? "" : "s")")
                .font(.claudeMicro)
                .foregroundStyle(Claude.textSecondary)
        }
    }
}

/// Warning text shown when session has been idle
struct IdleWarningText: View {
    let minutes: Int

    var body: some View {
        Text("Session idle for \(minutes) min")
            .font(.claudeNano)
            .foregroundStyle(Claude.warning)
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
    LastActivityCard(
        event: ActivityEvent(
            type: .taskCompleted,
            title: "Fixed auth bug",
            subtitle: nil
        ),
        stats: (tasks: 3, approvals: 8)
    )
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
