import Foundation
import Combine
import SwiftUI
import WatchKit
import UserNotifications
import Network
import WidgetKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Main service for communicating with Claude Watch MCP Server
/// Uses WebSocket for real-time updates, with REST fallback
@MainActor
class WatchService: ObservableObject {
    static let shared = WatchService()

    // MARK: - Published State
    @Published var state = WatchState()
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?
    @Published var isSendingPrompt = false
    @Published var sessionProgress: SessionProgress?
    @Published var isAPNsTokenReady = false

    /// Track when session progress was last updated (for staleness check)
    var lastProgressUpdate: Date?

    /// Clear stale session progress (60s for in-progress, 3s for complete)
    /// Complete state is a brief acknowledgment, then return to "Listening..."
    private let progressStaleThreshold: TimeInterval = 60
    private let completeStaleThreshold: TimeInterval = 3

    // MARK: - Foundation Models (On-Device AI)
    @Published var foundationModelsStatus: FoundationModelsStatus = .checking

    // MARK: - Configuration
    @AppStorage("serverURL") var serverURLString = "wss://localhost:8787"
    @AppStorage("cloudServerURL") var cloudServerURL = "https://claude-watch.fotescodev.workers.dev"
    @AppStorage("pairingId") var pairingId: String = ""
    @AppStorage("useCloudMode") var useCloudMode = true  // Use cloud relay by default
    @AppStorage("permissionMode") private var storedMode: String = PermissionMode.normal.rawValue

    /// Whether the watch is paired with a Claude Code instance
    var isPaired: Bool {
        !pairingId.isEmpty
    }

    // MARK: - Private
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let sharedDefaults = UserDefaults(suiteName: "group.com.claudewatch")
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var handshakeTimeoutTask: Task<Void, Never>?
    private var pongTimeoutTask: Task<Void, Never>?

    // MARK: - Reliability Configuration
    private let reconnectConfig = ReconnectionConfig()
    private var reconnectAttempt: Int = 0
    private var messageQueue: [QueuedMessage] = []
    private let maxQueueSize: Int = 50
    private var lastPongTime: Date?
    private let pingInterval: TimeInterval = 15.0
    private let pongTimeout: TimeInterval = 10.0
    private let handshakeTimeout: TimeInterval = 10.0
    private var hasCompletedHandshake: Bool = false

    // MARK: - Network Monitoring
    private var pathMonitor: NWPathMonitor?
    private var isNetworkAvailable: Bool = true

    // MARK: - Cloud Mode Polling
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 2.0

    // MARK: - Activity Batching
    private var activityBatcher: ActivityBatcher?

