import SwiftUI
import WatchKit

/// V3 C1-C3: Single approval view with StateCard and tier-based styling
/// - C1 (Tier 1): Green - low risk, double tap approves
/// - C2 (Tier 2): Orange - medium risk, double tap approves
/// - C3 (Tier 3): Red - high risk, NO approve button, reject only
struct ApprovalView: View {
    var service = WatchService.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Press feedback states
    @State private var approvePressed = false
    @State private var rejectPressed = false

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
        ScreenShell {
            // V3: StateCard with tier-colored glow and border (toolbar handles status)
            if let action = action {
                StateCard(state: tierState, glowOffset: 10, padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Badge (type indicator)
                        Text(badgeText)
                            .font(.claudeMicroMono)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(tierColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Title (filename or command)
                        Text(action.title)
                            .font(.claudeHeadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        // Description (not optional, check if empty)
                        if !action.description.isEmpty {
                            Text(action.description)
                                .font(.claudeCaption)
                                .foregroundStyle(Claude.textMuted)
                                .lineLimit(2)
                        }
                    }
                }
            }
        } action: {
            // V3: Button row OUTSIDE card
            if let action = action {
                HStack(spacing: 8) {
                    // Approve button (green gradient, or muted for dangerous)
                    Button {
                        approve(action)
                    } label: {
                        Text("Approve")
                            .font(.claudeBodyMedium)
                            .foregroundStyle(action.tier == .high ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                action.tier == .high
                                    ? AnyShapeStyle(Claude.destructive.opacity(0.3))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [Claude.success.opacity(0.85), Claude.success],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                action.tier == .high
                                    ? RoundedRectangle(cornerRadius: 20).stroke(Claude.destructive, lineWidth: 1)
                                    : nil
                            )
                            .scaleEffect(approvePressed && !reduceMotion ? 0.92 : 1.0)
                            .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: approvePressed)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in approvePressed = true }
                            .onEnded { _ in approvePressed = false }
                    )
                    // Double tap to approve (Tier 1-2 only)
                    .modifier(DoubleTapApproveModifier(enabled: action.tier != .high))

                    // Reject button (red)
                    Button {
                        reject(action)
                    } label: {
                        Text("Reject")
                            .font(.claudeBodyMedium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.destructive)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .scaleEffect(rejectPressed && !reduceMotion ? 0.92 : 1.0)
                            .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: rejectPressed)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in rejectPressed = true }
                            .onEnded { _ in rejectPressed = false }
                    )
                }
            }
        } hint: {
            if let action = action {
                ScreenHint(action.tier == .high ? "Dangerous - handle on Mac" : "Double tap to approve")
            }
        }
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
            await service.respondToAction(action.id, approved: true)
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
            await service.respondToAction(action.id, approved: false)
        }
    }
}

/// Applies `.handGestureShortcut(.primaryAction)` to the Approve button
/// so double-tap gesture triggers approval (Series 9+ / Ultra 2+, watchOS 11+)
private struct DoubleTapApproveModifier: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            if #available(watchOS 11.0, *) {
                content
                    .handGestureShortcut(.primaryAction)
            } else {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Previews
#Preview("Approval - Tier 1 (Low)") {
    ApprovalView()
}
