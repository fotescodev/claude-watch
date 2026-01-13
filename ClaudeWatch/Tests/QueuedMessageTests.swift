import XCTest
@testable import ClaudeWatch

final class QueuedMessageTests: XCTestCase {

    // MARK: - Priority Comparison

    func testLowPriorityLessThanNormal() {
        XCTAssertTrue(QueuedMessage.MessagePriority.low < .normal)
    }

    func testNormalPriorityLessThanHigh() {
        XCTAssertTrue(QueuedMessage.MessagePriority.normal < .high)
    }

    func testLowPriorityLessThanHigh() {
        XCTAssertTrue(QueuedMessage.MessagePriority.low < .high)
    }

    func testPriorityRawValues() {
        XCTAssertEqual(QueuedMessage.MessagePriority.low.rawValue, 0)
        XCTAssertEqual(QueuedMessage.MessagePriority.normal.rawValue, 1)
        XCTAssertEqual(QueuedMessage.MessagePriority.high.rawValue, 2)
    }

    // MARK: - canRetry Property

    func testCanRetryWhenRetryCountZero() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            retryCount: 0,
            priority: .normal
        )
        XCTAssertTrue(message.canRetry)
    }

    func testCanRetryWhenRetryCountOne() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            retryCount: 1,
            priority: .normal
        )
        XCTAssertTrue(message.canRetry)
    }

    func testCanRetryWhenRetryCountTwo() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            retryCount: 2,
            priority: .normal
        )
        XCTAssertTrue(message.canRetry)
    }

    func testCannotRetryWhenRetryCountEqualsMaxRetries() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            retryCount: 3,
            priority: .normal
        )
        XCTAssertFalse(message.canRetry)
    }

    func testCannotRetryWhenRetryCountExceedsMaxRetries() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            retryCount: 5,
            priority: .normal
        )
        XCTAssertFalse(message.canRetry)
    }

    // MARK: - Identifiable Conformance

    func testUniqueIdentifiers() {
        let message1 = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            priority: .normal
        )
        let message2 = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            priority: .normal
        )

        XCTAssertNotEqual(message1.id, message2.id)
    }

    // MARK: - Priority Sorting

    func testPrioritySorting() {
        let lowPriority = QueuedMessage(
            payload: ["type": "low"],
            createdAt: Date(),
            priority: .low
        )
        let normalPriority = QueuedMessage(
            payload: ["type": "normal"],
            createdAt: Date(),
            priority: .normal
        )
        let highPriority = QueuedMessage(
            payload: ["type": "high"],
            createdAt: Date(),
            priority: .high
        )

        var messages = [lowPriority, normalPriority, highPriority]
        messages.sort { $0.priority > $1.priority }

        XCTAssertEqual(messages[0].priority, .high)
        XCTAssertEqual(messages[1].priority, .normal)
        XCTAssertEqual(messages[2].priority, .low)
    }

    func testMixedPrioritySorting() {
        let messages = [
            QueuedMessage(payload: [:], createdAt: Date(), priority: .normal),
            QueuedMessage(payload: [:], createdAt: Date(), priority: .high),
            QueuedMessage(payload: [:], createdAt: Date(), priority: .low),
            QueuedMessage(payload: [:], createdAt: Date(), priority: .high),
            QueuedMessage(payload: [:], createdAt: Date(), priority: .normal)
        ]

        let sorted = messages.sorted { $0.priority > $1.priority }

        // First two should be high priority
        XCTAssertEqual(sorted[0].priority, .high)
        XCTAssertEqual(sorted[1].priority, .high)
        // Next two should be normal priority
        XCTAssertEqual(sorted[2].priority, .normal)
        XCTAssertEqual(sorted[3].priority, .normal)
        // Last should be low priority
        XCTAssertEqual(sorted[4].priority, .low)
    }

    // MARK: - Default Values

    func testDefaultMaxRetries() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            priority: .normal
        )
        XCTAssertEqual(message.maxRetries, 3)
    }

    func testDefaultRetryCount() {
        let message = QueuedMessage(
            payload: ["type": "test"],
            createdAt: Date(),
            priority: .normal
        )
        XCTAssertEqual(message.retryCount, 0)
    }

    // MARK: - Payload Storage

    func testPayloadStorage() {
        let payload: [String: Any] = [
            "type": "action_response",
            "action_id": "test-123",
            "approved": true
        ]
        let message = QueuedMessage(
            payload: payload,
            createdAt: Date(),
            priority: .high
        )

        XCTAssertEqual(message.payload["type"] as? String, "action_response")
        XCTAssertEqual(message.payload["action_id"] as? String, "test-123")
        XCTAssertEqual(message.payload["approved"] as? Bool, true)
    }
}
