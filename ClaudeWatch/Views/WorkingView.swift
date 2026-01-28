import SwiftUI
import WatchKit

/// Shows current task progress when Claude is actively working
/// V3 B1: Compact card with task checklist, progress bar, pause button
/// Must fit on screen without scrolling
struct WorkingView: View {
    @ObservedObject private var service = WatchService.shared
    @State private var pulsePhase: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            // Header with state indicator
            HStack(spacing: 6) {
                ClaudeStateDot(state: .working, size: 8)
                    .opacity(reduceMotion ? 1.0 : 0.5 + 0.5 * Double(pulsePhase))

                Text("Working")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ClaudeState.working.color)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            // V3 B1: StateCard with blue glow (compact)
            if let progress = service.sessionProgress {
                StateCard(state: .working, glowOffset: 15, padding: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Task title with count
                        Text("\(progress.completedCount)/\(progress.totalCount) \(progress.currentActivity ?? progress.currentTask ?? "Working...")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        // Task checklist - max 3 items
                        if !progress.tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(progress.tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                                    taskRow(task)
                                }
                            }
                        }

                        // Progress bar with percentage
                        HStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(ClaudeState.working.color)
                                        .frame(width: geo.size.width * progress.progress)
                                }
                            }
                            .frame(height: 5)

                            Text("\(Int(progress.progress * 100))%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(ClaudeState.working.color)
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
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
            }

            Spacer(minLength: 2)

            // Pause button (compact)
            // Note: Haptic played by WatchService.sendInterrupt on success
            Button {
                Task {
                    await service.sendInterrupt(action: .stop)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                    Text("Pause")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            // Hint text
            Text("Double tap to pause")
                .font(.system(size: 9))
                .foregroundColor(Color(red: 0.431, green: 0.431, blue: 0.451))
        }
        .onAppear {
            startPulse()
        }
    }

    /// Task row with status indicator (compact)
    @ViewBuilder
    private func taskRow(_ task: TodoItem) -> some View {
        HStack(spacing: 4) {
            // Status indicator
            switch task.status {
            case .completed:
                Text("✓")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Claude.success)
            case .inProgress:
                Text("●")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(ClaudeState.working.color)
            case .pending:
                Text("○")
                    .font(.system(size: 7))
                    .foregroundColor(Color(red: 0.431, green: 0.431, blue: 0.451))
            }

            // Task text
            Text(task.content)
                .font(.system(size: 9, weight: task.status == .inProgress ? .medium : .regular))
                .foregroundColor(task.status == .inProgress ? .white : Color(red: 0.431, green: 0.431, blue: 0.451))
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
