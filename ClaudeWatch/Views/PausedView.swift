import SwiftUI
import WatchKit

/// Shows paused state when user has interrupted the session
/// V3 B2: Simple card with PAUSED badge, title, subtitle - no checklist
struct PausedView: View {
    @ObservedObject private var service = WatchService.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Get task title from session progress
    private var taskTitle: String {
        if let progress = service.sessionProgress {
            let activity = progress.currentActivity ?? progress.currentTask ?? "Task"
            return "\(progress.completedCount)/\(progress.totalCount) \(activity)"
        }
        return "Session paused"
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header with gray "Paused" status
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(red: 0.557, green: 0.557, blue: 0.576)) // #8E8E93
                    .frame(width: 8, height: 8)

                Text("Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(red: 0.557, green: 0.557, blue: 0.576))

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 4)

            // V3 B2: StateCard with gray glow
            StateCard(state: .idle, glowOffset: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    // PAUSED badge (black text on gray bg per design)
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.557, green: 0.557, blue: 0.576))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Task title with count (15pt semibold)
                    Text(taskTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // "Waiting to resume..." subtitle
                    Text("Waiting to resume...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.604, green: 0.604, blue: 0.624)) // #9A9A9F
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // Resume button (solid blue per design)
            // Note: Haptic played by WatchService.sendInterrupt on success
            Button {
                Task {
                    await service.sendInterrupt(action: .resume)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("Resume")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0, green: 0.478, blue: 1)) // #007AFF
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .accessibilityLabel("Resume session")

            // Hint text
            Text("Double tap to resume")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.431, green: 0.431, blue: 0.451)) // #6E6E73
        }
        // Double tap to resume (watchOS 26+)
        .modifier(DoubleTapShortcutModifier())
    }
}

/// Conditionally applies hand gesture shortcut on watchOS 26+
struct DoubleTapShortcutModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

#Preview("Paused View") {
    PausedView()
}
