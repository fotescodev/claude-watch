import SwiftUI
import WatchKit

/// V3 D1: Task completion screen with checkmark, title, and task summary inside StateCard
/// Uses ScreenShell for consistent layout
struct TaskOutcomeView: View {
    var service = WatchService.shared
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Completed tasks from session
    private var completedTasks: [TodoItem] {
        service.sessionProgress?.tasks.filter { $0.status == .completed } ?? []
    }

    var body: some View {
        ScreenShell {
            // Single card: checkmark + title + task summary
            StateCard(state: .success, glowOffset: 10, padding: Claude.Spacing.sm) {
                VStack(spacing: 4) {
                    // Checkmark icon
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(ClaudeState.success.color)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)

                    Text("Done")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)

                    // Task list with bullet dots (max 2 visible)
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(completedTasks.prefix(2)) { task in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Claude.textMuted)
                                        .frame(width: 3, height: 3)

                                    Text(task.content)
                                        .font(.caption2)
                                        .foregroundStyle(Claude.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            if completedTasks.count > 2 {
                                Text("+\(completedTasks.count - 2) more")
                                    .font(.caption2)
                                    .foregroundStyle(Claude.textMuted)
                                    .padding(.leading, 7)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } hint: {
            ScreenHint("Double tap to dismiss")
        }
        .onAppear {
            animateCheckmark()
            WKInterfaceDevice.current().play(.success)
            // Auto-dismiss after 10 seconds — gives user time to read task summary
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                service.clearSessionProgress()
            }
        }
        // Double tap to dismiss (watchOS 26+)
        .modifier(TaskOutcomeDoubleTapModifier(onDismiss: {
            service.clearSessionProgress()
        }))
    }

    private func animateCheckmark() {
        guard !reduceMotion else {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
            return
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }
    }
}

/// Conditionally applies hand gesture shortcut on watchOS 26+
private struct TaskOutcomeDoubleTapModifier: ViewModifier {
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .handGestureShortcut(.primaryAction)
                .onTapGesture(count: 2) {
                    onDismiss()
                }
        } else {
            content
                .onTapGesture(count: 2) {
                    onDismiss()
                }
        }
    }
}

#Preview("Task Outcome View") {
    TaskOutcomeView()
}
