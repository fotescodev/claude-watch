//
//  TaskProgress.swift
//  ClaudeWatch
//
//  Standalone model for tracking task progress with ETA calculation
//  Addresses Jordan's need for monitoring long-running tasks
//
//  Note: SessionProgress in WatchService.swift now has ETA built in.
//  This model is for standalone progress tracking (e.g., complications,
//  notifications) where SessionProgress isn't available.
//

import Foundation

/// Represents the progress of a running Claude task with ETA calculation
struct TaskProgress: Equatable {
    /// Current step or item number
    let current: Int

    /// Total steps or items expected
    let total: Int

    /// Seconds elapsed since task started
    let elapsedSeconds: Int

    /// Optional task name/description
    var taskName: String?

    // MARK: - Computed Properties

    /// Percentage complete (0.0 to 1.0)
    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    /// Percentage as integer (0 to 100)
    var percentInt: Int {
        Int(percentComplete * 100)
    }

    /// Estimated remaining seconds based on current rate
    var estimatedRemainingSeconds: Int? {
        guard current > 0, total > current else { return nil }
        let rate = Double(elapsedSeconds) / Double(current)
        return Int(rate * Double(total - current))
    }

    /// Formatted ETA string for display
    /// Returns "~Xm" for minutes, "<1m" for under a minute, "—" if unknown
    var formattedETA: String {
        guard let remaining = estimatedRemainingSeconds else { return "—" }
        if remaining < 60 { return "<1m" }
        let minutes = remaining / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "~\(hours)h \(mins)m"
        }
        return "~\(minutes)m"
    }

    /// Formatted elapsed time string
    var formattedElapsed: String {
        if elapsedSeconds < 60 {
            return "\(elapsedSeconds)s"
        }
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    /// Short progress string like "127/195"
    var progressString: String {
        "\(current)/\(total)"
    }

    // MARK: - Initialization

    init(current: Int, total: Int, elapsedSeconds: Int, taskName: String? = nil) {
        self.current = current
        self.total = total
        self.elapsedSeconds = elapsedSeconds
        self.taskName = taskName
    }

    /// Create from server data
    init?(from data: [String: Any]) {
        guard let current = data["current"] as? Int,
              let total = data["total"] as? Int else {
            return nil
        }
        self.current = current
        self.total = total
        self.elapsedSeconds = data["elapsed_seconds"] as? Int ?? 0
        self.taskName = data["task_name"] as? String
    }
}

// MARK: - Demo/Preview Support

extension TaskProgress {
    /// Sample progress for previews
    static let sample = TaskProgress(
        current: 127,
        total: 195,
        elapsedSeconds: 720,
        taskName: "Database migration"
    )

    /// Early stage progress
    static let earlyStage = TaskProgress(
        current: 5,
        total: 100,
        elapsedSeconds: 30,
        taskName: "Building feature"
    )

    /// Nearly complete
    static let nearlyComplete = TaskProgress(
        current: 95,
        total: 100,
        elapsedSeconds: 540,
        taskName: "Finishing up"
    )
}
