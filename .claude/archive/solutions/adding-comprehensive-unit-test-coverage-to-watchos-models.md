---
title: "Adding Comprehensive Unit Test Coverage to watchOS Models"
tags: [testing, swift, xcode, watchos, tdd]
created: 2026-01-18
updated: 2026-01-18
status: solved
---

# Adding Comprehensive Unit Test Coverage to watchOS Models

## Problem
The Claude Watch watchOS application had minimal test coverage, leaving critical business logic untested:
- ApprovalRequest heuristic parsing logic
- FoundationModelsStatus enum display properties
- CloudError conformance to LocalizedError
- Design system tokens and properties
- WatchService state management enums

## Solution

Created five comprehensive test files with 99+ unit tests following XCTest patterns established in the project.

### 1. ApprovalRequestTests.swift (16 tests)

**Location:** `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/ApprovalRequestTests.swift`

Tests the heuristic-based approval request parsing logic used when Foundation Models are unavailable.

#### Key Patterns

**Risk Level Heuristics Test Pattern:**
```swift
func testFileDeleteHasHighestRiskLevel() {
    let data: [String: Any] = [
        "type": "file_delete",
        "description": "Delete a file"
    ]

    let request = ApprovalRequest.from(actionData: data)

    XCTAssertEqual(request.riskLevel, 5)
}
```

**Summary Generation with Fallback Pattern:**
```swift
func testSummaryUsesDescriptionWhenPresent() {
    let data: [String: Any] = [
        "type": "file_edit",
        "description": "Update authentication logic"
    ]

    let request = ApprovalRequest.from(actionData: data)

    XCTAssertEqual(request.summary, "Update authentication logic")
}

func testSummaryGeneratedWhenDescriptionEmpty() {
    let data: [String: Any] = [
        "type": "bash",
        "description": ""
    ]

    let request = ApprovalRequest.from(actionData: data)

    XCTAssertEqual(request.summary, "Perform bash action")
}
```

**Reversibility Logic Pattern:**
```swift
func testFileDeleteIsNotReversible() {
    let data: [String: Any] = [
        "type": "file_delete",
        "description": "Delete a file"
    ]

    let request = ApprovalRequest.from(actionData: data)

    XCTAssertFalse(request.isReversible)
}

func testFileEditIsReversible() {
    // ...
    XCTAssertTrue(request.isReversible)
}
```

### 2. FoundationModelsStatusTests.swift (25 tests)

**Location:** `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/FoundationModelsStatusTests.swift`

Tests computed properties for UI display and equatable conformance of the FoundationModelsStatus enum.

#### Key Patterns

**Display Name Mapping Pattern:**
```swift
func testCheckingDisplayName() {
    XCTAssertEqual(FoundationModelsStatus.checking.displayName, "Checking...")
}

func testAvailableDisplayName() {
    XCTAssertEqual(FoundationModelsStatus.available.displayName, "Ready")
}

func testUnavailableDeviceNotSupportedDisplayName() {
    let status = FoundationModelsStatus.unavailable(.deviceNotSupported)
    XCTAssertEqual(status.displayName, "Device not supported")
}
```

**Icon Mapping Pattern:**
```swift
func testCheckingIcon() {
    XCTAssertEqual(FoundationModelsStatus.checking.icon, "arrow.triangle.2.circlepath")
}

func testUnavailableIcon() {
    let status = FoundationModelsStatus.unavailable(.deviceNotSupported)
    XCTAssertEqual(status.icon, "brain.head.profile.slash")
}
```

**Boolean Property Pattern:**
```swift
func testIsAvailableForAvailableStatus() {
    XCTAssertTrue(FoundationModelsStatus.available.isAvailable)
}

func testIsNotAvailableForCheckingStatus() {
    XCTAssertFalse(FoundationModelsStatus.checking.isAvailable)
}
```

**Equatable Conformance Pattern:**
```swift
func testEquatableUnavailableSameReason() {
    let status1 = FoundationModelsStatus.unavailable(.deviceNotSupported)
    let status2 = FoundationModelsStatus.unavailable(.deviceNotSupported)
    XCTAssertEqual(status1, status2)
}

func testNotEqualUnavailableDifferentReasons() {
    let status1 = FoundationModelsStatus.unavailable(.deviceNotSupported)
    let status2 = FoundationModelsStatus.unavailable(.appleIntelligenceDisabled)
    XCTAssertNotEqual(status1, status2)
}
```

### 3. CloudErrorTests.swift (9 tests)

**Location:** `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/CloudErrorTests.swift`

Verifies error descriptions and LocalizedError protocol conformance.

