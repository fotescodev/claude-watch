import Foundation
import Combine
import WatchKit
import UserNotifications

/// Main service for communicating with Claude Watch MCP Server
/// Uses WebSocket for real-time updates, with REST fallback
@MainActor
class WatchService: ObservableObject {
    static let shared = WatchService()

    // MARK: - Published State
    @Published var state = WatchState()
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: String?

    // MARK: - Configuration
    @AppStorage("serverURL") var serverURLString = "ws://localhost:8787"

    // MARK: - Private
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        urlSession = URLSession(configuration: config)
    }

    // MARK: - Connection
    func connect() {
        disconnect()
        connectionStatus = .connecting

        guard let url = URL(string: serverURLString) else {
            connectionStatus = .disconnected
            lastError = "Invalid server URL"
            return
        }

        webSocket = urlSession.webSocketTask(with: url)
        webSocket?.resume()

        connectionStatus = .connected
        startReceiving()
        startPingLoop()

        // Request current state
        send(["type": "get_state"])
    }

    func disconnect() {
        pingTask?.cancel()
        reconnectTask?.cancel()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
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
                state.yoloMode = json["enabled"] as? Bool ?? false

            case "pong":
                break // Ping response received

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
        state.yoloMode = data["yolo_mode"] as? Bool ?? false

        if let statusStr = data["status"] as? String {
            state.status = SessionStatus(rawValue: statusStr) ?? .idle
        }

        if let actionsData = data["pending_actions"] as? [[String: Any]] {
            state.pendingActions = actionsData.compactMap { PendingAction(from: $0) }
        }
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
    }

    private func handleDisconnection(error: Error) {
        connectionStatus = .disconnected
        lastError = error.localizedDescription

        // Attempt reconnection
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                connect()
            }
        }
    }

    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                send(["type": "ping"])
            }
        }
    }

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        webSocket?.send(.string(string)) { _ in }
    }

    // MARK: - Actions
    func approveAction(_ actionId: String) {
        send([
            "type": "action_response",
            "action_id": actionId,
            "approved": true
        ])

        // Optimistic update
        state.pendingActions.removeAll { $0.id == actionId }
        if state.pendingActions.isEmpty {
            state.status = .running
        }

        playHaptic(.success)
    }

    func rejectAction(_ actionId: String) {
        send([
            "type": "action_response",
            "action_id": actionId,
            "approved": false
        ])

        // Optimistic update
        state.pendingActions.removeAll { $0.id == actionId }
        if state.pendingActions.isEmpty {
            state.status = .running
        }

        playHaptic(.failure)
    }

    func approveAll() {
        send(["type": "approve_all"])

        // Optimistic update
        state.pendingActions.removeAll()
        state.status = .running

        playHaptic(.success)
    }

    func toggleYolo() {
        let newValue = !state.yoloMode
        send([
            "type": "toggle_yolo",
            "enabled": newValue
        ])

        // Optimistic update
        state.yoloMode = newValue

        playHaptic(newValue ? .start : .stop)
    }

    func sendPrompt(_ text: String) {
        send([
            "type": "prompt",
            "text": text
        ])

        playHaptic(.click)
    }

    // MARK: - Haptics
    func playHaptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Push Token Registration
    func registerPushToken(_ token: Data) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        send([
            "type": "register_push_token",
            "token": tokenString
        ])
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
    var yoloMode: Bool = false
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

enum ConnectionStatus: String {
    case disconnected
    case connecting
    case connected
}

struct PendingAction: Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let filePath: String?
    let command: String?
    let timestamp: Date

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
