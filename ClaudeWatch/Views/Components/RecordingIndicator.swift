import SwiftUI
import WatchKit

// MARK: - Recording Indicator Component
/// Visual indicator for active microphone recording.
/// Shows a pulsing red dot with optional animation for privacy compliance.
struct RecordingIndicator: View {
    /// Whether recording is currently active
    let isRecording: Bool

    // Accessibility: Reduce Motion support
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Outer pulsing ring (when recording, respects Reduce Motion)
            if isRecording && !reduceMotion {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }

            // Inner solid dot
            Circle()
                .fill(isRecording ? Color.red : Color.gray.opacity(0.5))
                .frame(width: 12, height: 12)

            // Microphone icon overlay
            if isRecording {
                Image(systemName: "mic.fill")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
                // Haptic feedback on recording start
                WKInterfaceDevice.current().play(.start)
            } else {
                stopPulseAnimation()
                // Haptic feedback on recording stop
                WKInterfaceDevice.current().play(.stop)
            }
            // VoiceOver announcement for recording state change
            let announcement = newValue ? "Recording started" : "Recording stopped"
            AccessibilityNotification.Announcement(announcement).post()
        }
        .accessibilityLabel(isRecording ? "Recording in progress" : "Not recording")
        .accessibilityAddTraits(isRecording ? .updatesFrequently : [])
    }

    private func startPulseAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseScale = 1.5
            pulseOpacity = 0.3
        }
    }

    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            pulseScale = 1.0
            pulseOpacity = 1.0
        }
    }
}

// MARK: - Recording State Enum
/// Represents the current state of voice recording
enum RecordingState: Equatable {
    case idle
    case recording
    case processing

    var isActive: Bool {
        self == .recording
    }
}

// MARK: - Recording Banner
/// Full-width banner showing recording status with indicator
struct RecordingBanner: View {
    let recordingState: RecordingState

    var body: some View {
        if recordingState == .recording {
            HStack(spacing: 8) {
                RecordingIndicator(isRecording: true)

                Text("Recording...")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red.opacity(0.15))
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Voice recording in progress")
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RecordingIndicator(isRecording: true)
        RecordingIndicator(isRecording: false)
        RecordingBanner(recordingState: .recording)
    }
    .padding()
    .background(Color.black)
}
