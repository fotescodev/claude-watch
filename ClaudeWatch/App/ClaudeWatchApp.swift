import SwiftUI
import WatchKit
import UserNotifications

@main
struct ClaudeWatchApp: App {
    @WKApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            MainView()
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
        WKExtension.shared().registerForRemoteNotifications()
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        // Send token to server
        Task { @MainActor in
            WatchService.shared.registerPushToken(deviceToken)
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        print("Failed to register for remote notifications: \(error)")
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
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = userInfo["action_id"] as? String

        Task { @MainActor in
            switch response.actionIdentifier {
            case "APPROVE_ACTION":
                if let actionId = actionId {
                    WatchService.shared.approveAction(actionId)
                }

            case "REJECT_ACTION":
                if let actionId = actionId {
                    WatchService.shared.rejectAction(actionId)
                }

            case "APPROVE_ALL_ACTION":
                WatchService.shared.approveAll()

            case UNNotificationDefaultActionIdentifier:
                // User tapped notification - app opens to main view
                break

            case UNNotificationDismissActionIdentifier:
                // User dismissed notification
                break

            default:
                break
            }
        }

        completionHandler()
    }
}
