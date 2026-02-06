import SwiftUI
import WatchKit

// MARK: - Pairing View
struct PairingView: View {
    var service: WatchService
    @State private var showCodeDisplay = false

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            if showCodeDisplay {
                PairingCodeDisplayView(service: service, onBack: { showCodeDisplay = false })
            } else {
                UnpairedMainView(
                    onPairNow: { showCodeDisplay = true },
                    onLocalMode: {
                        service.useCloudMode = false
                        service.connect()
                    },
                    onDemoMode: {
                        service.isDemoMode = true
                        service.loadDemoData()
                    }
                )
            }
        }
    }
}

// MARK: - Unpaired Main View (V3)
struct UnpairedMainView: View {
    var service = WatchService.shared
    let onPairNow: () -> Void
    let onLocalMode: () -> Void
    let onDemoMode: () -> Void

    // Ensure "Preparing..." is shown for at least 1 second so user sees feedback
    @State private var minimumDelayPassed = false

    var body: some View {
        VStack(spacing: 8) {
            // Note: Status header handled by MainView toolbar

            Spacer(minLength: 8)

            // V3: Claude icon with brand ambient glow
            ZStack {
                // Brand (orange) ambient glow behind icon - smaller for fit
                AmbientGlow.brand()
                    .scaleEffect(0.7)
                    .offset(y: 8)

                // Claude icon 48×48
                ClaudeFaceLogo(size: 48)
            }

            // V3 A1: "Ready to pair" text below icon
            Text("Ready to pair")
                .font(.claudeBodyMedium)
                .foregroundStyle(Claude.textSecondary)

            Spacer(minLength: 8)

            // V3: Single primary button only
            if service.isAPNsTokenReady && minimumDelayPassed {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    onPairNow()
                } label: {
                    Text("Pair with Code")
                        .font(.claudeBodyMedium)
                        .foregroundStyle(.black)  // V3: Black text on orange button
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.anthropicOrange)  // V3: Solid orange, no gradient
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                // Waiting for APNs token registration
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Claude.orange)
                    Text("Preparing...")
                        .font(.claudeBodyMedium)
                        .foregroundStyle(Claude.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Claude.surface1)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        // V3: Long press for quick actions menu
        .onLongPressGesture {
            WKInterfaceDevice.current().play(.click)
            // Show dev options sheet
            onDemoMode()
        }
        .onAppear {
            // Start minimum delay timer (1 second) so user sees "Preparing..." feedback
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeInOut(duration: 0.3)) {
                    minimumDelayPassed = true
                }
            }
        }
    }
}

// MARK: - Pairing Code Display View (NEW FLOW)
struct PairingCodeDisplayView: View {
    var service: WatchService
    let onBack: () -> Void

    @State private var code: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var secondsRemaining: Int = 300  // 5 minutes
    @State private var pairingTrigger: Bool = false

    var body: some View {
        if showSuccess {
            ConnectedSuccessView()
        } else {
            VStack(spacing: Claude.Spacing.sm) {
                // V3: Header with back arrow + "Pairing" title
                HStack(spacing: 8) {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.claudeBodyMedium)
                            .foregroundStyle(Claude.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Text("Pairing")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)

                    Spacer()
                }

                if isLoading {
                    // Loading state
                    Spacer()
                    ProgressView()
                        .tint(Claude.orange)
                    Text("Getting code...")
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.textSecondary)
                    Spacer()
                } else if let error = errorMessage {
                    // Error state
                    Spacer()
                    VStack(spacing: Claude.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(Claude.danger)

                        Text(error)
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.danger)
                            .multilineTextAlignment(.center)

                        Button {
                            WKInterfaceDevice.current().play(.click)
                            pairingTrigger.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                } else if let code = code {
                    // V3: Code display with Claude icon
                    Spacer()

                    // Claude icon 32×32
                    ClaudeFaceLogo(size: 32)

                    // Instruction text
                    Text("Enter code into terminal")
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.textSecondary)
                        .padding(.top, Claude.Spacing.xs)

                    // Large code display - Anthropic orange per design spec
                    codeDisplayView(for: code)
                        .padding(.vertical, Claude.Spacing.md)

                    Spacer()

                    // Code expires countdown
                    Text("Expires in \(secondsRemaining / 60):\(String(format: "%02d", secondsRemaining % 60))")
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.textTertiary)
                }
            }
            .padding(Claude.Spacing.md)
            .task(id: pairingTrigger) {
                await initiatePairing()
            }
        }
    }

    /// Creates code display with WHITE text per design spec
    @ViewBuilder
    private func codeDisplayView(for code: String) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)  // V3: White text per design
            }
        }
    }

    private func initiatePairing() async {
        isLoading = true
        errorMessage = nil
        code = nil
        secondsRemaining = 300  // Reset countdown

        do {
            let result = try await service.initiatePairing()
            self.code = result.code
            self.isLoading = false
            WKInterfaceDevice.current().play(.click)

            // Run countdown and polling concurrently as child tasks;
            // both are automatically cancelled when the .task is cancelled
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await runCountdown()
                }
                group.addTask {
                    await pollForPairing(watchId: result.watchId)
                }
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                isLoading = false
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func runCountdown() async {
        while !Task.isCancelled && secondsRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled && secondsRemaining > 0 {
                secondsRemaining -= 1
            }
        }
    }

    private func pollForPairing(watchId: String) async {
        // Poll every 2 seconds for up to 5 minutes
        let maxAttempts = 150 // 5 min / 2 sec
        var attempt = 0

        while !Task.isCancelled && attempt < maxAttempts {
            do {
                let status = try await service.checkPairingStatus(watchId: watchId)

                if status.paired, let pairingId = status.pairingId {
                    service.finishPairing(pairingId: pairingId)
                    showSuccess = true
                    WKInterfaceDevice.current().play(.success)
                    return
                }
            } catch {
                // Session expired or error
                if !Task.isCancelled {
                    errorMessage = "Code expired. Tap to try again."
                    WKInterfaceDevice.current().play(.failure)
                }
                return
            }

            try? await Task.sleep(for: .seconds(2))
            attempt += 1
        }

        // Timeout
        if !Task.isCancelled {
            errorMessage = "Timed out waiting for CLI."
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

// MARK: - Connected Success View
struct ConnectedSuccessView: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.md) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Claude.success.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "checkmark")
                    .font(.claudeHero)
                    .foregroundStyle(Claude.success)
            }

            // Title
            Text("Connected!")
                .font(.claudeHeadline)
                .foregroundStyle(Claude.textPrimary)

            // Description
            Text("Paired with Claude Code")
                .font(.claudeFootnote)
                .foregroundStyle(Claude.textSecondary)

            Spacer()

            // Pro tip
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.warning)
                Text("Raise wrist to approve")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.textSecondary)
            }
            .padding(Claude.Spacing.sm)
            .background(Claude.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.small))
        }
        .padding(Claude.Spacing.md)
    }
}

#Preview("Pairing View") {
    PairingView(service: WatchService())
}

#Preview("Unpaired Main") {
    UnpairedMainView(onPairNow: {}, onLocalMode: {}, onDemoMode: {})
}

#Preview("Code Display") {
    PairingCodeDisplayView(service: WatchService(), onBack: {})
}

#Preview("Connected Success") {
    ConnectedSuccessView()
}
