import SwiftUI

// MARK: - Claude Design System
/// Centralized design tokens for Claude Watch app
/// All colors, materials, spacing, and animations in one place
public enum Claude {
    // MARK: - Brand Colors
    /// Primary Claude orange
    static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)        // #FF9500
    /// Light variant for highlights
    static let orangeLight = Color(red: 1.0, green: 0.702, blue: 0.251) // #FFB340
    /// Dark variant for depth
    static let orangeDark = Color(red: 0.8, green: 0.467, blue: 0.0)    // #CC7700

    // MARK: - Semantic Colors
    /// Success state (Apple green)
    static let success = Color(red: 0.204, green: 0.780, blue: 0.349)   // #34C759
    /// Danger/error state (Apple red)
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)      // #FF3B30
    /// Warning state (matches orange)
    static let warning = Color(red: 1.0, green: 0.584, blue: 0.0)       // #FF9500
    /// Info/neutral action (Apple blue)
    static let info = Color(red: 0.0, green: 0.478, blue: 1.0)          // #007AFF

    // MARK: - Surface Colors
    /// Primary background (pure black for OLED)
    static let background = Color.black
    /// Elevated surface level 1
    static let surface1 = Color(red: 0.110, green: 0.110, blue: 0.118)  // #1C1C1E
    /// Elevated surface level 2
    static let surface2 = Color(red: 0.173, green: 0.173, blue: 0.180)  // #2C2C2E
    /// Elevated surface level 3
    static let surface3 = Color(red: 0.227, green: 0.227, blue: 0.235)  // #3A3A3C

    // MARK: - Text Colors
    /// Primary text (white)
    static let textPrimary = Color.white
    /// Secondary text (60% white)
    static let textSecondary = Color(white: 0.6)
    /// Tertiary text (40% white)
    static let textTertiary = Color(white: 0.4)

    // MARK: - High Contrast Support
    /// Returns text secondary color adjusted for high contrast mode
    static func textSecondaryContrast(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color(white: 0.75) : textSecondary
    }

    /// Returns text tertiary color adjusted for high contrast mode
    static func textTertiaryContrast(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color(white: 0.6) : textTertiary
    }

    /// Returns border color for high contrast mode
    static func borderContrast(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color(white: 0.5) : Color.clear
    }

    // MARK: - Materials
    /// Material presets for glass effects
    enum Materials {
        /// Card background material
        static var card: some ShapeStyle { .ultraThinMaterial }
        /// Overlay material for sheets
        static var overlay: some ShapeStyle { .thinMaterial }
        /// Prominent material for important elements
        static var prominent: some ShapeStyle { .regularMaterial }
    }

    // MARK: - Spacing
    /// Spacing tokens for consistent layout
    enum Spacing {
        /// Extra small: 4pt
        static let xs: CGFloat = 4
        /// Small: 8pt
        static let sm: CGFloat = 8
        /// Medium: 12pt
        static let md: CGFloat = 12
        /// Large: 16pt
        static let lg: CGFloat = 16
        /// Extra large: 24pt
        static let xl: CGFloat = 24
    }

    // MARK: - Radius
    /// Corner radius tokens
    enum Radius {
        /// Small radius: 8pt
        static let small: CGFloat = 8
        /// Medium radius: 12pt
        static let medium: CGFloat = 12
        /// Large radius: 16pt
        static let large: CGFloat = 16
        /// Extra large radius: 20pt
        static let xlarge: CGFloat = 20
    }
}

// MARK: - Claude Primary Button Style
/// Standard button style with press feedback
struct ClaudePrimaryButtonStyle: ButtonStyle {
    let color: Color

    init(color: Color = Claude.orange) {
        self.color = color
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.buttonSpring, value: configuration.isPressed)
    }
}

// MARK: - Spring Animation Extensions
extension Animation {
    /// Standard spring animation for interactive button feedback
    static var buttonSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
    }

    /// Bouncy spring for attention-grabbing elements
    static var bouncySpring: Animation {
        .interpolatingSpring(stiffness: 200, damping: 15)
    }

    /// Gentle spring for subtle transitions
    static var gentleSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }

    /// Returns appropriate animation based on Reduce Motion preference
    /// - Parameter reduceMotion: Whether Reduce Motion is enabled
    /// - Returns: Animation or nil if motion should be reduced
    static func buttonSpringIfAllowed(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .buttonSpring
    }

    /// Returns appropriate animation based on Reduce Motion preference
    static func bouncySpringIfAllowed(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .bouncySpring
    }
}

// MARK: - Convenience Extensions
extension View {
    /// Apply Claude card background style
    func claudeCardBackground() -> some View {
        self
            .padding(Claude.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.large)
                    .fill(.ultraThinMaterial)
            )
    }

    /// Apply Claude primary button style
    func claudePrimaryButton(color: Color = Claude.orange) -> some View {
        self.buttonStyle(ClaudePrimaryButtonStyle(color: color))
    }
}
