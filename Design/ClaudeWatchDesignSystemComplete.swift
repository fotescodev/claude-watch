// ClaudeWatchDesignSystemComplete.swift
// Complete Claude Watch Design System - All screens in one file
// Add this to a watchOS/iOS project and run previews in Xcode
//
// To use:
// 1. Create a new watchOS app in Xcode
// 2. Add this file to the project
// 3. Open the Canvas (Editor > Canvas) to see all previews
// 4. Screenshot previews for design reference

import SwiftUI

// MARK: - ============================================
// MARK: - DESIGN TOKENS
// MARK: - ============================================

/// Claude Watch Color Palette
public enum Claude {
    // Brand
    public static let orange = Color(hex: "FF9500")
    public static let orangeLight = Color(hex: "FFB340")
    public static let orangeDark = Color(hex: "CC7700")

    // Semantic
    public static let success = Color(hex: "34C759")
    public static let danger = Color(hex: "FF3B30")
    public static let warning = Color(hex: "FF9500")
    public static let info = Color(hex: "007AFF")

    // Surfaces (OLED optimized)
    public static let background = Color.black
    public static let surface1 = Color(hex: "1C1C1E")
    public static let surface2 = Color(hex: "2C2C2E")
    public static let surface3 = Color(hex: "3A3A3C")

    // Text
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.6)
    public static let textTertiary = Color.white.opacity(0.4)

    // Spacing
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    // Radius
    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 20
    }

    // iOS-specific
    public enum iOS {
        public static let horizontalPadding: CGFloat = 24
        public static let verticalSpacing: CGFloat = 32
        public static let buttonHeight: CGFloat = 56
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        self.init(
            red: Double((rgbValue >> 16) & 0xff) / 255,
            green: Double((rgbValue >> 8) & 0xff) / 255,
            blue: Double(rgbValue & 0xff) / 255
        )
    }
}

// MARK: - Typography

extension Font {
    static let claudeTitle = Font.system(size: 17, weight: .bold)
    static let claudeLargeTitle = Font.system(size: 20, weight: .bold)
    static let claudeHeadline = Font.system(size: 15, weight: .semibold)
    static let claudeBody = Font.system(size: 15, weight: .regular)
    static let claudeFootnote = Font.system(size: 13, weight: .semibold)
    static let claudeCaption = Font.system(size: 12, weight: .semibold)
    static let claudeCode = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - ============================================
// MARK: - TYPES & ENUMS
// MARK: - ============================================

enum ActionType: String, CaseIterable {
    case edit = "Edit"
    case create = "Create"
    case delete = "Delete"
    case bash = "Bash"
    case tool = "Tool"

    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .create: return "doc.badge.plus"
        case .delete: return "trash"
        case .bash: return "terminal"
        case .tool: return "gearshape"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .edit, .tool:
            return LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom)
        case .create:
            return LinearGradient(colors: [Claude.info, Claude.info.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .delete:
            return LinearGradient(colors: [Claude.danger, Claude.danger.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        case .bash:
            return LinearGradient(colors: [Color.purple, Color.purple.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        }
    }
}

enum ClaudeStatus: String {
    case idle = "Idle"
    case running = "Running"
    case waiting = "Waiting"
    case completed = "Completed"
    case failed = "Failed"
    case disconnected = "Disconnected"

    var color: Color {
        switch self {
        case .idle, .completed: return Claude.success
        case .running, .waiting: return Claude.orange
        case .failed: return Claude.danger
        case .disconnected: return Claude.textTertiary
        }
    }

    var icon: String {
        switch self {
        case .idle: return "checkmark"
        case .running: return "play.fill"
        case .waiting: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .disconnected: return "wifi.slash"
        }
    }
}

enum PermissionMode: String, CaseIterable {
    case normal = "Normal"
    case autoAccept = "Auto"
    case plan = "Plan"

    var icon: String {
        switch self {
        case .normal: return "shield"
        case .autoAccept: return "bolt.fill"
        case .plan: return "book"
        }
    }

    var color: Color {
        switch self {
        case .normal: return Claude.info
        case .autoAccept: return Claude.danger
        case .plan: return .purple
        }
    }

    var description: String {
        switch self {
        case .normal: return "Review each action"
        case .autoAccept: return "Auto-approve"
        case .plan: return "Read-only"
        }
    }
}

// MARK: - ============================================
// MARK: - ATOMIC COMPONENTS
// MARK: - ============================================

struct ActionTypeIcon: View {
    let type: ActionType
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25)
                .fill(type.gradient)
            Image(systemName: type.icon)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct StatusDot: View {
    let status: ClaudeStatus
    var size: CGFloat = 8
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing && status == .running ? 1.2 : 1.0)
            .animation(status == .running ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

struct ClaudeProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [Claude.orange, Claude.orangeLight], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

struct ClaudePrimaryButton: View {
    let title: String
    var color: Color = Claude.orange
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.claudeFootnote)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .top, endPoint: .bottom)))
        }
        .buttonStyle(.plain)
    }
}

