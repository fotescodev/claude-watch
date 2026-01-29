import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// V3 B1: Compact card with task checklist, progress bar, pause button
/// Must fit on screen without scrolling
struct WorkingView: View {
    var service = WatchService.shared
    @State private var pulsePhase: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            // V3 B1: StateCard with blue glow (compact)
            // Note: Status header is now handled by MainView toolbar
            if let progress = service.sessionProgress {
                StateCard(state: .working, glowOffset: 15, padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Task title with count - larger for glanceability
                        Text("\(progress.completedCount)/\(progress.totalCount) \(progress.currentActivity ?? progress.currentTask ?? "Working...")")
                            .font(.system(size: 15, weight: .semibold))
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
                                        .fill(Color.white.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ClaudeState.working.color)
                                        .frame(width: geo.size.width * progress.progress)
                                }
                            }
                            .frame(height: 8)

                            Text("\(Int(progress.progress * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ClaudeState.working.color)
                        }
                    }
                }
                .padding(.horizontal, 8)
            } else {
                // Fallback loading state
                StateCard(state: .working, glowOffset: 15, padding: 10) {
                    VStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ClaudeState.working.color))
                        Text("Processing...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 4)

            // Pause button - minimal, secondary prominence
            // Note: Haptic played by WatchService.sendInterrupt on success
            Button {
                Task {
                    await service.sendInterrupt(action: .stop)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10))
                    Text("Pause")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            startPulse()
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Claude.success)
            case .inProgress:
                Text("●")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ClaudeState.working.color)
            case .pending:
                Text("○")
                    .font(.system(size: 9))
                    .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.451))
            }

            // Task text - larger for glanceability
            Text(task.content)
                .font(.system(size: 11, weight: task.status == .inProgress ? .medium : .regular))
                .foregroundStyle(task.status == .inProgress ? .white : Color(red: 0.431, green: 0.431, blue: 0.451))
                .lineLimit(1)
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
