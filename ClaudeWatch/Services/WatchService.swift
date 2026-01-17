import Foundation
import Combine
import SwiftUI
import WatchKit
import UserNotifications
import Network
import WidgetKit

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

    // MARK: - Configuration
    @AppStorage("serverURL") var serverURLString = "ws://192.168.1.165:8787"
    @AppStorage("cloudServerURL") var cloudServerURL = "https://claude-watch.fotescodev.workers.dev"
    @AppStorage("pairingId") var pairingId: String = ""
    @AppStorage("useCloudMode") var useCloudMode = true  // Use cloud relay by default

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

    // MARK: - Demo Mode
    @AppStorage("demoMode") var isDemoMode = false  // Connect to real server by default

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)

        // Start network monitoring
        startNetworkMonitoring()

        // Load demo data if demo mode is enabled
        if isDemoMode {
            loadDemoData()
        }
    }

    nonisolated deinit {
        // Note: NWPathMonitor.cancel() is thread-safe
        // We access it directly here since deinit is nonisolated
    }

    // MARK: - App Lifecycle

    /// Handles app transition to active state.
    /// Resets reconnection backoff and initiates connection (polling in cloud mode, WebSocket otherwise).
    func handleAppDidBecomeActive() {
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

    /// Handles app transition to inactive state.
    /// Currently a no-op, allowing the system to manage connection lifecycle.
    func handleAppWillResignActive() {
        // Don't disconnect - let the system handle it
        // But we could pause aggressive reconnection if needed
    }

    /// Handles app entering background state.
    /// Stops polling in cloud mode to conserve battery, or sends final state request in WebSocket mode.
    func handleAppDidEnterBackground() {
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

        // Add to pending actions
        if !state.pendingActions.contains(where: { $0.id == action.id }) {
            state.pendingActions.append(action)
        }
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

        playHaptic(.failure)
    }

    /// Approves all pending actions at once.
    /// Clears all pending actions locally and notifies server to proceed with all requests.
    func approveAll() {
        send(["type": "approve_all"], priority: .high)

        // Optimistic update
        state.pendingActions.removeAll()
        state.status = .running

        playHaptic(.success)
    }

    /// Legacy method for toggling YOLO mode.
    /// Now delegates to `cycleMode()` to cycle through all permission modes.
    func toggleYolo() {
        // Legacy support - now cycles through modes
        cycleMode()
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
        send([
            "type": "set_mode",
            "mode": mode.rawValue
        ])

        // Optimistic update
        state.mode = mode

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

        send([
            "type": "prompt",
            "text": text
        ])

        isSendingPrompt = false
        playHaptic(.success)
    }

    // MARK: - Cloud Mode (Production)

    /// Complete pairing with Claude Code using a 6-character code.
    /// Sends the pairing code and device token to the cloud server to establish a persistent connection.
    /// - Parameter code: The 6-character pairing code displayed in Claude Code
    /// - Throws: `CloudError.invalidCode` if the code is invalid or expired,
    ///           `CloudError.invalidResponse` if the server response is malformed,
    ///           `CloudError.serverError` if the server returns an error status code
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

        playHaptic(approved ? .success : .failure)
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
        playHaptic(.click)
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
                    try await self.fetchPendingRequests()
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

        // Update state
        state.pendingActions = newActions

        if !state.pendingActions.isEmpty {
            state.status = .waiting
        }

        // Play haptic for new actions
        if !addedIds.isEmpty {
            playHaptic(.notification)
        }
    }

    // MARK: - Cloud Errors

    enum CloudError: LocalizedError {
        case invalidCode
        case invalidResponse
        case serverError(Int)
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidCode:
                return "Invalid or expired pairing code"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let code):
                return "Server error: \(code)"
            case .timeout:
                return "Request timed out"
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
        state.mode = .normal

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