struct ClaudeSecondaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.claudeFootnote)
                .foregroundStyle(Claude.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct Badge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.claudeCaption)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Claude.orange))
    }
}

// MARK: - ============================================
// MARK: - MOLECULE COMPONENTS
// MARK: - ============================================

struct StatusHeader: View {
    let status: ClaudeStatus
    let taskName: String
    let progress: Double?
    var pendingCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Claude.Spacing.xs) {
            HStack(spacing: Claude.Spacing.sm) {
                StatusDot(status: status)
                Text(status.rawValue).font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                if let progress = progress {
                    Text("• \(Int(progress * 100))%").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                }
                Spacer()
                if pendingCount > 0 { Badge(count: pendingCount) }
            }
            if status == .running || status == .waiting {
                Text(taskName).font(.claudeCaption).foregroundStyle(Claude.textPrimary)
                if let progress = progress { ClaudeProgressBar(progress: progress) }
            } else if status == .idle {
                Text("✓ All Clear").font(.claudeCaption).foregroundStyle(Claude.success)
            }
        }
    }
}

struct PrimaryActionCard: View {
    let type: ActionType
    let title: String
    let description: String
    var onApprove: () -> Void = {}
    var onReject: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Claude.Spacing.md) {
            HStack(spacing: Claude.Spacing.md) {
                ActionTypeIcon(type: type)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue).font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                    Text(title).font(.claudeHeadline).foregroundStyle(Claude.textPrimary).lineLimit(1)
                    Text(description).font(.claudeCaption).foregroundStyle(Claude.textSecondary).lineLimit(2)
                }
                Spacer()
            }
            HStack(spacing: Claude.Spacing.sm) {
                ClaudePrimaryButton(title: "Reject", color: Claude.danger, action: onReject)
                ClaudePrimaryButton(title: "Approve", color: Claude.success, action: onApprove)
            }
        }
        .padding(Claude.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: Claude.Radius.medium).fill(Claude.surface1))
    }
}

struct CompactActionCard: View {
    let type: ActionType
    let title: String

    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            ActionTypeIcon(type: type, size: 28)
            Text(title).font(.claudeCaption).foregroundStyle(Claude.textPrimary).lineLimit(1)
            Spacer()
        }
        .padding(Claude.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: Claude.Radius.small).fill(Claude.surface1))
    }
}

struct ModeSelector: View {
    @Binding var selectedMode: PermissionMode

    var body: some View {
        VStack(alignment: .leading, spacing: Claude.Spacing.md) {
            Text("Permission Mode").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
            HStack(spacing: Claude.Spacing.sm) {
                ForEach(PermissionMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        VStack(spacing: Claude.Spacing.xs) {
                            ZStack {
                                Circle()
                                    .fill(selectedMode == mode ? mode.color.opacity(0.2) : Claude.surface2)
                                    .frame(width: 40, height: 40)
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(mode.color)
                            }
                            Text(mode.rawValue).font(.system(size: 10)).foregroundStyle(selectedMode == mode ? Claude.textPrimary : Claude.textSecondary)
                            Circle().fill(selectedMode == mode ? mode.color : .clear).frame(width: 5, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            Text(selectedMode.description).font(.claudeCaption).foregroundStyle(Claude.textSecondary)
        }
    }
}

struct QuickCommandsGrid: View {
    let commands: [(icon: String, title: String, color: Color)] = [
        ("play.fill", "Go", Claude.success),
        ("bolt.fill", "Test", Claude.warning),
        ("wrench.fill", "Fix", Claude.orange),
        ("stop.fill", "Stop", Claude.danger)
    ]

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            Text("Quick Commands").font(.claudeCaption).foregroundStyle(Claude.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Claude.Spacing.sm) {
                ForEach(commands, id: \.title) { cmd in
                    VStack(spacing: Claude.Spacing.xs) {
                        Image(systemName: cmd.icon).font(.system(size: 14)).foregroundStyle(cmd.color)
                        Text(cmd.title).font(.claudeCaption).foregroundStyle(Claude.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Claude.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Claude.Radius.small).fill(Claude.surface1))
                }
            }
            HStack {
                Image(systemName: "mic.fill")
                Text("Voice Command")
            }
            .font(.claudeCaption)
            .foregroundStyle(Claude.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Claude.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Claude.Radius.small).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - ============================================
// MARK: - WATCHOS SCREENS - ONBOARDING
// MARK: - ============================================

struct SplashScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom)).frame(width: 80, height: 80)
                Image(systemName: "sparkle").font(.system(size: 36, weight: .medium)).foregroundStyle(.white)
            }
            Text("Claude Watch").font(.claudeTitle).foregroundStyle(Claude.textPrimary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

// MARK: - Consent Flow

struct ConsentPage1Privacy: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Claude.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Claude.orange)
            }

