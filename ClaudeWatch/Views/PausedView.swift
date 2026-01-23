import SwiftUI
import WatchKit

/// Shows paused state when user has interrupted the session
struct PausedView: View {
    @ObservedObject private var service = WatchService.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // Pause icon
            ZStack {
                Circle()
                    .fill(Claude.warning.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(Claude.warning)
            }

            // Status text
            VStack(spacing: 4) {
                Text("Paused")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Claude.textPrimary)

                Text("Claude is waiting to resume")
                    .font(.system(size: 11))
                    .foregroundColor(Claude.textSecondary)
            }

            // Progress indicator if available
            if let progress = service.sessionProgress {
                HStack(spacing: 6) {
                    ProgressView(value: progress.progress)
                        .tint(Claude.warning)
                        .frame(width: 60)

                    Text("\(progress.completedCount)/\(progress.totalCount)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Claude.textSecondary)
                }
            }

            Spacer()

            // Resume button
            Button {
                WKInterfaceDevice.current().play(.click)
                Task {
                    await service.sendInterrupt(action: .resume)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Resume")
                        .font(.system(size: 14, weight: .semibold))
                }
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
