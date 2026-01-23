import SwiftUI
import WatchKit

/// Shows task completion summary
/// Displayed when a Claude session completes successfully
struct TaskOutcomeView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Success checkmark with animation
            ZStack {
                Circle()
                    .fill(ClaudeState.success.color.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(ClaudeState.success.color)
                    .scaleEffect(checkmarkScale)
                    .opacity(checkmarkOpacity)
            }

            // Completion text
            Text("Complete")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Claude.textPrimary)

            // Summary stats
            if let progress = service.sessionProgress {
                VStack(spacing: 4) {
                    Text("\(progress.completedCount) tasks completed")
                        .font(.system(size: 12))
                        .foregroundColor(Claude.textSecondary)

                    if progress.elapsedSeconds > 0 {
                        Text(formatDuration(progress.elapsedSeconds))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Claude.textTertiary)
                    }
                }
            }

            Spacer()

            // Done button
            Button {
                WKInterfaceDevice.current().play(.click)
                service.clearSessionProgress()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ClaudeState.success.color)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .onAppear {
            animateCheckmark()
            WKInterfaceDevice.current().play(.success)
        }
        // Double tap to dismiss (watchOS 26+)
        .modifier(TaskOutcomeDoubleTapModifier())
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

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m \(seconds % 60)s"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return "\(hours)h \(mins)m"
        }
    }
}

/// Conditionally applies hand gesture shortcut on watchOS 26+
private struct TaskOutcomeDoubleTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

#Preview("Task Outcome View") {
    TaskOutcomeView()
}
