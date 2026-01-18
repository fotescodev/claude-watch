import XCTest
import SwiftUI
@testable import ClaudeWatch

final class DesignSystemTests: XCTestCase {

    // MARK: - Spacing Tokens

    func testSpacingXS() {
        XCTAssertEqual(Claude.Spacing.xs, 4)
    }

    func testSpacingSM() {
        XCTAssertEqual(Claude.Spacing.sm, 8)
    }

    func testSpacingMD() {
        XCTAssertEqual(Claude.Spacing.md, 12)
    }

    func testSpacingLG() {
        XCTAssertEqual(Claude.Spacing.lg, 16)
    }

    func testSpacingXL() {
        XCTAssertEqual(Claude.Spacing.xl, 24)
    }

    // MARK: - Radius Tokens

    func testRadiusSmall() {
        XCTAssertEqual(Claude.Radius.small, 8)
    }

    func testRadiusMedium() {
        XCTAssertEqual(Claude.Radius.medium, 12)
    }

    func testRadiusLarge() {
        XCTAssertEqual(Claude.Radius.large, 16)
    }

    func testRadiusXLarge() {
        XCTAssertEqual(Claude.Radius.xlarge, 20)
    }

    // MARK: - Spacing Progression

    func testSpacingProgression() {
        // Each spacing should be larger than the previous
        XCTAssertLessThan(Claude.Spacing.xs, Claude.Spacing.sm)
        XCTAssertLessThan(Claude.Spacing.sm, Claude.Spacing.md)
        XCTAssertLessThan(Claude.Spacing.md, Claude.Spacing.lg)
        XCTAssertLessThan(Claude.Spacing.lg, Claude.Spacing.xl)
    }

    // MARK: - Radius Progression

    func testRadiusProgression() {
        // Each radius should be larger than the previous
        XCTAssertLessThan(Claude.Radius.small, Claude.Radius.medium)
        XCTAssertLessThan(Claude.Radius.medium, Claude.Radius.large)
        XCTAssertLessThan(Claude.Radius.large, Claude.Radius.xlarge)
    }

    // MARK: - Brand Colors Exist

    func testBrandColorsExist() {
        // Just verify the colors can be created (type checking)
        let _ = Claude.orange
        let _ = Claude.orangeLight
        let _ = Claude.orangeDark
    }

    // MARK: - Semantic Colors Exist

    func testSemanticColorsExist() {
        let _ = Claude.success
        let _ = Claude.danger
        let _ = Claude.warning
        let _ = Claude.info
    }

    // MARK: - Surface Colors Exist

    func testSurfaceColorsExist() {
        let _ = Claude.background
        let _ = Claude.surface1
        let _ = Claude.surface2
        let _ = Claude.surface3
    }

    // MARK: - Text Colors Exist

    func testTextColorsExist() {
        let _ = Claude.textPrimary
        let _ = Claude.textSecondary
        let _ = Claude.textTertiary
    }

    // MARK: - High Contrast Support

    func testTextSecondaryContrastStandard() {
        let standardColor = Claude.textSecondaryContrast(.standard)
        let increasedColor = Claude.textSecondaryContrast(.increased)
        // In increased contrast mode, the color should be different (brighter)
        XCTAssertNotEqual(standardColor.description, increasedColor.description)
    }

    func testTextTertiaryContrastStandard() {
        let standardColor = Claude.textTertiaryContrast(.standard)
        let increasedColor = Claude.textTertiaryContrast(.increased)
        // In increased contrast mode, the color should be different (brighter)
        XCTAssertNotEqual(standardColor.description, increasedColor.description)
    }

    func testBorderContrastStandard() {
        let standardColor = Claude.borderContrast(.standard)
        let increasedColor = Claude.borderContrast(.increased)
        // Standard should be clear, increased should have visible border
        XCTAssertEqual(standardColor, Color.clear)
        XCTAssertNotEqual(increasedColor, Color.clear)
    }

    // MARK: - Liquid Glass Enum Cases

    func testLiquidGlassVariantsExist() {
        // Verify all cases exist
        let _ = Claude.LiquidGlass.regular
        let _ = Claude.LiquidGlass.clear
        let _ = Claude.LiquidGlass.identity
    }
}

// MARK: - Animation Extension Tests

final class AnimationExtensionTests: XCTestCase {

    func testButtonSpringExists() {
        let _ = Animation.buttonSpring
    }

    func testBouncySpringExists() {
        let _ = Animation.bouncySpring
    }

    func testGentleSpringExists() {
        let _ = Animation.gentleSpring
    }

    func testButtonSpringIfAllowedReturnsNilWhenReduced() {
        let animation = Animation.buttonSpringIfAllowed(reduceMotion: true)
        XCTAssertNil(animation)
    }

    func testButtonSpringIfAllowedReturnsAnimationWhenNotReduced() {
        let animation = Animation.buttonSpringIfAllowed(reduceMotion: false)
        XCTAssertNotNil(animation)
    }

    func testBouncySpringIfAllowedReturnsNilWhenReduced() {
        let animation = Animation.bouncySpringIfAllowed(reduceMotion: true)
        XCTAssertNil(animation)
    }

    func testBouncySpringIfAllowedReturnsAnimationWhenNotReduced() {
        let animation = Animation.bouncySpringIfAllowed(reduceMotion: false)
        XCTAssertNotNil(animation)
    }
}

// MARK: - Typography Tests

final class TypographyTests: XCTestCase {

    func testClaudeLargeTitleExists() {
        let _ = Font.claudeLargeTitle
    }

    func testClaudeHeadlineExists() {
        let _ = Font.claudeHeadline
    }

    func testClaudeBodyExists() {
        let _ = Font.claudeBody
    }

    func testClaudeCaptionExists() {
        let _ = Font.claudeCaption
    }

    func testClaudeFootnoteExists() {
        let _ = Font.claudeFootnote
    }

    func testClaudeMonoExists() {
        let _ = Font.claudeMono
    }
}

// MARK: - Button Style Tests

final class ButtonStyleTests: XCTestCase {

    func testClaudePrimaryButtonStyleExists() {
        let _ = ClaudePrimaryButtonStyle()
    }

    func testClaudePrimaryButtonStyleWithCustomColor() {
        let style = ClaudePrimaryButtonStyle(color: .red)
        XCTAssertNotNil(style)
    }

    func testGlassButtonStyleCompatExists() {
        let _ = GlassButtonStyleCompat()
    }

    func testGlassProminentButtonStyleCompatExists() {
        let _ = GlassProminentButtonStyleCompat()
    }
}
