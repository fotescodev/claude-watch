import SwiftUI
import WatchKit

// MARK: - Consent Flow (3 Pages)
struct ConsentView: View {
    @AppStorage("hasAcceptedConsent") private var hasAcceptedConsent = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Claude.background.ignoresSafeArea()

            TabView(selection: $currentPage) {
                ConsentPage1Privacy(onContinue: { currentPage = 1 })
                    .tag(0)
                ConsentPage2Data(onContinue: { currentPage = 2 })
                    .tag(1)
                ConsentPage3Accept(onAccept: acceptConsent)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
        }
    }

    private func acceptConsent() {
        WKInterfaceDevice.current().play(.success)
        hasAcceptedConsent = true
    }
}

// MARK: - Page 1: Privacy First
struct ConsentPage1Privacy: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Icon
            Image(systemName: "lock.fill")
                .font(.claudeIconButton)
                .foregroundStyle(Claude.orange)
                .accessibilityHidden(true)

            // Title
            Text("Secure Connection")
                .font(.headline)
                .foregroundStyle(.primary)

            // Content
            Text("Approve Claude Code actions directly from your wrist")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Continue button
            Button {
                WKInterfaceDevice.current().play(.click)
                onContinue()
            } label: {
                Text("Continue")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue")
        }
        .padding(Claude.Spacing.md)
    }
}

// MARK: - Page 2: Data Handling
struct ConsentPage2Data: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.claudeIconButton)
                .foregroundStyle(Claude.info)
                .accessibilityHidden(true)

            // Title
            Text("Your Data")
                .font(.headline)
                .foregroundStyle(.primary)

            // Concise description
            Text("Only action titles are sent.\nAll data is encrypted end-to-end.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Continue button
            Button {
                WKInterfaceDevice.current().play(.click)
                onContinue()
            } label: {
                Text("Continue")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue")
        }
        .padding(Claude.Spacing.md)
    }
}

// MARK: - Data Bullet Helper
struct DataBullet: View {
    let text: String

    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            Circle()
                .fill(Claude.success)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(text)
                .font(.claudeCaption)
                .foregroundStyle(Claude.textSecondary)
        }
    }
}

// MARK: - Page 3: Accept Terms
struct ConsentPage3Accept: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.claudeIconButton)
                .foregroundStyle(Claude.success)
                .accessibilityHidden(true)

            // Title
            Text("Ready")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            // Accept button
            Button {
                onAccept()
            } label: {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Claude.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Get started")
        }
        .padding(Claude.Spacing.md)
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
                        .font(.claudeBodyMedium)
                    Text("Privacy")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Claude.textPrimary)

                // Privacy points
                VStack(spacing: 12) {
                    privacyRow(
                        icon: "lock.fill",
                        title: "Privacy First",
                        description: "Secure, encrypted connection"
                    )

                    privacyRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Data Handling",
                        description: "Only action titles, encrypted"
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
                        .foregroundStyle(hasAcceptedConsent ? Claude.success : Claude.orange)
                    Text(hasAcceptedConsent ? "Consent given" : "Consent pending")
                        .font(.claudeCaptionBold)
                        .foregroundStyle(hasAcceptedConsent ? Claude.success : Claude.orange)
                }
                .padding(.top, 8)

                // Withdraw consent button
                if hasAcceptedConsent {
                    Button {
                        hasAcceptedConsent = false
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("Withdraw Consent")
                            .font(.claudeSubheadline)
                            .foregroundStyle(Claude.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Withdraw consent")
                }

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.claudeSubheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.info)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done")
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
                    .font(.claudeBodyMedium)
                    .foregroundStyle(Claude.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.claudeSubheadline)
                    .foregroundStyle(Claude.textPrimary)

                Text(description)
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Claude.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("Consent Flow") {
    ConsentView()
}

#Preview("Privacy Info") {
    PrivacyInfoView()
}
