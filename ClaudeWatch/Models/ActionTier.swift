//
//  ActionTier.swift
//  ClaudeWatch
//
//  Tiered risk classification for approval requests
//  V2: Safety-first design with Tier 3 requiring Mac approval
//

import SwiftUI

// MARK: - Action Tier

/// Risk tier classification for approval requests
/// Determines UI appearance and available actions
public enum ActionTier: Int, Comparable, CaseIterable, Codable, Sendable {
    /// Low risk - Safe operations (Read, simple Edit)
    case low = 1
    /// Medium risk - Caution needed (Write, simple Bash, MCP)
    case medium = 2
    /// High risk - Dangerous operations (Delete, rm -rf, sudo)
    case high = 3

    // MARK: - Comparable

    public static func < (lhs: ActionTier, rhs: ActionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Display Properties

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "Dangerous"
        }
    }

    /// Short label for badges
    public var shortName: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MED"
        case .high: return "DANGER"
        }
    }

    /// Card background color based on tier
    public var cardColor: Color {
        switch self {
        case .low: return .green      // Safe - green
        case .medium: return .orange  // Caution - orange
        case .high: return .red       // Danger - red
        }
    }

    /// Icon for the tier
    public var icon: String {
        switch self {
        case .low: return "checkmark.shield"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.shield.fill"
        }
    }

    // MARK: - Behavior

    /// Whether this tier can be approved from the watch
    /// All tiers can now be approved from watch (user requested)
    public var canApproveFromWatch: Bool {
        true
    }

    /// What double tap gesture does for this tier
    /// Tier 1-2: Approve (safe default)
    /// Tier 3: Reject (safety default - no accidental approve)
    public var doubleTapAction: DoubleTapAction {
        switch self {
        case .low, .medium: return .approve
        case .high: return .reject
        }
    }

    /// Hint text shown below action cards (V3 design spec)
    public var hintText: String {
        switch self {
        case .low: return "Double tap to approve"
        case .medium: return "Review before approve"
        case .high: return "Approve requires Mac"
        }
    }

    /// Legacy property - use hintText instead
    public var macHint: String? {
        self == .high ? hintText : nil
    }

    // MARK: - Classification

    /// Classify a risk level (1-5) into a tier
    public static func from(riskLevel: Int) -> ActionTier {
        switch riskLevel {
        case 1...2: return .low
        case 3: return .medium
        case 4...5: return .high
        default: return .medium  // Default to medium for unknown
        }
    }

    /// Classify action type and command into risk level
    public static func classify(type: String, command: String? = nil, filePath: String? = nil) -> ActionTier {
        let riskLevel = calculateRiskLevel(type: type, command: command, filePath: filePath)
        return from(riskLevel: riskLevel)
    }

    /// Calculate risk level (1-5) from action details
    private static func calculateRiskLevel(type: String, command: String?, filePath: String?) -> Int {
        switch type.lowercased() {
        // Low risk (1-2)
        case "read", "glob", "grep":
            return 1
        case "edit", "file_edit":
            return 2
        case "create", "file_create":
            return 1

        // Medium risk (3)
        case "write", "file_write":
            return 3  // Write = medium per spec
        case "mcp":
            return 3

        // High risk (4-5)
        case "delete", "file_delete":
            return 5

        // Bash requires command analysis
        case "bash":
            return classifyBashCommand(command)

        // Default to medium
        default:
            return 3
        }
    }

    /// Classify bash command risk level
    private static func classifyBashCommand(_ command: String?) -> Int {
        guard let cmd = command?.lowercased() else { return 3 }

        // Dangerous patterns - Tier 3 (High)
        // Matches spec: rm -rf, sudo, chmod 777, > /dev, | sh, curl | bash
        let dangerousPatterns = [
            "rm -rf", "rm -r", "rmdir",
            "sudo", "su -",
            "chmod 777", "chmod -R",
            "chown -R",
            "> /dev/", "dd if=",
            "mkfs", "fdisk",
            ":(){:|:&};:",  // Fork bomb
            "mv /* ", "cp -r /* ",
            "git reset --hard", "git clean -fd",
            "drop database", "drop table",
            "truncate table",
            "| sh", "| bash",           // Piped shell execution
            "curl | bash", "wget | sh"  // Remote code execution
        ]
        for pattern in dangerousPatterns {
            if cmd.contains(pattern) {
                return 5
            }
        }

        // Medium patterns - Tier 2 (Medium)
        let mediumPatterns = [
            "npm install", "yarn add", "pip install",
            "brew install", "apt install", "apt-get install",
            "git push", "git commit",
            "docker run", "docker-compose up",
            "curl", "wget"
        ]
        for pattern in mediumPatterns {
            if cmd.contains(pattern) {
                return 3
            }
        }

        // Safe patterns - Tier 1 (Low)
        let safePatterns = [
            "ls", "pwd", "echo", "cat", "head", "tail",
            "grep", "find", "which", "whoami",
            "git status", "git log", "git diff", "git branch",
            "npm list", "npm outdated",
            "node --version", "python --version"
        ]
        for pattern in safePatterns {
            if cmd.hasPrefix(pattern) || cmd.contains(" \(pattern)") {
                return 2
            }
        }

        // Default bash to medium
        return 3
    }
}

// MARK: - Double Tap Action

/// Action performed on double tap gesture
public enum DoubleTapAction: String, Sendable {
    case approve
    case reject

    /// SF Symbol icon
    public var icon: String {
        switch self {
        case .approve: return "checkmark"
        case .reject: return "xmark"
        }
    }

    /// Color for the action
    public var color: Color {
        switch self {
        case .approve: return .green
        case .reject: return .red
        }
    }
}

// MARK: - Tier Badge View

/// A small badge showing the action tier
public struct TierBadge: View {
    public let tier: ActionTier
    public var compact: Bool = false

    public init(tier: ActionTier, compact: Bool = false) {
        self.tier = tier
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 4) {
            if !compact {
                Image(systemName: tier.icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(tier.shortName)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, 3)
        .background(tier.cardColor)
        .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Tier Badges") {
    VStack(spacing: 16) {
        ForEach(ActionTier.allCases, id: \.self) { tier in
            HStack(spacing: 12) {
                TierBadge(tier: tier)
                TierBadge(tier: tier, compact: true)
                Spacer()
                Text(tier.displayName)
                    .font(.caption)
                Text("Can approve: \(tier.canApproveFromWatch ? "Yes" : "No")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
    }
    .padding()
}

#Preview("Bash Classification") {
    let testCommands = [
        "ls -la",
        "npm install express",
        "rm -rf ./build",
        "sudo apt install",
        "git status",
        "chmod 777 /tmp/test"
    ]

    VStack(alignment: .leading, spacing: 8) {
        ForEach(testCommands, id: \.self) { cmd in
            let tier = ActionTier.classify(type: "bash", command: cmd)
            HStack {
                TierBadge(tier: tier, compact: true)
                Text(cmd)
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
        }
    }
    .padding()
}
