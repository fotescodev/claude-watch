import Foundation
import SwiftUI
import Combine
import WatchKit

@MainActor
class SessionManager: ObservableObject {
    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var currentTask: TaskState?
    @Published var pendingActions: [PendingAction] = []
    @Published var config: SessionConfig = .default
    @Published var recentPrompts: [QuickPrompt] = []
    @Published var subscriptionPercent: Int = 85
    @Published var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Bridge Service (Web Sessions)
    private let bridgeService = ClaudeBridgeService.shared

    // MARK: - Quick Prompts Library
    let quickPrompts: [QuickPrompt] = [
        QuickPrompt(text: "Continue", icon: "arrow.right", category: .action),
        QuickPrompt(text: "Run tests", icon: "checkmark.diamond", category: .action),
        QuickPrompt(text: "Fix errors", icon: "ant", category: .action),
        QuickPrompt(text: "Explain this", icon: "questionmark.circle", category: .question),
        QuickPrompt(text: "Show diff", icon: "doc.text.magnifyingglass", category: .navigation),
        QuickPrompt(text: "Commit changes", icon: "tray.and.arrow.up", category: .action),
        QuickPrompt(text: "Undo last", icon: "arrow.uturn.backward", category: .action),
        QuickPrompt(text: "Summarize", icon: "text.alignleft", category: .question),
    ]

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        loadConfig()
        setupBridgeServiceObservers()
    }

    private func setupBridgeServiceObservers() {
        // Observe bridge service state changes
        bridgeService.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                self?.isConnected = connected
                self?.connectionStatus = connected ? .connected : .disconnected
            }
            .store(in: &cancellables)

        bridgeService.$currentSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                self?.syncSessionState(from: session)
            }
            .store(in: &cancellables)

        bridgeService.$serverStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .connected: self?.connectionStatus = .connected
                case .connecting: self?.connectionStatus = .connecting
                case .disconnected: self?.connectionStatus = .disconnected
                }
            }
            .store(in: &cancellables)
    }

    private func syncSessionState(from webSession: WebSession?) {
        guard let session = webSession else {
            currentTask = nil
            pendingActions = []
            return
        }

        // Map web session to local task state
        currentTask = TaskState(
            name: session.taskName,
            progress: session.progress,
            status: mapSessionStatus(session.statusEnum)
        )

        // Map pending actions
        pendingActions = session.pendingActions.map { action in
            PendingAction(
                id: UUID(uuidString: action.id) ?? UUID(),
                type: action.actionType,
                description: action.description,
                filePath: action.filePath,
                timestamp: ISO8601DateFormatter().date(from: action.timestamp) ?? Date()
            )
        }
    }

    private func mapSessionStatus(_ status: SessionStatus) -> TaskStatus {
        switch status {
        case .starting: return .pending
        case .running: return .running
        case .waiting_approval: return .waitingApproval
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .failed
        }
    }

    // MARK: - Connection Management
    func connect() {
        connectionStatus = .connecting
        Task {
            await bridgeService.connect()
        }
    }

    func disconnect() {
        bridgeService.disconnect()
        connectionStatus = .disconnected
        isConnected = false
        currentTask = nil
        pendingActions = []
    }

    // MARK: - Action Handlers
    func acceptChanges() {
        guard let session = bridgeService.currentSession,
              let action = pendingActions.first else { return }
        playHaptic(.success)

        Task {
            do {
                try await bridgeService.approveAction(sessionId: session.id, actionId: action.id.uuidString)
            } catch {
                print("Failed to approve action: \(error)")
            }
        }
    }

    func discardChanges() {
        guard let session = bridgeService.currentSession,
              let action = pendingActions.first else { return }
        playHaptic(.failure)

        Task {
            do {
                try await bridgeService.discardAction(sessionId: session.id, actionId: action.id.uuidString)
            } catch {
                print("Failed to discard action: \(error)")
            }
        }
    }

    func approveAction() {
        acceptChanges()
    }

    func retryAction() {
        playHaptic(.retry)
        // For retry, we just refresh - the action stays in place
        Task {
            await bridgeService.refreshSessions()
        }
    }

    func approveAll() {
        guard let session = bridgeService.currentSession else { return }
        playHaptic(.success)

        Task {
            do {
                try await bridgeService.approveAll(sessionId: session.id)
            } catch {
                print("Failed to approve all: \(error)")
            }
        }
    }

    // MARK: - YOLO Mode
    func toggleYoloMode() {
        config.yoloMode.toggle()
        playHaptic(config.yoloMode ? .start : .stop)
        saveConfig()

        if config.yoloMode {
            // Auto-approve all pending actions
            approveAll()
        }
    }

    // MARK: - Model Selection
    func selectModel(_ model: ClaudeModel) {
        config.selectedModel = model
        playHaptic(.click)
        saveConfig()
    }

    func cycleModel() {
        let models = ClaudeModel.allCases
        if let currentIndex = models.firstIndex(of: config.selectedModel) {
            let nextIndex = (currentIndex + 1) % models.count
            selectModel(models[nextIndex])
        }
    }

    // MARK: - Prompt Handling
    func sendPrompt(_ prompt: QuickPrompt) {
        playHaptic(.click)

        // Add to recent prompts
        if !recentPrompts.contains(where: { $0.text == prompt.text }) {
            recentPrompts.insert(prompt, at: 0)
            if recentPrompts.count > 5 {
                recentPrompts.removeLast()
            }
        }

        // Create web session with the prompt
        Task {
            do {
                let session = try await bridgeService.createSession(prompt: prompt.text)
                print("Created session: \(session.id)")
            } catch {
                print("Failed to create session: \(error)")
            }
        }
    }

    func sendVoicePrompt(_ text: String) {
        let prompt = QuickPrompt(text: text, icon: "mic.fill", category: .action)
        sendPrompt(prompt)
    }

    // MARK: - Haptic Feedback
    func playHaptic(_ type: HapticType) {
        guard config.hapticFeedback else { return }

        let device = WKInterfaceDevice.current()
        switch type {
        case .success:
            device.play(.success)
        case .failure:
            device.play(.failure)
        case .click:
            device.play(.click)
        case .start:
            device.play(.start)
        case .stop:
            device.play(.stop)
        case .retry:
            device.play(.retry)
        case .notification:
            device.play(.notification)
        }
    }

    // MARK: - Persistence
    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "sessionConfig")
        }
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: "sessionConfig"),
           let loaded = try? JSONDecoder().decode(SessionConfig.self, from: data) {
            config = loaded
        }
    }

    // MARK: - Server URL Configuration
    var serverURL: String {
        get { bridgeService.serverURLString }
        set {
            bridgeService.serverURLString = newValue
            bridgeService.updateBaseURL()
        }
    }
}

// MARK: - Supporting Types
enum ConnectionStatus: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"

    var color: Color {
        switch self {
        case .disconnected: return .red
        case .connecting: return .orange
        case .connected: return .green
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

enum HapticType {
    case success
    case failure
    case click
    case start
    case stop
    case retry
    case notification
}
