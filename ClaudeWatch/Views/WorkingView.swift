import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// V2: Displays percentage, collapsible task list, Digital Crown scroll
struct WorkingView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var pulsePhase: CGFloat = 0
    @State private var isTaskListExpanded = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header with state indicator and percentage
                HStack(spacing: 6) {
                    ClaudeStateDot(state: .working)
                        .opacity(reduceMotion ? 1.0 : 0.5 + 0.5 * Double(pulsePhase))

                    Text("Working")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Claude.textSecondary)

                    Spacer()

                    // Progress percentage (V2)
                    if let progress = service.sessionProgress, progress.totalCount > 0 {
                        Text("\(Int(progress.progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(ClaudeState.working.color)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Current activity
                if let progress = service.sessionProgress {
                    VStack(alignment: .leading, spacing: 6) {
                        // Activity name with in-progress task indicator
                        if let activity = progress.currentActivity ?? progress.currentTask {
                            HStack(spacing: 6) {
                                // Animated activity indicator
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)

                                Text(activity)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Claude.textPrimary)
                                    .lineLimit(2)
                            }
                        } else {
                            Text("Processing...")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Claude.textPrimary)
                        }

                        // Collapsible todo list (V2)
                        if !progress.tasks.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isTaskListExpanded.toggle()
                                }
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isTaskListExpanded ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Claude.textTertiary)

                                    Text("\(progress.completedCount)/\(progress.totalCount) tasks")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Claude.textSecondary)

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            // Expanded task list (max 4 items to prevent scroll overflow on watch)
                            if isTaskListExpanded {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(progress.tasks.prefix(4)) { task in
                                        HStack(spacing: 4) {
                                            Image(systemName: task.status.systemIcon)
                                                .font(.system(size: 9))
                                                .foregroundColor(task.status.color)

                                            Text(task.content)
                                                .font(.system(size: 9))
                                                .foregroundColor(task.status == .completed ? Claude.textSecondary : Claude.textPrimary)
                                                .lineLimit(1)
                                                .strikethrough(task.status == .completed, color: Claude.textTertiary)
                                        }
                                    }

                                    // Show overflow indicator if more than 4 tasks
                                    if progress.tasks.count > 4 {
                                        Text("+\(progress.tasks.count - 4) more")
                                            .font(.system(size: 8))
                                            .foregroundColor(Claude.textTertiary)
                                            .padding(.leading, 13)
                                    }
                                }
                                .padding(.leading, 12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // Progress bar with elapsed time
                        VStack(spacing: 4) {
                            ProgressView(value: progress.progress)
                                .tint(ClaudeState.working.color)

                            HStack {
                                Text("\(progress.completedCount)/\(progress.totalCount)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(Claude.textSecondary)

                                Spacer()

                                if progress.elapsedSeconds > 0 {
                                    Text(progress.formattedElapsedTime)
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(Claude.textTertiary)
                                }
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

                // Pause button at bottom (V2 design spec)
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

                Spacer(minLength: 20)
            }
        }
        .focusable()  // Enable Digital Crown scrolling
        .contentMargins(.top, 8, for: .scrollContent)  // Prevent toolbar overlap when scrolling
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

#Preview("Working View - Expanded") {
    // Preview with expanded task list
    WorkingView()
}