#### Key Patterns

**Error Description Pattern:**
```swift
func testInvalidCodeDescription() {
    let error = WatchService.CloudError.invalidCode
    XCTAssertEqual(error.errorDescription, "Invalid or expired code. Try again.")
}

func testServerErrorDescription() {
    let error = WatchService.CloudError.serverError(500)
    XCTAssertEqual(error.errorDescription, "Server error (500). Try again.")
}
```

**Associated Value Verification Pattern:**
```swift
func testServerErrorDescriptionWithDifferentCode() {
    let error = WatchService.CloudError.serverError(403)
    XCTAssertEqual(error.errorDescription, "Server error (403). Try again.")
}
```

**Protocol Conformance Pattern:**
```swift
func testConformsToLocalizedError() {
    let error: LocalizedError = WatchService.CloudError.invalidCode
    XCTAssertNotNil(error.errorDescription)
}

func testAllErrorsHaveDescriptions() {
    let errors: [WatchService.CloudError] = [
        .invalidCode,
        .invalidResponse,
        .serverError(200),
        .networkUnavailable,
        .timeout
    ]

    for error in errors {
        XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
        XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
    }
}
```

### 4. DesignSystemTests.swift (40 tests)

**Location:** `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/DesignSystemTests.swift`

Tests Claude design system tokens, colors, animations, typography, and button styles.

#### Key Patterns

**Token Value Verification Pattern:**
```swift
func testSpacingXS() {
    XCTAssertEqual(Claude.Spacing.xs, 4)
}

func testRadiusSmall() {
    XCTAssertEqual(Claude.Radius.small, 8)
}
```

**Design Progression Pattern:**
```swift
func testSpacingProgression() {
    // Each spacing should be larger than the previous
    XCTAssertLessThan(Claude.Spacing.xs, Claude.Spacing.sm)
    XCTAssertLessThan(Claude.Spacing.sm, Claude.Spacing.md)
    XCTAssertLessThan(Claude.Spacing.md, Claude.Spacing.lg)
    XCTAssertLessThan(Claude.Spacing.lg, Claude.Spacing.xl)
}

func testRadiusProgression() {
    XCTAssertLessThan(Claude.Radius.small, Claude.Radius.medium)
    XCTAssertLessThan(Claude.Radius.medium, Claude.Radius.large)
    XCTAssertLessThan(Claude.Radius.large, Claude.Radius.xlarge)
}
```

**Color Existence Pattern:**
```swift
func testBrandColorsExist() {
    let _ = Claude.orange
    let _ = Claude.orangeLight
    let _ = Claude.orangeDark
}

func testSemanticColorsExist() {
    let _ = Claude.success
    let _ = Claude.danger
    let _ = Claude.warning
    let _ = Claude.info
}
```

**Accessibility/Contrast Pattern:**
```swift
func testTextSecondaryContrastStandard() {
    let standardColor = Claude.textSecondaryContrast(.standard)
    let increasedColor = Claude.textSecondaryContrast(.increased)
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
```

**Animation and Reduce Motion Pattern:**
```swift
func testButtonSpringIfAllowedReturnsNilWhenReduced() {
    let animation = Animation.buttonSpringIfAllowed(reduceMotion: true)
    XCTAssertNil(animation)
}

func testButtonSpringIfAllowedReturnsAnimationWhenNotReduced() {
    let animation = Animation.buttonSpringIfAllowed(reduceMotion: false)
    XCTAssertNotNil(animation)
}
```

**Button Style Initialization Pattern:**
```swift
func testClaudePrimaryButtonStyleWithCustomColor() {
    let style = ClaudePrimaryButtonStyle(color: .red)
    XCTAssertNotNil(style)
}
```

### 5. WatchServiceTests.swift (Extended with 9 new tests)

**Location:** `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/WatchServiceTests.swift`

Extended existing test file with additional PermissionMode, SessionStatus, and PendingAction tests.

#### Key Patterns

**Enum Property Verification Pattern:**
```swift
// PermissionMode tests
func testPermissionModeColor() {
    let color = PermissionMode.allowed.color
    XCTAssertNotNil(color)
}

func testPermissionModeDescription() {
    XCTAssertEqual(PermissionMode.allowed.description, "Allowed")
}

func testPermissionModeRawValue() {
    XCTAssertEqual(PermissionMode.allowed.rawValue, "allowed")
}

func testPermissionModeFromRawValue() {
    let mode = PermissionMode(rawValue: "allowed")
    XCTAssertEqual(mode, .allowed)
}
```

