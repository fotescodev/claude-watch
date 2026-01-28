import SwiftUI
import WatchKit

/// V3 C1-C3: Single approval view with StateCard and tier-based styling
/// - C1 (Tier 1): Green - low risk, double tap approves
/// - C2 (Tier 2): Orange - medium risk, double tap approves
/// - C3 (Tier 3): Red - high risk, NO approve button, reject only
struct ApprovalView: View {
    @ObservedObject private var service = WatchService.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Current action to display
    private var action: PendingAction? {
        service.state.pendingActions.first
    }

    /// Total pending count
    private var pendingCount: Int {
        service.state.pendingActions.count
    }

    /// Get ClaudeState based on action tier for StateCard
    private var tierState: ClaudeState {
        guard let action = action else { return .success }
        switch action.tier {
        case .low: return .success      // Green
        case .medium: return .approval  // Orange
        case .high: return .error       // Red
        }
    }

    /// Tier color (matching V3 spec)
    private var tierColor: Color {
        guard let action = action else { return Claude.success }
        switch action.tier {
        case .low: return Claude.success    // Green
        case .medium: return Claude.warning // Orange
        case .high: return Claude.danger    // Red
        }
    }

    /// Badge text based on action type
    private var badgeText: String {
        guard let action = action else { return "ACTION" }
        switch action.type.lowercased() {
        case "edit", "write": return "EDIT"
        case "read": return "READ"
        case "bash", "command": return "BASH"
        case "delete": return "DELETE"
        default: return action.type.uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // V3: Header with tier-colored dot and pending count
            HStack(spacing: 6) {
                Circle()
                    .fill(tierColor)
                    .frame(width: 8, height: 8)

                Text("\(pendingCount) pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(tierColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 4)

            // V3: StateCard with tier-colored glow and border
            if let action = action {
                StateCard(state: tierState, glowOffset: 10, padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Badge (type indicator)
                        Text(badgeText)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(tierColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Title (filename or command)
                        Text(action.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Description (not optional, check if empty)
                        if !action.description.isEmpty {
                            Text(action.description)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.604, green: 0.604, blue: 0.624))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 4)

            // V3: Button row OUTSIDE card
            if let action = action {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Approve button (green gradient, or red for dangerous)
                        Button {
                            approve(action)
                        } label: {
                            Text("Approve")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(action.tier == .high ? .white : .black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    action.tier == .high
                                        ? AnyShapeStyle(Claude.danger.opacity(0.3))
                                        : AnyShapeStyle(LinearGradient(
                                            colors: [Color(red: 0.29, green: 0.87, blue: 0.50), Claude.success],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    action.tier == .high
                                        ? RoundedRectangle(cornerRadius: 20).stroke(Claude.danger, lineWidth: 1)
                                        : nil
                                )
                        }
                        .buttonStyle(.plain)

                        // Reject button (red)
                        Button {
                            reject(action)
                        } label: {
                            Text("Reject")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Claude.danger)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    // Hint text
                    Text(action.tier == .high ? "Dangerous - handle on Mac" : "Double tap to approve")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.431, green: 0.431, blue: 0.451))
                }
            }
        }
        // Double tap to approve (Tier 1-2 only)
        .modifier(ApprovalDoubleTapModifier(onApprove: {
            if let action = action, action.tier != .high {
                approve(action)
            }
        }))
    }

    private func approve(_ action: PendingAction) {
        guard action.tier.canApproveFromWatch else {
            WKInterfaceDevice.current().play(.failure)
            return
        }

        Task { @MainActor in
            // Optimistic update
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                if service.sessionProgress == nil {
                    service.state.status = .idle
                } else {
                    service.state.status = .running
                }
            }
            WKInterfaceDevice.current().play(.success)

            // Notify server
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: true)
            } else {
                service.approveAction(action.id)
            }
        }
    }

    private func reject(_ action: PendingAction) {
        Task { @MainActor in
            // Optimistic update
            service.state.pendingActions.removeAll { $0.id == action.id }
            if service.state.pendingActions.isEmpty {
                service.state.status = .idle
            }
            WKInterfaceDevice.current().play(.failure)

            // Notify server
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: false)
            } else {
                service.rejectAction(action.id)
            }
        }
    }
}

/// Double tap modifier for approval
private struct ApprovalDoubleTapModifier: ViewModifier {
    let onApprove: () -> Void

    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

// MARK: - Previews
#Preview("Approval - Tier 1 (Low)") {
    ApprovalView()
}
