import Foundation
import WatchConnectivity
import Combine

/// Service for communicating with the paired iPhone/Mac running Claude Code
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isReachable = false
    @Published var lastReceivedMessage: [String: Any]?

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send Messages
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            print("Watch session not reachable")
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }

    // MARK: - Action Commands
    func sendAcceptCommand() {
        sendMessage([
            "action": "accept",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendDiscardCommand() {
        sendMessage([
            "action": "discard",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendApproveCommand() {
        sendMessage([
            "action": "approve",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendRetryCommand() {
        sendMessage([
            "action": "retry",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendApproveAllCommand() {
        sendMessage([
            "action": "approveAll",
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendToggleYoloCommand(enabled: Bool) {
        sendMessage([
            "action": "toggleYolo",
            "enabled": enabled,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendModelChangeCommand(model: String) {
        sendMessage([
            "action": "changeModel",
            "model": model,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    func sendPromptCommand(prompt: String) {
        sendMessage([
            "action": "sendPrompt",
            "prompt": prompt,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    // MARK: - Request Updates
    func requestStatusUpdate() {
        sendMessage([
            "action": "requestStatus",
            "timestamp": Date().timeIntervalSince1970
        ]) { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleStatusUpdate(reply)
            }
        }
    }

    private func handleStatusUpdate(_ data: [String: Any]) {
        // Parse and broadcast status update
        NotificationCenter.default.post(
            name: .claudeStatusUpdated,
            object: nil,
            userInfo: data
        )
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }

        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message
            self.handleIncomingMessage(message)
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message
            self.handleIncomingMessage(message)
        }
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handleStatusUpdate(applicationContext)
        }
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "taskUpdate":
            NotificationCenter.default.post(name: .claudeTaskUpdated, object: nil, userInfo: message)

        case "actionPending":
            NotificationCenter.default.post(name: .claudeActionPending, object: nil, userInfo: message)

        case "statusUpdate":
            NotificationCenter.default.post(name: .claudeStatusUpdated, object: nil, userInfo: message)

        case "notification":
            // Show local notification for important updates
            if let title = message["title"] as? String,
               let body = message["body"] as? String {
                showLocalNotification(title: title, body: body)
            }

        default:
            print("Unknown message type: \(type)")
        }
    }

    private func showLocalNotification(title: String, body: String) {
        // Create and schedule local notification
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let claudeTaskUpdated = Notification.Name("claudeTaskUpdated")
    static let claudeActionPending = Notification.Name("claudeActionPending")
    static let claudeStatusUpdated = Notification.Name("claudeStatusUpdated")
}

// MARK: - Message Types for Type Safety
enum ClaudeMessageType: String {
    case taskUpdate
    case actionPending
    case statusUpdate
    case notification
}

struct ClaudeStatusMessage: Codable {
    let taskName: String?
    let taskProgress: Double
    let taskStatus: String
    let pendingActionsCount: Int
    let selectedModel: String
    let yoloMode: Bool
    let subscriptionPercent: Int
}
