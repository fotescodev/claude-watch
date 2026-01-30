import SwiftUI

// MARK: - Claude State (V3 8-State Model)
/// The eight visual states for Remmy V3
/// Each state has a distinct color for immediate recognition
public enum ClaudeState: String, CaseIterable, Codable, Sendable {
    /// Idle - Gray (#8E8E93) - Listening, no activity
    case idle
    /// Working - Blue (#007AFF) - Task in progress
    case working
    /// Approval - Orange (#FF9500) - Needs user action
    case approval
    /// Success - Green (#34C759) - Task completed successfully
    case success
    /// Error - Red (#FF3B30) - Something went wrong
    case error
    /// Plan - Purple (#5E5CE6) - Planning mode active
    case plan
    /// Context - Yellow (#FFD60A) - Context usage warning
    case context
    /// Question - Purple (#BF5AF2) - Needs user input
    case question

    // MARK: - Display Properties

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .idle: return "Ready"
        case .working: return "Working"
        case .approval: return "Approval Needed"
        case .success: return "Complete"
        case .error: return "Error"
        case .plan: return "Plan Mode"
        case .context: return "Context Warning"
        case .question: return "Question"
        }
    }

    /// SF Symbol icon for the state
    public var icon: String {
        switch self {
        case .idle: return "circle"
        case .working: return "circle.dotted.circle"
        case .approval: return "hand.raised.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .plan: return "pencil.and.outline"
        case .context: return "exclamationmark.triangle.fill"
        case .question: return "questionmark.circle.fill"
        }
    }

    /// Associated color (Apple semantic colors for native feel)
    public var color: Color {
        switch self {
        case .idle: return .gray         // #8E8E93
        case .working: return .blue      // #007AFF
        case .approval: return .orange   // #FF9500
        case .success: return .green     // #34C759
        case .error: return .red         // #FF3B30
        case .plan: return Color(red: 0.369, green: 0.361, blue: 0.902)     // #5E5CE6
        case .context: return Color(red: 1.0, green: 0.839, blue: 0.039)    // #FFD60A
        case .question: return Color(red: 0.749, green: 0.353, blue: 0.949) // #BF5AF2
        }
    }

    /// Hex value for reference/debugging
    public var hexColor: String {
        switch self {
        case .idle: return "#8E8E93"
        case .working: return "#007AFF"
        case .approval: return "#FF9500"
        case .success: return "#34C759"
        case .error: return "#FF3B30"
        case .plan: return "#5E5CE6"
        case .context: return "#FFD60A"
        case .question: return "#BF5AF2"
        }
    }

    // MARK: - State Transitions

    /// Derive state from SessionStatus (existing model)
    init(from sessionStatus: SessionStatus) {
        switch sessionStatus {
        case .idle: self = .idle
        case .running: self = .working
        case .waiting: self = .approval
        case .completed: self = .success
        case .failed: self = .error
        }
    }

    /// Derive state from pending actions and status
    static func derive(pendingCount: Int, sessionStatus: SessionStatus, hasProgress: Bool) -> ClaudeState {
        if pendingCount > 0 {
            return .approval
        }
        if hasProgress {
            return sessionStatus == .completed ? .success : .working
        }
        return ClaudeState(from: sessionStatus)
    }
}

// MARK: - State Dot View
/// A colored dot indicator for the current Claude state
public struct ClaudeStateDot: View {
    public let state: ClaudeState
    public var size: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(state: ClaudeState, size: CGFloat = 8) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(state.color)
            .frame(width: size, height: size)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: state)
    }
}

// MARK: - State Icon View
/// An SF Symbol icon for the current Claude state
public struct ClaudeStateIcon: View {
    public let state: ClaudeState
    public var size: CGFloat = 24

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(state: ClaudeState, size: CGFloat = 24) {
        self.state = state
        self.size = size
    }

    public var body: some View {
        Image(systemName: state.icon)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(state.color)
            .contentTransition(.symbolEffect(.replace))
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: state)
    }
}

// MARK: - Previews
#Preview("State Colors") {
    VStack(spacing: 16) {
        ForEach(ClaudeState.allCases, id: \.self) { state in
            HStack(spacing: 12) {
                ClaudeStateDot(state: state)
                ClaudeStateIcon(state: state)
                Text(state.displayName)
                    .font(.headline)
                Spacer()
                Text(state.hexColor)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }
    .padding()
}
