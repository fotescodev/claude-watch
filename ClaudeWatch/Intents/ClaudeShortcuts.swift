import AppIntents

/// Provider for Claude Watch shortcuts
/// Makes intents discoverable in the Shortcuts app and Siri
@available(watchOS 26.0, *)
struct ClaudeShortcuts: AppShortcutsProvider {
    /// Shortcuts exposed to the system
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ApproveClaudeIntent(),
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
            intent: RejectClaudeIntent(),
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
            intent: ClaudeStatusIntent(),
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
            intent: PauseClaudeIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Stop \(.applicationName)",
                "Hold \(.applicationName)"
            ],
            shortTitle: "Pause",
            systemImageName: "pause.circle.fill"
        )

        AppShortcut(
            intent: ResumeClaudeIntent(),
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
