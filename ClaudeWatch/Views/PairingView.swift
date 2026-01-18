import SwiftUI
import WatchKit

// MARK: - Pairing View
struct PairingView: View {
    @ObservedObject var service: WatchService
    @State private var showCodeEntry = false

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            if showCodeEntry {
                PairingCodeEntryView(service: service, onBack: { showCodeEntry = false })
            } else {
                UnpairedMainView(
                    onPairNow: { showCodeEntry = true },
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

// MARK: - Unpaired Main View
struct UnpairedMainView: View {
    let onPairNow: () -> Void
    let onLocalMode: () -> Void
    let onDemoMode: () -> Void

    var body: some View {
        VStack(spacing: Claude.Spacing.md) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Claude.textTertiary)
                    .frame(width: 6, height: 6)
                Text("Not Connected")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.textSecondary)
                Spacer()
            }

            // Empty state card - compact
            VStack(spacing: Claude.Spacing.sm) {
                Image(systemName: "link")
                    .font(.system(size: 28))
                    .foregroundStyle(Claude.orange)

                Text("Pair with Claude")
                    .font(.claudeHeadline)
                    .foregroundStyle(Claude.textPrimary)

                Text("Enter code from terminal")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.textSecondary)
            }
            .padding(Claude.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.medium)
                    .fill(Claude.surface1)
            )

            // Action buttons - compact
            VStack(spacing: Claude.Spacing.xs) {
                Button(action: {
                    WKInterfaceDevice.current().play(.click)
                    onPairNow()
                }) {
                    Text("Pair Now")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                HStack(spacing: Claude.Spacing.sm) {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onLocalMode()
                    }) {
                        Text("Local")
                            .font(.claudeFootnote)
                            .foregroundColor(Claude.orange)
                    }
                    .buttonStyle(.plain)

                    Text("•").foregroundStyle(Claude.textTertiary)

                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onDemoMode()
                    }) {
                        Text("Demo")
                            .font(.claudeFootnote)
                            .foregroundColor(Claude.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Claude.Spacing.md)
    }
}

// MARK: - Pairing Code Entry View
struct PairingCodeEntryView: View {
    @ObservedObject var service: WatchService
    let onBack: () -> Void

    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @FocusState private var isCodeFocused: Bool

    private var isValidCode: Bool {
        // Numeric format: exactly 6 digits
        if code.count == 6 && code.allSatisfy({ $0.isNumber }) {
            return true
        }
        // Alphanumeric format: ABC-123 (7 chars with hyphen)
        if code.count == 7 && code.contains("-") {
            let parts = code.split(separator: "-")
            return parts.count == 2 && parts[0].count == 3 && parts[1].count == 3
        }
        return false
    }

    var body: some View {
        if showSuccess {
            ConnectedSuccessView()
        } else {
            VStack(spacing: Claude.Spacing.sm) {
                // Header with back button
                HStack {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        onBack()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.orange)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                // Title
                Text("Enter Code")
                    .font(.claudeHeadline)
                    .foregroundStyle(Claude.textPrimary)

                // Code input
                TextField("123456", text: $code)
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .textCase(.uppercase)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .focused($isCodeFocused)
                    .onChange(of: code) { _, newValue in
                        formatCode(newValue)
                    }
                    .padding(Claude.Spacing.sm)
                    .background(Claude.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.small))

                // Error message with retry button
                if let error = errorMessage {
                    VStack(spacing: Claude.Spacing.xs) {
                        Text(error)
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.danger)
                            .multilineTextAlignment(.center)

                        Button(action: {
                            WKInterfaceDevice.current().play(.click)
                            resetForRetry()
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
                }

                Spacer()

                // Connect button
                Button(action: submitCode) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Connect")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isValidCode ? Claude.orange : Claude.surface2)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isValidCode || isSubmitting)
            }
            .padding(Claude.Spacing.md)
        }
    }

    private func formatCode(_ newValue: String) {
        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let digitsOnly = filtered.filter { $0.isNumber }
        let hasLetters = filtered.contains(where: { $0.isLetter })

        if !hasLetters && digitsOnly.count <= 6 {
            code = String(digitsOnly.prefix(6))
        } else {
            if filtered.count == 3 && !filtered.contains("-") && hasLetters {
                code = filtered + "-"
            } else if filtered.count <= 7 {
                code = filtered
            } else {
                code = String(filtered.prefix(7))
            }
        }

        errorMessage = nil

        if isValidCode {
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func resetForRetry() {
        code = ""
        errorMessage = nil
        isCodeFocused = true
    }

    private func submitCode() {
        guard isValidCode else {
            errorMessage = "Invalid code format"
            WKInterfaceDevice.current().play(.failure)
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await service.completePairing(code: code)
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                    WKInterfaceDevice.current().play(.success)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
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

#Preview("Code Entry") {
    PairingCodeEntryView(service: WatchService(), onBack: {})
}

#Preview("Connected Success") {
    ConnectedSuccessView()
}
