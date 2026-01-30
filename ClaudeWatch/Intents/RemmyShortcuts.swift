import AppIntents

/// Provider for Remmy shortcuts
/// Makes intents discoverable in the Shortcuts app and Siri
@available(watchOS 26.0, *)
struct RemmyShortcuts: AppShortcutsProvider {
    /// Shortcuts exposed to the system
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApproveRemmyIntent(),
            phrases: [
                "Approve \(.applicationName)",
                "Approve \(.applicationName)'s request",
                "Accept \(.applicationName)",
                "Yes \(.applicationName)",
                "Approve with \(.applicationName)"
            ],
            shortTitle: "Approve",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: RejectRemmyIntent(),
            phrases: [
                "Reject \(.applicationName)",
                "Reject \(.applicationName)'s request",
                "Deny \(.applicationName)",
                "No \(.applicationName)",
                "Cancel \(.applicationName)"
            ],
            shortTitle: "Reject",
            systemImageName: "xmark.circle.fill"
        )

        AppShortcut(
            intent: RemmyStatusIntent(),
            phrases: [
                "What's \(.applicationName) doing",
                "What is \(.applicationName) doing",
                "\(.applicationName) status",
                "Check \(.applicationName)",
                "How's \(.applicationName)"
            ],
            shortTitle: "Status",
            systemImageName: "info.circle.fill"
        )

        AppShortcut(
            intent: PauseRemmyIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Stop \(.applicationName)",
                "Hold \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.circle.fill"
        )

        AppShortcut(
            intent: ResumeRemmyIntent(),
            phrases: [
                "Resume \(.applicationName)",
                "Continue \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Resume",
            systemImageName: "play.circle.fill"
        )
    }
}
