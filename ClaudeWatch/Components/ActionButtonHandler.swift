//
//  ActionButtonHandler.swift
//  Remmy
//
//  V2: Context-aware Action Button mapping
//  Single press: Context-dependent action
//  Long press: Emergency Stop
//

import SwiftUI
import WatchKit

// MARK: - Action Button State

/// Current context for Action Button behavior
enum ActionButtonContext {
    case idle           // Open app
    case working        // Pause
    case approvalPending(tier: ActionTier)  // Approve (Tier 1-2) or Full screen (Tier 3)
    case paused         // Resume
    case error          // Dismiss

    /// What single press does in this context
    var singlePressAction: ActionButtonAction {
        switch self {
        case .idle:
            return .openApp
        case .working:
            return .pause
        case .approvalPending(let tier):
            return tier.canApproveFromWatch ? .approve : .openFullScreen
        case .paused:
            return .resume
        case .error:
            return .dismiss
        }
    }

    /// Icon for the current context
    var icon: String {
        switch self {
        case .idle:
            return "circle"
        case .working:
            return "pause.fill"
        case .approvalPending(let tier):
            return tier.canApproveFromWatch ? "checkmark" : "hand.raised.fill"
        case .paused:
            return "play.fill"
        case .error:
            return "xmark"
        }
    }

    /// Color for the current context
    var color: Color {
        switch self {
        case .idle:
            return Claude.textSecondary
        case .working:
            return Claude.info
        case .approvalPending(let tier):
            return tier.cardColor
        case .paused:
            return Claude.warning
        case .error:
            return Claude.danger
        }
    }
}

// MARK: - Action Button Actions

enum ActionButtonAction {
    case openApp
    case pause
    case resume
    case approve
    case openFullScreen
    case dismiss
    case emergencyStop
}

// MARK: - Action Button Handler

/// Handles Action Button press events based on current context
@MainActor
@Observable
class ActionButtonHandler {
    static let shared = ActionButtonHandler()

    var context: ActionButtonContext = .idle
    var showEmergencyStopConfirmation = false

    private var service: WatchService { WatchService.shared }

    private init() {
        // Observe state changes to update context
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateContext),
            name: Notification.Name("SessionStateChanged"),
            object: nil
        )
    }

    @objc private func updateContext() {
        self.context = deriveContext()
    }

    /// Derive current context from session state
    func deriveContext() -> ActionButtonContext {
        // Check for pending approvals first
        if let firstAction = service.state.pendingActions.first {
            return .approvalPending(tier: firstAction.tier)
        }

        // Check session status
        switch service.state.status {
        case .idle:
            return .idle
        case .running:
            return .working
        case .waiting:
            return .idle  // Waiting but no pending = idle
        case .completed:
            return .idle
        case .failed:
            return .error
        }
    }

    /// Handle single press based on current context
    func handleSinglePress() {
        context = deriveContext()  // Refresh context

        switch context.singlePressAction {
        case .openApp:
            // App is already open on watch
            break

        case .pause:
            Task {
                await service.sendInterrupt(action: .stop)
            }
            WKInterfaceDevice.current().play(.click)

        case .resume:
            Task {
                await service.sendInterrupt(action: .resume)
            }
            WKInterfaceDevice.current().play(.click)

        case .approve:
            if let action = service.firstPendingAction,
               action.tier.canApproveFromWatch {
                Task {
                    // Optimistic update
                    service.state.pendingActions.removeAll { $0.id == action.id }
                    if service.state.pendingActions.isEmpty {
                        service.state.status = .running
                    }
                    service.playHaptic(.success)

                    // Notify server
                    await service.respondToAction(action.id, approved: true)
                }
            }

        case .openFullScreen:
            // Just notify - UI should already be showing full screen
            WKInterfaceDevice.current().play(.click)

        case .dismiss:
            service.clearSessionProgress()
            WKInterfaceDevice.current().play(.click)

        case .emergencyStop:
            // Handled by long press
            break
        }
    }

    /// Handle long press - Emergency Stop
    func handleLongPress() {
        showEmergencyStopConfirmation = true
        WKInterfaceDevice.current().play(.notification)
    }

    /// Execute emergency stop
    func executeEmergencyStop() {
        Task {
            await service.emergencyStop()
        }
    }
}

// MARK: - Action Button Indicator View

/// Shows current Action Button context in UI
struct ActionButtonIndicator: View {
    var handler = ActionButtonHandler.shared

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: handler.context.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(handler.context.color)

            Text(actionDescription)
                .font(.system(size: 9))
                .foregroundStyle(Claude.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(handler.context.color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var actionDescription: String {
        switch handler.context.singlePressAction {
        case .openApp: return "Action: Open"
        case .pause: return "Action: Pause"
        case .resume: return "Action: Resume"
        case .approve: return "Action: Approve"
        case .openFullScreen: return "Action: View"
        case .dismiss: return "Action: Dismiss"
        case .emergencyStop: return "Action: Stop"
        }
    }
}

// MARK: - Emergency Stop Alert View

/// Alert shown when emergency stop is triggered
struct EmergencyStopAlert: View {
    var handler = ActionButtonHandler.shared

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 36))
                .foregroundStyle(Claude.danger)

            Text("Emergency Stop?")
                .font(.headline)
                .foregroundStyle(Claude.textPrimary)

            Text("This will reject all pending requests and end the session.")
                .font(.caption)
                .foregroundStyle(Claude.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Cancel") {
                    handler.showEmergencyStopConfirmation = false
                }
                .buttonStyle(.bordered)

                Button("Stop") {
                    handler.executeEmergencyStop()
                    handler.showEmergencyStopConfirmation = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Claude.danger)
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("Action Button Indicator") {
    VStack(spacing: 20) {
        ActionButtonIndicator()
    }
    .padding()
}

#Preview("Emergency Stop Alert") {
    EmergencyStopAlert()
}
