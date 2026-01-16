import SwiftUI

/// View for pairing the watch with Claude Code via a 6-character code
struct PairingView: View {
    @ObservedObject var service: WatchService
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isCodeFocused: Bool

    private let codeLength = 7 // ABC-123 format

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

                // Code input
                TextField("ABC-123", text: $code)
                    .font(.system(.title3, design: .monospaced))
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .focused($isCodeFocused)
                    .onChange(of: code) { _, newValue in
                        // Auto-format: add hyphen after 3 chars
                        let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        if filtered.count == 3 && !filtered.contains("-") {
                            code = filtered + "-"
                        } else if filtered.count <= codeLength {
                            code = filtered
                        } else {
                            code = String(filtered.prefix(codeLength))
                        }

                        // Clear error when typing
                        errorMessage = nil
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
                .disabled(code.count != codeLength || isSubmitting)

                // Skip button for demo mode
                Button("Use Demo Mode") {
                    service.isDemoMode = true
                    service.loadDemoData()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .onAppear {
            isCodeFocused = true
        }
    }

    private func submitCode() {
        guard code.count == codeLength else { return }

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
