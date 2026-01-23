import SwiftUI
import WidgetKit
import AppIntents

/// Control Center button showing Claude status
/// Opens the app when tapped
@available(watchOS 26.0, *)
struct StatusControl: ControlWidget {
    static let kind = "com.claudewatch.status"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: StatusValueProvider()
        ) { status in
            ControlWidgetButton(action: OpenClaudeIntent()) {
                Label {
                    Text(status.displayText)
                } icon: {
                    Image(systemName: status.icon)
                }
            }
            .tint(status.tintColor)
        }
        .displayName("Claude Status")
        .description("See Claude status and open app")
    }
}

/// Status value for the control widget
struct ClaudeControlStatus {
    let displayText: String
    let icon: String
    let tintColor: Color

    static let disconnected = ClaudeControlStatus(
        displayText: "Offline",
        icon: "link.badge.plus",
        tintColor: .gray
    )

    static let idle = ClaudeControlStatus(
        displayText: "Ready",
        icon: "circle",
        tintColor: .gray
    )

    static let working = ClaudeControlStatus(
        displayText: "Working",
        icon: "circle.dotted.circle",
        tintColor: .blue
    )

    static func pending(_ count: Int) -> ClaudeControlStatus {
        ClaudeControlStatus(
            displayText: count == 1 ? "1 Pending" : "\(count) Pending",
            icon: "hand.raised.fill",
            tintColor: .orange
        )
    }

    static let paused = ClaudeControlStatus(
        displayText: "Paused",
        icon: "pause.circle.fill",
        tintColor: .yellow
    )
}

/// Provides the current status for the control
@available(watchOS 26.0, *)
struct StatusValueProvider: AppIntentControlValueProvider {
    func previewValue(configuration: StatusConfiguration) -> ClaudeControlStatus {
        .idle
    }

    func currentValue(configuration: StatusConfiguration) async throws -> ClaudeControlStatus {
        await MainActor.run {
            let service = WatchService.shared

            guard service.isPaired else {
                return .disconnected
            }

            // Check for pending actions first
            let pendingCount = service.state.pendingActions.count
            if pendingCount > 0 {
                return .pending(pendingCount)
            }

            // Check if paused
            if service.isSessionInterrupted {
                return .paused
            }

            // Check session progress
            if let progress = service.sessionProgress, !progress.isComplete {
                return .working
            }

            // Default to idle
            return .idle
        }
    }
}

/// Configuration for the status control (empty, no parameters needed)
@available(watchOS 26.0, *)
struct StatusConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Status Configuration"
}

/// Intent that opens the Claude Watch app
@available(watchOS 26.0, *)
struct OpenClaudeIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Claude Watch"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