            // Title
            Text("Privacy First")
                .font(.claudeLargeTitle)
                .foregroundStyle(Claude.textPrimary)

            // Content
            Text("Claude Watch connects to your Claude Code session to enable action approvals")
                .font(.claudeCaption)
                .foregroundStyle(Claude.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Claude.Spacing.sm)

            Spacer()

            // Pagination
            HStack(spacing: Claude.Spacing.sm) {
                Circle().fill(Claude.orange).frame(width: 6, height: 6)
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
            }

            // Continue
            Button {} label: {
                HStack(spacing: 4) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .font(.claudeFootnote)
                .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct ConsentPage2Data: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Claude.info.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24))
                    .foregroundStyle(Claude.info)
            }

            // Title
            Text("Data Handling")
                .font(.claudeLargeTitle)
                .foregroundStyle(Claude.textPrimary)

            // Bullet list
            VStack(alignment: .leading, spacing: Claude.Spacing.xs) {
                DataBullet(text: "Action titles sent")
                DataBullet(text: "No code content")
                DataBullet(text: "No file contents")
                DataBullet(text: "Encrypted transit")
            }

            Spacer()

            // Pagination
            HStack(spacing: Claude.Spacing.sm) {
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
                Circle().fill(Claude.orange).frame(width: 6, height: 6)
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
            }

            // Continue
            Button {} label: {
                HStack(spacing: 4) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
                .font(.claudeFootnote)
                .foregroundStyle(Claude.orange)
            }
            .buttonStyle(.plain)
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct DataBullet: View {
    let text: String
    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            Circle().fill(Claude.success).frame(width: 6, height: 6)
            Text(text).font(.claudeCaption).foregroundStyle(Claude.textSecondary)
        }
    }
}

struct ConsentPage3Accept: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Claude.success.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Claude.success)
            }

            // Title
            Text("Ready to Start")
                .font(.claudeLargeTitle)
                .foregroundStyle(Claude.textPrimary)

            // Content
            Text("By continuing you agree to the Terms of Service and Privacy Policy")
                .font(.claudeCaption)
                .foregroundStyle(Claude.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Claude.Spacing.sm)

            Spacer()

            // Pagination
            HStack(spacing: Claude.Spacing.sm) {
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
                Circle().fill(Claude.textTertiary).frame(width: 6, height: 6)
                Circle().fill(Claude.orange).frame(width: 6, height: 6)
            }

            // Accept button
            ClaudePrimaryButton(title: "Accept & Continue")

            // Privacy link
            Button("View Privacy Policy") {}
                .font(.claudeCaption)
                .foregroundStyle(Claude.textTertiary)
                .buttonStyle(.plain)
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

// MARK: - Pairing Flow

