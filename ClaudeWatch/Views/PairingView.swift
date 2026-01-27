import SwiftUI
import WatchKit

// MARK: - Pairing View
struct PairingView: View {
    @ObservedObject var service: WatchService
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
                        service.objectWillChange.send()
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
    @ObservedObject private var service = WatchService.shared
    let onPairNow: () -> Void
    let onLocalMode: () -> Void
    let onDemoMode: () -> Void

    // Ensure "Preparing..." is shown for at least 1 second so user sees feedback
    @State private var minimumDelayPassed = false

    var body: some View {
        VStack(spacing: Claude.Spacing.md) {
            // V3: Status indicator - "Unpaired" with gray dot
            HStack(spacing: 6) {
                Circle()
                    .fill(Claude.idle)
                    .frame(width: 8, height: 8)
                Text("Unpaired")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.textSecondary)
                Spacer()
            }

            Spacer()

            // V3: Claude icon with ambient glow
            ZStack {
                // Ambient glow behind icon
                AmbientGlow.idle()
                    .offset(y: 10)

                // Claude icon 48×48
                ClaudeFaceLogo(size: 48)
            }

            Spacer()

            // V3: Single primary button only
            VStack(spacing: Claude.Spacing.sm) {
                if service.isAPNsTokenReady && minimumDelayPassed {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onPairNow()
                    }) {
                        Text("Pair with Code")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Claude.orange, Claude.orangeDark],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Claude.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Claude.surface1)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(Claude.Spacing.md)
        // V3: Long press for dev options (Local/Demo)
        .onLongPressGesture {
            WKInterfaceDevice.current().play(.click)
            // Show dev options sheet
            onDemoMode()
        }
        .onAppear {
            // Start minimum delay timer (1 second) so user sees "Preparing..." feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    minimumDelayPassed = true
                }
            }
        }
    }
}

// MARK: - Pairing Code Display View (NEW FLOW)
struct PairingCodeDisplayView: View {
    @ObservedObject var service: WatchService
    let onBack: () -> Void

    @State private var code: String?
    @State private var watchId: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var pollingTask: Task<Void, Never>?
    @State private var secondsRemaining: Int = 300  // 5 minutes
    @State private var countdownTimer: Timer?

    var body: some View {
        if showSuccess {
            ConnectedSuccessView()
        } else {
            VStack(spacing: Claude.Spacing.sm) {
                // V3: Header with back arrow + "Pairing" title
                HStack(spacing: 8) {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        pollingTask?.cancel()
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
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

                        Button(action: {
                            WKInterfaceDevice.current().play(.click)
                            initiatePairing()
                        }) {
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
                        .font(.system(size: 11))
                        .foregroundStyle(Claude.textTertiary)
                }
            }
            .padding(Claude.Spacing.md)
            .onAppear {
                initiatePairing()
            }
            .onDisappear {
                pollingTask?.cancel()
                countdownTimer?.invalidate()
            }
        }
    }

    /// Creates code display with Anthropic orange per design spec
    @ViewBuilder
    private func codeDisplayView(for code: String) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(code.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Claude.anthropicOrange)
            }
        }
    }

    private func initiatePairing() {
        isLoading = true
        errorMessage = nil
        code = nil
        watchId = nil
        secondsRemaining = 300  // Reset countdown
        countdownTimer?.invalidate()

        Task {
            do {
                let result = try await service.initiatePairing()
                await MainActor.run {
                    self.code = result.code
                    self.watchId = result.watchId
                    self.isLoading = false
                    WKInterfaceDevice.current().play(.click)
                    startPolling(watchId: result.watchId)
                    startCountdownTimer()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func startPolling(watchId: String) {
        pollingTask?.cancel()

        pollingTask = Task {
            // Poll every 2 seconds for up to 5 minutes
            let maxAttempts = 150 // 5 min / 2 sec
            var attempt = 0

            while !Task.isCancelled && attempt < maxAttempts {
                do {
                    let status = try await service.checkPairingStatus(watchId: watchId)

                    if status.paired, let pairingId = status.pairingId {
                        await MainActor.run {
                            service.finishPairing(pairingId: pairingId)
                            showSuccess = true
                            WKInterfaceDevice.current().play(.success)
                        }
                        return
                    }
                } catch {
                    // Session expired or error
                    await MainActor.run {
                        errorMessage = "Code expired. Tap to try again."
                        WKInterfaceDevice.current().play(.failure)
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                attempt += 1
            }

            // Timeout
            if !Task.isCancelled {
                await MainActor.run {
                    errorMessage = "Timed out waiting for CLI."
                    WKInterfaceDevice.current().play(.failure)
                }
            }
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
                    .font(.system(size: 24, weight: .bold))
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
                    .font(.system(size: 12))
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
