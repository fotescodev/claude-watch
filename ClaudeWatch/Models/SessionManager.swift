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

    // MARK: - Initialization
    init() {
        loadConfig()
        setupMockData() // For demo purposes
    }

    // MARK: - Connection Management
    func connect() {
        connectionStatus = .connecting

        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.connectionStatus = .connected
            self?.isConnected = true
            self?.playHaptic(.success)
        }
    }

    func disconnect() {
        connectionStatus = .disconnected
        isConnected = false
        currentTask = nil
        pendingActions = []
    }

    // MARK: - Action Handlers
    func acceptChanges() {
        guard let action = pendingActions.first else { return }
        playHaptic(.success)

        withAnimation(.spring(response: 0.3)) {
            pendingActions.removeFirst()
        }

        // Update task progress
        if var task = currentTask {
            task.progress = min(task.progress + 0.1, 1.0)
            if task.progress >= 1.0 {
                task.status = .completed
            }
            currentTask = task
        }
    }

    func discardChanges() {
        guard !pendingActions.isEmpty else { return }
        playHaptic(.failure)

        withAnimation(.spring(response: 0.3)) {
            pendingActions.removeFirst()
        }
    }

    func approveAction() {
        acceptChanges()
    }

    func retryAction() {
        playHaptic(.retry)

        // Re-queue the current action
        if let action = pendingActions.first {
            var retryAction = action
            retryAction.timestamp = Date()
            pendingActions[0] = retryAction
        }
    }

    func approveAll() {
        playHaptic(.success)

        withAnimation(.spring(response: 0.5)) {
            pendingActions.removeAll()
        }

        if var task = currentTask {
            task.progress = 1.0
            task.status = .completed
            currentTask = task
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

        // Simulate starting a new task
        currentTask = TaskState(name: prompt.text.uppercased(), progress: 0.0, status: .running)

        // Simulate progress
        simulateTaskProgress()
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

    // MARK: - Mock Data (Demo)
    private func setupMockData() {
        currentTask = TaskState(
            name: "CODE REFACTOR",
            progress: 0.6,
            status: .waitingApproval
        )

        pendingActions = [
            PendingAction(type: .fileEdit, description: "Update SessionManager.swift", filePath: "ClaudeWatch/Models/SessionManager.swift"),
            PendingAction(type: .bashCommand, description: "Run swift build"),
            PendingAction(type: .fileCreate, description: "Create new test file", filePath: "Tests/SessionTests.swift"),
        ]

        isConnected = true
        connectionStatus = .connected
    }

    private func simulateTaskProgress() {
        guard var task = currentTask else { return }

        // Simulate gradual progress
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, var currentTask = self.currentTask else {
                timer.invalidate()
                return
            }

            if currentTask.progress < 1.0 && !self.config.yoloMode {
                currentTask.progress += 0.05

                // Add pending action at certain progress points
                if Int(currentTask.progress * 100) % 20 == 0 {
                    let action = PendingAction(
                        type: [.fileEdit, .bashCommand, .toolCall].randomElement()!,
                        description: "Pending action \(Int(currentTask.progress * 100))%"
                    )
                    self.pendingActions.append(action)
                    currentTask.status = .waitingApproval
                    self.playHaptic(.notification)
                }

                self.currentTask = currentTask
            } else {
                currentTask.status = .completed
                currentTask.progress = 1.0
                self.currentTask = currentTask
                self.playHaptic(.success)
                timer.invalidate()
            }
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