struct UnpairedMainView: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            // Toolbar
            HStack {
                Spacer()
                Image(systemName: "gearshape")
                    .foregroundStyle(Claude.textSecondary)
            }

            // Status
            HStack(spacing: Claude.Spacing.sm) {
                Circle()
                    .fill(Claude.textTertiary)
                    .frame(width: 8, height: 8)
                Text("Not Connected")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.textSecondary)
                Spacer()
            }

            // Empty state card
            VStack(spacing: Claude.Spacing.lg) {
                Image(systemName: "link")
                    .font(.system(size: 36))
                    .foregroundStyle(Claude.orange)

                VStack(spacing: Claude.Spacing.xs) {
                    Text("Pair with Claude Code")
                        .font(.claudeHeadline)
                        .foregroundStyle(Claude.textPrimary)

                    Text("Scan QR or enter pairing code")
                        .font(.claudeCaption)
                        .foregroundStyle(Claude.textSecondary)
                }
            }
            .padding(Claude.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.medium)
                    .fill(Claude.surface1)
            )

            VStack(spacing: Claude.Spacing.sm) {
                ClaudePrimaryButton(title: "Pair Now")
                ClaudeSecondaryButton(title: "Load Demo")
            }

            Spacer()
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct PairingCodeEntry: View {
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            // Header
            HStack {
                Button {} label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Cancel")
                    }
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.orange)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // Title
            Text("Enter Pairing Code")
                .font(.claudeTitle)
                .foregroundStyle(Claude.textPrimary)

            // Input field
            Text(code.isEmpty ? "_ _ _ - _ _ _" : code)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(code.isEmpty ? Claude.textTertiary : Claude.textPrimary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Claude.Radius.small)
                        .fill(Claude.surface1)
                )

            // Helper text
            VStack(spacing: Claude.Spacing.xs) {
                Text("Run this in terminal:")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.textSecondary)

                HStack {
                    Text("claude --pair")
                        .font(.claudeCode)
                        .foregroundStyle(Claude.textPrimary)

                    Spacer()

                    Image(systemName: "doc.on.doc")
                        .font(.claudeCaption)
                        .foregroundStyle(Claude.orange)
                }
                .padding(Claude.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Claude.Radius.small)
                        .fill(Claude.surface2)
                )
            }

            Spacer()

            ClaudePrimaryButton(title: "Connect")
                .opacity(code.isEmpty ? 0.5 : 1)
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct PairingCodeEntered: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            // Header
            HStack {
                Button {} label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Cancel")
                    }
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.orange)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            // Title
            Text("Enter Pairing Code")
                .font(.claudeTitle)
                .foregroundStyle(Claude.textPrimary)

            // Input field with code
            HStack(spacing: 0) {
                Text("A B C - 1 2 3")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Claude.textPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.small)
                    .fill(Claude.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: Claude.Radius.small)
                            .strokeBorder(Claude.success.opacity(0.5), lineWidth: 1)
                    )
            )

            // Valid indicator
            HStack(spacing: Claude.Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Claude.success)
                Text("Valid format")
                    .foregroundStyle(Claude.success)
            }
            .font(.claudeCaption)

            Spacer()

            ClaudePrimaryButton(title: "Connect")
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct ConnectingScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()

            // Spinner
            ZStack {
                Circle()
                    .stroke(Claude.surface2, lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Claude.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: Claude.Spacing.xs) {
                Text("Connecting...")
                    .font(.claudeHeadline)
                    .foregroundStyle(Claude.textPrimary)

                Text("Verifying code ABC-123")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct ConnectedSuccessScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()

            // Success icon
            ZStack {
                Circle()
                    .fill(Claude.success.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Claude.success)
            }

            VStack(spacing: Claude.Spacing.xs) {
                Text("Connected!")
                    .font(.claudeLargeTitle)
                    .foregroundStyle(Claude.textPrimary)

                Text("Ready to approve actions")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.textSecondary)
            }

            Spacer()

            // Tip
            VStack(spacing: Claude.Spacing.sm) {
                HStack(spacing: Claude.Spacing.xs) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(Claude.orange)
                    Text("Tip")
                        .fontWeight(.semibold)
                }
                .font(.claudeCaption)
                .foregroundStyle(Claude.orange)

                Text("Add the complication to your watch face for quick access")
                    .font(.claudeCaption)
                    .foregroundStyle(Claude.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Claude.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.small)
                    .fill(Claude.surface1)
            )
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

// MARK: - ============================================
// MARK: - WATCHOS SCREENS - MAIN VIEWS
// MARK: - ============================================

struct MainViewEmpty: View {
    @State private var selectedMode: PermissionMode = .normal

    var body: some View {
        ScrollView {
            VStack(spacing: Claude.Spacing.lg) {
                HStack { Spacer(); Image(systemName: "gearshape").foregroundStyle(Claude.textSecondary) }
                StatusHeader(status: .idle, taskName: "", progress: nil, pendingCount: 0)

                VStack(spacing: Claude.Spacing.lg) {
                    Image(systemName: "checkmark.circle").font(.system(size: 40)).foregroundStyle(Claude.success)
                    Text("No actions pending").font(.claudeHeadline).foregroundStyle(Claude.textPrimary)
                    Text("Claude is ready").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                }
                .padding(Claude.Spacing.xl)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Claude.Radius.medium).fill(Claude.surface1))

                ClaudeSecondaryButton(title: "Load Demo")
                QuickCommandsGrid()
                ModeSelector(selectedMode: $selectedMode)
            }
            .padding(Claude.Spacing.lg)
        }
        .background(Claude.background)
    }
}

struct MainViewPending: View {
    @State private var selectedMode: PermissionMode = .normal

    var body: some View {
        ScrollView {
            VStack(spacing: Claude.Spacing.lg) {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape").foregroundStyle(Claude.textSecondary)
                        Badge(count: 5)
                    }
                }
                StatusHeader(status: .running, taskName: "Building feature", progress: 0.42, pendingCount: 5)
                PrimaryActionCard(type: .edit, title: "src/App.tsx", description: "Add dark mode toggle")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Claude.Spacing.sm) {
                    CompactActionCard(type: .create, title: "test.ts")
                    CompactActionCard(type: .edit, title: "index.ts")
                }
                Text("+ 2 more").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                ClaudePrimaryButton(title: "Approve All (5)")
                QuickCommandsGrid()
                ModeSelector(selectedMode: $selectedMode)
            }
            .padding(Claude.Spacing.lg)
        }
        .background(Claude.background)
    }
}