    // MARK: - Demo Mode
    @AppStorage("demoMode") var isDemoMode = false  // Connect to real server by default

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)

        // Restore persisted mode
        if let mode = PermissionMode(rawValue: storedMode) {
            state.mode = mode
        }

        // Check if APNs token is already registered (from previous session)
        if UserDefaults.standard.string(forKey: "apnsDeviceToken") != nil {
            isAPNsTokenReady = true
        }

        // Start network monitoring
        startNetworkMonitoring()

        // Load demo data if demo mode is enabled
        if isDemoMode {
            loadDemoData()
        }

        // Check Foundation Models availability
        checkFoundationModelsAvailability()

        // Initialize activity batcher for smoother progress updates
        activityBatcher = ActivityBatcher { [weak self] progress in
            self?.applyBatchedProgress(progress)
        }
    }

    // MARK: - Foundation Models Availability

    /// Check if Foundation Models (on-device AI) is available
    func checkFoundationModelsAvailability() {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            foundationModelsStatus = .available
        case .unavailable(.deviceNotEligible):
            foundationModelsStatus = .unavailable(.deviceNotSupported)
        case .unavailable(.appleIntelligenceNotEnabled):
            foundationModelsStatus = .unavailable(.appleIntelligenceDisabled)
        case .unavailable(.modelNotReady):
            foundationModelsStatus = .downloading
            // Start observing for when the model becomes ready
            observeFoundationModelsReadiness()
        case .unavailable:
            foundationModelsStatus = .unavailable(.unknown)
        }
        #else
        // FoundationModels framework not available on this platform (e.g., watchOS)
        foundationModelsStatus = .unavailable(.platformNotSupported)
        #endif
    }

    /// Observe for Foundation Models readiness changes
    private func observeFoundationModelsReadiness() {
        #if canImport(FoundationModels)
        // Periodically check if the model becomes ready
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }

                let model = SystemLanguageModel.default
                if case .available = model.availability {
                    await MainActor.run {
                        self.foundationModelsStatus = .available
                    }
                    return
                }

                try? await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds
            }
        }
        #endif
    }

    nonisolated deinit {
        // Note: NWPathMonitor.cancel() is thread-safe
        // We access it directly here since deinit is nonisolated
    }

    // MARK: - App Lifecycle

    /// Handles app transition to active state.
    /// Resets reconnection backoff and initiates connection (polling in cloud mode, WebSocket otherwise).
    func handleAppDidBecomeActive() {
        // Don't try to connect in demo mode
        guard !isDemoMode else { return }

        // Reset backoff when coming to foreground
        reconnectAttempt = 0

        // Cloud mode with polling
        if useCloudMode && isPaired {
            startPolling()
            return
        }

        // WebSocket mode
        // If disconnected or reconnecting, try to connect immediately
        switch connectionStatus {
        case .disconnected:
            connect()
        case .reconnecting:
            reconnectTask?.cancel()
            connect()
        case .connected:
            // Send ping to verify connection is still alive
            sendImmediate(["type": "ping"])
        case .connecting:
            // Already trying to connect, do nothing
            break
        }
    }

    /// Called when app is about to become inactive.
    ///
    /// Intentionally empty - watchOS handles connection lifecycle automatically.
    /// Disconnecting here would cause unnecessary reconnection cycles when the
    /// user briefly switches apps or receives a notification.
    ///
    /// The WebSocket connection is maintained by the system and will naturally
    /// close when the app enters background (handled by `handleAppDidEnterBackground`).
    func handleAppWillResignActive() {
        // No action needed - watchOS manages background state transitions
    }

    /// Handles app entering background state.
    /// Stops polling in cloud mode to conserve battery, or sends final state request in WebSocket mode.
    func handleAppDidEnterBackground() {
        // Flush any pending batched updates before backgrounding
        activityBatcher?.flushNow()

        // Stop polling in background to save battery
        if useCloudMode {
            stopPolling()
            return
        }

        // WebSocket mode: The system may keep the connection alive briefly
        // Send a final state request to ensure we have latest data
        if connectionStatus.isConnected {
            sendImmediate(["type": "get_state"])
        }
    }

    // MARK: - Connection

    /// Establishes WebSocket connection to the MCP server.
    /// Skips WebSocket creation in cloud mode (uses polling instead).
    /// Cancels existing reconnection attempts, cleans up previous connections,
    /// and initiates handshake with timeout monitoring.
    func connect() {
        // Skip WebSocket connection in cloud mode - use polling instead
        if useCloudMode {
            return
        }

        // Cancel any existing reconnect attempt
        reconnectTask?.cancel()

        // Clean up existing connection
        disconnect()

        connectionStatus = .connecting
        hasCompletedHandshake = false

        guard let url = URL(string: serverURLString) else {
            connectionStatus = .disconnected
            lastError = WebSocketError.invalidURL.localizedDescription
            return
        }

        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        // Start receiving immediately (status stays .connecting)
        startReceiving()

        // Start handshake timeout - if no message received, fail
        handshakeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.handshakeTimeout ?? 10.0) * 1_000_000_000)
            guard let self = self, !Task.isCancelled else { return }
            if !self.hasCompletedHandshake {
                self.handleError(.handshakeTimeout)
            }
        }

        // Request current state (response will confirm connection)
        sendImmediate(["type": "get_state"])
    }

    /// Closes the WebSocket connection and cancels all pending tasks.
    /// Resets connection state to disconnected. Safe to call when already disconnected.
    func disconnect() {
        pingTask?.cancel()
        reconnectTask?.cancel()
        handshakeTimeoutTask?.cancel()
        pongTimeoutTask?.cancel()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        hasCompletedHandshake = false
        connectionStatus = .disconnected
    }

    // MARK: - WebSocket Communication
    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.startReceiving() // Continue receiving

                case .failure(let error):
                    self?.handleDisconnection(error: error)
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        // Complete handshake on first successful message
        if !hasCompletedHandshake {
            completeHandshake()
        }

        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                return
            }

            switch type {
            case "state_sync":
                if let stateData = json["state"] as? [String: Any] {
                    updateState(from: stateData)
                }

            case "action_requested":
                if let actionData = json["action"] as? [String: Any] {
                    handleActionRequested(actionData)
                }

            case "progress_update":
                if let progress = json["progress"] as? Double {
                    state.progress = progress
                }
                if let taskName = json["task_name"] as? String {
                    state.taskName = taskName
                }
                updateComplicationData()

            case "task_started":
                state.taskName = json["task_name"] as? String ?? ""
                state.taskDescription = json["task_description"] as? String ?? ""
                state.status = .running
                state.progress = 0

            case "task_completed":
                let success = json["success"] as? Bool ?? true
                state.status = success ? .completed : .failed
                state.progress = success ? 1.0 : state.progress
                playHaptic(success ? .success : .failure)

            case "yolo_changed":
                // Legacy support
                let enabled = json["enabled"] as? Bool ?? false
                state.mode = enabled ? .autoAccept : .normal

            case "mode_changed":
                if let modeStr = json["mode"] as? String,
                   let mode = PermissionMode(rawValue: modeStr) {
                    state.mode = mode
                }

            case "pong":
                handlePongReceived()

            case "notification":
                let title = json["title"] as? String ?? "Claude"
                let message = json["message"] as? String ?? ""
                showLocalNotification(title: title, message: message)

            default:
                break
            }

        case .data:
            break // Not handling binary data

        @unknown default:
            break
        }
    }

    private func updateState(from data: [String: Any]) {
        state.taskName = data["task_name"] as? String ?? ""
        state.taskDescription = data["task_description"] as? String ?? ""
        state.progress = data["progress"] as? Double ?? 0
        state.model = data["model"] as? String ?? "opus"

        // Handle mode (with legacy yolo_mode fallback)
        if let modeStr = data["mode"] as? String,
           let mode = PermissionMode(rawValue: modeStr) {
            state.mode = mode
        } else if let yoloMode = data["yolo_mode"] as? Bool {
            state.mode = yoloMode ? .autoAccept : .normal
        }

        if let statusStr = data["status"] as? String {
            state.status = SessionStatus(rawValue: statusStr) ?? .idle
        }

        if let actionsData = data["pending_actions"] as? [[String: Any]] {
            state.pendingActions = actionsData.compactMap { PendingAction(from: $0) }
        }

        updateComplicationData()
    }

    private func handleActionRequested(_ data: [String: Any]) {
        guard let action = PendingAction(from: data) else { return }

        // Avoid duplicates
        guard !state.pendingActions.contains(where: { $0.id == action.id }) else { return }

        // AUTO-ACCEPT MODE: Automatically approve instead of queueing
        if state.mode == .autoAccept {
            playHaptic(.success)
            approveAction(action.id)
            return
        }

        // Add to pending actions
        state.pendingActions.append(action)
        state.status = .waiting

        // Play haptic
        playHaptic(.notification)
        updateComplicationData()
    }

    private func handleDisconnection(error: Error) {
        handleError(.receiveFailed(error))
    }

    // MARK: - Connection Lifecycle Helpers

    private func completeHandshake() {
        guard !hasCompletedHandshake else { return }

        hasCompletedHandshake = true
        handshakeTimeoutTask?.cancel()
        connectionStatus = .connected
        reconnectAttempt = 0  // Reset backoff on successful connection
        lastPongTime = Date()

        // Start ping loop now that we're connected
        startPingLoop()

        // Flush any queued messages
        flushMessageQueue()

        playHaptic(.success)
        updateComplicationData()
    }

    private func handlePongReceived() {
        lastPongTime = Date()
        pongTimeoutTask?.cancel()
    }

    private func handleError(_ error: WebSocketError) {
        // Cancel all tasks
        pingTask?.cancel()
        handshakeTimeoutTask?.cancel()
        pongTimeoutTask?.cancel()

        // Close the WebSocket
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        hasCompletedHandshake = false

        lastError = error.localizedDescription

        // Check if we should retry
        guard error.isRecoverable else {
            connectionStatus = .disconnected
            updateComplicationData()
            return
        }

        // Check max retries
        guard reconnectAttempt < reconnectConfig.maxRetries else {
            connectionStatus = .disconnected
            lastError = WebSocketError.maxRetriesExceeded.localizedDescription
            return
        }

        // Schedule reconnection with exponential backoff
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        // Don't schedule reconnect if network is unavailable
        guard isNetworkAvailable else {
            connectionStatus = .disconnected
            lastError = WebSocketError.networkUnavailable.localizedDescription
            return
        }

        let delay = reconnectConfig.delay(forAttempt: reconnectAttempt)
        reconnectAttempt += 1

        connectionStatus = .reconnecting(attempt: reconnectAttempt, nextRetryIn: delay)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self = self, !Task.isCancelled else { return }
            // Double-check network is still available before attempting
            guard self.isNetworkAvailable else { return }
            self.connect()
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.handleNetworkPathUpdate(path)
            }
        }
        pathMonitor?.start(queue: DispatchQueue(label: "com.claudewatch.network-monitor"))
    }

    /// Cancels network path monitoring.
    ///
    /// Network path monitoring runs for the app's lifetime. Explicit cleanup is
    /// not required because NWPathMonitor is lightweight and automatically releases
    /// when WatchService is deallocated. This method exists for completeness but
    /// is not called during normal operation.
    private func stopNetworkMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    private func handleNetworkPathUpdate(_ path: NWPath) {
        let wasAvailable = isNetworkAvailable
        isNetworkAvailable = path.status == .satisfied

        if !wasAvailable && isNetworkAvailable {
            // Network became available - reconnect immediately with reset backoff
            reconnectAttempt = 0
            reconnectTask?.cancel()

            // Only connect if we were trying to connect or are disconnected
            if case .reconnecting = connectionStatus {
                connect()
            } else if connectionStatus == .disconnected {
                connect()
            }
        } else if wasAvailable && !isNetworkAvailable {
            // Network became unavailable - cancel reconnection attempts
            reconnectTask?.cancel()

            // If currently connected, let the socket fail naturally
            // If reconnecting, update status
            if case .reconnecting = connectionStatus {
                connectionStatus = .disconnected
                lastError = WebSocketError.networkUnavailable.localizedDescription
            }
        }
    }

    private func startPingLoop() {
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }

                // Only ping if connected
                guard self.connectionStatus.isConnected else {
                    try? await Task.sleep(nanoseconds: UInt64(self.pingInterval * 1_000_000_000))
                    continue
                }

                // Check for pong timeout before sending new ping
                if let lastPong = self.lastPongTime,
                   Date().timeIntervalSince(lastPong) > self.pingInterval + self.pongTimeout {
                    self.handleError(.pongTimeout)
                    return
                }

                // Send ping
                self.sendImmediate(["type": "ping"])

                // Schedule pong timeout check
                self.pongTimeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64((self?.pongTimeout ?? 10.0) * 1_000_000_000))
                    guard let self = self, !Task.isCancelled else { return }
                    if let lastPong = self.lastPongTime,
                       Date().timeIntervalSince(lastPong) > self.pongTimeout {
                        self.handleError(.pongTimeout)
                    }
                }

                try? await Task.sleep(nanoseconds: UInt64(self.pingInterval * 1_000_000_000))
            }
        }
    }

    // MARK: - Message Sending

    private func send(_ message: [String: Any], priority: QueuedMessage.MessagePriority = .normal) {
        // Queue message if not connected
        guard connectionStatus.isConnected else {
            queueMessage(message, priority: priority)
            return
        }

        sendImmediate(message) { [weak self] error in
            if let error = error {
                self?.handleSendError(message, error: error, priority: priority)
            }
        }
    }

    private func sendImmediate(_ message: [String: Any], completion: ((Error?) -> Void)? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            completion?(WebSocketError.sendFailed(NSError(domain: "WatchService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize message"])))
            return
        }
        webSocket?.send(.string(string)) { error in
            completion?(error)
        }
    }

    private func queueMessage(_ message: [String: Any], priority: QueuedMessage.MessagePriority) {
        let queued = QueuedMessage(payload: message, createdAt: Date(), priority: priority)

        // Maintain queue size limit (drop oldest low-priority messages)
        if messageQueue.count >= maxQueueSize {
            if let index = messageQueue.firstIndex(where: { $0.priority == .low }) {
                messageQueue.remove(at: index)
            } else if messageQueue.count >= maxQueueSize {
                // If no low priority messages, drop oldest
                messageQueue.removeFirst()
            }
        }

        messageQueue.append(queued)
        messageQueue.sort { $0.priority > $1.priority }
    }

    private func flushMessageQueue() {
        let messages = messageQueue
        messageQueue.removeAll()

        for queued in messages {
            send(queued.payload, priority: queued.priority)
        }
    }

    private func handleSendError(_ message: [String: Any], error: Error, priority: QueuedMessage.MessagePriority) {
        // For high-priority messages (approve/reject), re-queue for retry
        if priority == .high {
            queueMessage(message, priority: priority)
        }

        // This might indicate connection failure
        handleError(.sendFailed(error))
    }

    // MARK: - Actions

    /// Approves a specific pending action and notifies the server.
    /// Optimistically removes the action from local state and provides haptic feedback.
    func approveAction(_ actionId: String) {
        send([
            "type": "action_response",
            "action_id": actionId,
            "approved": true
        ], priority: .high)

        // Optimistic update
        state.pendingActions.removeAll { $0.id == actionId }
        if state.pendingActions.isEmpty {
            state.status = .running
        }

        // Clear the notification for this action
        clearDeliveredNotification(for: actionId)

        playHaptic(.success)
    }

    /// Rejects a specific pending action and notifies the server.
    /// Optimistically removes the action from local state and provides haptic feedback.
    func rejectAction(_ actionId: String) {
        send([
            "type": "action_response",
            "action_id": actionId,
            "approved": false
        ], priority: .high)

        // Optimistic update
        state.pendingActions.removeAll { $0.id == actionId }
        if state.pendingActions.isEmpty {
            state.status = .running
        }

        // Clear the notification for this action
        clearDeliveredNotification(for: actionId)

        playHaptic(.failure)
    }

    /// Approves all pending actions at once.
    /// Clears all pending actions locally and notifies server to proceed with all requests.
    func approveAll() {
        if useCloudMode && isPaired {
            // Cloud mode: approve each pending action via cloud API
            let actionsToApprove = state.pendingActions
            Task {
                for action in actionsToApprove {
                    do {
                        try await respondToCloudRequest(action.id, approved: true)
                    } catch {
                        print("Failed to approve \(action.id): \(error)")
                    }
                }
            }
        } else {
            // WebSocket mode
            send(["type": "approve_all"], priority: .high)
        }

        // Optimistic update
        state.pendingActions.removeAll()
        state.status = .running

        // Clear ALL delivered notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Legacy method for toggling YOLO mode.
    /// Now delegates to `cycleMode()` to cycle through all permission modes.
    func toggleYolo() {
        // Legacy support - now cycles through modes
        cycleMode()
        playHaptic(.success)
    }

    /// Cycles through permission modes in sequence (normal → auto-accept → plan).
    /// Updates server state and provides haptic feedback for the new mode.
    func cycleMode() {
        let newMode = state.mode.next()
        setMode(newMode)
    }

    /// Sets the permission mode for Claude Code interactions.
    /// Automatically approves pending actions when entering auto-accept mode.
    /// - Parameter mode: The permission mode to activate (normal, autoAccept, or plan)
    func setMode(_ mode: PermissionMode) {
        // Persist mode locally
        storedMode = mode.rawValue
        state.mode = mode

        // Only send to WebSocket if not in cloud mode (cloud mode has no WebSocket)
        if !useCloudMode {
            send([
                "type": "set_mode",
                "mode": mode.rawValue
            ])
        }

        // Haptic feedback based on mode
        switch mode {
        case .normal:
            playHaptic(.click)
        case .autoAccept:
            playHaptic(.start)
            // Auto-approve all pending when entering auto-accept
            if !state.pendingActions.isEmpty {
                approveAll()
            }
        case .plan:
            playHaptic(.stop)
        }
    }

    /// Sends a voice prompt to Claude Code for processing.
    /// Sets temporary state flag while sending and provides haptic feedback on completion.
    /// - Parameter text: The transcribed voice input to send as a prompt
    func sendPrompt(_ text: String) {
        isSendingPrompt = true

        Task { @MainActor in
            defer { isSendingPrompt = false }

            let message: [String: Any] = [
                "type": "prompt",
                "text": text
            ]

            // Wait for send to complete using async wrapper
            await withCheckedContinuation { continuation in
                guard connectionStatus.isConnected else {
                    queueMessage(message, priority: .normal)
                    continuation.resume()
                    return
                }

                sendImmediate(message) { [weak self] error in
                    if let error = error {
                        self?.handleSendError(message, error: error, priority: .normal)
                    }
                    continuation.resume()
                }
            }

            playHaptic(.success)
        }
    }

    // MARK: - Cloud Mode (Production)

    /// Complete pairing with Claude Code using a 6-character code.
    /// Sends the pairing code and device token to the cloud server to establish a persistent connection.
    /// - Parameter code: The 6-character pairing code displayed in Claude Code
    /// - Throws: `CloudError.invalidCode` if the code is invalid or expired,
    ///           `CloudError.invalidResponse` if the server response is malformed,
    ///           `CloudError.serverError` if the server returns an error status code
    /// Initiate pairing - watch requests a code to display
    /// Returns the code to display and a watchId for polling
    func initiatePairing() async throws -> (code: String, watchId: String) {
        let url = URL(string: "\(cloudServerURL)/pair/initiate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get device token for push notifications
        let deviceToken = await getDeviceToken()

        let body: [String: Any] = [
            "deviceToken": deviceToken ?? "simulator-token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String,
              let watchId = json["watchId"] as? String else {
            throw CloudError.invalidResponse
        }

        return (code: code, watchId: watchId)
    }

    /// Check pairing status - watch polls until CLI completes pairing
    func checkPairingStatus(watchId: String) async throws -> (paired: Bool, pairingId: String?) {
        let url = URL(string: "\(cloudServerURL)/pair/status/\(watchId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw CloudError.timeout
        }

        guard httpResponse.statusCode == 200 else {
            throw CloudError.serverError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let paired = json["paired"] as? Bool else {
            throw CloudError.invalidResponse
        }

        let pairingId = json["pairingId"] as? String
        return (paired: paired, pairingId: pairingId)
    }

    /// Complete pairing after CLI has entered the code
    func finishPairing(pairingId: String) {
        self.pairingId = pairingId
        connectionStatus = .connected
        playHaptic(.success)
        startPolling()
    }

    /// DEPRECATED: Old pairing flow where watch entered code from CLI.
    /// New flow: Watch shows code → CLI enters code → use initiatePairing() + checkPairingStatus() instead.
    @available(*, deprecated, message: "Use initiatePairing() + checkPairingStatus() instead. Watch now DISPLAYS code, CLI enters it.")
    func completePairing(code: String) async throws {
        let url = URL(string: "\(cloudServerURL)/pair/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Get device token for push notifications
        let deviceToken = await getDeviceToken()

        let body: [String: Any] = [
            "code": code,
            "deviceToken": deviceToken ?? "simulator-token"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw CloudError.invalidCode
        }

        guard httpResponse.statusCode == 200 else {
            throw CloudError.serverError(httpResponse.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newPairingId = json["pairingId"] as? String else {
            throw CloudError.invalidResponse
        }

        // Store pairing ID
        pairingId = newPairingId
        connectionStatus = .connected
        playHaptic(.success)

        // Start polling for requests
        startPolling()
    }

    /// Respond to an approval request via cloud API.
    /// Sends the user's approval or rejection decision to the cloud server for the specified request.
    /// - Parameter requestId: The unique identifier of the pending request
    /// - Parameter approved: Whether to approve (true) or reject (false) the request
    /// - Throws: `CloudError.serverError` if the server returns an error status code or the response is invalid
    func respondToCloudRequest(_ requestId: String, approved: Bool) async throws {
        let url = URL(string: "\(cloudServerURL)/respond/\(requestId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "approved": approved,
            "pairingId": pairingId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Update local state
        state.pendingActions.removeAll { $0.id == requestId }
        if state.pendingActions.isEmpty {
            state.status = .running
        }

        // Clear delivered notifications for this request
        // APNs notifications may not use requestId as identifier, so we query and remove matching ones
        clearDeliveredNotification(for: requestId)

        playHaptic(approved ? .success : .failure)
    }

    /// Clear delivered notification for a specific request ID
    private func clearDeliveredNotification(for requestId: String) {
        let center = UNUserNotificationCenter.current()

        // Get all delivered notifications and remove ones matching this request
        center.getDeliveredNotifications { notifications in
            let idsToRemove = notifications.compactMap { notification -> String? in
                let userInfo = notification.request.content.userInfo
                let notificationRequestId = userInfo["requestId"] as? String ?? userInfo["action_id"] as? String
                if notificationRequestId == requestId {
                    return notification.request.identifier
                }
                return nil
            }

            if !idsToRemove.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
            }
        }
    }

    /// Get device token for APNs (set during notification registration)
    private func getDeviceToken() async -> String? {
        // In production, this would be stored during UNUserNotificationCenter registration
        // For now, return nil and we'll handle it in the pairing flow
        return UserDefaults.standard.string(forKey: "apnsDeviceToken")
    }

    /// Disconnects from Claude Code and clears all pairing data.
    /// Stops active polling, resets pairing ID, clears app state, and provides haptic feedback.
    func unpair() {
        stopPolling()
        pairingId = ""
        connectionStatus = .disconnected
        state = WatchState()
        sessionProgress = nil
        playHaptic(.click)
    }

    /// End the current session and signal the Mac to stop watch mode
    /// This is called from the watch UI when user wants to disconnect
    func endSession() async {
        guard isPaired else { return }

        let currentPairingId = pairingId

        // Signal the cloud server that this session is ending
        // The Mac-side hooks will detect this and stop waiting for watch approval
        do {
            let url = URL(string: "\(cloudServerURL)/session-end")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["pairingId": currentPairingId]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Session end signal sent: \(httpResponse.statusCode)")
            }
        } catch {
            print("Failed to send session end signal: \(error)")
            // Continue with local cleanup even if cloud signal fails
        }

        // Clear local state on main actor
        await MainActor.run {
            unpair()
        }
    }

    // MARK: - Session Interrupt Controls

    /// Interrupt action types for stop/resume from watch
    enum InterruptAction: String {
        case stop
        case resume
        case clear
    }

    /// Current interrupt state (true = session paused)
    @Published var isSessionInterrupted: Bool = false

    /// Send interrupt signal to pause or resume Claude Code session.
    /// When stopped, PreToolUse hook will block all tool calls until resume.
    /// - Parameter action: The interrupt action (.stop, .resume, or .clear)
    func sendInterrupt(action: InterruptAction) async {
        guard isPaired else { return }

        do {
            let url = URL(string: "\(cloudServerURL)/session-interrupt")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "pairingId": pairingId,
                "action": action.rawValue
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await urlSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Parse response to get interrupt state
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let interrupted = json["interrupted"] as? Bool {
                    await MainActor.run {
                        self.isSessionInterrupted = interrupted
                    }
                }
                playHaptic(action == .stop ? .stop : .start)
            }
        } catch {
            print("Failed to send interrupt signal: \(error)")
        }
    }

    // MARK: - Cloud Polling

    /// Starts polling the cloud server for pending approval requests.
    /// Creates a background task that periodically fetches new requests every 2 seconds.
    /// Only active when in cloud mode with an active pairing. Safe to call multiple times.
    func startPolling() {
        guard useCloudMode && isPaired else { return }
        guard pollingTask == nil else { return }

        connectionStatus = .connected
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }

                do {
                    // Fetch both pending requests AND session progress
                    try await self.fetchPendingRequests()
                    try await self.fetchSessionProgress()
                } catch {
                    print("Polling error: \(error)")
                }

                try? await Task.sleep(nanoseconds: UInt64(self.pollingInterval * 1_000_000_000))
            }
        }
    }

    /// Stops the active polling task.
    /// Cancels the background polling task and cleans up resources.
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Fetch pending requests from cloud server
    private func fetchPendingRequests() async throws {
        let url = URL(string: "\(cloudServerURL)/requests/\(pairingId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requests = json["requests"] as? [[String: Any]] else {
            return
        }

        // Convert to pending actions
        var newActions: [PendingAction] = []
        for req in requests {
            // Request data is returned directly from /requests/:pairingId endpoint
            guard let id = req["id"] as? String,
                  let type = req["type"] as? String,
                  let title = req["title"] as? String else {
                continue
            }

            let action = PendingAction(
                id: id,
                type: type,
                title: title,
                description: req["description"] as? String ?? "",
                filePath: req["filePath"] as? String,
                command: req["command"] as? String,
                timestamp: Date()
            )
            newActions.append(action)
        }

        // Check if new actions were added
        let existingIds = Set(state.pendingActions.map { $0.id })
        let newIds = Set(newActions.map { $0.id })
        let addedIds = newIds.subtracting(existingIds)

        // Update state on main thread for SwiftUI
        await MainActor.run {
            // Merge: keep notification-added actions that aren't in cloud response
            // This prevents race conditions where notification arrives before cloud updates
            let cloudIds = Set(newActions.map { $0.id })
            let localOnly = state.pendingActions.filter { !cloudIds.contains($0.id) }

            // Combine cloud actions with local-only actions
            state.pendingActions = newActions + localOnly

            // AUTO-ACCEPT MODE: Automatically approve all pending actions
            if state.mode == .autoAccept && !state.pendingActions.isEmpty {
                playHaptic(.success)
                approveAll()
                return  // approveAll clears pendingActions and sets status
            }

            if !state.pendingActions.isEmpty {
                state.status = .waiting
            } else {
                state.status = .idle
            }

            // Play haptic for new actions
            if !addedIds.isEmpty {
                playHaptic(.notification)
            }

            // Clear stale session progress
            // Use shorter timeout (10s) for completed tasks, longer (60s) for in-progress
            if let lastUpdate = lastProgressUpdate, let progress = sessionProgress {
                let isComplete = progress.progress >= 1.0 || (progress.totalCount > 0 && progress.completedCount == progress.totalCount)
                let threshold = isComplete ? completeStaleThreshold : progressStaleThreshold
                if Date().timeIntervalSince(lastUpdate) > threshold {
                    sessionProgress = nil
                    lastProgressUpdate = nil
                }
            }
        }
    }

    /// Fetch session progress from cloud server (polling fallback for silent push)
    private func fetchSessionProgress() async throws {
        let url = URL(string: "\(cloudServerURL)/session-progress/\(pairingId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let currentTask = json["currentTask"] as? String
        let currentActivity = json["currentActivity"] as? String
        let progress = json["progress"] as? Double ?? 0
        let completedCount = json["completedCount"] as? Int ?? 0
        let totalCount = json["totalCount"] as? Int ?? 0
        let elapsedSeconds = json["elapsedSeconds"] as? Int ?? 0

        // Parse tasks array
        let tasksArray = json["tasks"] as? [[String: Any]] ?? []
        let tasks = tasksArray.map { taskDict -> TodoItem in
            TodoItem(
                content: taskDict["content"] as? String ?? "",
                status: taskDict["status"] as? String ?? "pending",
                activeForm: taskDict["activeForm"] as? String
            )
        }

        // Batch the progress update (flushes every 2 seconds for smoother UI)
        let newProgress = SessionProgress(
            currentTask: currentTask,
            currentActivity: currentActivity,
            progress: progress,
            completedCount: completedCount,
            totalCount: totalCount,
            elapsedSeconds: elapsedSeconds,
            tasks: tasks
        )

        await MainActor.run {
            if totalCount > 0 {
                // Route through batcher for smoother updates
                activityBatcher?.add(newProgress)
            } else if sessionProgress != nil {
                // Only clear if we had progress before (avoid clearing on initial empty response)
                // Check staleness threshold
                if let lastUpdate = lastProgressUpdate {
                    let isComplete = sessionProgress?.isComplete ?? false
                    let threshold = isComplete ? completeStaleThreshold : progressStaleThreshold
                    if Date().timeIntervalSince(lastUpdate) > threshold {
                        sessionProgress = nil
                        lastProgressUpdate = nil
                    }
                }
            }
        }
    }

    /// Apply batched progress update to UI
    /// Called by ActivityBatcher after 2-second window
    private func applyBatchedProgress(_ progress: SessionProgress) {
        sessionProgress = progress
        lastProgressUpdate = Date()
    }

    // MARK: - Cloud Errors

    enum CloudError: LocalizedError {
        case invalidCode
        case invalidResponse
        case serverError(Int)
        case networkUnavailable
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "Invalid or expired code. Try again."
            case .invalidResponse:
                return "Unexpected server response."
            case .serverError(let code):
                return "Server error (\(code)). Try again."
            case .networkUnavailable:
                return "No network connection."
            case .timeout:
                return "Connection timed out."
            }
        }
    }

    // MARK: - Notifications
    private func showLocalNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }

        playHaptic(.notification)
    }

    // MARK: - Haptics

    /// Triggers haptic feedback on the Apple Watch.
    /// Provides tactile feedback for user actions and system events.
    /// - Parameter type: The haptic pattern to play (success, failure, notification, click, etc.)
    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Complication Data
    private func updateComplicationData() {
        sharedDefaults?.set(state.pendingActions.count, forKey: "pendingCount")
        sharedDefaults?.set(state.progress, forKey: "progress")
        sharedDefaults?.set(state.taskName, forKey: "taskName")
        sharedDefaults?.set(state.model, forKey: "model")
        sharedDefaults?.set(connectionStatus == .connected, forKey: "isConnected")

        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeWatchWidget")
    }

    // MARK: - Push Token Registration

    /// Registers the APNs device token for push notifications.
    /// Saves the token locally for cloud pairing and sends it to the server for remote notifications.
    /// - Parameter token: The device token provided by APNs during notification registration
    func registerPushToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        // Save token to UserDefaults for use during cloud pairing
        UserDefaults.standard.set(tokenString, forKey: "apnsDeviceToken")

        // Mark APNs as ready - pairing can now proceed with valid token
        isAPNsTokenReady = true

        send([
            "type": "register_push_token",
            "token": tokenString
        ])
    }

    // MARK: - Demo Mode (for UI testing)

    /// Loads demonstration data for UI testing and preview purposes.
    /// Populates the app with sample task state, pending actions, and simulated connection.
    /// Sets demo mode flag, simulates connected state, and adds three sample pending actions.
    /// Provides haptic feedback to confirm demo data loading.
    func loadDemoData() {
        // Enable demo mode flag
        isDemoMode = true

        // Simulate connected state
        connectionStatus = .connected

        // Set up a running task
        state.taskName = "Refactoring auth module"
        state.taskDescription = "Updating authentication to use OAuth2"
        state.progress = 0.45
        state.status = .waiting
        state.model = "opus"
        // Preserve persisted mode (don't overwrite with .normal)

        // Add some pending actions
        state.pendingActions = [
            PendingAction(
                id: "action-1",
                type: "file_edit",
                title: "Edit App.tsx",
                description: "Update main component",
                filePath: "src/app/App.tsx",
                command: nil,
                timestamp: Date().addingTimeInterval(-120)
            ),
            PendingAction(
                id: "action-2",
                type: "file_create",
                title: "Create AuthService.ts",
                description: "New authentication service",
                filePath: "src/services/AuthService.ts",
                command: nil,
                timestamp: Date().addingTimeInterval(-300)
            ),
            PendingAction(
                id: "action-3",
                type: "bash",
                title: "Run npm install",
                description: "Install new dependencies",
                filePath: nil,
                command: "npm install oauth2-client",
                timestamp: Date().addingTimeInterval(-480)
            ),
        ]

        playHaptic(.notification)
    }
}

