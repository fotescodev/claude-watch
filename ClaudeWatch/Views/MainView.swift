import SwiftUI
import WatchKit

// RALPH_TEST: Loop verification successful

// MARK: - Main View
struct MainView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showingVoiceInput = false
    @State private var showingSettings = false
    @State private var pulsePhase: CGFloat = 0

    // Liquid Glass morphing namespace (watchOS 26+)
    @Namespace private var glassNamespace

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

            // Wrap state views in GlassEffectContainer for morphing transitions (watchOS 26+)
            glassEffectContainerForMorphing {
                // Always-On Display: Show simplified view
                if isLuminanceReduced {
                    AlwaysOnDisplayView(
                        connectionStatus: service.connectionStatus,
                        pendingCount: service.state.pendingActions.count,
                        status: service.state.status
                    )
                    .glassEffectIDCompat("mainState", in: glassNamespace)
                }
                // Content based on state
                else if service.useCloudMode && !service.isPaired && !service.isDemoMode {
                    PairingView(service: service)
                        .glassEffectIDCompat("mainState", in: glassNamespace)
                } else if service.connectionStatus == .disconnected && !service.isDemoMode {
                    OfflineStateView()
                        .glassEffectIDCompat("mainState", in: glassNamespace)
                } else if case .reconnecting = service.connectionStatus {
                    // Show reconnecting indicator over main content
                    VStack {
                        ReconnectingView(status: service.connectionStatus)
                        Spacer()
                    }
                    .glassEffectIDCompat("mainState", in: glassNamespace)
                } else if service.state.pendingActions.isEmpty && service.state.status == .idle {
                    EmptyStateView()
                        .glassEffectIDCompat("mainState", in: glassNamespace)
                } else {
                    mainContentView
                        .glassEffectIDCompat("mainState", in: glassNamespace)
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: currentViewState)
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
        glassEffectContainerCompat {
            VStack(spacing: 8) {
                // Only show status header when NO pending actions
                if service.state.pendingActions.isEmpty {
                    StatusHeader(pulsePhase: pulsePhase)
                    ModeSelector()
                } else {
                    // Pending actions take priority - show them directly
                    ActionQueue()
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
    }

    /// Wraps content in GlassEffectContainer on watchOS 26+, otherwise returns content as-is
    @ViewBuilder
    private func glassEffectContainerCompat<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(watchOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content()
            }
        } else {
            content()
        }
    }

    /// Wraps state views in GlassEffectContainer for morphing transitions (watchOS 26+)
    @ViewBuilder
    private func glassEffectContainerForMorphing<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(watchOS 26.0, *) {
            GlassEffectContainer {
                content()
            }
        } else {
            content()
        }
    }

    /// Current view state for animation tracking
    private var currentViewState: ViewState {
        if isLuminanceReduced {
            return .alwaysOn
        } else if service.useCloudMode && !service.isPaired && !service.isDemoMode {
            return .pairing
        } else if service.connectionStatus == .disconnected && !service.isDemoMode {
            return .offline
        } else if case .reconnecting = service.connectionStatus {
            return .reconnecting
        } else if service.state.pendingActions.isEmpty && service.state.status == .idle {
            return .empty
        } else {
            return .main
        }
    }

    /// View state enum for animation tracking
    private enum ViewState: Equatable {
        case alwaysOn, pairing, offline, reconnecting, empty, main
    }

    private var connectionIcon: String {
        switch service.connectionStatus {
        case .connected: return "link.circle.fill"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .reconnecting: return "arrow.clockwise.circle"
        case .disconnected: return "link.badge.plus"
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

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var statusIconContainerSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var statusIconSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            // Status icon with pulse
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

            // Status text
            Text(statusText)
                .font(.claudeHeadline)
                .foregroundColor(Claude.textPrimary)

            // Task name or subtitle
            if !service.state.taskName.isEmpty {
                Text(service.state.taskName)
                    .font(.claudeFootnote)
                    .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text(statusSubtitle)
                    .font(.claudeFootnote)
                    .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
                    .multilineTextAlignment(.center)
            }

            // Progress bar when running
            if service.state.status == .running || service.state.status == .waiting {
                ProgressView(value: service.state.progress)
                    .tint(Claude.orange)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassEffectCompat(RoundedRectangle(cornerRadius: 16))
    }

    private var statusSubtitle: String {
        switch service.state.status {
        case .idle: return "Waiting for actions"
        case .running: return "Claude is working..."
        case .waiting: return "Waiting for approval"
        case .completed: return "Task completed"
        case .failed: return "Something went wrong"
        }
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
