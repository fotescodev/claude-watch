import SwiftUI
import WatchKit

// MARK: - Error Banner
struct ErrorBanner: View {
    let message: String
    @Binding var isVisible: Bool

    // Accessibility: High Contrast support
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        if isVisible {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Claude.danger)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .task {
                // Auto-dismiss after 3 seconds (auto-cancelled on disappear)
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.3)) {
                    isVisible = false
                }
            }
            .accessibilityLabel("Error: \(message)")
        }
    }
}

// MARK: - Action Queue
struct ActionQueue: View {
    @ObservedObject private var service = WatchService.shared

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Spring animation state
    @State private var approveAllPressed = false
    @State private var didApproveAll = false

    // Confirmation dialog state
    @State private var showApproveAllConfirmation = false

    /// Check if any pending action is Tier 3 (dangerous)
    private var hasHighRiskAction: Bool {
        service.state.pendingActions.contains { $0.tier == .high }
    }

    /// Count of approvable actions (Tier 1-2 only)
    private var approvableCount: Int {
        service.state.pendingActions.filter { $0.tier != .high }.count
    }

    var body: some View {
        VStack(spacing: 6) {
            // Primary action card only (now tiered)
            if let action = service.state.pendingActions.first {
                TieredActionCard(action: action, totalCount: service.state.pendingActions.count)
            }

            // Approve All button - only if more than 1 action AND all are approvable (no Tier 3)
            if approvableCount > 1 && !hasHighRiskAction {
                Button {
                    showApproveAllConfirmation = true
                } label: {
                    Text("Approve All (\(approvableCount))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Claude.success)
                        .clipShape(Capsule())
                        .scaleEffect(approveAllPressed && !reduceMotion ? 0.95 : 1.0)
                        .animation(.bouncySpringIfAllowed(reduceMotion: reduceMotion), value: approveAllPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in approveAllPressed = true }
                        .onEnded { _ in approveAllPressed = false }
                )
                .accessibilityLabel("Approve all \(approvableCount) pending actions")
                .sensoryFeedback(.success, trigger: didApproveAll)
                .confirmationDialog(
                    "Approve All?",
                    isPresented: $showApproveAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Approve \(approvableCount) Actions", role: .destructive) {
                        service.approveAll()
                        didApproveAll.toggle()
                        AccessibilityNotification.Announcement("Approved all \(approvableCount) actions").post()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will approve all pending actions at once.")
                }
            }

            // Warning if Tier 3 present with multiple actions
            if hasHighRiskAction && service.state.pendingActions.count > 1 {
                Text("Some actions require Mac approval")
                    .font(.system(size: 9))
                    .foregroundColor(Claude.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Tiered Action Card (V2)
/// Action card with tier-based styling and behavior
/// - Tier 1 (Low): Green accent, double tap approves
/// - Tier 2 (Medium): Orange accent, double tap approves
/// - Tier 3 (High): Red accent, Reject + Remind only, double tap REJECTS
struct TieredActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction
    var totalCount: Int = 1

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Dynamic Type support - compact sizes for watch
    @ScaledMetric(relativeTo: .footnote) private var iconContainerSize: CGFloat = 32
    @ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 14

    // Spring animation states for buttons
    @State private var rejectPressed = false
    @State private var approvePressed = false
    @State private var remindPressed = false

    // Haptic feedback triggers
    @State private var didReject = false
    @State private var didApprove = false
    @State private var didRemind = false

    // Error handling state
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var didError = false

    /// The action's risk tier
    private var tier: ActionTier { action.tier }

    var body: some View {
        VStack(spacing: 8) {
            // Error banner
            ErrorBanner(message: errorMessage, isVisible: $showError)

            // Tier badge + Action info
            HStack(spacing: 8) {
                // Type icon with tier-colored background
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tier.cardColor)
                        .frame(width: iconContainerSize, height: iconContainerSize)

                    Image(systemName: action.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(action.title)
                            .font(.claudeHeadline)
                            .foregroundColor(Claude.textPrimary)
                            .lineLimit(1)

                        // Tier badge for dangerous actions
                        if tier == .high {
                            TierBadge(tier: tier, compact: true)
                        }
                    }

                    if let path = action.filePath {
                        Text(truncatePath(path))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    } else if let cmd = action.command {
                        Text(truncateCommand(cmd))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Show count badge if more than 1 action
                if totalCount > 1 {
                    Text("\(totalCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(tier.cardColor)
                        .clipShape(Circle())
                }
            }

            // Action buttons - different for Tier 3
            if tier == .high {
                // Tier 3: Reject + Remind 5m (NO approve button)
                tier3Buttons
            } else {
                // Tier 1-2: Standard Approve/Reject
                standardButtons
            }

            // Mac hint for Tier 3
            if let hint = tier.macHint {
                Text(hint)
                    .font(.system(size: 9))
                    .foregroundColor(Claude.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Claude.Radius.large)
                .stroke(tier.cardColor.opacity(0.6), lineWidth: 2)
        )
        .glassEffectInteractive(RoundedRectangle(cornerRadius: Claude.Radius.large))
        .sensoryFeedback(.error, trigger: didError)
        // Double tap gesture per tier
        .modifier(TieredDoubleTapModifier(tier: tier, onApprove: approveAction, onReject: rejectAction))
    }

    // MARK: - Standard Buttons (Tier 1-2)

    private var standardButtons: some View {
        HStack(spacing: 6) {
            // Reject button
            Button {
                rejectAction()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Claude.danger)
                    .clipShape(Capsule())
                    .scaleEffect(rejectPressed && !reduceMotion ? 0.92 : 1.0)
                    .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: rejectPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in rejectPressed = true }
                    .onEnded { _ in rejectPressed = false }
            )
            .accessibilityLabel("Reject \(action.title)")
            .accessibilitySortPriority(1)
            .sensoryFeedback(.error, trigger: didReject)

            // Approve button
            Button {
                approveAction()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Claude.success)
                    .clipShape(Capsule())
                    .scaleEffect(approvePressed && !reduceMotion ? 0.92 : 1.0)
                    .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: approvePressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in approvePressed = true }
                    .onEnded { _ in approvePressed = false }
            )
            .accessibilityLabel("Approve \(action.title)")
            .accessibilitySortPriority(2)
            .sensoryFeedback(.success, trigger: didApprove)
        }
    }

    // MARK: - Tier 3 Buttons (Reject + Remind 5m)

    private var tier3Buttons: some View {
        HStack(spacing: 6) {
            // Reject button (primary for Tier 3)
            Button {
                rejectAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Reject")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Claude.danger)
                .clipShape(Capsule())
                .scaleEffect(rejectPressed && !reduceMotion ? 0.92 : 1.0)
                .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: rejectPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in rejectPressed = true }
                    .onEnded { _ in rejectPressed = false }
            )
            .accessibilityLabel("Reject dangerous action: \(action.title)")
            .accessibilitySortPriority(2)
            .sensoryFeedback(.error, trigger: didReject)

            // Remind 5m button
            Button {
                remindLater()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                    Text("5m")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(Claude.textPrimary)
                .background(Claude.surface2)
                .clipShape(Capsule())
                .scaleEffect(remindPressed && !reduceMotion ? 0.92 : 1.0)
                .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: remindPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in remindPressed = true }
                    .onEnded { _ in remindPressed = false }
            )
            .accessibilityLabel("Remind me in 5 minutes")
            .accessibilitySortPriority(1)
            .sensoryFeedback(.success, trigger: didRemind)
        }
    }

    // MARK: - Actions

    private func approveAction() {
        guard tier.canApproveFromWatch else {
            // Tier 3 cannot be approved from watch
            errorMessage = "Must approve from Mac"
            withAnimation { showError = true }
            didError.toggle()
            return
        }

        Task { @MainActor in
            // Optimistic update first - remove action immediately
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                // V2 Fix: Return to idle unless there's active session progress
                if service.sessionProgress == nil {
                    service.state.status = .idle
                } else {
                    service.state.status = .running
                }
            }
            service.playHaptic(.success)
            didApprove.toggle()
            AccessibilityNotification.Announcement("Approved \(action.title)").post()

            // Then notify server (best effort)
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: true)
            } else {
                service.approveAction(action.id)
            }
        }
    }

    private func rejectAction() {
        Task { @MainActor in
            // Optimistic update first - remove action immediately
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                // V2 Fix: Return to idle (reject never triggers working state)
                service.state.status = .idle
            }
            service.playHaptic(.failure)
            didReject.toggle()
            AccessibilityNotification.Announcement("Rejected \(action.title)").post()

            // Then notify server (best effort)
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: false)
            } else {
                service.rejectAction(action.id)
            }
        }
    }

    private func remindLater() {
        // TODO: Implement remind functionality - snooze for 5 minutes
        // For now, just remove from view (notification will return)
        Task { @MainActor in
            service.state.pendingActions.removeAll { $0.id == action.id }
            service.playHaptic(.notification)
            didRemind.toggle()
            AccessibilityNotification.Announcement("Will remind in 5 minutes").post()

            // TODO: Schedule local notification for 5 minutes
        }
    }

    // MARK: - Helpers

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return path
    }

    private func truncateCommand(_ cmd: String) -> String {
        if cmd.count > 25 {
            return String(cmd.prefix(22)) + "..."
        }
        return cmd
    }
}