struct CriticalActionScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("DANGEROUS OPERATION").font(.claudeCaption).fontWeight(.bold)
            }
            .foregroundStyle(Claude.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Claude.Spacing.sm)
            .background(Claude.danger.opacity(0.2))

            ScrollView {
                VStack(spacing: Claude.Spacing.md) {
                    HStack(spacing: Claude.Spacing.sm) {
                        ActionTypeIcon(type: .delete)
                        Text("DELETE Operation").font(.claudeHeadline).foregroundStyle(Claude.textPrimary)
                        Spacer()
                    }

                    Text("DELETE FROM users\nWHERE inactive=true")
                        .font(.claudeCode)
                        .foregroundStyle(Claude.danger)
                        .padding(Claude.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Claude.Radius.small).fill(Claude.surface2))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Table: users").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                        HStack(spacing: 4) {
                            Text("Est. rows:").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                            Text("1,247").font(.claudeCaption).fontWeight(.bold).foregroundStyle(Claude.danger)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ClaudePrimaryButton(title: "REJECT", color: Claude.danger)
                    Button("Approve") {}.font(.claudeCaption).foregroundStyle(Claude.textTertiary).buttonStyle(.plain)
                }
                .padding(Claude.Spacing.lg)
            }
        }
        .background(Claude.background)
    }
}

