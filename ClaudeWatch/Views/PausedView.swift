import SwiftUI
import WatchKit

/// Shows paused state when user has interrupted the session
/// V3 B2: Simple card with PAUSED badge, title, subtitle - no checklist
/// Uses ScreenShell for consistent layout
struct PausedView: View {
    var service = WatchService.shared

    /// Get task title from session progress (prefer task name over activity which may echo "Paused")
    private var taskTitle: String {
        if let progress = service.sessionProgress {
            let task = progress.currentTask ?? progress.currentActivity ?? "Task"
            return "\(progress.completedCount)/\(progress.totalCount) \(task)"
        }
        return "Session paused"
    }

    /// Convert session tasks to checklist items (max 4)
    private var checklistItems: [(status: TaskCheckStatus, text: String)] {
        guard let progress = service.sessionProgress, !progress.tasks.isEmpty else { return [] }
        return progress.tasks.prefix(4).map { task in
            let status: TaskCheckStatus = switch task.status {
            case .completed: .done
            case .inProgress: .active
            case .pending: .pending
            }
            return (status: status, text: task.content)
        }
    }

    var body: some View {
        ScreenShell {
            // V3 B2: StateCard with gray glow (toolbar already shows "● Paused")
            StateCard(state: .idle, glowOffset: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    // Task title with count
                    Text(taskTitle)
                        .font(.claudeHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    // Task checklist when available, otherwise subtitle
                    if !checklistItems.isEmpty {
                        TaskChecklist(items: checklistItems)
                    } else {
                        Text("Waiting to resume...")
                            .font(.claudeCaption)
                            .foregroundStyle(Claude.textMuted)
                    }
                }
            }
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
