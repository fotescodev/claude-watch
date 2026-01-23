import SwiftUI
import WatchKit

/// Context warning view for F16: Context > 75% alert
/// Shows context usage percentage with appropriate urgency level
struct ContextWarningView: View {
    let percentage: Int  // 75, 85, or 95

    @ObservedObject private var service = WatchService.shared
    @State private var acknowledged = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            // Warning icon with urgency color
            ZStack {
                Circle()
                    .fill(urgencyColor.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: urgencyIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(urgencyColor)
            }
            .padding(.top, 16)

            // Context usage percentage
            Text("\(percentage)%")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(urgencyColor)

            // Warning message
            VStack(spacing: 4) {
                Text("Context Usage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Claude.textPrimary)

                Text(warningMessage)
                    .font(.system(size: 10))
                    .foregroundColor(Claude.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Spacer()

            // Acknowledge button
            Button {
                acknowledge()
            } label: {
                Text("OK")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(urgencyColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .disabled(acknowledged)
        }
        .onAppear {
            // Play haptic based on urgency
            if percentage >= 95 {
                WKInterfaceDevice.current().play(.failure)
            } else if percentage >= 85 {
                WKInterfaceDevice.current().play(.notification)
            } else {
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    private var urgencyColor: Color {
        if percentage >= 95 {
            return ClaudeState.error.color
        } else if percentage >= 85 {
            return Claude.warning
        } else {
            return Claude.info
        }
    }

    private var urgencyIcon: String {
        if percentage >= 95 {
            return "exclamationmark.triangle.fill"
        } else if percentage >= 85 {
            return "exclamationmark.circle.fill"
        } else {
            return "info.circle.fill"
        }
    }

    private var warningMessage: String {
        if percentage >= 95 {
            return "Context nearly full. Consider starting fresh."
        } else if percentage >= 85 {
            return "Context getting full. Summarization may occur."
        } else {
            return "Context usage is elevated. Monitor closely."
        }
    }

    private func acknowledge() {
        guard !acknowledged else { return }
        acknowledged = true
        WKInterfaceDevice.current().play(.click)
        service.acknowledgeContextWarning()
    }
}

#Preview("Context Warning 75%") {
    ContextWarningView(percentage: 75)
}

#Preview("Context Warning 85%") {
    ContextWarningView(percentage: 85)
}

#Preview("Context Warning 95%") {
    ContextWarningView(percentage: 95)
}
