import SwiftUI

// MARK: - Claude Design System V2
/// Centralized design tokens for Claude Watch app
/// Hybrid color strategy: Anthropic brand + Apple semantic colors
/// All colors, materials, spacing, and animations in one place
public enum Claude {
    // MARK: - Anthropic Brand Colors (Logo, Headers, Primary Accent)
    /// Primary Anthropic orange - use for logo, headers, brand identity
    static let anthropicOrange = Color(red: 0.851, green: 0.467, blue: 0.341)  // #d97757
    /// Dark background from Anthropic palette - use for elevated surfaces
    static let anthropicDark = Color(red: 0.078, green: 0.078, blue: 0.075)    // #141413
    /// Light text from Anthropic palette - use on dark backgrounds
    static let anthropicLight = Color(red: 0.980, green: 0.976, blue: 0.961)   // #faf9f5

    // Legacy brand colors (kept for backward compatibility)
    /// Primary accent (legacy - maps to anthropicOrange)
    static let orange = Color(red: 0.851, green: 0.467, blue: 0.341)           // #d97757
    /// Light variant for highlights
    static let orangeLight = Color(red: 0.902, green: 0.569, blue: 0.463)      // #e69176
    /// Dark variant for depth
    static let orangeDark = Color(red: 0.749, green: 0.365, blue: 0.239)       // #bf5d3d

    // MARK: - Apple Semantic Colors (Native Feel, Accessibility)
    /// Success state - Apple green for approve, checkmarks, completion
    static let success = Color.green      // #34C759
    /// Warning state - Apple orange for approval needed, attention
    static let warning = Color.orange     // #FF9500
    /// Danger/error state - Apple red for reject, errors, destructive
    static let danger = Color.red         // #FF3B30
    /// Info/working state - Apple blue for active, progress
    static let info = Color.blue          // #007AFF
    /// Idle state - Apple gray for inactive, neutral
    static let idle = Color.gray          // #8E8E93

    // MARK: - State Colors (V2 5-State Model)
    /// Returns the color for a given Claude state
    /// Delegates to ClaudeState.color for consistency
    static func color(for state: ClaudeState) -> Color {
        state.color
    }

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

    // MARK: - Liquid Glass (watchOS 26)
    /// Glass effect variants for Liquid Glass design
    enum LiquidGlass {
        /// Standard glass with refraction
        case regular
        /// Clear glass with subtle effect
        case clear
        /// Identity (minimal effect)
        case identity
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
        /// Button radius: 22pt (V2 standard for pill buttons)
        static let button: CGFloat = 22
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

// MARK: - Typography Extensions
extension Font {
    /// Large title for screen headers (18pt bold)
    static let claudeLargeTitle = Font.system(size: 18, weight: .bold)
    /// Headline for section titles (15pt semibold)
    static let claudeHeadline = Font.system(size: 15, weight: .semibold)
    /// Body text (14pt regular)
    static let claudeBody = Font.system(size: 14, weight: .regular)
    /// Caption for secondary text (12pt regular)
    static let claudeCaption = Font.system(size: 12, weight: .regular)
    /// Footnote for tertiary text (11pt regular)
    static let claudeFootnote = Font.system(size: 11, weight: .regular)
    /// Monospaced for code/data (13pt monospaced)
    static let claudeMono = Font.system(size: 13, weight: .medium, design: .monospaced)
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

    /// Apply Liquid Glass effect with backwards compatibility (watchOS 26+)
    /// Falls back to material background on older versions
    @ViewBuilder
    func glassEffectCompat<S: Shape>(_ shape: S) -> some View {
        if #available(watchOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }

    /// Apply interactive Liquid Glass effect (responds to touch)
    /// Falls back to material background on older versions
    @ViewBuilder
    func glassEffectInteractive<S: Shape>(_ shape: S) -> some View {
        if #available(watchOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(shape.fill(.ultraThinMaterial))
        }
    }

    /// Apply Liquid Glass card style with rounded rectangle
    @ViewBuilder
    func liquidGlassCard(cornerRadius: CGFloat = Claude.Radius.large) -> some View {
        glassEffectCompat(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Apply interactive Liquid Glass card style (responds to touch)
    @ViewBuilder
    func liquidGlassCardInteractive(cornerRadius: CGFloat = Claude.Radius.large) -> some View {
        glassEffectInteractive(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Apply glassEffectID for morphing transitions (watchOS 26+)
    /// Falls back to matchedGeometryEffect on older versions for smooth transitions
    @ViewBuilder
    func glassEffectIDCompat(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(watchOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

// MARK: - Glass Button Style (watchOS 26+)
/// Button style that uses Liquid Glass on watchOS 26+, falls back to material on older versions
struct GlassButtonStyleCompat: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassButtonLabel(configuration: configuration, isProminent: false)
    }
}

/// Prominent glass button style for primary actions
struct GlassProminentButtonStyleCompat: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassButtonLabel(configuration: configuration, isProminent: true)
    }
}

/// Helper view that applies glass effect based on OS availability
private struct GlassButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool

    var body: some View {
        if #available(watchOS 26.0, *) {
            configuration.label
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(isProminent ? .regular.tint(Claude.orange).interactive() : .regular.interactive())
        } else {
            if isProminent {
                configuration.label
                    .font(.body.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Claude.orange, Claude.orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                    .animation(.buttonSpring, value: configuration.isPressed)
            } else {
                configuration.label
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                    .animation(.buttonSpring, value: configuration.isPressed)
            }
        }
    }
}

extension ButtonStyle where Self == GlassButtonStyleCompat {
    /// Glass button style with backwards compatibility
    static var glassCompat: GlassButtonStyleCompat { GlassButtonStyleCompat() }
}

extension ButtonStyle where Self == GlassProminentButtonStyleCompat {
    /// Prominent glass button style with backwards compatibility
    static var glassProminentCompat: GlassProminentButtonStyleCompat { GlassProminentButtonStyleCompat() }
}