**SessionStatus Enum Pattern:**
```swift
// SessionStatus tests
func testSessionStatusColor() {
    let color = SessionStatus.paired.color
    XCTAssertNotNil(color)
}

func testSessionStatusRawValue() {
    XCTAssertEqual(SessionStatus.paired.rawValue, "paired")
}

func testSessionStatusFromRawValue() {
    let status = SessionStatus(rawValue: "paired")
    XCTAssertEqual(status, .paired)
}
```

**Model Property Access Pattern:**
```swift
// PendingAction tests
func testPendingActionTypeColor() {
    let action = PendingAction(
        id: "test-action",
        type: "file_edit",
        title: "Edit",
        description: "Edit a file",
        filePath: "test.swift",
        command: nil,
        timestamp: Date()
    )
    let color = action.typeColor
    XCTAssertNotNil(color)
}

func testPendingActionTimestamp() {
    let now = Date()
    let action = PendingAction(
        id: "test-action",
        type: "file_edit",
        title: "Edit",
        description: "Edit a file",
        filePath: "test.swift",
        command: nil,
        timestamp: now
    )
    XCTAssertEqual(action.timestamp, now)
}

func testPendingActionCommandField() {
    let action = PendingAction(
        id: "test-action",
        type: "bash",
        title: "Command",
        description: "Run a command",
        filePath: nil,
        command: "npm test",
        timestamp: Date()
    )
    XCTAssertEqual(action.command, "npm test")
}
```

## Testing Approach

### 1. Import Pattern
All test files follow consistent imports:
```swift
import XCTest
@testable import ClaudeWatch
```

Optional imports as needed:
```swift
import SwiftUI  // For design system tests
```

### 2. Test Organization
- Mark test categories with `// MARK: -` comments
- Group related tests logically
- One assertion per test or related assertions
- Descriptive test names using pattern: `test<Feature><Scenario><Expected>`

### 3. Setup and Teardown
For stateful tests (WatchServiceTests):
```swift
@MainActor
final class WatchServiceTests: XCTestCase {
    var service: WatchService!

    override func setUp() async throws {
        try await super.setUp()
        service = WatchService.shared
        service.isDemoMode = false
    }

    override func tearDown() async throws {
        service.disconnect()
        service = nil
        try await super.tearDown()
    }
}
```

### 4. Given/When/Then Pattern
When appropriate, use informal Given/When/Then comments:
```swift
func testApproveActionRemovesFromPending() {
    // Given: A pending action
    let action = PendingAction(...)
    service.state.pendingActions = [action]

    // When: Action is approved
    service.approveAction("test-action-1")

    // Then: Action should be removed
    XCTAssertTrue(service.state.pendingActions.isEmpty)
}
```

## Code Coverage Results

| File | Tests | Key Methods Covered |
|------|-------|-------------------|
| ApprovalRequest.swift | 16 | `from(actionData:)` risk levels, summary generation, reversibility logic |
| FoundationModelsStatus.swift | 25 | displayName, icon, isAvailable, Equatable conformance |
| CloudError | 9 | errorDescription for all cases, LocalizedError protocol |
| DesignSystem | 40 | Spacing/Radius tokens, Colors, Animations, Typography, Button styles |
| WatchService | +9 | PermissionMode, SessionStatus, PendingAction properties |
| **TOTAL** | **99+** | — |

## Key Takeaways

1. **Heuristic Logic Testing**: When AI-based parsing unavailable, test fallback heuristics thoroughly across action types
2. **Display Property Testing**: For enums with computed properties used in UI, verify all cases and progressions
3. **Error Conformance**: Always test protocol conformance (LocalizedError, Equatable, etc.)
4. **Design System Testing**: Token values should be tested for correctness AND progression (xs < sm < md)
5. **Accessibility Testing**: Verify contrast modes and reduce motion behavior
6. **State Management**: Use @MainActor for SwiftUI/watchOS service tests with proper async setup/teardown

## Testing Commands

```bash
# Run all tests
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -enableCodeCoverage YES test

# Run specific test file
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch test -only ClaudeWatchTests/ApprovalRequestTests

# View code coverage
open -a Xcode ClaudeWatch.xcodeproj/
# Then: Product > Scheme > Edit Scheme > Test > Code Coverage
```

## Files Modified

- Created: `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/ApprovalRequestTests.swift`
- Created: `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/FoundationModelsStatusTests.swift`
- Created: `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/CloudErrorTests.swift`
- Created: `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/DesignSystemTests.swift`
- Extended: `/Users/dfotesco/claude-watch/claude-watch/ClaudeWatch/Tests/WatchServiceTests.swift`