// MARK: - Tiered Double Tap Modifier

/// Applies double tap gesture based on tier
/// Tier 1-2: Double tap approves
/// Tier 3: Double tap REJECTS (safety default)
private struct TieredDoubleTapModifier: ViewModifier {
    let tier: ActionTier
    let onApprove: () -> Void
    let onReject: () -> Void

    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .handGestureShortcut(.primaryAction)
                .onTapGesture(count: 2) {
                    switch tier.doubleTapAction {
                    case .approve:
                        onApprove()
                    case .reject:
                        onReject()
                    }
                }
        } else {
            content
                .onTapGesture(count: 2) {
                    switch tier.doubleTapAction {
                    case .approve:
                        onApprove()
                    case .reject:
                        onReject()
                    }
                }
        }
    }
}

// MARK: - Compact Status Header
/// Single-line status header for glanceable design (under 40pt height)
struct CompactStatusHeader: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        HStack(spacing: 6) {
            // Status dot (8pt)
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Status text
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundColor(Claude.textPrimary)

            Spacer()

            // Pending badge (if any)
            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(highestTierColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var pendingCount: Int {
        service.state.pendingActions.count
    }

    /// Badge color reflects highest tier pending
    private var highestTierColor: Color {
        let tiers = service.state.pendingActions.map { $0.tier }
        if tiers.contains(.high) { return ActionTier.high.cardColor }
        if tiers.contains(.medium) { return ActionTier.medium.cardColor }
        return ActionTier.low.cardColor
    }

    private var statusText: String {
        switch service.state.status {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .waiting:
            return "Waiting"
        case .completed:
            return "Done"
        case .failed:
            return "Error"
        }
    }

    private var statusColor: Color {
        switch service.state.status {
        case .idle:
            return Claude.textSecondary
        case .running:
            return Claude.info
        case .waiting:
            return Claude.orange
        case .completed:
            return Claude.success
        case .failed:
            return Claude.danger
        }
    }

    private var accessibilityDescription: String {
        if pendingCount > 0 {
            return "\(statusText), \(pendingCount) pending actions"
        }
        return statusText
    }
}

// MARK: - Legacy Primary Action Card (Deprecated)
/// Use TieredActionCard instead - this is kept for backward compatibility
@available(*, deprecated, message: "Use TieredActionCard for V2 tier-based styling")
typealias PrimaryActionCard = TieredActionCard

// MARK: - Compact Action Card
/// Glanceable action card showing only the first pending action with approve/reject buttons
struct CompactActionCard: View {
    @ObservedObject private var service = WatchService.shared

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Haptic feedback triggers
    @State private var didReject = false
    @State private var didApprove = false
    @State private var didError = false

    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""

