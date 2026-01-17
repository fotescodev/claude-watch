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
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
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

    var body: some View {
        VStack(spacing: 4) {
            // Primary action card
            if let action = service.state.pendingActions.first {
                PrimaryActionCard(action: action)
            }

            // Additional pending items - show just 1 + count
            if service.state.pendingActions.count > 1 {
                // Show one more action preview
                if let nextAction = service.state.pendingActions.dropFirst().first {
                    CompactActionCard(action: nextAction)
                }

                // Show count if more than 2
                if service.state.pendingActions.count > 2 {
                    Text("+\(service.state.pendingActions.count - 2) more")
                        .font(.system(size: 10))
                        .foregroundColor(Claude.textTertiary)
                }

                // Approve All button - compact
                Button {
                    showApproveAllConfirmation = true
                } label: {
                    Text("Approve All (\(service.state.pendingActions.count))")
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
                .accessibilityLabel("Approve all \(service.state.pendingActions.count) pending actions")
                .sensoryFeedback(.success, trigger: didApproveAll)
                .confirmationDialog(
                    "Approve All?",
                    isPresented: $showApproveAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Approve \(service.state.pendingActions.count) Actions", role: .destructive) {
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
    }
}

// MARK: - Primary Action Card
struct PrimaryActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction

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

    var body: some View {
        VStack(spacing: 8) {
            // Error banner
            ErrorBanner(message: errorMessage, isVisible: $showError)
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
            }

            // Action buttons - compact with icons only
            HStack(spacing: 6) {
                // Reject button
                Button {
                    Task { @MainActor in
                        do {
                            if service.useCloudMode && service.isPaired {
                                try await service.respondToCloudRequest(action.id, approved: false)
                            } else {
                                service.rejectAction(action.id)
                            }
                            didReject.toggle()
                            AccessibilityNotification.Announcement("Rejected \(action.title)").post()
                        } catch {
                            errorMessage = "Failed to reject"
                            withAnimation(.easeIn(duration: 0.2)) {
                                showError = true
                            }
                            didError.toggle()
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
                        do {
                            if service.useCloudMode && service.isPaired {
                                try await service.respondToCloudRequest(action.id, approved: true)
                            } else {
                                service.approveAction(action.id)
                            }
                            didApprove.toggle()
                            AccessibilityNotification.Announcement("Approved \(action.title)").post()
                        } catch {
                            errorMessage = "Failed to approve"
                            withAnimation(.easeIn(duration: 0.2)) {
                                showError = true
                            }
                            didError.toggle()
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
        .glassEffectInteractive(RoundedRectangle(cornerRadius: 16))
        .sensoryFeedback(.error, trigger: didError)
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

    // Dynamic Type support - very compact
    @ScaledMetric(relativeTo: .caption) private var iconContainerSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 10

    var body: some View {
        HStack(spacing: 6) {
            // Type icon - tiny
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(typeColor.opacity(0.2))
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: action.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            Text(action.title)
                .font(.claudeFootnote)
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(8)
        .glassEffectInteractive(RoundedRectangle(cornerRadius: 10))
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

// MARK: - Previews
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

#Preview("Compact Action Card") {
    CompactActionCard(action: PendingAction(
        id: "2",
        type: "bash",
        title: "npm install",
        description: "Installing dependencies",
        filePath: nil,
        command: "npm install",
        timestamp: Date()
    ))
    .padding()
}

#Preview("Error Banner") {
    @Previewable @State var showError = true
    ErrorBanner(message: "Failed to approve", isVisible: $showError)
        .padding()
}