// MARK: - Data Models

struct WatchState {
    var taskName: String = ""
    var taskDescription: String = ""
    var progress: Double = 0
    var status: SessionStatus = .idle
    var pendingActions: [PendingAction] = []
    var model: String = "opus"
    var mode: PermissionMode = .normal

    // Convenience for backward compatibility
    var yoloMode: Bool {
        mode == .autoAccept
    }
}

/// Session progress from Claude Code's TodoWrite hook
struct SessionProgress {
    var currentTask: String?
    var currentActivity: String?  // Active form for display (e.g., "Running tests")
    var progress: Double  // 0.0 to 1.0
    var completedCount: Int
    var totalCount: Int
    var elapsedSeconds: Int  // Time since session started
    var tasks: [TodoItem]  // Full task list with statuses
    var outcome: String?  // Summary of what was accomplished (shown on completion)

    init(
        currentTask: String? = nil,
        currentActivity: String? = nil,
        progress: Double = 0,
        completedCount: Int = 0,
        totalCount: Int = 0,
        elapsedSeconds: Int = 0,
        tasks: [TodoItem] = [],
        outcome: String? = nil
    ) {
        self.currentTask = currentTask
        self.currentActivity = currentActivity
        self.progress = progress
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.elapsedSeconds = elapsedSeconds
        self.tasks = tasks
        self.outcome = outcome
    }

