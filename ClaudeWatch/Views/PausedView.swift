import SwiftUI
import WatchKit

/// Shows paused state when user has interrupted the session
struct PausedView: View {
    @ObservedObject private var service = WatchService.shared

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            // V2: State header with colored dot
            HStack(spacing: 6) {
                ClaudeStateDot(state: .idle, size: 6)
                Text("Paused")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ClaudeState.idle.color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Pause icon - compact
            ZStack {
                Circle()
                    .fill(Claude.warning.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Claude.warning)
            }
            .padding(.top, 4)

            // Status text - title only (icon communicates paused state)
            Text("Paused")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Claude.textPrimary)

            // Progress indicator if available - inline compact
            if let progress = service.sessionProgress {
                Text("\(progress.completedCount)/\(progress.totalCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Claude.textSecondary)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 6) {
                // Resume button (primary)
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
                    .background(Claude.info)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Resume session")

                // End Session button (secondary/destructive)
                Button {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        await service.endSession()
                    }
                } label: {
                    Text("End Session")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Claude.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End watch session")
            }
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
