import SwiftUI
import WatchKit

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    var service = WatchService.shared
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
                    .foregroundStyle(Claude.textPrimary)

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
                        .foregroundStyle(Claude.success)
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
                            .foregroundStyle(Claude.textSecondary)
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
                        .foregroundStyle(Claude.danger)
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
                            try? await Task.sleep(for: .seconds(1))
                            dismiss()
                        }
                    } label: {
                        Text("Send")
                            .font(.claudeFootnote)
                            .foregroundStyle(.white)
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
/// Simplified single-scroll settings with easy access to demo/testing
struct SettingsSheet: View {
    var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingPairing = false
    @State private var showingPrivacy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // MARK: - Status Header (compact)
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(statusText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Version badge
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(.system(size: 10))
                        .foregroundStyle(Claude.textTertiary)
                }
                .padding(.horizontal, 4)

                // MARK: - Quick Actions
                if service.isDemoMode {
                    // Exit Demo button (prominent)
                    Button {
                        exitDemo()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                            Text("Exit Demo")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.danger)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    // Test Screens Grid
                    demoTestGrid
                } else {
                    // Try Demo (prominent)
                    Button {
                        service.loadDemoData()
                        WKInterfaceDevice.current().play(.click)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(.black)
                            Text("Try Demo")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Claude.warning)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    // Pair/Unpair
                    if service.isPaired {
                        Button {
                            Task {
                                await service.endSession()
                                WKInterfaceDevice.current().play(.success)
                                dismiss()
                            }
                        } label: {
                            SettingsActionRow(icon: "stop.circle.fill", title: "End Session", color: Claude.danger)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            showingPairing = true
                        } label: {
                            SettingsActionRow(icon: "link", title: "Pair Now", color: Claude.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: - Footer
                Divider()
                    .padding(.vertical, 4)

                Button {
                    showingPrivacy = true
                } label: {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Claude.textTertiary)
                        Text("Privacy")
                            .font(.system(size: 11))
                            .foregroundStyle(Claude.textSecondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .background(Claude.background)
        .sheet(isPresented: $showingPairing) {
            PairingView(service: service)
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyInfoView()
        }
    }

    // MARK: - Demo Test Grid (compact 2-column)
    private var demoTestGrid: some View {
        VStack(spacing: 6) {
            Text("TEST SCREENS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Claude.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Row 1: Working, Paused
            HStack(spacing: 6) {
                demoButton("B1", icon: "play.fill", color: Claude.info) {
                    service.loadDemoWorking()
                }
                demoButton("B2", icon: "pause.fill", color: Claude.idle) {
                    service.loadDemoPaused()
                }
            }

            // Row 2: Approvals T1, T2, T3
            HStack(spacing: 6) {
                demoButton("T1", icon: "hand.raised.fill", color: Claude.success) {
                    service.loadDemoApproval(tier: .low)
                }
                demoButton("T2", icon: "hand.raised.fill", color: Claude.warning) {
                    service.loadDemoApproval(tier: .medium)
                }
                demoButton("T3", icon: "hand.raised.fill", color: Claude.danger) {
                    service.loadDemoApproval(tier: .high)
                }
            }

            // Row 3: Queues
            HStack(spacing: 6) {
                demoButton("Q3", icon: "list.bullet", color: Claude.warning) {
                    service.loadDemoApprovalQueue()
                }
                demoButton("Q1", icon: "list.bullet", color: Claude.success) {
                    service.loadDemoQueueSingleTierSingle()
                }
                demoButton("QD", icon: "list.bullet", color: Claude.danger) {
                    service.loadDemoQueueDangerTier()
                }
            }

            // Row 4: Success, Question, Context
            HStack(spacing: 6) {
                demoButton("D1", icon: "checkmark", color: Claude.success) {
                    service.loadDemoSuccess()
                }
                demoButton("E1", icon: "questionmark", color: Claude.question) {
                    service.loadDemoQuestion()
                }
                demoButton("E2", icon: "exclamationmark.triangle.fill", color: Claude.context) {
                    service.loadDemoContextWarning()
                }
            }
        }
    }

    // MARK: - Compact Demo Button
    private func demoButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            WKInterfaceDevice.current().play(.click)
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Claude.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func exitDemo() {
        service.isDemoMode = false
        service.state = WatchState()
        service.sessionProgress = nil
        service.pendingQuestion = nil
        service.contextWarning = nil
        service.connectionStatus = .disconnected
        service.pairingId = ""
        WKInterfaceDevice.current().play(.click)
        dismiss()
    }

    private var statusColor: Color {
        if service.isDemoMode { return Claude.warning }
        switch service.connectionStatus {
        case .connected: return Claude.success
        case .connecting, .reconnecting: return Claude.warning
        case .disconnected: return Claude.danger
        }
    }

    private var statusText: String {
        if service.isDemoMode { return "Demo Mode" }
        if service.isPaired { return "Paired" }
        return "Not Paired"
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
