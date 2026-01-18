import XCTest
@testable import ClaudeWatch

final class FoundationModelsStatusTests: XCTestCase {

    // MARK: - Display Names

    func testCheckingDisplayName() {
        XCTAssertEqual(FoundationModelsStatus.checking.displayName, "Checking...")
    }

    func testAvailableDisplayName() {
        XCTAssertEqual(FoundationModelsStatus.available.displayName, "Ready")
    }

    func testDownloadingDisplayName() {
        XCTAssertEqual(FoundationModelsStatus.downloading.displayName, "Downloading...")
    }

    func testUnavailableDeviceNotSupportedDisplayName() {
        let status = FoundationModelsStatus.unavailable(.deviceNotSupported)
        XCTAssertEqual(status.displayName, "Device not supported")
    }

    func testUnavailableAppleIntelligenceDisabledDisplayName() {
        let status = FoundationModelsStatus.unavailable(.appleIntelligenceDisabled)
        XCTAssertEqual(status.displayName, "Enable Apple Intelligence")
    }

    func testUnavailablePlatformNotSupportedDisplayName() {
        let status = FoundationModelsStatus.unavailable(.platformNotSupported)
        XCTAssertEqual(status.displayName, "Not available on watchOS")
    }

    func testUnavailableUnknownDisplayName() {
        let status = FoundationModelsStatus.unavailable(.unknown)
        XCTAssertEqual(status.displayName, "Unavailable")
    }

    // MARK: - Icons

    func testCheckingIcon() {
        XCTAssertEqual(FoundationModelsStatus.checking.icon, "arrow.triangle.2.circlepath")
    }

    func testAvailableIcon() {
        XCTAssertEqual(FoundationModelsStatus.available.icon, "brain")
    }

    func testDownloadingIcon() {
        XCTAssertEqual(FoundationModelsStatus.downloading.icon, "arrow.down.circle")
    }

    func testUnavailableIcon() {
        let status = FoundationModelsStatus.unavailable(.deviceNotSupported)
        XCTAssertEqual(status.icon, "brain.head.profile.slash")
    }

    // MARK: - isAvailable Property

    func testIsAvailableForAvailableStatus() {
        XCTAssertTrue(FoundationModelsStatus.available.isAvailable)
    }

    func testIsNotAvailableForCheckingStatus() {
        XCTAssertFalse(FoundationModelsStatus.checking.isAvailable)
    }

    func testIsNotAvailableForDownloadingStatus() {
        XCTAssertFalse(FoundationModelsStatus.downloading.isAvailable)
    }

    func testIsNotAvailableForUnavailableStatus() {
        XCTAssertFalse(FoundationModelsStatus.unavailable(.deviceNotSupported).isAvailable)
    }

    // MARK: - Equatable Conformance

    func testEquatableChecking() {
        XCTAssertEqual(FoundationModelsStatus.checking, FoundationModelsStatus.checking)
    }

    func testEquatableAvailable() {
        XCTAssertEqual(FoundationModelsStatus.available, FoundationModelsStatus.available)
    }

    func testEquatableDownloading() {
        XCTAssertEqual(FoundationModelsStatus.downloading, FoundationModelsStatus.downloading)
    }

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

    func testNotEqualDifferentCases() {
        XCTAssertNotEqual(FoundationModelsStatus.checking, FoundationModelsStatus.available)
        XCTAssertNotEqual(FoundationModelsStatus.available, FoundationModelsStatus.downloading)
    }
}

// MARK: - FoundationModelsUnavailabilityReason Tests

final class FoundationModelsUnavailabilityReasonTests: XCTestCase {

    // MARK: - Display Names

    func testDeviceNotSupportedDisplayName() {
        XCTAssertEqual(FoundationModelsUnavailabilityReason.deviceNotSupported.displayName, "Device not supported")
    }

    func testAppleIntelligenceDisabledDisplayName() {
        XCTAssertEqual(FoundationModelsUnavailabilityReason.appleIntelligenceDisabled.displayName, "Enable Apple Intelligence")
    }

    func testPlatformNotSupportedDisplayName() {
        XCTAssertEqual(FoundationModelsUnavailabilityReason.platformNotSupported.displayName, "Not available on watchOS")
    }

    func testUnknownDisplayName() {
        XCTAssertEqual(FoundationModelsUnavailabilityReason.unknown.displayName, "Unavailable")
    }

    // MARK: - Descriptions

    func testDeviceNotSupportedDescription() {
        let description = FoundationModelsUnavailabilityReason.deviceNotSupported.description
        XCTAssertTrue(description.contains("iPhone 15 Pro"))
        XCTAssertTrue(description.contains("M1 Mac"))
    }

    func testAppleIntelligenceDisabledDescription() {
        let description = FoundationModelsUnavailabilityReason.appleIntelligenceDisabled.description
        XCTAssertTrue(description.contains("Apple Intelligence"))
        XCTAssertTrue(description.contains("Settings"))
    }

    func testPlatformNotSupportedDescription() {
        let description = FoundationModelsUnavailabilityReason.platformNotSupported.description
        XCTAssertTrue(description.contains("watchOS"))
        XCTAssertTrue(description.contains("iPhone") || description.contains("iPad") || description.contains("Mac"))
    }

    func testUnknownDescription() {
        let description = FoundationModelsUnavailabilityReason.unknown.description
        XCTAssertTrue(description.contains("unavailable"))
    }

    // MARK: - Equatable Conformance

    func testEquatableSameReason() {
        XCTAssertEqual(FoundationModelsUnavailabilityReason.deviceNotSupported, FoundationModelsUnavailabilityReason.deviceNotSupported)
        XCTAssertEqual(FoundationModelsUnavailabilityReason.appleIntelligenceDisabled, FoundationModelsUnavailabilityReason.appleIntelligenceDisabled)
        XCTAssertEqual(FoundationModelsUnavailabilityReason.platformNotSupported, FoundationModelsUnavailabilityReason.platformNotSupported)
        XCTAssertEqual(FoundationModelsUnavailabilityReason.unknown, FoundationModelsUnavailabilityReason.unknown)
    }

    func testNotEqualDifferentReasons() {
        XCTAssertNotEqual(FoundationModelsUnavailabilityReason.deviceNotSupported, FoundationModelsUnavailabilityReason.appleIntelligenceDisabled)
        XCTAssertNotEqual(FoundationModelsUnavailabilityReason.platformNotSupported, FoundationModelsUnavailabilityReason.unknown)
    }
}
