import SwiftUI
import WatchKit

/// Shows approval queue when 2+ actions are pending
/// Provides quick approve/reject for first + approve all option
struct ApprovalQueueView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showApproveAllConfirmation = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var pendingActions: [PendingAction] {
        service.state.pendingActions
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header with count
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Claude.warning)

                Text("\(pendingActions.count) Pending")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // First action (primary)
            if let first = pendingActions.first {
                PrimaryActionCard(action: first, totalCount: pendingActions.count)
            }

            // Queue preview (remaining actions)
            if pendingActions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pendingActions.dropFirst().prefix(3), id: \.id) { action in
                            QueuePreviewChip(action: action)
                        }

                        if pendingActions.count > 4 {
                            Text("+\(pendingActions.count - 4)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Claude.textTertiary)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 28)
            }

            // Approve All button
            if pendingActions.count > 1 {
                Button {
                    showApproveAllConfirmation = true
                } label: {
                    Text("Approve All (\(pendingActions.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ClaudeState.success.color)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .confirmationDialog(
                    "Approve All?",
                    isPresented: $showApproveAllConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Approve \(pendingActions.count) Actions", role: .destructive) {
                        service.approveAll()
                        WKInterfaceDevice.current().play(.success)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will approve all pending actions.")
                }
            }
        }
    }
}

/// Compact chip showing a queued action
struct QueuePreviewChip: View {
    let action: PendingAction

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(typeColor)

            Text(truncatedTitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Claude.surface2)
        .clipShape(Capsule())
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

    private var truncatedTitle: String {
        if action.title.count > 12 {
            return String(action.title.prefix(10)) + "..."
        }
        return action.title
    }
}

#Preview("Approval Queue") {
    ApprovalQueueView()
}
