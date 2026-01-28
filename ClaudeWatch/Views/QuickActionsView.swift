import SwiftUI
import WatchKit

/// Quick actions menu accessible via swipe or long press
/// Provides fast access to common actions based on current state
struct QuickActionsView: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            // Session controls
            Section("Session") {
                if service.isSessionInterrupted {
                    Button {
                        resumeSession()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .tint(ClaudeState.success.color)
                } else if service.sessionProgress != nil {
                    Button {
                        pauseSession()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .tint(Claude.warning)
                }

                if !service.state.pendingActions.isEmpty {
                    Button {
                        approveNext()
                    } label: {
                        Label("Approve Next", systemImage: "checkmark.circle.fill")
                    }
                    .tint(ClaudeState.success.color)

                    Button(role: .destructive) {
                        rejectNext()
                    } label: {
                        Label("Reject Next", systemImage: "xmark.circle.fill")
                    }

                    if service.state.pendingActions.count > 1 {
                        Button {
                            approveAll()
                        } label: {
                            Label("Approve All (\(service.state.pendingActions.count))", systemImage: "checkmark.circle.badge.checkmark")
                        }
                        .tint(ClaudeState.success.color)
                    }
                }
            }

            // Connection controls
            Section("Connection") {
                if service.isPaired {
                    Button(role: .destructive) {
                        unpair()
                    } label: {
                        Label("Unpair", systemImage: "link.badge.minus")
                    }
                } else {
                    Button {
                        showPairing()
                    } label: {
                        Label("Pair", systemImage: "link.badge.plus")
                    }
                    .tint(Claude.info)
                }
            }

            // Permission Mode
            Section("Permission Mode") {
                ForEach(PermissionMode.allCases, id: \.self) { mode in
                    Button {
                        setPermissionMode(mode)
                    } label: {
                        HStack {
                            Label(mode.displayName, systemImage: mode.icon)
                            Spacer()
                            if service.state.mode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Claude.success)
                            }
                        }
                    }
                    .tint(service.state.mode == mode ? Claude.success : nil)
                }
            }

            // App controls
            Section("App") {
                NavigationLink {
                    SettingsSheet()
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
        }
        .navigationTitle("Quick Actions")
    }

    // MARK: - Actions

    private func pauseSession() {
        WKInterfaceDevice.current().play(.click)
        Task {
            await service.sendInterrupt(action: .stop)
        }
        dismiss()
    }

    private func resumeSession() {
        WKInterfaceDevice.current().play(.click)
        Task {
            await service.sendInterrupt(action: .resume)
        }
        dismiss()
    }

    private func approveNext() {
        guard let action = service.state.pendingActions.first else { return }
        WKInterfaceDevice.current().play(.success)

        Task { @MainActor in
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: true)
            } else {
                service.approveAction(action.id)
            }
        }
        dismiss()
    }

    private func rejectNext() {
        guard let action = service.state.pendingActions.first else { return }
        WKInterfaceDevice.current().play(.failure)

        Task { @MainActor in
            if service.useCloudMode && service.isPaired {
                try? await service.respondToCloudRequest(action.id, approved: false)
            } else {
                service.rejectAction(action.id)
            }
        }
        dismiss()
    }

    private func approveAll() {
        WKInterfaceDevice.current().play(.success)
        service.approveAll()
        dismiss()
    }

    private func unpair() {
        WKInterfaceDevice.current().play(.click)
        service.unpair()
        dismiss()
    }

    private func showPairing() {
        WKInterfaceDevice.current().play(.click)
        // This would navigate to pairing view
        dismiss()
    }

    private func setPermissionMode(_ mode: PermissionMode) {
        WKInterfaceDevice.current().play(.click)
        service.setMode(mode)
        dismiss()
    }
}

#Preview("Quick Actions") {
    NavigationStack {
        QuickActionsView()
    }
}
