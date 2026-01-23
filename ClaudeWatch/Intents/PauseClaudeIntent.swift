import AppIntents
import SwiftUI

/// App Intent for pausing the Claude session
/// Voice: "Hey Siri, pause Claude"
@available(watchOS 26.0, *)
struct PauseClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Claude"
    static var description = IntentDescription("Pause the current Claude session")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        guard service.isPaired else {
            return .result(dialog: "Claude Watch is not paired")
        }

        // Check if already paused
        if service.isSessionInterrupted {
            return .result(dialog: "Claude is already paused")
        }

        // Send pause signal
        await service.sendInterrupt(action: .stop)

        return .result(dialog: "Claude paused")
    }
}

/// App Intent for resuming the Claude session
/// Voice: "Hey Siri, resume Claude"
@available(watchOS 26.0, *)
struct ResumeClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Claude"
    static var description = IntentDescription("Resume the paused Claude session")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = WatchService.shared

        guard service.isPaired else {
            return .result(dialog: "Claude Watch is not paired")
        }

        // Check if already running
        if !service.isSessionInterrupted {
            return .result(dialog: "Claude is already running")
        }

        // Send resume signal
        await service.sendInterrupt(action: .resume)

        return .result(dialog: "Claude resumed")
    }
}
