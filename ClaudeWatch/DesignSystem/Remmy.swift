import SwiftUI

// MARK: - Remmy Design System
/// Type alias for backwards compatibility during Claude → Remmy migration
/// All new code should use `Remmy` namespace directly
/// Existing code using `Claude` will continue to work via the original file

/// Primary namespace for Remmy design system
/// This is the new canonical name - identical to Claude enum
typealias Remmy = Claude

// MARK: - State Aliases
/// RemmyState is the new canonical name for ClaudeState
typealias RemmyState = ClaudeState

/// RemmyStateDot is the new canonical name for ClaudeStateDot
typealias RemmyStateDot = ClaudeStateDot

/// RemmyStateIcon is the new canonical name for ClaudeStateIcon
typealias RemmyStateIcon = ClaudeStateIcon

// MARK: - Button Style Aliases
/// RemmyPrimaryButtonStyle is the new canonical name
typealias RemmyPrimaryButtonStyle = ClaudePrimaryButtonStyle

// MARK: - Font Aliases
extension Font {
    /// Large title for screen headers (18pt bold)
    static let remmyLargeTitle = claudeLargeTitle
    /// Headline for section titles (15pt semibold)
    static let remmyHeadline = claudeHeadline
    /// Body text (14pt regular)
    static let remmyBody = claudeBody
    /// Caption for secondary text (12pt regular)
    static let remmyCaption = claudeCaption
    /// Footnote for tertiary text (11pt regular)
    static let remmyFootnote = claudeFootnote
    /// Monospaced for code/data (13pt monospaced)
    static let remmyMono = claudeMono
}

// MARK: - View Extension Aliases
extension View {
    /// Apply Remmy card background style
    func remmyCardBackground() -> some View {
        claudeCardBackground()
    }

    /// Apply Remmy primary button style
    func remmyPrimaryButton(color: Color = Remmy.orange) -> some View {
        claudePrimaryButton(color: color)
    }
}
