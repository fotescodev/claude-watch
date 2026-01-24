import SwiftUI
import WatchKit

/// Shows approval queue when 2+ actions are pending
/// V2: Uses tiered cards and respects Tier 3 restrictions
struct ApprovalQueueView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var showApproveAllConfirmation = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var pendingActions: [PendingAction] {
        service.state.pendingActions
    }

    /// Check if any pending action is Tier 3 (dangerous)
    private var hasHighRiskAction: Bool {
        pendingActions.contains { $0.tier == .high }
    }

    /// Check if the CURRENT (first) action is Tier 3 (dangerous)
    private var currentActionIsDangerous: Bool {
        pendingActions.first?.tier == .high
    }

    /// Count of approvable actions (Tier 1-2 only)
    private var approvableCount: Int {
        pendingActions.filter { $0.tier != .high }.count
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header with count - color reflects CURRENT card's tier, not queue
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(currentActionIsDangerous ? Claude.danger : Claude.warning)

                Text("\(pendingActions.count) Pending")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // First action (now using TieredActionCard)
            if let first = pendingActions.first {
                TieredActionCard(action: first, totalCount: pendingActions.count)
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

            // Approve All button (only if all are approvable - no Tier 3)
            if approvableCount > 1 && !hasHighRiskAction {
                Button {
                    showApproveAllConfirmation = true
                } label: {
                    Text("Approve All (\(approvableCount))")
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
                    Button("Approve \(approvableCount) Actions", role: .destructive) {
                        service.approveAll()
                        WKInterfaceDevice.current().play(.success)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will approve all pending actions.")
                }
            }

            // Warning if Tier 3 present
            if hasHighRiskAction {
                Text("Dangerous actions require Mac")
                    .font(.system(size: 9))
                    .foregroundColor(Claude.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
    }
}

/// Compact chip showing a queued action with tier coloring
/// Shows DANGER badge only for this specific action if it's high risk
struct QueuePreviewChip: View {
    let action: PendingAction

    /// Use tier color instead of type color
    private var tier: ActionTier { action.tier }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(tier.cardColor)

            Text(truncatedTitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)

            // Show DANGER badge only for THIS chip's high-risk action
            if tier == .high {
                Text("!")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 12, height: 12)
                    .background(Claude.danger)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tier.cardColor.opacity(0.15))
        .overlay(
            Capsule()
                .strokeBorder(tier.cardColor.opacity(0.3), lineWidth: 1)
        )
        .clipShape(Capsule())
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
