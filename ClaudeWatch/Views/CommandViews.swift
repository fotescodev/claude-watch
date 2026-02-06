import SwiftUI
import WatchKit

// MARK: - Command Grid
struct CommandGrid: View {
    var service = WatchService.shared
    @Binding var showingVoiceInput: Bool

    private let commands: [(String, String, String)] = [
        ("play.fill", "Go", "Continue"),
        ("bolt.fill", "Test", "Run tests"),
        ("wrench.fill", "Fix", "Fix errors"),
        ("stop.fill", "Stop", "Stop"),
    ]

    var body: some View {
        VStack(spacing: 8) {
            // Command buttons in 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(commands, id: \.1) { icon, label, prompt in
                    CommandButton(icon: icon, label: label, prompt: prompt)
                }
            }

            // Voice command button
            Button {
                showingVoiceInput = true
                WKInterfaceDevice.current().play(.click)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Claude.info)

                    Text("Voice Command")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Claude.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Claude.textTertiary)
                }
                .padding(12)
                .glassEffectCompat(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open voice command input")
        }
    }
}

// MARK: - Command Button
struct CommandButton: View {
    var service = WatchService.shared
    let icon: String
    let label: String
    let prompt: String

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var buttonHeight: CGFloat = 52

    // Spring animation state
    @State private var isPressed = false
    @State private var didTap = false

    var body: some View {
        Button {
            service.sendPrompt(prompt)
            didTap.toggle()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Claude.orange)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Claude.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: buttonHeight)
            .glassEffectCompat(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(isPressed && !reduceMotion ? 0.92 : 1.0)
            .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(label) command, sends \(prompt)")
        .sensoryFeedback(.selection, trigger: didTap)
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    var service = WatchService.shared

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Dynamic Type support - compact
    @ScaledMetric(relativeTo: .caption) private var modeIconContainerSize: CGFloat = 20
    @ScaledMetric(relativeTo: .caption) private var modeIconSize: CGFloat = 10

    // Spring animation state
    @State private var isPressed = false
    @State private var didChangeMode = false

    var body: some View {
        Button {
            service.cycleMode()
            didChangeMode.toggle()
            // VoiceOver announcement for mode change
            announceModChange()
        } label: {
            HStack(spacing: 6) {
                // Mode icon - compact
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.2))
                        .frame(width: modeIconContainerSize, height: modeIconContainerSize)

                    Image(systemName: service.state.mode.icon)
                        .font(.system(size: modeIconSize, weight: .bold))
                        .foregroundStyle(modeColor)
                }

                Text(service.state.mode.displayName)
                    .font(.claudeFootnote)
                    .foregroundStyle(modeColor)

                Spacer()

                // Next mode hint
                Image(systemName: "chevron.right")
                    .font(.claudeNano)
                    .foregroundStyle(Claude.textTertiary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(modeBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(modeColor.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
            .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Current mode: \(service.state.mode.displayName). Tap to change mode")
        .sensoryFeedback(.selection, trigger: didChangeMode)
    }

    private var modeColor: Color {
        switch service.state.mode {
        case .normal: return Claude.info
        case .autoAccept: return Claude.danger
        case .plan: return Color.purple
        }
    }

    private var modeBackground: Color {
        switch service.state.mode {
        case .normal: return Claude.surface1
        case .autoAccept: return Claude.danger.opacity(0.1)
        case .plan: return Color.purple.opacity(0.1)
        }
    }

    private func announceModChange() {
        // Post VoiceOver announcement for mode change
        let announcement = "Mode changed to \(service.state.mode.displayName). \(service.state.mode.description)"
        AccessibilityNotification.Announcement(announcement).post()
    }
}

// MARK: - Compact Mode Selector
/// Single-line mode selector for glanceable design
struct CompactModeSelector: View {
    var service = WatchService.shared

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Spring animation state
    @State private var isPressed = false
    @State private var didChangeMode = false

    var body: some View {
        Button {
            service.cycleMode()
            didChangeMode.toggle()
            announceModChange()
        } label: {
            HStack {
                Image(systemName: modeIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(modeColor)

                Text(service.state.mode.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(modeColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Claude.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(modeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
            .animation(.buttonSpringIfAllowed(reduceMotion: reduceMotion), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Current mode: \(service.state.mode.displayName). Tap to change mode")
        .sensoryFeedback(.selection, trigger: didChangeMode)
    }

    private var modeIcon: String {
        service.state.mode.icon
    }

    private var modeColor: Color {
        switch service.state.mode {
        case .normal: return Claude.info
        case .autoAccept: return Claude.danger
        case .plan: return Color.purple
        }
    }

    private func announceModChange() {
        let announcement = "Mode changed to \(service.state.mode.displayName)"
        AccessibilityNotification.Announcement(announcement).post()
    }
}

// MARK: - Previews
#Preview("Command Grid") {
    CommandGrid(showingVoiceInput: .constant(false))
        .padding()
}

#Preview("Command Button") {
    CommandButton(icon: "play.fill", label: "Go", prompt: "Continue")
        .frame(width: 80)
        .padding()
}

#Preview("Mode Selector") {
    ModeSelector()
        .padding()
}

#Preview("Compact Mode Selector") {
    CompactModeSelector()
        .padding()
}
