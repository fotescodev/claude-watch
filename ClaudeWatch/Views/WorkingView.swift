import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// Displays: current activity, todo list, progress bar
struct WorkingView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var pulsePhase: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            // Header with state indicator
            HStack(spacing: 6) {
                ClaudeStateDot(state: .working)
                    .opacity(reduceMotion ? 1.0 : 0.5 + 0.5 * Double(pulsePhase))

                Text("Working")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)

                Spacer()

                // Pause button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        await service.sendInterrupt(action: .stop)
                    }
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Claude.warning)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Current activity
            if let progress = service.sessionProgress {
                VStack(alignment: .leading, spacing: 6) {
                    // Activity name
                    if let activity = progress.currentActivity ?? progress.currentTask {
                        Text(activity)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)
                            .lineLimit(2)
                    } else {
                        Text("Processing...")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)
                    }

                    // Todo list (up to 3 items)
                    if !progress.tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(progress.tasks.prefix(3)) { task in
                                HStack(spacing: 4) {
                                    Text(task.status.icon)
                                        .font(.system(size: 8))
                                        .foregroundColor(task.status.color)

                                    Text(task.content)
                                        .font(.system(size: 9))
                                        .foregroundColor(task.status == .completed ? Claude.textSecondary : Claude.textPrimary)
                                        .lineLimit(1)
                                }
                            }

                            if progress.tasks.count > 3 {
                                Text("+\(progress.tasks.count - 3) more")
                                    .font(.system(size: 8))
                                    .foregroundColor(Claude.textTertiary)
                            }
                        }
                    }

                    // Progress bar
                    HStack(spacing: 6) {
                        ProgressView(value: progress.progress)
                            .tint(ClaudeState.working.color)

                        Text("\(progress.completedCount)/\(progress.totalCount)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Claude.textSecondary)
                    }
                }
                .padding(12)
                .glassEffectCompat(RoundedRectangle(cornerRadius: 12))
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
                .glassEffectCompat(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .onAppear {
            startPulse()
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
