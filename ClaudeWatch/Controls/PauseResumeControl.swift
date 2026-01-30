import SwiftUI
import WidgetKit
import AppIntents

/// Control Center toggle to pause/resume Remmy session
/// Shows current state and toggles on tap
@available(watchOS 26.0, *)
struct PauseResumeControl: ControlWidget {
    static let kind = "com.remmy.pause-resume"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: PauseResumeValueProvider()
        ) { value in
            ControlWidgetToggle(
                isOn: value,
                action: TogglePauseIntent()
            ) {
                Label {
                    Text(value ? "Paused" : "Running")
                } icon: {
                    Image(systemName: value ? "pause.circle.fill" : "play.circle.fill")
                }
            }
        }
        .displayName("Pause Remmy")
        .description("Pause or resume Remmy session")
    }
}

/// Provides the current pause state for the control
@available(watchOS 26.0, *)
struct PauseResumeValueProvider: AppIntentControlValueProvider {
    func previewValue(configuration: PauseResumeConfiguration) -> Bool {
        false  // Preview shows "Running"
    }

    func currentValue(configuration: PauseResumeConfiguration) async throws -> Bool {
        await MainActor.run {
            WatchService.shared.isSessionInterrupted
        }
    }
}

/// Configuration for the pause/resume control (empty, no parameters needed)
@available(watchOS 26.0, *)
struct PauseResumeConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Pause Resume Configuration"
}

/// Intent that toggles the pause state
@available(watchOS 26.0, *)
struct TogglePauseIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Toggle Remmy Pause"

    @Parameter(title: "Paused")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        let service = WatchService.shared

        if value {
            // Pause
            await service.sendInterrupt(action: .stop)
        } else {
            // Resume
            await service.sendInterrupt(action: .resume)
        }

        return .result()
    }
}