struct DisconnectedScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()
            Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundStyle(Claude.textSecondary)
            VStack(spacing: Claude.Spacing.xs) {
                Text("Disconnected").font(.claudeHeadline).foregroundStyle(Claude.textPrimary)
                Text("Lost connection to server").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
            }
            VStack(spacing: Claude.Spacing.sm) {
                ClaudePrimaryButton(title: "Retry")
                ClaudeSecondaryButton(title: "Demo Mode")
            }
            .padding(.horizontal, Claude.Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct ReconnectingScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 40)).foregroundStyle(Claude.orange)
            VStack(spacing: Claude.Spacing.xs) {
                Text("Reconnecting...").font(.claudeHeadline).foregroundStyle(Claude.textPrimary)
                Text("Attempt 3 of 10").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                Text("Next retry: 8s").font(.claudeCaption).foregroundStyle(Claude.textTertiary)
            }
            ClaudeProgressBar(progress: 0.3).padding(.horizontal, Claude.Spacing.xl)
            Button("Cancel") {}.font(.claudeCaption).foregroundStyle(Claude.textTertiary).buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct VoiceCommandScreen: View {
    var body: some View {
        VStack(spacing: Claude.Spacing.lg) {
            HStack {
                Button {} label: { HStack(spacing: 4) { Image(systemName: "chevron.left"); Text("Cancel") }.font(.claudeCaption).foregroundStyle(Claude.orange) }.buttonStyle(.plain)
                Spacer()
            }
            Text("Voice Command").font(.claudeTitle).foregroundStyle(Claude.textPrimary)
            Text("Type or dictate...")
                .font(.claudeCaption)
                .foregroundStyle(Claude.textTertiary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: Claude.Radius.small).fill(Claude.surface1))
            VStack(alignment: .leading, spacing: Claude.Spacing.sm) {
                Text("Suggestions:").font(.claudeCaption).foregroundStyle(Claude.textSecondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Claude.Spacing.sm) {
                    ForEach(["Go", "Test", "Fix", "Stop"], id: \.self) { s in
                        Text(s).font(.claudeCaption).foregroundStyle(Claude.textPrimary).padding(.horizontal, Claude.Spacing.md).padding(.vertical, Claude.Spacing.sm).background(Capsule().fill(Claude.surface2))
                    }
                }
            }
            Spacer()
            ClaudePrimaryButton(title: "Send").opacity(0.5)
        }
        .padding(Claude.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

// MARK: - ============================================
// MARK: - COMPLICATIONS
// MARK: - ============================================

struct CircularComplication: View {
    let status: ClaudeStatus
    let progress: Double?
    let pendingCount: Int

    var body: some View {
        ZStack {
            Circle().fill(Claude.surface1)
            if let progress = progress {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [Claude.orange, Claude.orangeLight], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Image(systemName: status.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(status.color)
                if pendingCount > 0 { Text("\(pendingCount)").font(.system(size: 10, weight: .bold)).foregroundStyle(Claude.textPrimary) }
            }
        }
        .frame(width: 42, height: 42)
    }
}

struct RectangularComplication: View {
    let status: ClaudeStatus
    let taskName: String
    let progress: Double?
    let pendingCount: Int

    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            ZStack {
                Circle().fill(status.color.opacity(0.2)).frame(width: 32, height: 32)
                Image(systemName: status.icon).font(.system(size: 14)).foregroundStyle(status.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("CLAUDE").font(.system(size: 10, weight: .bold)).foregroundStyle(Claude.textSecondary)
                    Spacer()
                    if pendingCount > 0 { Text("\(pendingCount) pending").font(.system(size: 10)).foregroundStyle(Claude.orange) }
                }
                if status == .idle {
                    Text("✓ All Clear").font(.system(size: 12, weight: .semibold)).foregroundStyle(Claude.success)
                } else {
                    Text(taskName).font(.system(size: 12, weight: .semibold)).foregroundStyle(Claude.textPrimary).lineLimit(1)
                }
                if let progress = progress {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 2).fill(Claude.orange).frame(width: g.size.width * progress)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(Claude.Spacing.sm)
        .frame(width: 160, height: 52)
        .background(Claude.surface1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - ============================================
// MARK: - IOS COMPANION SCREENS
// MARK: - ============================================

struct iOSWelcome: View {
    var body: some View {
        VStack(spacing: Claude.iOS.verticalSpacing) {
            Spacer()
            VStack(spacing: Claude.Spacing.lg) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom)).frame(width: 100, height: 100)
                    Image(systemName: "sparkle").font(.system(size: 44, weight: .medium)).foregroundStyle(.white)
                }
                VStack(spacing: Claude.Spacing.sm) {
                    Text("Claude Watch").font(.system(size: 28, weight: .bold)).foregroundStyle(Claude.textPrimary)
                    Rectangle().fill(Claude.orange).frame(width: 60, height: 3).clipShape(Capsule())
                }
            }
            Text("Pair your Apple Watch with\nClaude Code in seconds").font(.system(size: 17)).foregroundStyle(Claude.textSecondary).multilineTextAlignment(.center)
            Spacer()
            Button {} label: {
                HStack { Image(systemName: "camera.fill"); Text("Scan QR Code") }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Claude.iOS.buttonHeight)
                    .background(RoundedRectangle(cornerRadius: Claude.iOS.buttonHeight / 2).fill(LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom)))
            }.buttonStyle(.plain)
            HStack {
                Rectangle().fill(Claude.textTertiary).frame(height: 1)
                Text("or").font(.system(size: 15)).foregroundStyle(Claude.textTertiary).padding(.horizontal, Claude.Spacing.md)
                Rectangle().fill(Claude.textTertiary).frame(height: 1)
            }
            Button("Enter code manually") {}.font(.system(size: 17)).foregroundStyle(Claude.orange).buttonStyle(.plain)
            Spacer()
            Button("Already paired? Check status") {}.font(.system(size: 15)).foregroundStyle(Claude.textTertiary).buttonStyle(.plain)
        }
        .padding(.horizontal, Claude.iOS.horizontalPadding)
        .padding(.vertical, Claude.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct iOSConnected: View {
    var body: some View {
        VStack(spacing: Claude.iOS.verticalSpacing) {
            Spacer()
            ZStack {
                Circle().fill(Claude.success.opacity(0.2)).frame(width: 100, height: 100)
                Image(systemName: "checkmark").font(.system(size: 44, weight: .bold)).foregroundStyle(Claude.success)
            }
            VStack(spacing: Claude.Spacing.sm) {
                Text("Connected!").font(.system(size: 28, weight: .bold)).foregroundStyle(Claude.textPrimary)
                Text("Your Apple Watch is now paired\nwith Claude Code").font(.system(size: 17)).foregroundStyle(Claude.textSecondary).multilineTextAlignment(.center)
            }
            Spacer()
            VStack(alignment: .leading, spacing: Claude.Spacing.lg) {
                HStack(spacing: Claude.Spacing.md) {
                    Image(systemName: "applewatch").font(.system(size: 28)).foregroundStyle(Claude.orange)
                    Text("Claude Watch").font(.system(size: 17, weight: .semibold)).foregroundStyle(Claude.textPrimary)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: Claude.Spacing.sm) {
                    HStack { Text("Status:").foregroundStyle(Claude.textSecondary); HStack(spacing: 6) { Circle().fill(Claude.success).frame(width: 8, height: 8); Text("Connected").foregroundStyle(Claude.success) } }.font(.system(size: 15))
                    HStack { Text("Paired:").foregroundStyle(Claude.textSecondary); Text("Today, 10:32 AM").foregroundStyle(Claude.textPrimary) }.font(.system(size: 15))
                    HStack { Text("Code:").foregroundStyle(Claude.textSecondary); Text("ABC-123").font(.system(size: 15, design: .monospaced)).foregroundStyle(Claude.textPrimary) }.font(.system(size: 15))
                }
            }
            .padding(Claude.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Claude.surface1))
            Spacer()
            Button {} label: {
                Text("Done").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: Claude.iOS.buttonHeight).background(RoundedRectangle(cornerRadius: Claude.iOS.buttonHeight / 2).fill(LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom)))
            }.buttonStyle(.plain)
            Button("Pair a different device") {}.font(.system(size: 17)).foregroundStyle(Claude.orange).buttonStyle(.plain)
        }
        .padding(.horizontal, Claude.iOS.horizontalPadding)
        .padding(.vertical, Claude.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct iOSQRScanner: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {} label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Claude.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text("Scan QR Code")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Claude.textPrimary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, Claude.Spacing.md)
            .background(Claude.surface1)

            // Scanner area
            ZStack {
                // Camera preview placeholder
                Rectangle()
                    .fill(Color.black)

                // Scan frame
                VStack {
                    Spacer()
                    ZStack {
                        // Corner brackets
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Claude.orange, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        // Animated scan line
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Claude.orange.opacity(0), Claude.orange, Claude.orange.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: 220, height: 2)
                    }
                    Spacer()
                }

                // Instructions overlay
                VStack {
                    Spacer()
                    VStack(spacing: Claude.Spacing.md) {
                        Text("Point camera at QR code")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Run 'claude watch pair' in terminal\nto display the QR code")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(Claude.Spacing.xl)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 60)
                }
            }

            // Bottom bar
            HStack(spacing: Claude.Spacing.xl) {
                Button {} label: {
                    VStack(spacing: Claude.Spacing.xs) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                        Text("Flash")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Claude.textSecondary)
                }

                Spacer()

                Button {} label: {
                    VStack(spacing: Claude.Spacing.xs) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 20))
                        Text("Manual")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(Claude.orange)
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, Claude.Spacing.lg)
            .background(Claude.surface1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct iOSSyncing: View {
    let progress: Double

    var body: some View {
        VStack(spacing: Claude.iOS.verticalSpacing) {
            Spacer()

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Claude.surface2, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Claude.orange, Claude.orangeLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Claude.textPrimary)
                    Text("syncing")
                        .font(.system(size: 14))
                        .foregroundStyle(Claude.textSecondary)
                }
            }

            VStack(spacing: Claude.Spacing.sm) {
                Text("Syncing with Watch")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Claude.textPrimary)

                Text("Establishing secure connection\nand transferring credentials")
                    .font(.system(size: 17))
                    .foregroundStyle(Claude.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sync steps
            VStack(alignment: .leading, spacing: Claude.Spacing.md) {
                SyncStep(icon: "checkmark.circle.fill", text: "QR code verified", isComplete: true)
                SyncStep(icon: "checkmark.circle.fill", text: "Authentication confirmed", isComplete: progress > 0.3)
                SyncStep(icon: progress > 0.6 ? "checkmark.circle.fill" : "circle", text: "Sending to Watch", isComplete: progress > 0.6)
                SyncStep(icon: progress > 0.9 ? "checkmark.circle.fill" : "circle", text: "Watch confirmation", isComplete: progress > 0.9)
            }
            .padding(Claude.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Claude.surface1))

            Spacer()

            Button("Cancel") {}
                .font(.system(size: 17))
                .foregroundStyle(Claude.textTertiary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Claude.iOS.horizontalPadding)
        .padding(.vertical, Claude.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

struct SyncStep: View {
    let icon: String
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: Claude.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isComplete ? Claude.success : Claude.textTertiary)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(isComplete ? Claude.textPrimary : Claude.textTertiary)
        }
    }
}

