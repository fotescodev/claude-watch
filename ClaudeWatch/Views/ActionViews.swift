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

    // Selective queue navigation
    @State private var showingSelectiveQueue = false

    var body: some View {
        VStack(spacing: 6) {
            // Primary action card only
            if let action = service.state.pendingActions.first {
                PrimaryActionCard(action: action, totalCount: service.state.pendingActions.count)
            }

            // Multiple action controls - only if more than 1 action
            if service.state.pendingActions.count > 1 {
                HStack(spacing: 6) {
                    // Review Queue button - for selective approve/reject
                    Button {
                        showingSelectiveQueue = true
                    } label: {
                        Text("Review")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Claude.info)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review all \(service.state.pendingActions.count) pending actions")

                    // Approve All button
                    Button {
                        showApproveAllConfirmation = true
                    } label: {
                        Text("All ✓")
                            .font(.system(size: 11, weight: .semibold))
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
                    .accessibilityLabel("Approve all \(service.state.pendingActions.count) pending actions")
                    .sensoryFeedback(.success, trigger: didApproveAll)
                }
                .confirmationDialog(
                    "Approve All?",
                    isPresented: $showApproveAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Approve \(service.state.pendingActions.count) Actions", role: .destructive) {
                        // Record all to history first
                        for action in service.state.pendingActions {
                            HistoryManager.shared.record(action, outcome: .approved)
                        }
                        service.approveAll()
                        didApproveAll.toggle()
                        AccessibilityNotification.Announcement("Approved all \(service.state.pendingActions.count) actions").post()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will approve all pending actions at once.")
                }
            }
        }
        .sheet(isPresented: $showingSelectiveQueue) {
            NavigationStack {
                SelectiveQueueView()
            }
        }
    }
}

// MARK: - Primary Action Card
struct PrimaryActionCard: View {
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

    // Haptic feedback triggers
    @State private var didReject = false
    @State private var didApprove = false

    // Error handling state
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var didError = false

    // Detail view state (long-press to access)
    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 8) {
            // Error banner
            ErrorBanner(message: errorMessage, isVisible: $showError)

            // Danger indicator for destructive actions
            if action.isDangerous {
                DangerIndicator()
            }

            // Action info - compact
            HStack(spacing: 8) {
                // Type icon - smaller
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(typeColor)
                        .frame(width: iconContainerSize, height: iconContainerSize)

                    Image(systemName: action.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.claudeHeadline)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    if let path = action.filePath {
                        Text(truncatePath(path))
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
                        .background(Claude.orange)
                        .clipShape(Circle())
                }
            }

            // Action buttons - compact with icons only
            HStack(spacing: 6) {
                // Reject button
                Button {
                    Task { @MainActor in
                        // Record to history first
                        HistoryManager.shared.record(action, outcome: .rejected)

                        // Optimistic update - remove action immediately
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
                    Task { @MainActor in
                        // Record to history first
                        HistoryManager.shared.record(action, outcome: .approved)

                        // Optimistic update - remove action immediately
                        service.state.pendingActions.removeAll { $0.id == action.id }
                        if service.state.pendingActions.isEmpty {
                            service.state.status = .running
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
        .padding(10)
        .background(
            Group {
                if action.isDangerous {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Claude.dangerBackground)
                } else {
                    Color.clear
                }
            }
        )
        .glassEffectInteractive(RoundedRectangle(cornerRadius: 16))
        .overlay(
            Group {
                if action.isDangerous {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Claude.danger, lineWidth: 2)
                }
            }
        )
        .sensoryFeedback(.error, trigger: didError)
        .onLongPressGesture {
            WKInterfaceDevice.current().play(.click)
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                ActionDetailView(action: action)
            }
        }
        .accessibilityHint("Long press for more details")
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
            VStack(spacing: 8) {
                // Error banner
                ErrorBanner(message: errorMessage, isVisible: $showError)

                // Action info
                HStack {
                    Image(systemName: action.icon)
                        .foregroundColor(typeColor(for: action))
                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                }

                // File path
                if let path = action.filePath {
                    Text(truncatePath(path))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Approve/Reject buttons (side by side)
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
                    .tint(Claude.orange)
                    .accessibilityLabel("Approve \(action.title)")
                    .sensoryFeedback(.success, trigger: didApprove)
                }
            }
            .padding(12)
            .glassEffectCompat(RoundedRectangle(cornerRadius: 12))
            .sensoryFeedback(.error, trigger: didError)
        }
    }

    private func typeColor(for action: PendingAction) -> Color {
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
        Task { @MainActor in
            // Optimistic update first
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                service.state.status = .running
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
                    .background(Claude.orange)
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

#Preview("Primary Action Card") {
    PrimaryActionCard(action: PendingAction(
        id: "1",
        type: "file_edit",
        title: "Edit MainView.swift",
        description: "Updating the main view layout",
        filePath: "/path/to/MainView.swift",
        command: nil,
        timestamp: Date()
    ))
    .padding()
}

#Preview("Dangerous Action Card") {
    VStack(spacing: 16) {
        // File delete - always dangerous
        PrimaryActionCard(action: PendingAction(
            id: "2",
            type: "file_delete",
            title: "Delete old-utils.ts",
            description: "Removing deprecated file",
            filePath: "/path/to/old-utils.ts",
            command: nil,
            timestamp: Date()
        ))

        // Bash with dangerous command
        PrimaryActionCard(action: PendingAction(
            id: "3",
            type: "bash",
            title: "Run cleanup",
            description: "Delete unused files",
            filePath: nil,
            command: "rm -rf ./tmp/*",
            timestamp: Date()
        ))
    }
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