    /// Check if progress is complete
    var isComplete: Bool {
        progress >= 1.0 || (totalCount > 0 && completedCount == totalCount)
    }

    /// Generate outcome summary from completed tasks if no explicit outcome provided
    var displayOutcome: String {
        if let outcome = outcome, !outcome.isEmpty {
            return outcome
        }
        // Generate from completed tasks
        let completed = tasks.filter { $0.status == .completed }
        if completed.isEmpty {
            return "Tasks completed"
        }
        return completed.map { $0.content }.joined(separator: ", ")
    }

    /// Format elapsed time as "1m 27s" or "45s"
    var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

/// A single todo item from Claude Code's task list
struct TodoItem: Identifiable {
    let id = UUID()
    let content: String
    let status: TodoStatus
    let activeForm: String?

    enum TodoStatus: String {
        case pending
        case inProgress = "in_progress"
        case completed

        var icon: String {
            switch self {
            case .pending: return "○"
            case .inProgress: return "●"
            case .completed: return "◉"
            }
        }

        var color: Color {
            switch self {
            case .pending: return Color.gray
            case .inProgress: return Color.orange
            case .completed: return Color.green
            }
        }

        var systemIcon: String {
            switch self {
            case .pending: return "circle"
            case .inProgress: return "circle.dotted.circle"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }

    init(content: String, status: String, activeForm: String? = nil) {
        self.content = content
        self.status = TodoStatus(rawValue: status) ?? .pending
        self.activeForm = activeForm
    }
}

// MARK: - Permission Mode (like Claude Code's Shift+Tab)
enum PermissionMode: String, CaseIterable {
    case normal = "normal"
    case autoAccept = "auto_accept"
    case plan = "plan"

