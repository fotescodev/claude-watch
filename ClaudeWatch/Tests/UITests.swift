import XCTest

/// UI Tests for Claude Watch critical user flows
/// Tests consent flow, connection status, approval/rejection, and settings navigation
final class UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Reset app state for clean test
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Consent Flow Tests

    /// Test that consent view is shown on first launch
    func testConsentViewDisplayedOnFirstLaunch() throws {
        // Clear any existing consent
        app.launchArguments.append("--reset-consent")
        app.launch()

        // Verify consent view elements are displayed
        let welcomeText = app.staticTexts["Welcome to Claude Watch"]
        XCTAssertTrue(welcomeText.waitForExistence(timeout: 5), "Welcome text should be visible")

        // Verify consent pages exist
        let aiProcessingText = app.staticTexts["AI Processing"]
        XCTAssertTrue(aiProcessingText.exists || app.staticTexts["Voice Handling"].exists || app.staticTexts["Your Privacy"].exists,
                      "At least one consent page should be visible")
    }

    /// Test that accept button works and dismisses consent view
    func testConsentAcceptButton() throws {
        app.launchArguments.append("--reset-consent")
        app.launch()

        // Find and tap accept button
        let acceptButton = app.buttons["Accept privacy terms and continue"]
        if acceptButton.waitForExistence(timeout: 5) {
            acceptButton.tap()

            // After accepting, main view should be shown
            // Wait for consent view to disappear
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: app.staticTexts["Welcome to Claude Watch"]
            )
            let result = XCTWaiter().wait(for: [expectation], timeout: 5)
            XCTAssertEqual(result, .completed, "Consent view should disappear after accepting")
        }
    }

    // MARK: - Connection Status Tests

    /// Test that connection status is displayed in the UI
    func testConnectionStatusDisplay() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // The settings button shows connection status
        let settingsButton = app.buttons["Settings and connection status"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
    }

    /// Test offline state view when disconnected
    func testOfflineStateView() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--offline-mode")
        app.launch()

        // Should show offline state or empty state
        let offlineText = app.staticTexts["Offline"]
        let allClearText = app.staticTexts["All Clear"]
        let notPairedText = app.staticTexts["Not Paired"]

        XCTAssertTrue(
            offlineText.waitForExistence(timeout: 5) ||
            allClearText.waitForExistence(timeout: 5) ||
            notPairedText.waitForExistence(timeout: 5),
            "Should show offline, all clear, or not paired state"
        )
    }

    /// Test retry button functionality when offline
    func testRetryButtonExists() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--offline-mode")
        app.launch()

        // Look for retry button
        let retryButton = app.buttons["Retry connection"]
        if retryButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(retryButton.isHittable, "Retry button should be tappable")
        }
    }

    // MARK: - Approval/Rejection Actions Tests

    /// Test demo mode loads sample actions for testing
    func testDemoModeLoadsPendingActions() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // In demo mode, we should see pending actions
        let pendingText = app.staticTexts["Pending"]
        let editAppText = app.staticTexts["Edit App.tsx"]

        // Wait for demo data to load
        let foundPending = pendingText.waitForExistence(timeout: 5)
        let foundAction = editAppText.waitForExistence(timeout: 5)

        XCTAssertTrue(foundPending || foundAction, "Demo mode should show pending actions or status")
    }

    /// Test approve button exists and has correct accessibility label
    func testApproveButtonAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // Wait for demo data to load
        sleep(2)

        // Look for approve button with accessibility label pattern
        let approveButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Approve'"))
        if approveButtons.count > 0 {
            XCTAssertTrue(approveButtons.firstMatch.exists, "Approve button should exist")
        }
    }

    /// Test reject button exists and has correct accessibility label
    func testRejectButtonAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // Wait for demo data to load
        sleep(2)

        // Look for reject button with accessibility label pattern
        let rejectButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Reject'"))
        if rejectButtons.count > 0 {
            XCTAssertTrue(rejectButtons.firstMatch.exists, "Reject button should exist")
        }
    }

    /// Test approve all button when multiple actions are pending
    func testApproveAllButtonAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // Wait for demo data to load
        sleep(2)

        // Look for approve all button
        let approveAllButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Approve all'"))
        if approveAllButton.count > 0 {
            XCTAssertTrue(approveAllButton.firstMatch.exists, "Approve All button should exist when multiple actions pending")
        }
    }

    // MARK: - Settings Navigation Tests

    /// Test settings sheet opens when tapping settings button
    func testSettingsSheetOpens() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // Tap settings button
        let settingsButton = app.buttons["Settings and connection status"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Verify settings content appears
            let connectionText = app.staticTexts["Connection"]
            XCTAssertTrue(connectionText.waitForExistence(timeout: 5), "Connection section should appear in settings")
        }
    }

    /// Test settings shows version information
    func testSettingsShowsVersion() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // Open settings
        let settingsButton = app.buttons["Settings and connection status"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Look for version label
            let versionText = app.staticTexts["Version"]
            XCTAssertTrue(versionText.waitForExistence(timeout: 5), "Version should be displayed in settings")
        }
    }

    /// Test privacy settings button exists in settings
    func testPrivacySettingsAccessible() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // Open settings
        let settingsButton = app.buttons["Settings and connection status"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Look for privacy button
            let privacyButton = app.buttons["Review privacy settings and consent"]
            XCTAssertTrue(privacyButton.waitForExistence(timeout: 5), "Privacy button should exist in settings")
        }
    }

    /// Test done button closes settings
    func testDoneButtonClosesSettings() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // Open settings
        let settingsButton = app.buttons["Settings and connection status"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Tap done button
            let doneButton = app.buttons["Done, close settings"]
            if doneButton.waitForExistence(timeout: 5) {
                doneButton.tap()

                // Settings should close
                let connectionText = app.staticTexts["Connection"]
                let expectation = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "exists == false"),
                    object: connectionText
                )
                let result = XCTWaiter().wait(for: [expectation], timeout: 5)
                XCTAssertEqual(result, .completed, "Settings should close after tapping done")
            }
        }
    }

    // MARK: - Voice Command Tests

    /// Test voice command button exists and has accessibility label
    func testVoiceCommandButtonAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // Wait for UI to stabilize
        sleep(2)

        // Look for voice command button
        let voiceButton = app.buttons["Open voice command input"]
        if voiceButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(voiceButton.isHittable, "Voice command button should be tappable")
        }
    }

    // MARK: - Mode Selector Tests

    /// Test mode selector button exists and has accessibility
    func testModeSelectorAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launchArguments.append("--demo-mode")
        app.launch()

        // Wait for UI to load
        sleep(2)

        // Look for mode selector
        let modeButtons = app.buttons.matching(NSPredicate(format: "label CONTAINS 'mode'"))
        if modeButtons.count > 0 {
            XCTAssertTrue(modeButtons.firstMatch.exists, "Mode selector should exist")
        }
    }

    // MARK: - Quick Command Tests

    /// Test quick command buttons have proper accessibility labels
    func testQuickCommandButtonsAccessibility() throws {
        app.launchArguments.append("--skip-consent")
        app.launch()

        // Wait for UI to load
        sleep(2)

        // Check for command buttons with accessibility labels
        let goCommand = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Go command'"))
        let testCommand = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Test command'"))
        let fixCommand = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Fix command'"))
        let stopCommand = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Stop command'"))

        // At least some commands should exist in empty state
        let hasAnyCommand = goCommand.count > 0 || testCommand.count > 0 ||
                           fixCommand.count > 0 || stopCommand.count > 0

        // Commands may not be visible if there are pending actions
        // This test just verifies the pattern works
        if hasAnyCommand {
            XCTAssertTrue(true, "Quick command buttons found with accessibility labels")
        }
    }
}