struct iOSManualEntry: View {
    @State private var code: String = ""

    var body: some View {
        VStack(spacing: Claude.iOS.verticalSpacing) {
            // Header
            VStack(spacing: Claude.Spacing.sm) {
                Image(systemName: "keyboard")
                    .font(.system(size: 40))
                    .foregroundStyle(Claude.orange)

                Text("Enter Pairing Code")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Claude.textPrimary)

                Text("Enter the 6-character code shown\nin your terminal")
                    .font(.system(size: 17))
                    .foregroundStyle(Claude.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            Spacer()

            // Code input display
            HStack(spacing: Claude.Spacing.sm) {
                ForEach(0..<6, id: \.self) { index in
                    let character = index < code.count ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Claude.surface1)
                            .frame(width: 48, height: 56)

                        if character.isEmpty {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Claude.surface2, lineWidth: 2)
                                .frame(width: 48, height: 56)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Claude.orange, lineWidth: 2)
                                .frame(width: 48, height: 56)
                        }

                        Text(character.uppercased())
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(Claude.textPrimary)
                    }
                }
            }

            Spacer()

            // Connect button
            Button {} label: {
                Text("Connect")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: Claude.iOS.buttonHeight)
                    .background(
                        RoundedRectangle(cornerRadius: Claude.iOS.buttonHeight / 2)
                            .fill(code.count == 6 ?
                                  LinearGradient(colors: [Claude.orange, Claude.orangeDark], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [Claude.surface2, Claude.surface2], startPoint: .top, endPoint: .bottom))
                    )
            }
            .buttonStyle(.plain)
            .disabled(code.count != 6)

            Button("Scan QR code instead") {}
                .font(.system(size: 17))
                .foregroundStyle(Claude.orange)
                .buttonStyle(.plain)
                .padding(.bottom, Claude.Spacing.lg)
        }
        .padding(.horizontal, Claude.iOS.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Claude.background)
    }
}

