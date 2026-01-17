import SwiftUI
import WatchKit

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var transcribedText = ""
    @State private var showSentConfirmation = false
    @State private var isRecording = false

    // Quick suggestions for common commands
    private let suggestions = ["Continue", "Run tests", "Fix errors", "Commit"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Recording indicator banner
                if isRecording {
                    RecordingBanner(recordingState: .recording)
                }

                // Header with recording indicator
                HStack(spacing: 8) {
                    Text("Voice Command")
                        .font(.body.weight(.bold))
                        .foregroundColor(Claude.textPrimary)

                    if isRecording {
                        RecordingIndicator(isRecording: true)
                    }
                }

                // Text input with dictation support (watchOS 10+ native)
                TextField("Tap to speak...", text: $transcribedText)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: transcribedText) { oldValue, newValue in
                        // Detect dictation activity (text changing indicates recording)
                        if newValue.count > oldValue.count && !isRecording {
                            isRecording = true
                            WKInterfaceDevice.current().play(.start)
                        }
                    }
                    .onSubmit {
                        // Recording stopped when text is submitted
                        if isRecording {
                            isRecording = false
                            WKInterfaceDevice.current().play(.stop)
                        }
                    }

                // Quick suggestion chips
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            transcribedText = suggestion
                        } label: {
                            Text(suggestion)
                                .font(.caption2.weight(.medium))
                                .foregroundColor(Claude.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(.thinMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Quick suggestion: \(suggestion)")
                    }
                }

                // Sending/Sent status feedback
                if service.isSendingPrompt {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Claude.info))
                            .scaleEffect(0.7)
                        Text("Sending...")
                            .font(.caption)
                            .foregroundColor(Claude.textSecondary)
                    }
                } else if showSentConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(Claude.success)
                        Text("Sent")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Claude.success)
                    }
                }

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Claude.danger)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Claude.danger.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel voice command")

                    if !transcribedText.isEmpty && !showSentConfirmation {
                        Button {
                            service.sendPrompt(transcribedText)
                            showSentConfirmation = true
                            WKInterfaceDevice.current().play(.success)
                            Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                dismiss()
                            }
                        } label: {
                            Text("Send")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Claude.success)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send voice command")
                    }
                }
            }
            .padding()
        }
        .background(Claude.background)
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var showingPairing = false
    @State private var showingPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                    Text("Connection")
                        .font(.body.weight(.bold))
                }
                .foregroundColor(Claude.textPrimary)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(service.connectionStatus.displayName)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(statusColor)
                }
                .padding(.vertical, 4)

                // Demo Mode Section
                if service.isDemoMode {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(Claude.warning)
                            Text("Demo Mode Active")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Claude.warning)
                        }

                        Button {
                            service.isDemoMode = false
                            service.state = WatchState()
                            service.connectionStatus = .disconnected
                            service.pairingId = ""  // Reset pairing to show PairingView
                            WKInterfaceDevice.current().play(.click)
                            dismiss()
                        } label: {
                            Text("Exit Demo Mode")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Exit demo mode and disconnect")
                    }
                    .padding(.vertical, 8)
                }

                // Cloud Mode Section
                if service.useCloudMode && !service.isDemoMode {
                    VStack(spacing: 12) {
                        if service.isPaired {
                            // Show paired status
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Claude.success)
                                Text("Paired")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Claude.success)
                            }

                            // Unpair button
                            Button {
                                service.unpair()
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("Unpair")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Claude.danger)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Claude.danger.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Unpair from Claude Code")
                        } else {
                            // Pair button
                            Button {
                                showingPairing = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.caption.weight(.semibold))
                                    Text("Pair with Code")
                                        .font(.footnote.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Claude.orange)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Pair with Claude Code")
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Server URL input (WebSocket mode)
                if !service.useCloudMode {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Server URL")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Claude.textSecondary)

                        TextField("ws://...", text: $serverURL)
                            .font(.footnote)
                            .textContentType(.URL)
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Action buttons
                    HStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Claude.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.danger.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Cancel and close settings")

                        Button {
                            service.serverURLString = serverURL
                            service.connect()
                            WKInterfaceDevice.current().play(.success)
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Claude.success)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Save server URL and connect")
                    }
                }

                // About section
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption.weight(.semibold))
                        Text("About")
                            .font(.footnote.weight(.bold))
                    }
                    .foregroundColor(Claude.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Version
                    HStack {
                        Text("Version")
                            .font(.caption)
                            .foregroundColor(Claude.textSecondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Claude.textPrimary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                    // Privacy Consent (review in app)
                    Button {
                        showingPrivacy = true
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .font(.caption)
                                .foregroundColor(Claude.orange)
                            Text("Privacy & Consent")
                                .font(.caption)
                                .foregroundColor(Claude.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(Claude.textTertiary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Review privacy settings and consent")

                    // Privacy Policy
                    if let privacyURL = URL(string: "https://claude-watch.example.com/privacy") {
                        Link(destination: privacyURL) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(Claude.info)
                                Text("Privacy Policy")
                                    .font(.caption)
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Support
                    if let supportURL = URL(string: "https://claude-watch.example.com/support") {
                        Link(destination: supportURL) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption)
                                    .foregroundColor(Claude.info)
                                Text("Support")
                                    .font(.caption)
                                    .foregroundColor(Claude.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                                    .foregroundColor(Claude.textTertiary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.top, 8)

                // Done button for cloud mode
                if service.useCloudMode {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.info)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done, close settings")
                }
            }
            .padding()
        }
        .background(Claude.background)
        .onAppear {
            serverURL = service.serverURLString
        }
        .sheet(isPresented: $showingPairing) {
            PairingView(service: service)
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyInfoView()
        }
    }

    private var statusColor: Color {
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }
}

// MARK: - Previews
#Preview("Voice Input") {
    VoiceInputSheet()
}

#Preview("Settings") {
    SettingsSheet()
}
