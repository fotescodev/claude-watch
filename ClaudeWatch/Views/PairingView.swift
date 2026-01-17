import SwiftUI

/// View for pairing the watch with Claude Code via a pairing code
/// Supports both alphanumeric (ABC-123) and numeric (123456) formats
struct PairingView: View {
    @ObservedObject var service: WatchService
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    /// Validates if the code is in numeric format (6 digits, preserves leading zeros)
    private var isNumericCode: Bool {
        code.count == 6 && code.allSatisfy { $0.isNumber }
    }

    /// Validates if the code is in alphanumeric format (ABC-123)
    private var isAlphanumericCode: Bool {
        code.count == 7 && code.contains("-")
    }

    /// Returns true if the code is valid (either format)
    private func validateCode(_ input: String) -> Bool {
        // Numeric format: exactly 6 digits
        if input.count == 6 && input.allSatisfy({ $0.isNumber }) {
            return true
        }
        // Alphanumeric format: ABC-123 (7 chars with hyphen)
        if input.count == 7 && input.contains("-") {
            let parts = input.split(separator: "-")
            return parts.count == 2 && parts[0].count == 3 && parts[1].count == 3
        }
        return false
    }

    /// Check if code is valid for submission
    private var isValidCode: Bool {
        validateCode(code)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("Pair with Claude")
                    .font(.headline)

                Text("Enter the code shown in your terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Code input with support for both formats
                TextField("123456 or ABC-123", text: $code)
                    .font(.system(.title3, design: .monospaced))
                    .textCase(.uppercase)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .focused($isCodeFocused)
                    .onChange(of: code) { _, newValue in
                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }

                        // Check if user is entering numeric-only code
                        let digitsOnly = filtered.filter { $0.isNumber }
                        let hasLetters = filtered.contains(where: { $0.isLetter })

                        if !hasLetters && digitsOnly.count <= 6 {
                            // Numeric format: just digits, max 6
                            code = String(digitsOnly.prefix(6))
                        } else {
                            // Alphanumeric format: auto-add hyphen after 3 chars
                            if filtered.count == 3 && !filtered.contains("-") && hasLetters {
                                code = filtered + "-"
                            } else if filtered.count <= 7 {
                                code = filtered
                            } else {
                                code = String(filtered.prefix(7))
                            }
                        }

                        // Clear error when typing
                        errorMessage = nil

                        // Provide haptic feedback on valid code
                        if validateCode(code) {
                            WKInterfaceDevice.current().play(.click)
                        }
                    }
                    .accessibilityLabel("Pairing code input")
                    .accessibilityHint("Enter the 6-digit numeric code or 7-character alphanumeric code from your terminal")

                // Format hint
                if !code.isEmpty && !isValidCode {
                    Text(code.allSatisfy({ $0.isNumber }) ? "Enter 6 digits" : "Format: ABC-123")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                // Submit button
                Button(action: submitCode) {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidCode || isSubmitting)
                .accessibilityLabel(isSubmitting ? "Connecting to Claude Code" : "Connect to Claude Code")
                .accessibilityHint("Submits the pairing code to connect")

                // Local mode button (for testing with local server)
                Button("Use Local Mode") {
                    service.useCloudMode = false
                    service.objectWillChange.send()  // Trigger view refresh
                    service.connect()
                }
                .font(.caption)
                .foregroundStyle(.blue)
                .accessibilityLabel("Use local mode")
                .accessibilityHint("Connect directly to local WebSocket server")

                // Skip button for demo mode
                Button("Use Demo Mode") {
                    service.isDemoMode = true
                    service.loadDemoData()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Use demo mode")
                .accessibilityHint("Skip pairing and use sample data")
            }
            .padding()
        }
        // Removed auto-focus - let user tap to enter code
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
                    WKInterfaceDevice.current().play(.success)
                    // View will auto-dismiss since service.isPaired becomes true
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

#Preview {
    PairingView(service: WatchService())
}
