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
        VStack(spacing: Claude.Spacing.sm) {
            // Header with recording indicator
            HStack(spacing: 6) {
                Text("Voice")
                    .font(.claudeHeadline)
                    .foregroundColor(Claude.textPrimary)

                if isRecording {
                    RecordingIndicator(isRecording: true)
                }

                Spacer()

                // Status indicator
                if service.isSendingPrompt {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Claude.info))
                        .scaleEffect(0.7)
                } else if showSentConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Claude.success)
                }
            }

            // Text input with dictation support (watchOS 10+ native)
            TextField("Tap to speak...", text: $transcribedText)
                .font(.claudeBody)
                .multilineTextAlignment(.center)
                .padding(Claude.Spacing.sm)
                .background(Claude.surface1, in: RoundedRectangle(cornerRadius: Claude.Radius.small))
                .onChange(of: transcribedText) { oldValue, newValue in
                    if newValue.count > oldValue.count && !isRecording {
                        isRecording = true
                        WKInterfaceDevice.current().play(.start)
                    }
                }
                .onSubmit {
                    if isRecording {
                        isRecording = false
                        WKInterfaceDevice.current().play(.stop)
                    }
                }

            // Quick suggestion chips - 2x2 compact grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        transcribedText = suggestion
                    } label: {
                        Text(suggestion)
                            .font(.claudeCaption)
                            .foregroundColor(Claude.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(Claude.surface1, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quick suggestion: \(suggestion)")
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: Claude.Spacing.sm) {
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.claudeFootnote)
                        .foregroundColor(Claude.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
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
                            .font(.claudeFootnote)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Claude.success)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send voice command")
                }
            }
        }
        .padding(Claude.Spacing.md)
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
    @State private var selectedPage = 0

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Connection Status
            connectionPage
                .tag(0)

            // Page 2: Actions
            actionsPage
                .tag(1)

            // Page 3: About (only if needed)
            aboutPage
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
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

    // MARK: - Page 1: Connection Status
    private var connectionPage: some View {
        VStack(spacing: Claude.Spacing.md) {
            // Header
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(service.connectionStatus.displayName)
                    .font(.claudeFootnote)
                    .foregroundColor(statusColor)
                Spacer()
            }

            // Status card
            VStack(spacing: Claude.Spacing.sm) {
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)

                if service.isDemoMode {
                    Text("Demo Mode")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.warning)
                } else if service.isPaired {
                    Text("Paired")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.success)
                    // Show pairingId for debugging
                    Text(String(service.pairingId.prefix(8)) + "...")
                        .font(.claudeCaption)
                        .foregroundStyle(Claude.textTertiary)
                } else {
                    Text("Not Paired")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)
                }
            }
            .padding(Claude.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.medium)
                    .fill(Claude.surface1)
            )

            Spacer()

            // Page indicator hint
            Text("Swipe for actions")
                .font(.claudeCaption)
                .foregroundStyle(Claude.textTertiary)
        }
        .padding(Claude.Spacing.md)
    }

    // MARK: - Page 2: Actions
    private var actionsPage: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Demo Mode Actions
            if service.isDemoMode {
                Button {
                    service.loadDemoData()
                    WKInterfaceDevice.current().play(.click)
                    dismiss()
                } label: {
                    SettingsActionRow(
                        icon: "arrow.clockwise",
                        title: "Reload Demo",
                        color: Claude.info
                    )
                }
                .buttonStyle(.plain)

                Button {
                    service.isDemoMode = false
                    service.state = WatchState()
                    service.connectionStatus = .disconnected
                    service.pairingId = ""
                    WKInterfaceDevice.current().play(.click)
                    dismiss()
                } label: {
                    SettingsActionRow(
                        icon: "xmark.circle",
                        title: "Exit Demo",
                        color: Claude.orange
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Pairing/Unpairing
                if service.isPaired {
                    Button {
                        service.unpair()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        SettingsActionRow(
                            icon: "link.badge.plus",
                            title: "Unpair",
                            color: Claude.danger
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Unpair from Claude Code")
                } else {
                    Button {
                        showingPairing = true
                    } label: {
                        SettingsActionRow(
                            icon: "link",
                            title: "Pair Now",
                            color: Claude.orange
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pair with Claude Code")
                }

                // Demo mode entry
                Button {
                    service.loadDemoData()
                    WKInterfaceDevice.current().play(.click)
                    dismiss()
                } label: {
                    SettingsActionRow(
                        icon: "play.circle",
                        title: "Try Demo",
                        color: Claude.warning
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Done button
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.claudeFootnote)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Claude.info)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done, close settings")
        }
        .padding(Claude.Spacing.md)
    }

    // MARK: - Page 3: About
    private var aboutPage: some View {
        VStack(spacing: Claude.Spacing.sm) {
            HStack {
                Text("About")
                    .font(.claudeHeadline)
                    .foregroundStyle(Claude.textPrimary)
                Spacer()
            }

            // Version
            HStack {
                Text("Version")
                    .font(.claudeFootnote)
                    .foregroundColor(Claude.textSecondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.claudeFootnote)
                    .foregroundColor(Claude.textPrimary)
            }
            .padding(Claude.Spacing.sm)
            .background(Claude.surface1, in: RoundedRectangle(cornerRadius: Claude.Radius.small))

            // Privacy
            Button {
                showingPrivacy = true
            } label: {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption)
                        .foregroundColor(Claude.orange)
                    Text("Privacy")
                        .font(.claudeFootnote)
                        .foregroundColor(Claude.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Claude.textTertiary)
                }
                .padding(Claude.Spacing.sm)
                .background(Claude.surface1, in: RoundedRectangle(cornerRadius: Claude.Radius.small))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Review privacy settings")

            Spacer()
        }
        .padding(Claude.Spacing.md)
    }

    private var statusColor: Color {
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }

    private var statusIcon: String {
        if service.isDemoMode {
            return "play.circle.fill"
        }
        switch service.connectionStatus {
        case .connected: return "checkmark.circle.fill"
        case .connecting, .reconnecting: return "arrow.triangle.2.circlepath"
        case .disconnected: return "xmark.circle"
        }
    }
}

// MARK: - Settings Action Row
private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.claudeBody)
                .foregroundStyle(Claude.textPrimary)

            Spacer()
        }
        .padding(Claude.Spacing.sm)
        .background(Claude.surface1, in: RoundedRectangle(cornerRadius: Claude.Radius.small))
    }
}

// MARK: - Previews
#Preview("Voice Input") {
    VoiceInputSheet()
}

#Preview("Settings") {
    SettingsSheet()
}
