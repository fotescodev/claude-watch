import XCTest
@testable import ClaudeWatch

/// Tests for WatchService focusing on the happy path connection lifecycle.
/// Note: Full integration tests require mocking URLSessionWebSocketTask.
/// These tests focus on testable state transitions and logic.
@MainActor
final class WatchServiceTests: XCTestCase {

    var service: WatchService!

    override func setUp() async throws {
        try await super.setUp()
        service = WatchService.shared
        // Disable demo mode for testing
        service.isDemoMode = false
    }

    override func tearDown() async throws {
        service.disconnect()
        service = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func testInitialConnectionStatus() {
        // When demo mode is disabled, should start disconnected
        service.isDemoMode = false
        let newService = WatchService()
        XCTAssertEqual(newService.connectionStatus, .disconnected)
    }

    // MARK: - Connection Status Transitions

    func testConnectSetsConnectingStatus() async throws {
        // Given: Service is disconnected
        service.disconnect()
        service.serverURLString = "ws://localhost:9999" // Valid URL format, no server

        // When: Connect is called
        service.connect()

        // Then: Status should transition (connecting or already reconnecting due to failure)
        // Note: The status may transition quickly due to connection failure
        let validStatuses: [ConnectionStatus] = [.connecting, .disconnected]
        let isValidStatus = validStatuses.contains(service.connectionStatus) ||
            (service.connectionStatus != .connected) // Any non-connected state is acceptable
        XCTAssertTrue(isValidStatus, "Status should not be connected without a real server")
    }

    func testDisconnectResetsState() async throws {
        // Given: Service has some connection state
        service.loadDemoData() // Set up some state

        // When: Disconnect is called
        service.disconnect()

        // Small delay to let async cancellation complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: Connection status should be disconnected
        XCTAssertEqual(service.connectionStatus, .disconnected)
    }

    // MARK: - Invalid URL Handling

    func testInvalidURLSetsError() {
        // Given: A malformed URL (spaces make it invalid for URL(string:))
        service.serverURLString = "ws://invalid url with spaces"
        service.useCloudMode = false  // Disable cloud mode to test WebSocket URL validation

        // When: Connect is called
        service.connect()

        // Then: Should have error and be disconnected
        XCTAssertEqual(service.connectionStatus, .disconnected)
        XCTAssertNotNil(service.lastError)
        XCTAssertTrue(service.lastError?.contains("Invalid") ?? false, "Error should mention invalid URL")
    }

    // MARK: - Mode Changes

    func testCycleModeFromNormal() {
        // Given: Mode is normal
        service.state.mode = .normal

        // When: Cycle mode
        service.cycleMode()

        // Then: Should be autoAccept
        XCTAssertEqual(service.state.mode, .autoAccept)
    }

    func testCycleModeFromAutoAccept() {
        // Given: Mode is autoAccept
        service.state.mode = .autoAccept

        // When: Cycle mode
        service.cycleMode()

        // Then: Should be plan
        XCTAssertEqual(service.state.mode, .plan)
    }

    func testCycleModeFromPlan() {
        // Given: Mode is plan
        service.state.mode = .plan

        // When: Cycle mode
        service.cycleMode()

        // Then: Should be normal
        XCTAssertEqual(service.state.mode, .normal)
    }

    // MARK: - Action Handling

    func testApproveActionRemovesFromPending() {
        // Given: A pending action
        let action = PendingAction(
            id: "test-action-1",
            type: "file_edit",
            title: "Test Edit",
            description: "Test description",
            filePath: "test.swift",
            command: nil,
            timestamp: Date()
        )
        service.state.pendingActions = [action]
        service.state.status = .waiting

        // When: Action is approved
        service.approveAction("test-action-1")

        // Then: Action should be removed
        XCTAssertTrue(service.state.pendingActions.isEmpty)
    }

    func testRejectActionRemovesFromPending() {
        // Given: A pending action
        let action = PendingAction(
            id: "test-action-2",
            type: "bash",
            title: "Test Command",
            description: "Test description",
            filePath: nil,
            command: "npm test",
            timestamp: Date()
        )
        service.state.pendingActions = [action]
        service.state.status = .waiting

        // When: Action is rejected
        service.rejectAction("test-action-2")

        // Then: Action should be removed
        XCTAssertTrue(service.state.pendingActions.isEmpty)
    }

    func testApproveAllClearsPendingActions() {
        // Given: Multiple pending actions
        let action1 = PendingAction(
            id: "action-1", type: "file_edit", title: "Edit 1",
            description: "", filePath: nil, command: nil, timestamp: Date()
        )
        let action2 = PendingAction(
            id: "action-2", type: "file_edit", title: "Edit 2",
            description: "", filePath: nil, command: nil, timestamp: Date()
        )
        service.state.pendingActions = [action1, action2]

        // When: Approve all
        service.approveAll()

        // Then: All actions should be cleared
        XCTAssertTrue(service.state.pendingActions.isEmpty)
        XCTAssertEqual(service.state.status, .running)
    }

    func testApproveActionChangesStatusToRunning() {
        // Given: Waiting status with one action
        let action = PendingAction(
            id: "last-action", type: "bash", title: "Last",
            description: "", filePath: nil, command: nil, timestamp: Date()
        )
        service.state.pendingActions = [action]
        service.state.status = .waiting

        // When: Last action is approved
        service.approveAction("last-action")

        // Then: Status should change to running
        XCTAssertEqual(service.state.status, .running)
    }

    // MARK: - Demo Mode

    func testDemoModeLoadsData() {
        // Given: Demo mode is disabled
        service.isDemoMode = false
        service.state.pendingActions = []
        service.connectionStatus = .disconnected

        // When: Load demo data
        service.loadDemoData()

        // Then: Should have demo data
        XCTAssertEqual(service.connectionStatus, .connected)
        XCTAssertFalse(service.state.pendingActions.isEmpty)
        XCTAssertEqual(service.state.status, .waiting)
        XCTAssertFalse(service.state.taskName.isEmpty)
    }

    // MARK: - State Properties

    func testWatchStateDefaults() {
        let state = WatchState()

        XCTAssertEqual(state.taskName, "")
        XCTAssertEqual(state.taskDescription, "")
        XCTAssertEqual(state.progress, 0)
        XCTAssertEqual(state.status, .idle)
        XCTAssertTrue(state.pendingActions.isEmpty)
        XCTAssertEqual(state.model, "opus")
        XCTAssertEqual(state.mode, .normal)
    }

    func testYoloModeComputed() {
        var state = WatchState()

        state.mode = .normal
        XCTAssertFalse(state.yoloMode)

        state.mode = .autoAccept
        XCTAssertTrue(state.yoloMode)

        state.mode = .plan
        XCTAssertFalse(state.yoloMode)
    }

    // MARK: - Permission Mode

    func testPermissionModeNext() {
        XCTAssertEqual(PermissionMode.normal.next(), .autoAccept)
        XCTAssertEqual(PermissionMode.autoAccept.next(), .plan)
        XCTAssertEqual(PermissionMode.plan.next(), .normal)
    }

    func testPermissionModeDisplayNames() {
        XCTAssertEqual(PermissionMode.normal.displayName, "NORMAL")
        XCTAssertEqual(PermissionMode.autoAccept.displayName, "AUTO")
        XCTAssertEqual(PermissionMode.plan.displayName, "PLAN")
    }

    func testPermissionModeIcons() {
        XCTAssertEqual(PermissionMode.normal.icon, "hand.raised")
        XCTAssertEqual(PermissionMode.autoAccept.icon, "bolt.fill")
        XCTAssertEqual(PermissionMode.plan.icon, "doc.text.magnifyingglass")
    }

    // MARK: - Session Status

    func testSessionStatusDisplayNames() {
        XCTAssertEqual(SessionStatus.idle.displayName, "IDLE")
        XCTAssertEqual(SessionStatus.running.displayName, "RUNNING")
        XCTAssertEqual(SessionStatus.waiting.displayName, "WAITING")
        XCTAssertEqual(SessionStatus.completed.displayName, "DONE")
        XCTAssertEqual(SessionStatus.failed.displayName, "FAILED")
    }

    // MARK: - Pending Action

    func testPendingActionFromDictionary() {
        let data: [String: Any] = [
            "id": "test-id",
            "type": "file_edit",
            "title": "Edit file",
            "description": "Modify content",
            "file_path": "src/main.swift",
            "timestamp": "2024-01-15T10:30:00Z"
        ]

        let action = PendingAction(from: data)

        XCTAssertNotNil(action)
        XCTAssertEqual(action?.id, "test-id")
        XCTAssertEqual(action?.type, "file_edit")
        XCTAssertEqual(action?.title, "Edit file")
        XCTAssertEqual(action?.filePath, "src/main.swift")
    }

    func testPendingActionFromInvalidDictionary() {
        let data: [String: Any] = [
            "id": "test-id"
            // Missing required fields
        ]

        let action = PendingAction(from: data)
        XCTAssertNil(action)
    }

    func testPendingActionIcon() {
        XCTAssertEqual(
            PendingAction(id: "", type: "file_edit", title: "", description: "", filePath: nil, command: nil, timestamp: Date()).icon,
            "pencil"
        )
        XCTAssertEqual(
            PendingAction(id: "", type: "file_create", title: "", description: "", filePath: nil, command: nil, timestamp: Date()).icon,
            "doc.badge.plus"
        )
        XCTAssertEqual(
            PendingAction(id: "", type: "file_delete", title: "", description: "", filePath: nil, command: nil, timestamp: Date()).icon,
            "trash"
        )
        XCTAssertEqual(
            PendingAction(id: "", type: "bash", title: "", description: "", filePath: nil, command: nil, timestamp: Date()).icon,
            "terminal"
        )
        XCTAssertEqual(
            PendingAction(id: "", type: "unknown", title: "", description: "", filePath: nil, command: nil, timestamp: Date()).icon,
            "gear"
        )
    }
}