    var displayName: String {
        switch self {
        case .normal: return "NORMAL"
        case .autoAccept: return "AUTO"
        case .plan: return "PLAN"
        }
    }

    var icon: String {
        switch self {
        case .normal: return "hand.raised"
        case .autoAccept: return "bolt.fill"
        case .plan: return "doc.text.magnifyingglass"
        }
    }

    var color: String {
        switch self {
        case .normal: return "blue"
        case .autoAccept: return "red"
        case .plan: return "purple"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Approve each action"
        case .autoAccept: return "Auto-approve all"
        case .plan: return "Read-only planning"
        }
    }

    func next() -> PermissionMode {
        let all = PermissionMode.allCases
        let currentIndex = all.firstIndex(of: self) ?? 0
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}

enum SessionStatus: String {
    case idle
    case running
    case waiting
    case completed
    case failed

    var displayName: String {
        switch self {
        case .idle: return "IDLE"
        case .running: return "RUNNING"
        case .waiting: return "WAITING"
        case .completed: return "DONE"
        case .failed: return "FAILED"
        }
    }

    var color: String {
        switch self {
        case .idle: return "gray"
        case .running: return "green"
        case .waiting: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        }
    }
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, nextRetryIn: TimeInterval)

    var displayName: String {
        switch self {
        case .disconnected: return "OFFLINE"
        case .connecting: return "CONNECTING"
        case .connected: return "CONNECTED"
        case .reconnecting(let attempt, _): return "RETRY \(attempt)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - WebSocket Error Types
enum WebSocketError: Error {
    case handshakeTimeout
    case pongTimeout
    case sendFailed(Error)
    case receiveFailed(Error)
    case invalidURL
    case networkUnavailable
    case maxRetriesExceeded

    var isRecoverable: Bool {
        switch self {
        case .invalidURL, .maxRetriesExceeded:
            return false
        default:
            return true
        }
    }

    var localizedDescription: String {
        switch self {
        case .handshakeTimeout: return "Connection timeout"
        case .pongTimeout: return "Server not responding"
        case .sendFailed(let error): return "Send failed: \(error.localizedDescription)"
        case .receiveFailed(let error): return "Receive failed: \(error.localizedDescription)"
        case .invalidURL: return "Invalid server URL"
        case .networkUnavailable: return "Network unavailable"
        case .maxRetriesExceeded: return "Max reconnection attempts exceeded"
        }
    }
}

// MARK: - Reconnection Configuration
struct ReconnectionConfig {
    let initialDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 60.0
    let multiplier: Double = 2.0
    let maxRetries: Int = 10
    let jitterFactor: Double = 0.2

    func delay(forAttempt attempt: Int) -> TimeInterval {
        let baseDelay = min(initialDelay * pow(multiplier, Double(attempt)), maxDelay)
        let jitter = baseDelay * jitterFactor * Double.random(in: -1...1)
        return max(0.1, baseDelay + jitter) // Ensure positive delay
    }
}

// MARK: - Activity Batching (Happy Pattern)
/// Batches high-frequency updates and flushes every 2 seconds
/// Prevents UI thrashing and reduces network calls
/// Reference: happy-reference/sources/sync/sync.ts (ActivityUpdateAccumulator)
@MainActor
class ActivityBatcher {
    private var pendingProgress: SessionProgress?
    private var flushTimer: Timer?
    private let flushInterval: TimeInterval = 2.0
    private let onFlush: (SessionProgress) -> Void

    init(onFlush: @escaping (SessionProgress) -> Void) {
        self.onFlush = onFlush
    }

    /// Add a progress update to the batch
    func add(_ progress: SessionProgress) {
        // Keep the latest progress (overwrites previous)
        pendingProgress = progress
        scheduleFlush()
    }

    /// Schedule a flush if not already scheduled
    private func scheduleFlush() {
        guard flushTimer == nil else { return }

        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.flush()
            }
        }
    }

    /// Flush pending updates
    private func flush() {
        flushTimer?.invalidate()
        flushTimer = nil

        if let progress = pendingProgress {
            pendingProgress = nil
            onFlush(progress)
        }
    }

    /// Force immediate flush (for app lifecycle events)
    func flushNow() {
        flushTimer?.invalidate()
        flushTimer = nil

        if let progress = pendingProgress {
            pendingProgress = nil
            onFlush(progress)
        }
    }

    /// Cancel pending flush (for cleanup)
    func cancel() {
        flushTimer?.invalidate()
        flushTimer = nil
        pendingProgress = nil
    }
}

// MARK: - Message Queue Types
struct QueuedMessage: Identifiable {
    let id = UUID()
    let payload: [String: Any]
    let createdAt: Date
    var retryCount: Int = 0
    let maxRetries: Int = 3
    let priority: MessagePriority

