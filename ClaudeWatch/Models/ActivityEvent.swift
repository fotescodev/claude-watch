//
//  ActivityEvent.swift
//  ClaudeWatch
//
//  F22: Session Activity Dashboard
//  Activity event model for tracking session events
//

import SwiftUI

// MARK: - Activity Event Type

/// Types of activity events that can occur during a Claude session
enum ActivityEventType: String, Codable, CaseIterable {
    case sessionStarted
    case sessionEnded
    case taskStarted
    case taskCompleted
    case approvalApproved
    case approvalRejected
    case questionAnswered
    case contextWarning
    case error

    // MARK: - Display Properties

    /// SF Symbol icon for the event type
    var icon: String {
        switch self {
        case .sessionStarted: return "play.circle.fill"
        case .sessionEnded: return "stop.circle.fill"
        case .taskStarted: return "circle.dotted.circle"
        case .taskCompleted: return "checkmark.circle.fill"
        case .approvalApproved: return "hand.thumbsup.fill"
        case .approvalRejected: return "hand.thumbsdown.fill"
        case .questionAnswered: return "questionmark.circle.fill"
        case .contextWarning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    /// Associated color for the event type
    var color: Color {
        switch self {
        case .sessionStarted: return Claude.info
        case .sessionEnded: return Claude.idle
        case .taskStarted: return Claude.info
        case .taskCompleted: return Claude.success
        case .approvalApproved: return Claude.success
        case .approvalRejected: return Claude.danger
        case .questionAnswered: return Claude.warning
        case .contextWarning: return Claude.warning
        case .error: return Claude.danger
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .sessionStarted: return "Session Started"
        case .sessionEnded: return "Session Ended"
        case .taskStarted: return "Task Started"
        case .taskCompleted: return "Task Completed"
        case .approvalApproved: return "Approved"
        case .approvalRejected: return "Rejected"
        case .questionAnswered: return "Question Answered"
        case .contextWarning: return "Context Warning"
        case .error: return "Error"
        }
    }
}

// MARK: - Activity Event

/// Represents a single activity event in the session timeline
struct ActivityEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let type: ActivityEventType
    let title: String          // e.g., "Fixed auth bug"
    let subtitle: String?      // e.g., "Bash: npm install"
    let sessionId: UUID?       // Links event to a session

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: ActivityEventType,
        title: String,
        subtitle: String? = nil,
        sessionId: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.sessionId = sessionId
    }

    // MARK: - Computed Properties

    /// SF Symbol icon for the event
    var icon: String {
        type.icon
    }

    /// Color for the event
    var color: Color {
        type.color
    }

    /// Relative time text (e.g., "2m ago", "1h ago")
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(timestamp)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    /// Formatted time for timeline display (e.g., "2:34 PM")
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// Truncated title (max 30 chars with ellipsis)
    var truncatedTitle: String {
        if title.count > 30 {
            return String(title.prefix(27)) + "..."
        }
        return title
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ActivityEvent {
    static let previewSessionStarted = ActivityEvent(
        type: .sessionStarted,
        title: "Session Started",
        sessionId: UUID()
    )

    static let previewTaskCompleted = ActivityEvent(
        type: .taskCompleted,
        title: "Fixed authentication bug",
        subtitle: "3 files changed"
    )

    static let previewApprovalApproved = ActivityEvent(
        type: .approvalApproved,
        title: "Bash: npm install lodash",
        subtitle: "npm command"
    )

    static let previewApprovalRejected = ActivityEvent(
        type: .approvalRejected,
        title: "Write: /etc/hosts",
        subtitle: "File write"
    )

    static let previewContextWarning = ActivityEvent(
        type: .contextWarning,
        title: "Context at 80%",
        subtitle: "Consider summarizing"
    )

    static var previewEvents: [ActivityEvent] {
        [
            .previewTaskCompleted,
            .previewApprovalApproved,
            .previewApprovalRejected,
            .previewContextWarning,
            .previewSessionStarted
        ]
    }
}
#endif
