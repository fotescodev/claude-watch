import SwiftUI
import WatchKit

/// Context warning view for F16: Context > 75% alert
/// V3 E2: StateCard with yellow glow, border, percentage display
struct ContextWarningView: View {
    let percentage: Int  // 75, 85, or 95

    var service = WatchService.shared
    @State private var acknowledged = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            // V3: Header - "Context" status
            HStack(spacing: 6) {
                Circle()
                    .fill(Claude.context)
                    .frame(width: 8, height: 8)
                Text("Context")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Claude.context)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            Spacer(minLength: 4)

            // V3 E2: StateCard with context/yellow glow and border
            StateCard(state: .context, glowOffset: 10, padding: 10) {
                VStack(alignment: .center, spacing: 6) {
                    // Large percentage display (22pt bold, yellow)
                    Text("\(percentage)%")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Claude.context)
                        .frame(maxWidth: .infinity)

                    // Title (11pt semibold, white)
                    Text("Context Usage")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)

                    // Subtitle (10pt, #ffffff99)
                    Text("Running low on\nconversation context")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    // Progress bar (6px height, #ffffff20 bg, yellow fill)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Claude.context)
                                .frame(width: geo.size.width * CGFloat(percentage) / 100.0)
                        }
                    }
                    .frame(height: 6)

                    // OK button (yellow bg, black text, rounded)
                    Button {
                        dismiss()
                    } label: {
                        Text("OK")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 67, height: 27)
                            .background(Claude.context)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(acknowledged)
                    .padding(.top, 3)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 4)

            // V3: Hint text
            Text("Summarize to free space")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color.white.opacity(0.38))
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
