import AppIntents
import SwiftUI

/// App Intent for rejecting the next pending Claude action
/// Voice: "Hey Siri, reject Claude's request"
/// Control Center: Reject button
@available(watchOS 26.0, *)
struct RejectClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Reject Claude"
    static var description = IntentDescription("Reject the next pending Claude action")

    /// Show in Shortcuts app
    static var openAppWhenRun: Bool = false

    /// Perform the rejection
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        // Check if there's a pending action
        guard let action = service.state.pendingActions.first else {
            return .result(dialog: "No pending actions to reject")
        }

        // Reject the action
        if service.useCloudMode && service.isPaired {
            try? await service.respondToCloudRequest(action.id, approved: false)
        } else {
            service.rejectAction(action.id)
        }

        // Return result
        let remainingCount = service.state.pendingActions.count
        if remainingCount > 0 {
            return .result(dialog: "Rejected \(action.title). \(remainingCount) more pending.")
        } else {
            return .result(dialog: "Rejected \(action.title)")
        }
    }
}
