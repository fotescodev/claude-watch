import XCTest
@testable import ClaudeWatch

final class ReconnectionConfigTests: XCTestCase {

    var config: ReconnectionConfig!

    override func setUp() {
        super.setUp()
        config = ReconnectionConfig()
    }

    override func tearDown() {
        config = nil
        super.tearDown()
    }

    // MARK: - Default Values

    func testDefaultValues() {
        XCTAssertEqual(config.initialDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 60.0)
        XCTAssertEqual(config.multiplier, 2.0)
        XCTAssertEqual(config.maxRetries, 10)
        XCTAssertEqual(config.jitterFactor, 0.2)
    }

    // MARK: - Exponential Backoff

    func testDelayAttemptZero() {
        // First attempt should be around 1 second (±20% jitter)
        let delay = config.delay(forAttempt: 0)
        XCTAssertGreaterThanOrEqual(delay, 0.8) // 1.0 - 20%
        XCTAssertLessThanOrEqual(delay, 1.2)    // 1.0 + 20%
    }

    func testDelayAttemptOne() {
        // Second attempt should be around 2 seconds (±20% jitter)
        let delay = config.delay(forAttempt: 1)
        XCTAssertGreaterThanOrEqual(delay, 1.6) // 2.0 - 20%
        XCTAssertLessThanOrEqual(delay, 2.4)    // 2.0 + 20%
    }

    func testDelayAttemptTwo() {
        // Third attempt should be around 4 seconds (±20% jitter)
        let delay = config.delay(forAttempt: 2)
        XCTAssertGreaterThanOrEqual(delay, 3.2) // 4.0 - 20%
        XCTAssertLessThanOrEqual(delay, 4.8)    // 4.0 + 20%
    }

    func testDelayAttemptThree() {
        // Fourth attempt should be around 8 seconds (±20% jitter)
        let delay = config.delay(forAttempt: 3)
        XCTAssertGreaterThanOrEqual(delay, 6.4) // 8.0 - 20%
        XCTAssertLessThanOrEqual(delay, 9.6)    // 8.0 + 20%
    }

    func testDelayCapsAtMaxDelay() {
        // At high attempt counts, delay should cap at maxDelay (60s)
        let delay = config.delay(forAttempt: 10)
        XCTAssertLessThanOrEqual(delay, 72.0)   // 60.0 + 20%
        XCTAssertGreaterThanOrEqual(delay, 48.0) // 60.0 - 20%
    }

    func testDelayNeverBelowMinimum() {
        // Even with negative jitter, delay should never go below 0.1
        for _ in 0..<100 {
            let delay = config.delay(forAttempt: 0)
            XCTAssertGreaterThanOrEqual(delay, 0.1)
        }
    }

    func testDelayIncreases() {
        // Verify exponential growth (average of multiple samples to account for jitter)
        var delays: [Double] = []
        for attempt in 0..<6 {
            var sum = 0.0
            for _ in 0..<10 {
                sum += config.delay(forAttempt: attempt)
            }
            delays.append(sum / 10.0)
        }

        // Each delay should roughly double the previous
        for i in 1..<delays.count {
            XCTAssertGreaterThan(delays[i], delays[i-1] * 1.5, "Delay at attempt \(i) should be greater than 1.5x previous")
        }
    }

    // MARK: - Jitter Variation

    func testJitterVariation() {
        // Multiple calls should produce different values due to jitter
        var delays: Set<Double> = []
        for _ in 0..<20 {
            delays.insert(config.delay(forAttempt: 1))
        }

        // With 20 samples, we should see at least some variation
        XCTAssertGreaterThan(delays.count, 1, "Jitter should produce varying delay values")
    }
}
