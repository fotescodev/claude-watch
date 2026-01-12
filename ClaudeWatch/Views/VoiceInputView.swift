import SwiftUI
import WatchKit

struct VoiceInputView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss
    @State private var transcribedText = ""
    @State private var isListening = false
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: 12) {
            // Microphone Animation
            ZStack {
                // Pulse Animation
                if isListening {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 60 + CGFloat(i * 20), height: 60 + CGFloat(i * 20))
                            .scaleEffect(isListening ? 1.2 : 0.8)
                            .opacity(isListening ? 0 : 1)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                value: isListening
                            )
                    }
                }

                // Mic Button
                Button {
                    toggleListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isListening ? Color.red : Color.blue)
                            .frame(width: 50, height: 50)

                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(height: 100)

            // Status Text
            Text(isListening ? "Listening..." : "Tap to speak")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isListening ? .blue : .gray)

            // Transcribed Text Preview
            if !transcribedText.isEmpty {
                Text(transcribedText)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .lineLimit(3)
            }

            // Send Button
            if !transcribedText.isEmpty {
                Button {
                    sendVoicePrompt()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("SEND")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .onAppear {
            // Auto-start listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startDictation()
            }
        }
    }

    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startDictation()
        }
    }

    private func startDictation() {
        isListening = true
        sessionManager.playHaptic(.start)

        // Use WatchKit's text input controller for dictation
        WKExtension.shared().visibleInterfaceController?.presentTextInputController(
            withSuggestions: sessionManager.quickPrompts.map { $0.text },
            allowedInputMode: .allowEmoji
        ) { results in
            isListening = false

            if let result = results?.first as? String {
                transcribedText = result
                sessionManager.playHaptic(.success)
            }
        }
    }

    private func stopListening() {
        isListening = false
        sessionManager.playHaptic(.stop)
    }

    private func sendVoicePrompt() {
        sessionManager.sendVoicePrompt(transcribedText)
        sessionManager.playHaptic(.success)
        dismiss()
    }
}

#Preview {
    VoiceInputView()
        .environmentObject(SessionManager())
}
