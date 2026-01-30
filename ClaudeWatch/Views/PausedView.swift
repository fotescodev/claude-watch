import SwiftUI
import WatchKit

/// Shows paused state when user has interrupted the session
/// V3 B2: Simple card with PAUSED badge, title, subtitle - no checklist
/// Uses ScreenShell for consistent layout
struct PausedView: View {
    var service = WatchService.shared

    /// Get task title from session progress
    private var taskTitle: String {
        if let progress = service.sessionProgress {
            let activity = progress.currentActivity ?? progress.currentTask ?? "Task"
            return "\(progress.completedCount)/\(progress.totalCount) \(activity)"
        }
        return "Session paused"
    }

    var body: some View {
        ScreenShell {
            // V3 B2: StateCard with gray glow
            StateCard(state: .idle, glowOffset: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    // PAUSED badge (black text on gray bg per design)
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.557, green: 0.557, blue: 0.576))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Task title with count (15pt semibold)
                    Text(taskTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // "Waiting to resume..." subtitle
                    Text("Waiting to resume...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.604, blue: 0.624)) // #9A9A9F
                }
            }
        } action: {
            // Resume button (solid blue per design)
            ScreenActionButton("Resume", icon: "play.fill", color: Claude.info) {
                Task {
                    await service.sendInterrupt(action: .resume)
                }
            }
            .accessibilityLabel("Resume session")
        } hint: {
            ScreenHint("Double tap to resume")
        }
        // Double tap to resume (watchOS 26+)
        .modifier(DoubleTapShortcutModifier())
    }
}

/// Conditionally applies hand gesture shortcut on watchOS 26+
struct DoubleTapShortcutModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

#Preview("Paused View") {
    PausedView()
}
