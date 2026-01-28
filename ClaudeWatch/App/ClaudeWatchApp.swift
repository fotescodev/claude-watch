import SwiftUI
import WatchKit
import UserNotifications
import os

private let logger = Logger(subsystem: "com.edgeoftrust.claudewatch", category: "App")

@main
struct ClaudeWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("hasAcceptedConsent") private var hasAcceptedConsent = false

    var body: some Scene {
        WindowGroup {
            if hasAcceptedConsent {
                NavigationStack {
                    MainView()
                }
            } else {
                ConsentView()
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                self.registerNotificationCategories()
                self.registerForRemoteNotifications()
            }
        }

        UNUserNotificationCenter.current().delegate = self
    }

    private func registerNotificationCategories() {
        // Approve action
        let approveAction = UNNotificationAction(
            identifier: "APPROVE_ACTION",
            title: "Approve",
            options: [.foreground]
        )

        // Reject action
        let rejectAction = UNNotificationAction(
            identifier: "REJECT_ACTION",
            title: "Reject",
            options: [.destructive]
        )

        // Approve all action
        let approveAllAction = UNNotificationAction(
            identifier: "APPROVE_ALL_ACTION",
            title: "Approve All",
            options: [.foreground]
        )

        // Claude action category (for pending actions)
        let actionCategory = UNNotificationCategory(
            identifier: "CLAUDE_ACTION",
            actions: [approveAction, rejectAction, approveAllAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Register categories
        UNUserNotificationCenter.current().setNotificationCategories([actionCategory])
    }

    private func registerForRemoteNotifications() {
        WKApplication.shared().registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        // Send token to server
        Task { @MainActor in
            WatchService.shared.registerPushToken(deviceToken)
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        logger.error("Failed to register for remote notifications: \(error)")
    }

    /// Handle silent/background push notifications (content-available: 1)
    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void) {
        let notificationType = userInfo["type"] as? String

        if notificationType == "progress" {
            // Handle progress update
            handleProgressNotificationBackground(userInfo: userInfo)
            completionHandler(.newData)
        } else {
            completionHandler(.noData)
        }
    }

    /// Parse progress notification and update WatchService (background)
    private func handleProgressNotificationBackground(userInfo: [AnyHashable: Any]) {
        let currentTask = userInfo["currentTask"] as? String
        let currentActivity = userInfo["currentActivity"] as? String
        let progress = userInfo["progress"] as? Double ?? 0
        let completedCount = userInfo["completedCount"] as? Int ?? 0
        let totalCount = userInfo["totalCount"] as? Int ?? 0
        let elapsedSeconds = userInfo["elapsedSeconds"] as? Int ?? 0

        // Parse tasks array if present
        let tasksArray = userInfo["tasks"] as? [[String: Any]] ?? []
        let tasks = tasksArray.map { taskDict -> TodoItem in
            TodoItem(
                content: taskDict["content"] as? String ?? "",
                status: taskDict["status"] as? String ?? "pending",
                activeForm: taskDict["activeForm"] as? String
            )
        }

        Task { @MainActor in
            let service = WatchService.shared

            if totalCount > 0 {
                service.sessionProgress = SessionProgress(
                    currentTask: currentTask,
                    currentActivity: currentActivity,
                    progress: progress,
                    completedCount: completedCount,
                    totalCount: totalCount,
                    elapsedSeconds: elapsedSeconds,
                    tasks: tasks
                )
                service.lastProgressUpdate = Date()
            } else {
                service.sessionProgress = nil
                service.lastProgressUpdate = nil
            }
        }
    }

    // MARK: - App Lifecycle

    func applicationDidBecomeActive() {
        Task { @MainActor in
            WatchService.shared.handleAppDidBecomeActive()
        }
    }

    func applicationWillResignActive() {
        Task { @MainActor in
            WatchService.shared.handleAppWillResignActive()
        }
    }

    func applicationDidEnterBackground() {
        Task { @MainActor in
            WatchService.shared.handleAppDidEnterBackground()
        }
    }
}

// MARK: - Notification Handling
extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        // Check notification type
        let notificationType = userInfo["type"] as? String

        if notificationType == "progress" {
            // Handle progress update - update UI without showing banner
            handleProgressNotification(userInfo: userInfo)
            completionHandler([])
        } else if notificationType == "question" {
            // F18: Question Response - show QuestionResponseView
            Task { @MainActor in
                WatchService.shared.handleQuestionNotification(userInfo)
            }
            completionHandler([])
        } else if notificationType == "context_warning" {
            // F16: Context Warning - show ContextWarningView
            Task { @MainActor in
                WatchService.shared.handleContextWarningNotification(userInfo)
            }
            completionHandler([])
        } else {
            // Parse notification payload and add to pending actions
            addPendingActionFromNotification(userInfo: userInfo)
            // App is in foreground - suppress banner, let UI show the action inline
            // The action is already added to pendingActions queue above
            completionHandler([])
        }
    }

    /// Handle progress notification from Claude Code's TodoWrite hook (foreground)
    private func handleProgressNotification(userInfo: [AnyHashable: Any]) {
        // Use the same parsing logic as background handler
        handleProgressNotificationBackground(userInfo: userInfo)
    }

    /// Parse notification payload and add to WatchService pending actions
    private func addPendingActionFromNotification(userInfo: [AnyHashable: Any]) {
        guard let requestId = userInfo["requestId"] as? String ?? userInfo["action_id"] as? String else {
            return
        }

        // Use actionType (e.g., "Bash", "Edit", "Write") for tier classification
        // Fall back to type only if actionType not present (legacy payloads)
        let type = userInfo["actionType"] as? String ?? userInfo["type"] as? String ?? "tool_use"
        let title = userInfo["title"] as? String ?? "Action Required"
        let description = userInfo["description"] as? String ?? ""
        let filePath = userInfo["filePath"] as? String
        let command = userInfo["command"] as? String

        let action = PendingAction(
            id: requestId,
            type: type,
            title: title,
            description: description,
            filePath: filePath,
            command: command,
            timestamp: Date()
        )

        Task { @MainActor in
            let service = WatchService.shared
            // Avoid duplicates
            if !service.state.pendingActions.contains(where: { $0.id == requestId }) {
                // AUTO-ACCEPT MODE: Automatically approve instead of queueing
                if service.state.mode == .autoAccept {
                    service.playHaptic(.success)
                    // Respond to cloud with approval
                    if service.useCloudMode && service.isPaired {
                        try? await service.respondToCloudRequest(requestId, approved: true)
                    } else {
                        service.approveAction(requestId)
                    }
                } else {
                    service.state.pendingActions.append(action)
                    service.state.status = .waiting
                    service.playHaptic(.notification)
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        // Cloud mode uses "requestId", WebSocket mode uses "action_id"
        let requestId = userInfo["requestId"] as? String ?? userInfo["action_id"] as? String

        Task { @MainActor in
            defer { completionHandler() }

            let service = WatchService.shared

            switch response.actionIdentifier {
            case "APPROVE_ACTION":
                if let requestId = requestId {
                    // Always remove from local state first (optimistic update)
                    service.state.pendingActions.removeAll { $0.id == requestId }
                    if service.state.pendingActions.isEmpty {
                        service.state.status = .running
                    }
                    service.playHaptic(.success)

                    // Then try to notify server
                    if service.useCloudMode && service.isPaired {
                        try? await service.respondToCloudRequest(requestId, approved: true)
                    } else {
                        service.approveAction(requestId)
                    }
                }

            case "REJECT_ACTION":
                if let requestId = requestId {
                    if service.useCloudMode && service.isPaired {
                        try? await service.respondToCloudRequest(requestId, approved: false)
                    } else {
                        service.rejectAction(requestId)
                    }
                }

            case "APPROVE_ALL_ACTION":
                service.approveAll()

            case UNNotificationDefaultActionIdentifier:
                // User tapped notification - handle based on type
                let notificationType = userInfo["type"] as? String
                if notificationType == "question" {
                    service.handleQuestionNotification(userInfo)
                } else if notificationType == "context_warning" {
                    service.handleContextWarningNotification(userInfo)
                } else {
                    // Default: add as pending action
                    addPendingActionFromNotification(userInfo: userInfo)
                }

            case UNNotificationDismissActionIdentifier:
                // User dismissed notification
                break

            default:
                break
            }
        }
    }
}