    var action: PendingAction? {
        service.state.pendingActions.first
    }

    var body: some View {
        if let action = action {
            let tier = action.tier

            VStack(spacing: 8) {
                // Error banner
                ErrorBanner(message: errorMessage, isVisible: $showError)

                // Action info
                HStack {
                    Image(systemName: action.icon)
                        .foregroundColor(tier.cardColor)
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    TierBadge(tier: tier, compact: true)
                }

                // File path
                if let path = action.filePath {
                    Text(truncatePath(path))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Approve/Reject buttons (side by side) - respects tier
                if tier.canApproveFromWatch {
                    HStack(spacing: 12) {
                        Button {
                            reject(action)
                        } label: {
                            Image(systemName: "xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .accessibilityLabel("Reject \(action.title)")
                        .sensoryFeedback(.error, trigger: didReject)

                        Button {
                            approve(action)
                        } label: {
                            Image(systemName: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Claude.success)
                        .accessibilityLabel("Approve \(action.title)")
                        .sensoryFeedback(.success, trigger: didApprove)
                    }
                } else {
                    // Tier 3: Reject only
                    Button {
                        reject(action)
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                            Text("Reject")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel("Reject \(action.title)")
                    .sensoryFeedback(.error, trigger: didReject)

                    Text("Approve requires Mac")
                        .font(.system(size: 9))
                        .foregroundColor(Claude.textTertiary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.medium)
                    .stroke(tier.cardColor.opacity(0.6), lineWidth: 1)
            )
            .glassEffectCompat(RoundedRectangle(cornerRadius: Claude.Radius.medium))
            .sensoryFeedback(.error, trigger: didError)
        }
    }

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return path
    }

    private func reject(_ action: PendingAction) {
        Task { @MainActor in
            // Optimistic update first
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                service.state.status = .idle
            }
            service.playHaptic(.failure)
            didReject.toggle()
            AccessibilityNotification.Announcement("Rejected \(action.title)").post()

            // Then notify server (best effort)
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: false)
            } else {
                service.rejectAction(action.id)
            }
        }
    }

    private func approve(_ action: PendingAction) {
        guard action.tier.canApproveFromWatch else {
            errorMessage = "Must approve from Mac"
            withAnimation { showError = true }
            didError.toggle()
            return
        }

        Task { @MainActor in
            // Optimistic update first
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                // V2 Fix: Return to idle unless there's active session progress
                if service.sessionProgress == nil {
                    service.state.status = .idle
                } else {
                    service.state.status = .running
                }
            }
            service.playHaptic(.success)
            didApprove.toggle()
            AccessibilityNotification.Announcement("Approved \(action.title)").post()

            // Then notify server (best effort)
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: true)
            } else {
                service.approveAction(action.id)
            }
        }
    }
}