// MARK: - ============================================
// MARK: - PREVIEWS
// MARK: - ============================================

// watchOS 45mm size: 198×242
// iPhone 14 size: 390×844

#Preview("Splash") { SplashScreen().frame(width: 198, height: 242) }
#Preview("Main - Empty") { MainViewEmpty().frame(width: 198, height: 480) }
#Preview("Main - Pending") { MainViewPending().frame(width: 198, height: 600) }
#Preview("Critical Action") { CriticalActionScreen().frame(width: 198, height: 380) }
#Preview("Disconnected") { DisconnectedScreen().frame(width: 198, height: 280) }
#Preview("Reconnecting") { ReconnectingScreen().frame(width: 198, height: 280) }
#Preview("Voice Command") { VoiceCommandScreen().frame(width: 198, height: 380) }

#Preview("Complication - Circular Idle") { CircularComplication(status: .idle, progress: nil, pendingCount: 0).padding().background(Color.black) }
#Preview("Complication - Circular Running") { CircularComplication(status: .running, progress: 0.67, pendingCount: 3).padding().background(Color.black) }
#Preview("Complication - Rectangular") { RectangularComplication(status: .running, taskName: "Building", progress: 0.67, pendingCount: 3).padding().background(Color.black) }

// Consent Flow Previews
#Preview("Consent 1 - Privacy") { ConsentPage1Privacy().frame(width: 198, height: 300) }
#Preview("Consent 2 - Data") { ConsentPage2Data().frame(width: 198, height: 340) }
#Preview("Consent 3 - Accept") { ConsentPage3Accept().frame(width: 198, height: 340) }

// WatchOS Pairing Flow Previews
#Preview("Unpaired Main") { UnpairedMainView().frame(width: 198, height: 380) }
#Preview("Pairing - Empty") { PairingCodeEntry().frame(width: 198, height: 360) }
#Preview("Pairing - Entered") { PairingCodeEntered().frame(width: 198, height: 340) }
#Preview("Connecting") { ConnectingScreen().frame(width: 198, height: 242) }
#Preview("Connected Success") { ConnectedSuccessScreen().frame(width: 198, height: 340) }

// iOS Companion Previews
#Preview("iOS Welcome") { iOSWelcome().frame(width: 390, height: 844) }
#Preview("iOS QR Scanner") { iOSQRScanner().frame(width: 390, height: 844) }
#Preview("iOS Manual Entry") { iOSManualEntry().frame(width: 390, height: 844) }
#Preview("iOS Syncing - 50%") { iOSSyncing(progress: 0.5).frame(width: 390, height: 844) }
#Preview("iOS Syncing - 90%") { iOSSyncing(progress: 0.9).frame(width: 390, height: 844) }
#Preview("iOS Connected") { iOSConnected().frame(width: 390, height: 844) }

#Preview("Component - Action Icons") {
    HStack(spacing: 12) { ForEach(ActionType.allCases, id: \.self) { ActionTypeIcon(type: $0) } }
    .padding().background(Claude.background)
}

#Preview("Component - Buttons") {
    VStack(spacing: 12) {
        ClaudePrimaryButton(title: "Approve", color: Claude.success)
        ClaudePrimaryButton(title: "Reject", color: Claude.danger)
        ClaudeSecondaryButton(title: "Secondary")
    }
    .padding().background(Claude.background).frame(width: 198)
}

#Preview("Component - Mode Selector") {
    struct Wrapper: View {
        @State var mode: PermissionMode = .normal
        var body: some View { ModeSelector(selectedMode: $mode).padding().background(Claude.background) }
    }
    return Wrapper().frame(width: 198)
}

#Preview("Component - Quick Commands") {
    QuickCommandsGrid().padding().background(Claude.background).frame(width: 198)
}

#Preview("Component - Primary Action Card") {
    PrimaryActionCard(type: .edit, title: "src/App.tsx", description: "Add dark mode toggle").padding().background(Claude.background).frame(width: 198)
}
