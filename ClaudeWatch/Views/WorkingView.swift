import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// V3: Uses TaskChecklist component, progress bar with percentage, pause button
struct WorkingView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var pulsePhase: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header with state indicator
                HStack(spacing: 6) {
                    ClaudeStateDot(state: .working, size: 6)
                        .opacity(reduceMotion ? 1.0 : 0.5 + 0.5 * Double(pulsePhase))

                    Text("Working")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ClaudeState.working.color)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Task card with checklist and progress
                if let progress = service.sessionProgress {
                    VStack(alignment: .leading, spacing: 10) {
                        // Task title
                        if let taskTitle = progress.currentActivity ?? progress.currentTask {
                            Text(taskTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Claude.textPrimary)
                                .lineLimit(2)
                        } else {
                            Text("Processing...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Claude.textPrimary)
                        }

                        // Task checklist using TaskChecklist component
                        if !progress.tasks.isEmpty {
                            TaskChecklist(items: progress.tasks.prefix(4).map { task in
                                (status: mapTodoStatusToCheckStatus(task.status), text: task.content)
                            })
                        }

                        // Progress bar with percentage
                        VStack(spacing: 4) {
                            ProgressView(value: progress.progress)
                                .tint(ClaudeState.working.color)

                            HStack {
                                Spacer()
                                Text("\(Int(progress.progress * 100))%")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Claude.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .glassEffectCompat(RoundedRectangle(cornerRadius: Claude.Radius.large))
                } else {
                    // Fallback when no detailed progress available
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ClaudeState.working.color))

                        if !service.state.taskName.isEmpty {
                            Text(service.state.taskName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Claude.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(12)
                    .glassEffectCompat(RoundedRectangle(cornerRadius: Claude.Radius.large))
                }

                // Pause button (V3 design spec)
                Button {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        await service.sendInterrupt(action: .stop)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Pause")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Claude.warning)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                // Hint text
                Text("Double tap to pause")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Claude.textTertiary)

                Spacer(minLength: 12)
            }
        }
        .focusable()  // Enable Digital Crown scrolling
        .contentMargins(.top, 8, for: .scrollContent)  // Prevent toolbar overlap when scrolling
        .onAppear {
            startPulse()
        }
    }

    /// Maps TodoStatus to TaskCheckStatus for the TaskChecklist component
    private func mapTodoStatusToCheckStatus(_ status: TodoItem.TodoStatus) -> TaskCheckStatus {
        switch status {
        case .completed:
            return .done
        case .inProgress:
            return .active
        case .pending:
            return .pending
        }
    }

    private func startPulse() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulsePhase = 1
        }
    }
}

#Preview("Working View") {
    WorkingView()
}

#Preview("Working View - Expanded") {
    // Preview with expanded task list
    WorkingView()
}
