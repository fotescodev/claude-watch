import Foundation

/// Session status for the Claude Code session
/// Shared between main app (WatchService) and widget extension (ClaudeState)
enum SessionStatus: String {
    case idle
    case running
    case waiting
    case completed
    case failed

    var displayName: String {
        switch self {
        case .idle: return "IDLE"
        case .running: return "RUNNING"
        case .waiting: return "WAITING"
        case .completed: return "DONE"
        case .failed: return "FAILED"
        }
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .running: return "green"
        case .waiting: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}
