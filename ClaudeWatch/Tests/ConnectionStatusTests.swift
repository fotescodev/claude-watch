import XCTest
@testable import ClaudeWatch

final class ConnectionStatusTests: XCTestCase {

    // MARK: - isConnected Property

    func testIsConnectedForConnectedStatus() {
        let status = ConnectionStatus.connected
        XCTAssertTrue(status.isConnected)
    }

    func testIsConnectedForDisconnectedStatus() {
        let status = ConnectionStatus.disconnected
        XCTAssertFalse(status.isConnected)
    }

    func testIsConnectedForConnectingStatus() {
        let status = ConnectionStatus.connecting
        XCTAssertFalse(status.isConnected)
    }

    func testIsConnectedForReconnectingStatus() {
        let status = ConnectionStatus.reconnecting(attempt: 1, nextRetryIn: 2.0)
        XCTAssertFalse(status.isConnected)
    }

    // MARK: - Display Name

    func testDisplayNameForDisconnected() {
        XCTAssertEqual(ConnectionStatus.disconnected.displayName, "OFFLINE")
    }

    func testDisplayNameForConnecting() {
        XCTAssertEqual(ConnectionStatus.connecting.displayName, "CONNECTING")
    }

    func testDisplayNameForConnected() {
        XCTAssertEqual(ConnectionStatus.connected.displayName, "CONNECTED")
    }

    func testDisplayNameForReconnecting() {
        let status = ConnectionStatus.reconnecting(attempt: 3, nextRetryIn: 8.0)
        XCTAssertEqual(status.displayName, "RETRY 3")
    }

    // MARK: - Equatable Conformance

    func testEquatableConnected() {
        XCTAssertEqual(ConnectionStatus.connected, ConnectionStatus.connected)
    }

    func testEquatableDisconnected() {
        XCTAssertEqual(ConnectionStatus.disconnected, ConnectionStatus.disconnected)
    }

    func testEquatableConnecting() {
        XCTAssertEqual(ConnectionStatus.connecting, ConnectionStatus.connecting)
    }

    func testEquatableReconnectingSameValues() {
        let status1 = ConnectionStatus.reconnecting(attempt: 2, nextRetryIn: 4.0)
        let status2 = ConnectionStatus.reconnecting(attempt: 2, nextRetryIn: 4.0)
        XCTAssertEqual(status1, status2)
    }

    func testEquatableReconnectingDifferentAttempt() {
        let status1 = ConnectionStatus.reconnecting(attempt: 1, nextRetryIn: 4.0)
        let status2 = ConnectionStatus.reconnecting(attempt: 2, nextRetryIn: 4.0)
        XCTAssertNotEqual(status1, status2)
    }

    func testEquatableReconnectingDifferentDelay() {
        let status1 = ConnectionStatus.reconnecting(attempt: 2, nextRetryIn: 2.0)
        let status2 = ConnectionStatus.reconnecting(attempt: 2, nextRetryIn: 4.0)
        XCTAssertNotEqual(status1, status2)
    }

    func testNotEqualDifferentCases() {
        XCTAssertNotEqual(ConnectionStatus.connected, ConnectionStatus.disconnected)
        XCTAssertNotEqual(ConnectionStatus.connecting, ConnectionStatus.connected)
        XCTAssertNotEqual(ConnectionStatus.disconnected, ConnectionStatus.reconnecting(attempt: 1, nextRetryIn: 1.0))
    }
}
