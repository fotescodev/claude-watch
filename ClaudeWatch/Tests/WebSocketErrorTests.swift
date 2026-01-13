import XCTest
@testable import ClaudeWatch

final class WebSocketErrorTests: XCTestCase {

    // MARK: - isRecoverable Property

    func testHandshakeTimeoutIsRecoverable() {
        XCTAssertTrue(WebSocketError.handshakeTimeout.isRecoverable)
    }

    func testPongTimeoutIsRecoverable() {
        XCTAssertTrue(WebSocketError.pongTimeout.isRecoverable)
    }

    func testSendFailedIsRecoverable() {
        let underlyingError = NSError(domain: "test", code: -1)
        XCTAssertTrue(WebSocketError.sendFailed(underlyingError).isRecoverable)
    }

    func testReceiveFailedIsRecoverable() {
        let underlyingError = NSError(domain: "test", code: -1)
        XCTAssertTrue(WebSocketError.receiveFailed(underlyingError).isRecoverable)
    }

    func testNetworkUnavailableIsRecoverable() {
        XCTAssertTrue(WebSocketError.networkUnavailable.isRecoverable)
    }

    func testInvalidURLIsNotRecoverable() {
        XCTAssertFalse(WebSocketError.invalidURL.isRecoverable)
    }

    func testMaxRetriesExceededIsNotRecoverable() {
        XCTAssertFalse(WebSocketError.maxRetriesExceeded.isRecoverable)
    }

    // MARK: - Localized Description

    func testHandshakeTimeoutDescription() {
        XCTAssertEqual(WebSocketError.handshakeTimeout.localizedDescription, "Connection timeout")
    }

    func testPongTimeoutDescription() {
        XCTAssertEqual(WebSocketError.pongTimeout.localizedDescription, "Server not responding")
    }

    func testInvalidURLDescription() {
        XCTAssertEqual(WebSocketError.invalidURL.localizedDescription, "Invalid server URL")
    }

    func testNetworkUnavailableDescription() {
        XCTAssertEqual(WebSocketError.networkUnavailable.localizedDescription, "Network unavailable")
    }

    func testMaxRetriesExceededDescription() {
        XCTAssertEqual(WebSocketError.maxRetriesExceeded.localizedDescription, "Max reconnection attempts exceeded")
    }

    func testSendFailedDescriptionIncludesUnderlyingError() {
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = WebSocketError.sendFailed(underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Send failed"))
        XCTAssertTrue(error.localizedDescription.contains("Test error"))
    }

    func testReceiveFailedDescriptionIncludesUnderlyingError() {
        let underlyingError = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = WebSocketError.receiveFailed(underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Receive failed"))
        XCTAssertTrue(error.localizedDescription.contains("Test error"))
    }

    // MARK: - Error Protocol Conformance

    func testConformsToErrorProtocol() {
        let error: Error = WebSocketError.handshakeTimeout
        XCTAssertNotNil(error)
    }

    // MARK: - Recoverable vs Non-Recoverable Classification

    func testRecoverableErrorsCount() {
        let recoverableErrors: [WebSocketError] = [
            .handshakeTimeout,
            .pongTimeout,
            .sendFailed(NSError(domain: "test", code: 0)),
            .receiveFailed(NSError(domain: "test", code: 0)),
            .networkUnavailable
        ]

        for error in recoverableErrors {
            XCTAssertTrue(error.isRecoverable, "\(error) should be recoverable")
        }
    }

    func testNonRecoverableErrorsCount() {
        let nonRecoverableErrors: [WebSocketError] = [
            .invalidURL,
            .maxRetriesExceeded
        ]

        for error in nonRecoverableErrors {
            XCTAssertFalse(error.isRecoverable, "\(error) should NOT be recoverable")
        }
    }
}