// MARK: - Previews
#Preview("Compact Status Header") {
    VStack(spacing: 10) {
        CompactStatusHeader()
    }
    .padding()
}

#Preview("Action Queue") {
    ActionQueue()
}

#Preview("Tiered Action Card - Low Risk") {
    TieredActionCard(action: PendingAction(
        id: "1",
        type: "edit",
        title: "Edit MainView.swift",
        description: "Updating the main view layout",
        filePath: "/path/to/MainView.swift",
        command: nil,
        timestamp: Date()
    ))
    .padding()
}

#Preview("Tiered Action Card - Medium Risk") {
    TieredActionCard(action: PendingAction(
        id: "2",
        type: "bash",
        title: "Install dependencies",
        description: "npm install",
        filePath: nil,
        command: "npm install express",
        timestamp: Date()
    ))
    .padding()
}

#Preview("Tiered Action Card - High Risk (Tier 3)") {
    TieredActionCard(action: PendingAction(
        id: "3",
        type: "bash",
        title: "Delete build folder",
        description: "rm -rf build",
        filePath: nil,
        command: "rm -rf ./build",
        timestamp: Date()
    ))
    .padding()
}

#Preview("Compact Action Card") {
    CompactActionCard()
        .padding()
}

#Preview("Error Banner") {
    @Previewable @State var showError = true
    ErrorBanner(message: "Failed to approve", isVisible: $showError)
        .padding()
}
