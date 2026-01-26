import SwiftUI
import WatchKit

/// Shows task completion summary with bullet list
/// V2: Displays completed tasks as bullet points (max 5)
struct TaskOutcomeView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Completed tasks from session
    private var completedTasks: [TodoItem] {
        service.sessionProgress?.tasks.filter { $0.status == .completed } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // V2: State header with colored dot
                HStack(spacing: 6) {
                    ClaudeStateDot(state: .success, size: 6)
                    Text("Complete")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ClaudeState.success.color)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Success checkmark with animation
                ZStack {
                    Circle()
                        .fill(ClaudeState.success.color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(ClaudeState.success.color)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }
                .padding(.top, 8)

                // Completion text
                Text("Task Complete")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Claude.textPrimary)

                // V2: Bullet summary of completed tasks
                if !completedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        // Show up to 5 tasks
                        ForEach(completedTasks.prefix(5)) { task in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Claude.anthropicOrange)
                                    .frame(width: 4, height: 4)

                                Text(task.content)
                                    .font(.system(size: 10))
                                    .foregroundColor(Claude.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        // Show overflow if more than 5
                        if completedTasks.count > 5 {
                            Text("+\(completedTasks.count - 5) more")
                                .font(.system(size: 9))
                                .foregroundColor(Claude.textTertiary)
                                .padding(.leading, 10)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Claude.surface2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.small))
                    .padding(.horizontal, 12)
                }

                Spacer(minLength: 8)

                // Dismiss button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    service.clearSessionProgress()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Claude.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.surface2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .focusable()  // Enable Digital Crown scrolling
        .onAppear {
            animateCheckmark()
            WKInterfaceDevice.current().play(.success)
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

#Preview("Task Outcome - With Tasks") {
    // Preview would show completed tasks if service had data
    TaskOutcomeView()
}
