import SwiftUI
import WatchKit

// MARK: - Command Grid
struct CommandGrid: View {
    @ObservedObject private var service = WatchService.shared
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
                        .foregroundColor(Claude.info)

                    Text("Voice Command")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Claude.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Claude.textTertiary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open voice command input")
        }
    }
}

// MARK: - Command Button
struct CommandButton: View {
    @ObservedObject private var service = WatchService.shared
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

    var body: some View {
        Button {
            service.sendPrompt(prompt)
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(Claude.orange)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Claude.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
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
    }
}

// MARK: - Mode Selector
struct ModeSelector: View {
    @ObservedObject private var service = WatchService.shared

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // Dynamic Type support
    @ScaledMetric(relativeTo: .footnote) private var modeIconContainerSize: CGFloat = 28
    @ScaledMetric(relativeTo: .footnote) private var modeIconSize: CGFloat = 12

    // Spring animation state
    @State private var isPressed = false

    var body: some View {
        Button {
            service.cycleMode()
            WKInterfaceDevice.current().play(.click)
            // VoiceOver announcement for mode change
            announceModChange()
        } label: {
            HStack(spacing: 10) {
                // Mode icon
                ZStack {
                    Circle()
                        .fill(modeColor.opacity(0.2))
                        .frame(width: modeIconContainerSize, height: modeIconContainerSize)

                    Image(systemName: service.state.mode.icon)
                        .font(.system(size: modeIconSize, weight: .bold))
                        .foregroundColor(modeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(service.state.mode.displayName)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(modeColor)

                    Text(service.state.mode.description)
                        .font(.caption2)
                        .foregroundColor(Claude.textSecondary)
                }

                Spacer()

                // Next mode hint
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Claude.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(modeBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(modeColor.opacity(0.3), lineWidth: 1)
                    )
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