    enum MessagePriority: Int, Comparable {
        case low = 0      // state requests
        case normal = 1   // mode changes
        case high = 2     // approve/reject actions

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var canRetry: Bool {
        retryCount < maxRetries
    }
}

struct PendingAction: Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let filePath: String?
    let command: String?
    let timestamp: Date

    // Direct initializer for demo/testing
    init(id: String, type: String, title: String, description: String, filePath: String?, command: String?, timestamp: Date) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.filePath = filePath
        self.command = command
        self.timestamp = timestamp
    }

    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let type = data["type"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String else {
            return nil
        }

        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.filePath = data["file_path"] as? String
        self.command = data["command"] as? String

        if let ts = data["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            self.timestamp = formatter.date(from: ts) ?? Date()
        } else {
            self.timestamp = Date()
        }
    }

    var icon: String {
        switch type {
        case "file_edit": return "pencil"
        case "file_create": return "doc.badge.plus"
        case "file_delete": return "trash"
        case "bash": return "terminal"
        default: return "gear"
        }
    }

    var typeColor: String {
        switch type {
        case "file_edit": return "blue"
        case "file_create": return "green"
        case "file_delete": return "red"
        case "bash": return "orange"
        default: return "purple"
        }
    }
}

// MARK: - Foundation Models Status

/// Status of Foundation Models (on-device AI) availability
enum FoundationModelsStatus: Equatable {
    case checking
    case available
    case downloading
    case unavailable(FoundationModelsUnavailabilityReason)

