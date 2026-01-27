import SwiftUI

// MARK: - Ambient Glow Effect
/// Ambient glow effect for state emphasis
/// V3 Spec: 100x80 ellipse, 35px blur, 18% opacity
struct AmbientGlow: View {
    let color: Color

    init(color: Color) {
        self.color = color
    }

    init(state: ClaudeState) {
        self.color = state.color
    }

    var body: some View {
        Ellipse()
            .fill(color.opacity(0.18))
            .frame(width: 100, height: 80)
            .blur(radius: 35)
    }
}

// MARK: - Convenience Factories
extension AmbientGlow {
    static func success() -> AmbientGlow { AmbientGlow(color: Claude.success) }
    static func warning() -> AmbientGlow { AmbientGlow(color: Claude.warning) }
    static func danger() -> AmbientGlow { AmbientGlow(color: Claude.danger) }
    static func working() -> AmbientGlow { AmbientGlow(color: Claude.info) }
    static func brand() -> AmbientGlow { AmbientGlow(color: Claude.anthropicOrange) }
    static func idle() -> AmbientGlow { AmbientGlow(color: Claude.idle) }
    static func plan() -> AmbientGlow { AmbientGlow(color: Claude.plan) }
    static func question() -> AmbientGlow { AmbientGlow(color: Claude.question) }
    static func context() -> AmbientGlow { AmbientGlow(color: Claude.context) }
}

// MARK: - Preview
#Preview("Ambient Glows") {
    ZStack {
        Color.black
        VStack(spacing: 40) {
            ZStack {
                AmbientGlow.success()
                Text("Success").foregroundColor(.white)
            }
            ZStack {
                AmbientGlow.warning()
                Text("Warning").foregroundColor(.white)
            }
            ZStack {
                AmbientGlow.danger()
                Text("Danger").foregroundColor(.white)
            }
        }
    }
}
