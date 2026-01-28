import SwiftUI
import WatchKit

/// V3: Tier-grouped approval queue with bulk actions
/// Horizontal swipe between tiers, bulk approve for safe tiers
struct ApprovalQueueView: View {
    var service = WatchService.shared
    @State private var selectedTierIndex = 0
    @State private var showingReview = false
    @State private var reviewTier: ActionTier?

    /// Group pending actions by tier
    private var actionsByTier: [(tier: ActionTier, actions: [PendingAction])] {
        let grouped = Dictionary(grouping: service.state.pendingActions) { $0.tier }
        return ActionTier.allCases
            .compactMap { tier in
                guard let actions = grouped[tier], !actions.isEmpty else { return nil }
                return (tier: tier, actions: actions)
            }
    }

    /// Check if any tier has 2+ actions (worth grouping)
    private var hasMultiActionTier: Bool {
        actionsByTier.contains { $0.actions.count >= 2 }
    }

    var body: some View {
        if showingReview, let tier = reviewTier {
            // Review mode - show individual actions
            let actions = actionsByTier.first { $0.tier == tier }?.actions ?? []
            TierReviewView(
                tier: tier,
                actions: actions,
                onBack: { showingReview = false }
            )
        } else if actionsByTier.isEmpty {
            // No pending actions
            EmptyQueueView()
        } else if !hasMultiActionTier {
            // All tiers have only 1 action - show combined list (no point swiping for singles)
            CombinedQueueView(actions: service.state.pendingActions)
        } else if actionsByTier.count == 1 {
            // Single tier with 2+ actions - show tier view directly
            TierQueueView(
                tier: actionsByTier[0].tier,
                actions: actionsByTier[0].actions,
                onReview: {
                    reviewTier = actionsByTier[0].tier
                    showingReview = true
                },
                showSwipeHint: false
            )
        } else {
            // Multiple tiers with at least one having 2+ actions - swipe navigation
            let activeTiers = actionsByTier.map { $0.tier }
            TabView(selection: $selectedTierIndex) {
                ForEach(Array(actionsByTier.enumerated()), id: \.element.tier) { index, group in
                    TierQueueView(
                        tier: group.tier,
                        actions: group.actions,
                        activeTiers: activeTiers,
                        onReview: {
                            reviewTier = group.tier
                            showingReview = true
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))  // Horizontal swipe, custom dots
        }
    }
}

// MARK: - Tier Queue View (shows all actions of one tier)

struct TierQueueView: View {
    let tier: ActionTier
    let actions: [PendingAction]
    var activeTiers: [ActionTier] = []  // Only show dots for these tiers
    let onReview: () -> Void
    var showSwipeHint: Bool = true  // Only show when multiple tiers exist

    var service = WatchService.shared

    private var tierColor: Color {
        tierColorFor(tier)
    }

    private func tierColorFor(_ t: ActionTier) -> Color {
        switch t {
        case .low: return Claude.success
        case .medium: return Claude.warning
        case .high: return Claude.danger
        }
    }

    private var tierLabel: String {
        switch tier {
        case .low: return "Edit"
        case .medium: return "Bash"
        case .high: return "Danger"
        }
    }

    private var tierState: ClaudeState {
        switch tier {
        case .low: return .success
        case .medium: return .approval
        case .high: return .error
        }
    }

    /// Badge text for action type
    private func badgeText(for action: PendingAction) -> String {
        switch action.type.lowercased() {
        case "edit", "write": return "EDIT"
        case "read": return "EDIT"
        case "bash", "command": return "RUN"
        case "delete": return "DEL"
        default: return action.type.uppercased().prefix(4).uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Circle()
                    .fill(tierColor)
                    .frame(width: 8, height: 8)

                Text("\(actions.count) \(tierLabel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(tierColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 2)

            // Card with action summaries
            StateCard(state: tierState, glowOffset: 10, padding: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    // Action list (max 3) with badges
                    ForEach(actions.prefix(3)) { action in
                        HStack(spacing: 8) {
                            // Badge
                            Text(badgeText(for: action))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(tierColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))

                            Text(action.title)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }

                    // Overflow indicator
                    if actions.count > 3 {
                        Text("+\(actions.count - 3) more")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 2)

            // Pagination dots (only when multiple tiers with items)
            if showSwipeHint && activeTiers.count > 1 {
                HStack(spacing: 6) {
                    // Show dots with tier colors - active is larger and brighter
                    ForEach(activeTiers, id: \.self) { t in
                        Circle()
                            .fill(tierColorFor(t))
                            .frame(width: t == tier ? 8 : 6, height: t == tier ? 8 : 6)
                            .opacity(t == tier ? 1.0 : 0.6)
                    }
                }
                .padding(.bottom, 4)
            }

            // Buttons
            if tier == .high {
                // Danger tier - must review each (centered)
                Button { onReview() } label: {
                    Text("Review Each")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Claude.danger)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Claude.danger.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Claude.danger, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            } else {
                // Safe tiers - Review (left) + Approve All (right)
                HStack(spacing: 8) {
                    Button { onReview() } label: {
                        Text("Review")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)

                    Button { approveAll() } label: {
                        Text("Approve All \(actions.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Claude.success)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // Capture all taps to prevent TabView page navigation on empty space
        .contentShape(Rectangle())
        .onTapGesture { } // No-op: prevent taps from propagating to TabView
    }

    private func approveAll() {
        // Use WatchService.approveAll() which batches state updates atomically
        service.approveAll()
    }

    private func rejectAll() {
        // Use WatchService.rejectAll() which batches state updates atomically
        service.rejectAll()
    }
}

// MARK: - Tier Review View (individual actions within a tier)

struct TierReviewView: View {
    let tier: ActionTier
    let actions: [PendingAction]
    let onBack: () -> Void

    var service = WatchService.shared
    @State private var currentIndex = 0

    private var currentAction: PendingAction? {
        guard currentIndex < actions.count else { return nil }
        return actions[currentIndex]
    }

    private var tierColor: Color {
        switch tier {
        case .low: return Claude.success
        case .medium: return Claude.warning
        case .high: return Claude.danger
        }
    }

    private var tierState: ClaudeState {
        switch tier {
        case .low: return .success
        case .medium: return .approval
        case .high: return .error
        }
    }

    var body: some View {
        if let action = currentAction {
            VStack(spacing: 6) {
                // Header: colored dot + "X of Y"
                HStack(spacing: 6) {
                    Circle()
                        .fill(tierColor)
                        .frame(width: 8, height: 8)

                    Text("\(currentIndex + 1) of \(actions.count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(tierColor)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)

                Spacer(minLength: 2)

                // Action card
                StateCard(state: tierState, glowOffset: 10, padding: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Badge
                        Text(badgeText(for: action))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(tierColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Title
                        Text(action.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        // Description
                        if !action.description.isEmpty {
                            Text(action.description)
                                .font(.system(size: 12))
                                .foregroundColor(Color(red: 0.604, green: 0.604, blue: 0.624))
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 8)

                Spacer(minLength: 2)

                // Icon buttons: ✕ (reject) and ✓ (approve)
                HStack(spacing: 16) {
                    Button { reject(action) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)

                    Button { approve(action) } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 56, height: 44)
                            .background(Claude.success)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            // No more actions in this tier
            VStack {
                Text("All reviewed!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Button("Back") { onBack() }
                    .buttonStyle(.plain)
            }
        }
    }

    private func badgeText(for action: PendingAction) -> String {
        switch action.type.lowercased() {
        case "edit", "write": return "EDIT"
        case "read": return "READ"
        case "bash", "command": return "BASH"
        case "delete": return "DELETE"
        default: return action.type.uppercased()
        }
    }

    private func approve(_ action: PendingAction) {
        WKInterfaceDevice.current().play(.success)

        Task { @MainActor in
            service.state.pendingActions.removeAll { $0.id == action.id }

            await service.respondToAction(action.id, approved: true)

            // Advance or go back
            if currentIndex >= actions.count - 1 {
                onBack()
            }

            if service.state.pendingActions.isEmpty {
                service.state.status = service.sessionProgress == nil ? .idle : .running
            }
        }
    }

    private func reject(_ action: PendingAction) {
        WKInterfaceDevice.current().play(.failure)

        Task { @MainActor in
            service.state.pendingActions.removeAll { $0.id == action.id }

            await service.respondToAction(action.id, approved: false)

            // Advance or go back
            if currentIndex >= actions.count - 1 {
                onBack()
            }

            if service.state.pendingActions.isEmpty {
                service.state.status = .idle
            }
        }
    }
}

// MARK: - Empty Queue View

struct EmptyQueueView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(Claude.success)
            Text("Queue empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Combined Queue View (when each tier has only 1 action)

struct CombinedQueueView: View {
    let actions: [PendingAction]

    var service = WatchService.shared
    @State private var selectedAction: PendingAction?

    // Design spec colors (from Pencil MCP)
    private let greenColor = Color(red: 0.204, green: 0.780, blue: 0.349)  // #34C759
    private let orangeColor = Color(red: 1.0, green: 0.584, blue: 0.0)     // #FF9500
    private let redColor = Color(red: 1.0, green: 0.231, blue: 0.188)      // #FF3B30

    /// Badge text for action type
    private func badgeText(for action: PendingAction) -> String {
        switch action.type.lowercased() {
        case "edit", "write", "read": return "EDIT"
        case "bash", "command": return "BASH"
        case "delete": return "DELETE"
        default: return action.type.uppercased()
        }
    }

    /// Color for action tier (design spec colors)
    private func colorFor(_ action: PendingAction) -> Color {
        switch action.tier {
        case .low: return greenColor
        case .medium: return orangeColor
        case .high: return redColor
        }
    }

    /// Badge text color - white for danger, black for others
    private func badgeTextColor(for action: PendingAction) -> Color {
        action.tier == .high ? .white : .black
    }

    var body: some View {
        if let action = selectedAction {
            // Show individual action detail view
            CombinedActionDetailView(
                action: action,
                onBack: { selectedAction = nil }
            )
        } else {
            // Show combined list
            combinedListView
        }
    }

    private var combinedListView: some View {
        VStack(spacing: 6) {
            // Header - white dot (design spec: #FFFFFF)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)

                Text("\(actions.count) pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 4)

            // Action rows with glows - TAPPABLE
            VStack(spacing: 6) {
                ForEach(actions.prefix(4)) { action in
                    Button {
                        selectedAction = action
                    } label: {
                        ZStack {
                            // Glow layer (behind row)
                            Ellipse()
                                .fill(colorFor(action).opacity(0.12))
                                .frame(width: 80, height: 40)
                                .blur(radius: 20)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .offset(x: 10)

                            // Row content
                            HStack(spacing: 8) {
                                // Badge (design: cornerRadius 4, padding [2,6], fontSize 7)
                                Text(badgeText(for: action))
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(badgeTextColor(for: action))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(colorFor(action))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                // Title (design: fontSize 11, medium weight)
                                Text(action.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Spacer()

                                // Chevron to indicate tappable
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                            // Design spec: padding [8, 10], cornerRadius 12
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            // Background: 15% opacity (0x15 ≈ 8%)
                            .background(colorFor(action).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            // Stroke: 40% opacity (0x40 ≈ 25%)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(colorFor(action).opacity(0.25), lineWidth: 1)
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }

                if actions.count > 4 {
                    Text("+\(actions.count - 4) more")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // Approve All button (design: cornerRadius 16, padding [8,12], fontSize 13)
            Button { approveAll() } label: {
                Text("Approve All \(actions.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(greenColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
        }
    }

    private func approveAll() {
        // Use WatchService.approveAll() which batches state updates atomically
        service.approveAll()
    }
}

// MARK: - Combined Action Detail View (individual action from combined queue)

struct CombinedActionDetailView: View {
    let action: PendingAction
    let onBack: () -> Void

    var service = WatchService.shared

    // Design spec colors
    private let greenColor = Color(red: 0.204, green: 0.780, blue: 0.349)
    private let orangeColor = Color(red: 1.0, green: 0.584, blue: 0.0)
    private let redColor = Color(red: 1.0, green: 0.231, blue: 0.188)

    private var tierColor: Color {
        switch action.tier {
        case .low: return greenColor
        case .medium: return orangeColor
        case .high: return redColor
        }
    }

    private var tierState: ClaudeState {
        switch action.tier {
        case .low: return .success
        case .medium: return .approval
        case .high: return .error
        }
    }

    private var badgeText: String {
        switch action.type.lowercased() {
        case "edit", "write", "read": return "EDIT"
        case "bash", "command": return "BASH"
        case "delete": return "DELETE"
        default: return action.type.uppercased()
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header with back button
            HStack(spacing: 6) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(tierColor)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(tierColor)
                    .frame(width: 8, height: 8)

                Text(action.tier.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(tierColor)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 2)

            // Action card
            StateCard(state: tierState, glowOffset: 10, padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    // Badge
                    Text(badgeText)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(action.tier == .high ? .white : .black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(tierColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Title
                    Text(action.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    // Description
                    if !action.description.isEmpty {
                        Text(action.description)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.604, green: 0.604, blue: 0.624))
                            .lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 2)

            // Approve/Reject buttons
            HStack(spacing: 12) {
                Button { reject() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 40)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)

                Button { approve() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 40)
                        .background(greenColor)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func approve() {
        WKInterfaceDevice.current().play(.success)

        Task { @MainActor in
            service.state.pendingActions.removeAll { $0.id == action.id }

            await service.respondToAction(action.id, approved: true)

            // Go back to list (or it will auto-update if empty)
            onBack()

            if service.state.pendingActions.isEmpty {
                service.state.status = service.sessionProgress == nil ? .idle : .running
            }
        }
    }

    private func reject() {
        WKInterfaceDevice.current().play(.failure)

        Task { @MainActor in
            service.state.pendingActions.removeAll { $0.id == action.id }

            await service.respondToAction(action.id, approved: false)

            // Go back to list
            onBack()

            if service.state.pendingActions.isEmpty {
                service.state.status = .idle
            }
        }
    }
}

// MARK: - Previews

#Preview("Approval Queue") {
    ApprovalQueueView()
}