    var displayName: String {
        switch self {
        case .checking:
            return "Checking..."
        case .available:
            return "Ready"
        case .downloading:
            return "Downloading..."
        case .unavailable(let reason):
            return reason.displayName
        }
    }

    var icon: String {
        switch self {
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .available:
            return "brain"
        case .downloading:
            return "arrow.down.circle"
        case .unavailable:
            return "brain.head.profile.slash"
        }
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

/// Reasons why Foundation Models may be unavailable
enum FoundationModelsUnavailabilityReason: Equatable {
    case deviceNotSupported
    case appleIntelligenceDisabled
    case platformNotSupported
    case unknown

    var displayName: String {
        switch self {
        case .deviceNotSupported:
            return "Device not supported"
        case .appleIntelligenceDisabled:
            return "Enable Apple Intelligence"
        case .platformNotSupported:
            return "Not available on watchOS"
        case .unknown:
            return "Unavailable"
        }
    }

    var description: String {
        switch self {
        case .deviceNotSupported:
            return "This device doesn't support Apple Intelligence. Requires iPhone 15 Pro or later, or M1 Mac."
        case .appleIntelligenceDisabled:
            return "Turn on Apple Intelligence in Settings to use on-device AI features."
        case .platformNotSupported:
            return "Foundation Models are not available on watchOS. AI features work on iPhone, iPad, and Mac."
        case .unknown:
            return "On-device AI is currently unavailable."
        }
    }
}
