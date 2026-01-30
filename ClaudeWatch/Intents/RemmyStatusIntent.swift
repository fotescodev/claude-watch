import AppIntents
import SwiftUI

/// App Intent for checking Remmy's current status
/// Voice: "Hey Siri, what's Remmy doing?"
@available(watchOS 26.0, *)
struct RemmyStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Remmy Status"
    static var description = IntentDescription("Check what Remmy is currently doing")

    /// Don't open app - just speak the status
    static var openAppWhenRun: Bool = false

    /// Get the current status
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        // Check connection
        guard service.isPaired else {
            return .result(dialog: "Remmy is not paired")
        }

        // Build status message
        let pendingCount = service.state.pendingActions.count

        if pendingCount > 0 {
            if pendingCount == 1 {
                let action = service.state.pendingActions.first!
                return .result(dialog: "1 action pending: \(action.title)")
            } else {
                return .result(dialog: "\(pendingCount) actions pending for approval")
            }
        }

        // Check session progress
        if let progress = service.sessionProgress {
            if progress.isComplete {
                return .result(dialog: "Task complete: \(progress.completedCount) of \(progress.totalCount) items done")
            } else if let activity = progress.currentActivity ?? progress.currentTask {
                return .result(dialog: "Working on: \(activity)")
            } else {
                return .result(dialog: "Remmy is working")
            }
        }

        // Idle state
        switch service.state.status {
        case .idle:
            return .result(dialog: "Remmy is ready and listening")
        case .running:
            if let taskName = service.state.taskName.isEmpty ? nil : service.state.taskName {
                return .result(dialog: "Working on: \(taskName)")
            }
            return .result(dialog: "Remmy is working")
        case .waiting:
            return .result(dialog: "Remmy is waiting for input")
        case .completed:
            return .result(dialog: "Task completed")
        case .failed:
            return .result(dialog: "Task failed")
        }
    }
}
