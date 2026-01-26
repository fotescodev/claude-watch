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
            // Header with state dot
            HStack {
                Circle()
                    .fill(Claude.warning)
                    .frame(width: 6, height: 6)
                Text("Warning")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Claude.warning)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Warning icon - triangle
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
                .padding(.top, 4)

            // Title with percentage
            Text("Context at \(percentage)%")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Claude.textPrimary)

            // Subtitle
            Text("Session may compress soon")
                .font(.system(size: 11))
                .foregroundColor(Claude.textSecondary)

            // Red progress bar
            ProgressView(value: Double(percentage) / 100.0)
                .tint(.red)
                .padding(.horizontal, 20)

            Spacer()

            // Two buttons: Dismiss + View
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.surface2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    view()
                } label: {
                    Text("View")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.warning)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
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

    private func dismiss() {
        guard !acknowledged else { return }
        acknowledged = true
        WKInterfaceDevice.current().play(.click)
        service.acknowledgeContextWarning()
    }

    private func view() {
        guard !acknowledged else { return }
        acknowledged = true
        WKInterfaceDevice.current().play(.click)
        // View action - for now just acknowledge (could navigate to details in future)
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
