import AppIntents
import SwiftUI

/// App Intent for approving the next pending Remmy action
/// Voice: "Hey Siri, approve Remmy"
/// Control Center: Approve button
@available(watchOS 26.0, *)
struct ApproveRemmyIntent: AppIntent {
    static var title: LocalizedStringResource = "Approve Remmy"
    static var description = IntentDescription("Approve the next pending Remmy action")

    /// Show in Shortcuts app
    static var openAppWhenRun: Bool = false

    /// Perform the approval
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        // Check if there's a pending action
        guard let action = service.state.pendingActions.first else {
            return .result(dialog: "No pending actions to approve")
        }

        // Approve the action
        if service.useCloudMode && service.isPaired {
            try? await service.respondToCloudRequest(action.id, approved: true)
        } else {
            service.approveAction(action.id)
        }

        // Return result with action title
        let remainingCount = service.state.pendingActions.count
        if remainingCount > 0 {
            return .result(dialog: "Approved \(action.title). \(remainingCount) more pending.")
        } else {
            return .result(dialog: "Approved \(action.title)")
        }
    }
}

/// Shortcut phrases for Siri discoverability
@available(watchOS 26.0, *)
extension ApproveRemmyIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Approve Remmy's pending action")
    }
}
