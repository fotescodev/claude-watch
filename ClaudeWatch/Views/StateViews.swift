import SwiftUI
import WatchKit

// MARK: - Empty State
struct EmptyStateView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingPairing = false

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Icon
            Image(systemName: service.isPaired ? "tray" : "link.circle")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Claude.textTertiaryContrast(colorSchemeContrast))

            // Title
            Text(service.isPaired ? "All Clear" : "Not Paired")
                .font(.headline)
                .foregroundColor(Claude.textPrimary)

            Spacer()

            // Action buttons - using glass styles
            VStack(spacing: 6) {
                if !service.isPaired {
                    Button {
                        showingPairing = true
                    } label: {
                        Text("Pair with Code")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminentCompat)
                    .accessibilityLabel("Pair with Claude Code")
                }

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
}

// MARK: - Offline State
struct OfflineStateView: View {
    @ObservedObject private var service = WatchService.shared

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    // Dynamic Type support
    @ScaledMetric(relativeTo: .title) private var iconContainerSize: CGFloat = 80
    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 16) {
            // Icon with Liquid Glass (tap to load demo)
            ZStack {
                Image(systemName: "wifi.slash")
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundColor(Claude.textTertiaryContrast(colorSchemeContrast))
            }
            .frame(width: iconContainerSize, height: iconContainerSize)
            .glassEffectInteractive(Circle())
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
                .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))

            // Buttons
            VStack(spacing: 10) {
                // Retry button - using glass prominent style
                Button {
                    service.connect()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("Retry")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .accessibilityLabel("Retry connection")

                // Demo button - using glass style
                Button {
                    service.loadDemoData()
                } label: {
                    Text("Demo Mode")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Claude.orange)
                }
                .buttonStyle(.glassCompat)
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
