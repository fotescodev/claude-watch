import SwiftUI
import WatchKit

// MARK: - Design System Reference
private enum Claude {
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let info = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let background = Color.black
    static let surface1 = Color(red: 0.110, green: 0.110, blue: 0.118)
    static let surface2 = Color(red: 0.173, green: 0.173, blue: 0.180)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.6)
    static let textTertiary = Color(white: 0.4)
}

// MARK: - Consent View
struct ConsentView: View {
    @AppStorage("hasAcceptedConsent") private var hasAcceptedConsent = false
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, description: String)] = [
        ("brain.head.profile", "AI Processing", "Your commands and voice input are sent to Claude API for processing."),
        ("waveform", "Voice Handling", "Voice recordings are transcribed and processed to understand your requests."),
        ("hand.raised.fill", "Your Privacy", "Your data is never sold to third parties. We only use it to provide the service.")
    ]

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            VStack(spacing: 12) {
                // Header
                Text("Welcome to Claude Watch")
                    .font(.headline)
                    .foregroundColor(Claude.textPrimary)
                    .multilineTextAlignment(.center)

                // Content pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        consentPage(
                            icon: pages[index].icon,
                            title: pages[index].title,
                            description: pages[index].description
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 120)

                // Accept button (only on last page or always visible)
                Button {
                    acceptConsent()
                } label: {
                    Text(currentPage == pages.count - 1 ? "I Understand" : "Accept & Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Claude.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept privacy terms and continue")

                // Learn more link
                Text("You can review this in Settings")
                    .font(.caption2)
                    .foregroundColor(Claude.textTertiary)
            }
            .padding()
        }
    }

    private func consentPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Claude.surface1)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Claude.orange)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Claude.textPrimary)

            Text(description)
                .font(.system(size: 12))
                .foregroundColor(Claude.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, 8)
    }

    private func acceptConsent() {
        WKInterfaceDevice.current().play(.success)
        hasAcceptedConsent = true
    }
}

// MARK: - Privacy Info View (for Settings)
struct PrivacyInfoView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasAcceptedConsent") private var hasAcceptedConsent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Privacy")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(Claude.textPrimary)

                // Privacy points
                VStack(spacing: 12) {
                    privacyRow(
                        icon: "brain.head.profile",
                        title: "AI Processing",
                        description: "Commands sent to Claude API"
                    )

                    privacyRow(
                        icon: "waveform",
                        title: "Voice Input",
                        description: "Transcribed for processing"
                    )

                    privacyRow(
                        icon: "shield.checkered",
                        title: "Data Protection",
                        description: "Never sold to third parties"
                    )
                }

                // Consent status
                HStack(spacing: 8) {
                    Image(systemName: hasAcceptedConsent ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAcceptedConsent ? Claude.success : Claude.orange)
                    Text(hasAcceptedConsent ? "Consent given" : "Consent pending")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(hasAcceptedConsent ? Claude.success : Claude.orange)
                }
                .padding(.top, 8)

                // Withdraw consent button
                if hasAcceptedConsent {
                    Button {
                        hasAcceptedConsent = false
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("Withdraw Consent")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Claude.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Withdraw privacy consent")
                }

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.info)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close privacy settings")
            }
            .padding()
        }
        .background(Claude.background)
    }

    private func privacyRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Claude.surface1)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Claude.orange)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Claude.textPrimary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(Claude.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Claude.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ConsentView()
}
