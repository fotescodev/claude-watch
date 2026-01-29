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
            .tabViewStyle(.page(indexDisplayMode: .never))
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
            ZStack {
                Circle()
                    .fill(Claude.orange.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Claude.orange)
            }

            // Title
            Text("Privacy First")
                .font(.claudeHeadline)
                .foregroundStyle(Claude.textPrimary)

            // Content
            Text("Connects to Claude Code for action approvals")
                .font(.claudeFootnote)
                .foregroundStyle(Claude.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Pagination dots
            HStack(spacing: 6) {
                Circle().fill(Claude.orange).frame(width: 5, height: 5)
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
            }

            // Continue button
            Button {
                WKInterfaceDevice.current().play(.click)
                onContinue()
            } label: {
                Text("Continue →")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
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
            ZStack {
                Circle()
                    .fill(Claude.info.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 18))
                    .foregroundStyle(Claude.info)
            }

            // Title
            Text("Data Handling")
                .font(.claudeHeadline)
                .foregroundStyle(Claude.textPrimary)

            // Bullet list - compact
            VStack(alignment: .leading, spacing: 2) {
                DataBullet(text: "Action titles only")
                DataBullet(text: "No code content")
                DataBullet(text: "Encrypted transit")
            }

            Spacer()

            // Pagination dots
            HStack(spacing: 6) {
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
                Circle().fill(Claude.orange).frame(width: 5, height: 5)
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
            }

            // Continue button
            Button {
                WKInterfaceDevice.current().play(.click)
                onContinue()
            } label: {
                Text("Continue →")
                    .font(.claudeFootnote)
                    .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
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
            ZStack {
                Circle()
                    .fill(Claude.success.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Claude.success)
            }

            // Title
            Text("Ready to Start")
                .font(.claudeHeadline)
                .foregroundStyle(Claude.textPrimary)

            // Content
            Text("By continuing you agree to Terms & Privacy Policy")
                .font(.claudeFootnote)
                .foregroundStyle(Claude.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Pagination dots
            HStack(spacing: 6) {
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
                Circle().fill(Claude.textTertiary).frame(width: 5, height: 5)
                Circle().fill(Claude.orange).frame(width: 5, height: 5)
            }

            // Accept button
            Button {
                onAccept()
            } label: {
                Text("Accept")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Claude.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
                        .font(.system(size: 14, weight: .semibold))
                    Text("Privacy")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Claude.textPrimary)

                // Privacy points
                VStack(spacing: 12) {
                    privacyRow(
                        icon: "lock.fill",
                        title: "Privacy First",
                        description: "Secure connection to Claude"
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
                        .font(.system(size: 12, weight: .semibold))
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Claude.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Claude.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.info)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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
                    .foregroundStyle(Claude.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Claude.textPrimary)

                Text(description)
                    .font(.system(size: 11))
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
