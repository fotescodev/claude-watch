import SwiftUI

// MARK: - State Card Component
/// Reusable card component with gradient fill, border, and ambient glow
/// V3 Design Spec:
/// - Gradient fill: #ffffff12 (7%) top to #ffffff08 (3%) bottom
/// - Border/stroke: state color at 30% opacity, 1px thickness
/// - Corner radius: 16
/// - Padding: 10-14 (depending on content density)
/// - Glow: 100x80 ellipse, 35px blur, state color at 30% opacity
struct StateCard<Content: View>: View {
    let state: ClaudeState
    let glowOffset: CGFloat
    let padding: CGFloat
    let content: Content

    init(
        state: ClaudeState,
        glowOffset: CGFloat = 15,
        padding: CGFloat = 14,
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.glowOffset = glowOffset
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Ambient glow behind card (V3: 100x80 ellipse, 35px blur, 30% opacity)
            CardGlow(color: state.color)
                .offset(y: glowOffset)

            // Card with gradient fill and border
            content
                .padding(padding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.07),  // #ffffff12 ≈ 7%
                                    Color.white.opacity(0.03)   // #ffffff08 ≈ 3%
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // V3: Border/stroke in state color at 30% opacity
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(state.color.opacity(0.30), lineWidth: 1)
                )
        }
    }
}

// MARK: - Card Glow
/// Glow effect specifically sized for cards
/// V3 Spec: 100x80 ellipse, 35px blur, 30% opacity
struct CardGlow: View {
    let color: Color

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.30))
            .frame(width: 100, height: 80)
            .blur(radius: 35)
    }
}

// MARK: - Convenience Extensions
extension StateCard where Content == EmptyView {
    init(state: ClaudeState) {
        self.state = state
        self.glowOffset = 15
        self.padding = 14
        self.content = EmptyView()
    }
}

// MARK: - Preview
#Preview("State Cards") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            StateCard(state: .working) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("2/3 Update auth")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Working...")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.451))
                }
            }

            StateCard(state: .idle, glowOffset: 25) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(red: 0.557, green: 0.557, blue: 0.576))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text("2/3 Update auth")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Waiting to resume...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.604, green: 0.604, blue: 0.624))
                }
            }

            StateCard(state: .success) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Task Complete")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding()
    }
}
