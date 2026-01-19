import XCTest
@testable import ClaudeWatch

final class CloudErrorTests: XCTestCase {

    // MARK: - Error Descriptions

    func testInvalidCodeDescription() {
        let error = WatchService.CloudError.invalidCode
        XCTAssertEqual(error.errorDescription, "Invalid or expired code. Try again.")
    }

    func testInvalidResponseDescription() {
        let error = WatchService.CloudError.invalidResponse
        XCTAssertEqual(error.errorDescription, "Unexpected server response.")
    }

    func testServerErrorDescription() {
        let error = WatchService.CloudError.serverError(500)
        XCTAssertEqual(error.errorDescription, "Server error (500). Try again.")
    }

    func testServerErrorDescriptionWithDifferentCode() {
        let error = WatchService.CloudError.serverError(403)
        XCTAssertEqual(error.errorDescription, "Server error (403). Try again.")
    }

    func testNetworkUnavailableDescription() {
        let error = WatchService.CloudError.networkUnavailable
        XCTAssertEqual(error.errorDescription, "No network connection.")
    }

    func testTimeoutDescription() {
        let error = WatchService.CloudError.timeout
        XCTAssertEqual(error.errorDescription, "Connection timed out.")
    }

    // MARK: - LocalizedError Conformance

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

    // MARK: - Error Protocol Conformance

    func testConformsToErrorProtocol() {
        let error: Error = WatchService.CloudError.invalidCode
        XCTAssertNotNil(error)
    }
}
