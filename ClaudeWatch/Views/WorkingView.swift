import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// V3 B1: Compact card with task checklist, progress bar, pause button
/// Uses ScreenShell for consistent layout
struct WorkingView: View {
    var service = WatchService.shared

    var body: some View {
        ScreenShell {
            // Card content
            if let progress = service.sessionProgress {
                StateCard(state: .working, glowOffset: 15, padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Task title with count - larger for glanceability
                        Text("\(progress.completedCount)/\(progress.totalCount) \(progress.currentActivity ?? progress.currentTask ?? "Working...")")
                            .font(.claudeHeadline)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        // Task checklist - max 3 items, larger text
                        if !progress.tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(Array(progress.tasks.prefix(3))) { task in
                                    taskRow(task)
                                }
                            }
                        }

                        // Progress bar with percentage - taller bar
                        HStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Claude.fill3)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ClaudeState.working.color)
                                        .frame(width: geo.size.width * progress.progress)
                                }
                            }
                            .frame(height: 8)

                            Text("\(Int(progress.progress * 100))%")
                                .font(.claudeCaptionBold)
                                .foregroundStyle(ClaudeState.working.color)
                        }
                    }
                }
            } else {
                // Fallback loading state
                StateCard(state: .working, glowOffset: 15, padding: 10) {
                    VStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ClaudeState.working.color))
                        Text("Processing...")
                            .font(.claudeFootnoteMedium)
                            .foregroundStyle(.white)
                    }
                }
            }
        } action: {
            // Pause button - minimal, secondary prominence
            ScreenSecondaryButton("Pause", icon: "pause.fill") {
                Task {
                    await service.sendInterrupt(action: .stop)
                }
            }
        }
    }

    /// Task row with status indicator (larger for glanceability)
    @ViewBuilder
    private func taskRow(_ task: TodoItem) -> some View {
        HStack(spacing: 5) {
            // Status indicator
            switch task.status {
            case .completed:
                Text("✓")
                    .font(.claudeFootnoteBold)
                    .foregroundStyle(Claude.success)
            case .inProgress:
                Text("●")
                    .font(.claudeNano)
                    .foregroundStyle(ClaudeState.working.color)
            case .pending:
                Text("○")
                    .font(.claudeNano)
                    .foregroundStyle(Claude.textDisabled)
            }

            // Task text - larger for glanceability
            Text(task.content)
                .font(.system(size: 11, weight: task.status == .inProgress ? .medium : .regular))
                .foregroundStyle(task.status == .inProgress ? .white : Claude.textDisabled)
                .lineLimit(1)
        }
    }
}

#Preview("Working View") {
    WorkingView()
}
