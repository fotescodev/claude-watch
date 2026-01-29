import SwiftUI
import WatchKit

/// V3 D1: Task completion screen with checkmark, title, and task summary inside StateCard
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
        VStack(spacing: 8) {
            // V3: Header - "Complete" with green dot
            HStack(spacing: 6) {
                ClaudeStateDot(state: .success, size: 8)
                Text("Complete")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ClaudeState.success.color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 4)

            // V3 D1: StateCard containing checkmark + title + task list
            StateCard(state: .success, glowOffset: 10, padding: 14) {
                VStack(spacing: 10) {
                    // Checkmark icon (outline style per spec)
                    ZStack {
                        Circle()
                            .stroke(ClaudeState.success.color, lineWidth: 2)
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ClaudeState.success.color)
                    }
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)

                    // Title
                    Text("Tasks Complete")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    // Task list (inside card)
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(completedTasks.prefix(5)) { task in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(ClaudeState.success.color)
                                        .frame(width: 5, height: 5)

                                    Text(task.content)
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }

                            if completedTasks.count > 5 {
                                Text("+\(completedTasks.count - 5) more")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .padding(.leading, 11)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // V3: Dismiss button (subtle, inside footer area)
            Button {
                WKInterfaceDevice.current().play(.click)
                service.clearSessionProgress()
            } label: {
                Text("Dismiss")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            // Hint text
            Text("Double tap to dismiss")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.4))
        }
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
