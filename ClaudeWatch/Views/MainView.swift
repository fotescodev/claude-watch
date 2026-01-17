import SwiftUI
import WatchKit

// RALPH_TEST: Loop verification successful

// MARK: - Main View
struct MainView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingVoiceInput = false
    @State private var showingSettings = false
    @State private var pulsePhase: CGFloat = 0

    // Always-On Display support
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

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
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulsePhase = 1
        }
    }
}

// MARK: - Status Header
struct StatusHeader: View {
    @ObservedObject private var service = WatchService.shared
    let pulsePhase: CGFloat

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    // Dynamic Type support - scale icon sizes with text
    @ScaledMetric(relativeTo: .headline) private var statusIconContainerSize: CGFloat = 32
    @ScaledMetric(relativeTo: .headline) private var statusIconSize: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var badgeFontSize: CGFloat = 13

    var body: some View {
        VStack(spacing: 8) {
            // Main status
            HStack(spacing: 8) {
                // Status icon with pulse (respects Reduce Motion)
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: statusIconContainerSize, height: statusIconContainerSize)

                    if (service.state.status == .running || service.state.status == .waiting) && !reduceMotion {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: statusIconContainerSize, height: statusIconContainerSize)
                            .scaleEffect(1 + pulsePhase * 0.2)
                    }

                    Image(systemName: statusIcon)
                        .font(.system(size: statusIconSize, weight: .bold))
                        .foregroundColor(statusColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: isStatusActive && !reduceMotion)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(Claude.textPrimary)

                    if !service.state.taskName.isEmpty {
                        Text(service.state.taskName)
                            .font(.caption2)
                            .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
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
        .glassEffectCompat(RoundedRectangle(cornerRadius: 16))
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

    private var isStatusActive: Bool {
        service.state.status == .running || service.state.status == .waiting
    }
}

#Preview {
    MainView()
}
