import AppIntents
import SwiftUI

/// App Intent for pausing the Remmy session
/// Voice: "Hey Siri, pause Remmy"
@available(watchOS 26.0, *)
struct PauseRemmyIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Remmy"
    static var description = IntentDescription("Pause the current Remmy session")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        guard service.isPaired else {
            return .result(dialog: "Remmy is not paired")
        }

        // Check if already paused
        if service.isSessionInterrupted {
            return .result(dialog: "Remmy is already paused")
        }

        // Send pause signal
        await service.sendInterrupt(action: .stop)

        return .result(dialog: "Remmy paused")
    }
}

/// App Intent for resuming the Remmy session
/// Voice: "Hey Siri, resume Remmy"
@available(watchOS 26.0, *)
struct ResumeRemmyIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Remmy"
    static var description = IntentDescription("Resume the paused Remmy session")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        guard service.isPaired else {
            return .result(dialog: "Remmy is not paired")
        }

        // Check if already running
        if !service.isSessionInterrupted {
            return .result(dialog: "Remmy is already running")
        }

        // Send resume signal
        await service.sendInterrupt(action: .resume)

        return .result(dialog: "Remmy resumed")
    }
}
