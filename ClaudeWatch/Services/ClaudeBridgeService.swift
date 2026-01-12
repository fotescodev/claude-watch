import Foundation
import Combine

/// Service for communicating with the Claude Watch Bridge Server via HTTP
/// This enables direct communication from Apple Watch to Claude Code web sessions
/// over 5G/WiFi without requiring an iPhone as intermediary
@MainActor
class ClaudeBridgeService: ObservableObject {
    static let shared = ClaudeBridgeService()

    // MARK: - Published State
    @Published var isConnected = false
    @Published var serverStatus: ServerStatus = .disconnected
    @Published var activeSessions: [WebSession] = []
    @Published var currentSession: WebSession?
    @Published var lastError: String?

    // MARK: - Configuration
    private var baseURL: URL?
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 2.0

    // User configurable server URL
    @AppStorage("bridgeServerURL") var serverURLString: String = "http://localhost:8787"

    private var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Initialization
    init() {
        updateBaseURL()
    }

    func updateBaseURL() {
        baseURL = URL(string: serverURLString)
    }

    // MARK: - Connection Management
    func connect() async {
        serverStatus = .connecting
        updateBaseURL()

        do {
            let status = try await checkServerStatus()
            if status.status == "ok" {
                isConnected = true
                serverStatus = .connected
                startPolling()
                await refreshSessions()
            }
        } catch {
            isConnected = false
            serverStatus = .disconnected
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        stopPolling()
        isConnected = false
        serverStatus = .disconnected
        currentSession = nil
        activeSessions = []
    }

    // MARK: - Session Management
    func createSession(prompt: String, workingDir: String? = nil) async throws -> WebSession {
        guard let url = baseURL?.appendingPathComponent("session") else {
            throw BridgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateSessionRequest(prompt: prompt, working_dir: workingDir)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        let session = try JSONDecoder().decode(WebSession.self, from: data)
        currentSession = session
        await refreshSessions()

        return session
    }

    func getSession(id: String) async throws -> WebSession {
        guard let url = baseURL?.appendingPathComponent("session/\(id)") else {
            throw BridgeError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response)

        return try JSONDecoder().decode(WebSession.self, from: data)
    }

    func refreshSessions() async {
        guard let url = baseURL?.appendingPathComponent("sessions") else { return }

        do {
            let (data, response) = try await urlSession.data(from: url)
            try validateResponse(response)

            activeSessions = try JSONDecoder().decode([WebSession].self, from: data)

            // Update current session if exists
            if let current = currentSession,
               let updated = activeSessions.first(where: { $0.id == current.id }) {
                currentSession = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Action Commands
    func approveAction(sessionId: String, actionId: String? = nil) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionId)/approve") else {
            throw BridgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let actionId = actionId {
            let body = ActionRequest(action_id: actionId)
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        await refreshSessions()
    }

    func approveAll(sessionId: String) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionId)/approveAll") else {
            throw BridgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        await refreshSessions()
    }

    func discardAction(sessionId: String, actionId: String? = nil) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionId)/discard") else {
            throw BridgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let actionId = actionId {
            let body = ActionRequest(action_id: actionId)
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        await refreshSessions()
    }

    func cancelSession(sessionId: String) async throws {
        guard let url = baseURL?.appendingPathComponent("session/\(sessionId)/cancel") else {
            throw BridgeError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (_, response) = try await urlSession.data(for: request)
        try validateResponse(response)

        if currentSession?.id == sessionId {
            currentSession = nil
        }

        await refreshSessions()
    }

    // MARK: - Server Status
    func checkServerStatus() async throws -> ServerStatusResponse {
        guard let url = baseURL?.appendingPathComponent("status") else {
            throw BridgeError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)
        try validateResponse(response)

        return try JSONDecoder().decode(ServerStatusResponse.self, from: data)
    }

    // MARK: - Polling
    private func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshSessions()
            }
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Helpers
    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BridgeError.serverError(httpResponse.statusCode)
        }
    }
}

// MARK: - Data Types
struct WebSession: Codable, Identifiable {
    let id: String
    let prompt: String
    let status: String
    let progress: Double
    let task_name: String
    let pending_actions: [WebPendingAction]
    let output_log: [String]
    let created_at: String
    let completed_at: String?
    let web_session_id: String?
    let error: String?

    var statusEnum: SessionStatus {
        SessionStatus(rawValue: status) ?? .running
    }

    var taskName: String { task_name }
    var pendingActions: [WebPendingAction] { pending_actions }
}

struct WebPendingAction: Codable, Identifiable {
    let id: String
    let type: String
    let description: String
    let file_path: String?
    let timestamp: String

    var actionType: ActionType {
        ActionType(rawValue: type) ?? .toolCall
    }

    var filePath: String? { file_path }
}

enum SessionStatus: String, Codable {
    case starting
    case running
    case waiting_approval
    case completed
    case failed
    case cancelled
}

struct CreateSessionRequest: Codable {
    let prompt: String
    let working_dir: String?
}

struct ActionRequest: Codable {
    let action_id: String
}

struct ServerStatusResponse: Codable {
    let status: String
    let server: String?
    let version: String?
    let active_sessions: Int?
}

enum ServerStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"

    var color: String {
        switch self {
        case .disconnected: return "red"
        case .connecting: return "orange"
        case .connected: return "green"
        }
    }

    var icon: String {
        switch self {
        case .disconnected: return "wifi.slash"
        case .connecting: return "wifi.exclamationmark"
        case .connected: return "wifi"
        }
    }
}

enum BridgeError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - App Storage wrapper for URL
extension AppStorage where Value == String {
    init(wrappedValue: String, _ key: String) {
        self.init(wrappedValue: wrappedValue, key)
    }
}
