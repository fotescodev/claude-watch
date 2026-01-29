import SwiftUI
import WatchKit

// RALPH_TEST: Loop verification successful

// MARK: - Main View (V2 State-Driven Architecture)
struct MainView: View {
    var service = WatchService.shared
    @State private var showingVoiceInput = false
    @State private var showingSettings = false
    @State private var showingQuickActions = false
    @State private var pulsePhase: CGFloat = 0
    @State private var demoScreenIndex: Int = 0

    // Always-On Display support
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Status info for centralized status bar
    private var currentStatusInfo: (text: String, color: Color)? {
        switch currentViewState {
        case .working:
            return ("Working", ClaudeState.working.color)
        case .paused:
            return ("Paused", Color(red: 0.557, green: 0.557, blue: 0.576))
        case .question:
            return ("Question", Claude.question)
        case .contextWarning:
            return ("Warning", Claude.warning)
        case .pairing:
            return ("Unpaired", Claude.idle)
        case .offline:
            return ("Offline", Claude.danger)
        case .reconnecting:
            return ("Connecting", Claude.warning)
        case .success:
            return ("Complete", Claude.success)
        default:
            return nil  // approvalQueue, approval, empty, main, alwaysOn handle their own
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Claude.background.ignoresSafeArea()

                // V2 State-driven content
                Group {
                    switch currentViewState {
                case .alwaysOn:
                    AlwaysOnDisplayView(
                        connectionStatus: service.connectionStatus,
                        pendingCount: service.state.pendingActions.count,
                        status: service.state.status
                    )
                case .pairing:
                    PairingView(service: service)
                case .offline:
                    OfflineStateView()
                case .reconnecting:
                    VStack {
                        ReconnectingView(status: service.connectionStatus)
                        Spacer()
                    }
                case .paused:
                    PausedView()
                case .success:
                    TaskOutcomeView()
                case .working:
                    WorkingView()
                case .approvalQueue:
                    ApprovalQueueView()
                case .approval:
                    // V3 C1-C3: Single approval with tier-based styling
                    ApprovalView()
                case .question:
                    // F18: Binary question response (V2: exactly 2 options)
                    if let question = service.pendingQuestion {
                        QuestionResponseView(
                            question: question.question,
                            options: question.options.map { opt in
                                QuestionOption(label: opt.label, description: opt.description)
                            },
                            questionId: question.id
                        )
                    } else {
                        mainContentView
                    }
                case .contextWarning:
                    // F16: Context warning
                    if let warning = service.contextWarning {
                        ContextWarningView(percentage: warning.percentage)
                    } else {
                        mainContentView
                    }
                case .empty:
                    EmptyStateView()
                case .main:
                    mainContentView
                }
            }
            .id(currentViewState)  // Force view replacement instead of animation overlap
            }
            .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.8), value: currentViewState)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let statusInfo = currentStatusInfo {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusInfo.color)
                                .frame(width: 6, height: 6)
                            Text(statusInfo.text)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(statusInfo.color)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
            }
        }
        // Demo mode: Navigation buttons as overlay (doesn't affect layout)
        .overlay(alignment: .bottom) {
            if service.isDemoMode {
                HStack(spacing: 6) {
                    // << Back
                    Button {
                        cycleToPreviousDemoScreen()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Claude.warning)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Current label
                    Text(demoScreenLabel)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Claude.warning)

                    // >> Next
                    Button {
                        cycleToNextDemoScreen()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Claude.warning)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 2)
            }
        }
        // V3: Removed toolbar - Settings accessible via footer button per design spec
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputSheet()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .sheet(isPresented: $showingQuickActions) {
            NavigationStack {
                QuickActionsView()
            }
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
        // Long press for quick actions menu
        .onLongPressGesture {
            showingQuickActions = true
            WKInterfaceDevice.current().play(.click)
        }
    }

    private var mainContentView: some View {
        glassEffectContainerCompat {
            VStack(spacing: 8) {
                // Only show status header when NO pending actions
                if service.state.pendingActions.isEmpty {
                    StatusHeader(pulsePhase: pulsePhase)

                    // Bottom row: Pause button + Mode selector on same plane
                    HStack(spacing: 8) {
                        // Pause/Resume button (only when session active and not complete)
                        if let progress = service.sessionProgress {
                            if !progress.isComplete {
                                // Note: Haptic played by WatchService.sendInterrupt on success
                                Button {
                                    Task {
                                        if service.isSessionInterrupted {
                                            await service.sendInterrupt(action: .resume)
                                        } else {
                                            await service.sendInterrupt(action: .stop)
                                        }
                                    }
                                } label: {
                                    Image(systemName: service.isSessionInterrupted ? "play.fill" : "pause.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 32, height: 32)
                                        .background(service.isSessionInterrupted ? Claude.success : Claude.danger)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ModeSelector()
                    }
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

    /// Current view state for animation tracking (V2 state-driven)
    private var currentViewState: ViewState {
        // System states take priority
        if isLuminanceReduced {
            return .alwaysOn
        } else if service.useCloudMode && !service.isPaired && !service.isDemoMode {
            return .pairing
        } else if service.connectionStatus == .disconnected && !service.isDemoMode {
            return .offline
        } else if case .reconnecting = service.connectionStatus {
            return .reconnecting
        }

        // V2 state-driven views
        // Paused state takes priority
        if service.isSessionInterrupted {
            return .paused
        }

        // F18: Question takes high priority
        if service.pendingQuestion != nil {
            return .question
        }

        // F16: Context warning takes priority over normal states
        if service.contextWarning != nil {
            return .contextWarning
        }

        // Approval states - PRIORITY over working (user must approve for Claude to continue)
        let pendingCount = service.state.pendingActions.count
        if pendingCount >= 2 {
            return .approvalQueue
        } else if pendingCount == 1 {
            return .approval
        }

        // Session progress states (only shown when no pending approvals)
        if let progress = service.sessionProgress {
            let isComplete = progress.isComplete
            if isComplete {
                return .success
            } else {
                return .working
            }
        }

        // Idle/empty state
        if service.state.status == .idle {
            return .empty
        }

        return .main
    }

    /// View state enum for animation tracking (V2 expanded)
    private enum ViewState: Equatable {
        // System states
        case alwaysOn, pairing, offline, reconnecting
        // V2 states
        case paused, working, success, approval, approvalQueue
        // F18/F16 states
        case question, contextWarning
        // Fallback
        case empty, main
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulsePhase = 1
        }
    }

    // MARK: - Demo Screen Cycling

    /// Ordered list of demo screens for cycling
    private var demoScreens: [(label: String, loader: () -> Void)] {
        [
            ("B1", { service.loadDemoWorking() }),
            ("B2", { service.loadDemoPaused() }),
            ("T1", { service.loadDemoApproval(tier: .low) }),
            ("T2", { service.loadDemoApproval(tier: .medium) }),
            ("T3", { service.loadDemoApproval(tier: .high) }),
            ("Q3", { service.loadDemoApprovalQueue() }),
            ("D1", { service.loadDemoSuccess() }),
            ("E1", { service.loadDemoQuestion() }),
            ("E2", { service.loadDemoContextWarning() }),
        ]
    }

    /// Current demo screen label for the >> button
    private var demoScreenLabel: String {
        let screens = demoScreens
        guard !screens.isEmpty else { return "??" }
        let index = demoScreenIndex % screens.count
        return screens[index].label
    }

    /// Cycle to the next demo screen
    private func cycleToNextDemoScreen() {
        let screens = demoScreens
        guard !screens.isEmpty else { return }
        demoScreenIndex = (demoScreenIndex + 1) % screens.count
        screens[demoScreenIndex].loader()
    }

    /// Cycle to the previous demo screen
    private func cycleToPreviousDemoScreen() {
        let screens = demoScreens
        guard !screens.isEmpty else { return }
        demoScreenIndex = (demoScreenIndex - 1 + screens.count) % screens.count
        screens[demoScreenIndex].loader()
    }
}

// MARK: - Status Header
struct StatusHeader: View {
    var service = WatchService.shared
    let pulsePhase: CGFloat

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        VStack(spacing: 10) {
            // Show session progress from TodoWrite if available
            if let progress = service.sessionProgress {
                sessionProgressView(progress)
            } else {
                // Fallback to existing task name display
                if !service.state.taskName.isEmpty {
                    Text(service.state.taskName)
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    Text(idleMessage)
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)
                        .multilineTextAlignment(.center)
                }

                // Progress bar with percentage when running (fallback)
                if service.state.status == .running || service.state.status == .waiting {
                    VStack(spacing: 4) {
                        ProgressView(value: service.state.progress)
                            .tint(Claude.orange)

                        Text("\(Int(service.state.progress * 100))%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Claude.textSecondary)
                    }
                }
            }

            // Status indicator - only show when NOT displaying session progress
            // (session progress already shows status in the header)
            if service.sessionProgress == nil {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)

                    Text(statusText)
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.textSecondaryContrast(colorSchemeContrast))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassEffectCompat(RoundedRectangle(cornerRadius: 16))
    }

    /// Session progress view showing rich state from TodoWrite
    /// Optimized spacing to fit within watch bezel
    @ViewBuilder
    private func sessionProgressView(_ progress: SessionProgress) -> some View {
        let isComplete = progress.isComplete

        VStack(spacing: 4) {
            // Current task label + activity
            VStack(alignment: .leading, spacing: 1) {
                // Subtle "CURRENT TASK" label
                if !isComplete {
                    Text("CURRENT TASK")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(Claude.textTertiary)
                        .tracking(0.5)
                }

                // Activity with status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(isComplete ? Claude.success : Claude.orange)
                        .frame(width: 5, height: 5)
                        .opacity(isComplete || reduceMotion ? 1.0 : 0.5 + 0.5 * Double(pulsePhase))

                    // Show completion state, current activity, or working status
                    if isComplete {
                        Text("Complete")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Claude.success)
                    } else if let activity = progress.currentActivity ?? progress.currentTask {
                        Text(activity)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Claude.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text("Working...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Claude.textPrimary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Todo list (show up to 3 items to save space on watch)
            if !progress.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(progress.tasks.prefix(3)) { task in
                        HStack(spacing: 4) {
                            Text(task.status.icon)
                                .font(.system(size: 8))
                                .foregroundStyle(task.status.color)

                            Text(task.content)
                                .font(.system(size: 9))
                                .foregroundStyle(task.status == .completed ? Claude.textSecondary : Claude.textPrimary)
                                .lineLimit(1)
                        }
                    }

                    // Show "... and X more" if there are more tasks
                    if progress.tasks.count > 3 {
                        Text("+\(progress.tasks.count - 3) more")
                            .font(.system(size: 8, weight: .regular))
                            .foregroundStyle(Claude.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Progress bar with stats - compact
            HStack(spacing: 6) {
                ProgressView(value: progress.progress)
                    .tint(isComplete ? Claude.success : Claude.orange)

                Text("\(progress.completedCount)/\(progress.totalCount)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Claude.textSecondary)
            }

        }
    }

    private var idleMessage: String {
        switch service.state.status {
        case .idle:
            return "Ready for tasks"
        case .running:
            return "Working..."
        case .waiting:
            return "Awaiting input"
        case .completed:
            return "Task complete"
        case .failed:
            return "Task failed"
        }
    }

    private var statusText: String {
        // Override status text when showing session progress
        if let progress = service.sessionProgress {
            return progress.isComplete ? "Complete" : "Working"
        }

        switch service.state.status {
        case .idle: return "Idle"
        case .running: return "Working"
        case .waiting: return "Waiting"
        case .completed: return "Done"
        case .failed: return "Error"
        }
    }

    private var statusColor: Color {
        // Override status color when showing session progress
        if let progress = service.sessionProgress {
            return progress.isComplete ? Claude.success : Claude.orange
        }

        switch service.state.status {
        case .idle: return Claude.textSecondary
        case .running: return Claude.orange
        case .waiting: return Claude.warning
        case .completed: return Claude.success
        case .failed: return Claude.danger
        }
    }
}

#Preview {
    MainView()
}
