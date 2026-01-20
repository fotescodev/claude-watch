//
//  SelectiveQueueView.swift
//  ClaudeWatch
//
//  Selective queue view for batch approve/reject with checkboxes
//  Addresses Sam's need for granular control over multiple actions
//

import SwiftUI
import WatchKit

/// View showing all pending actions with checkbox selection
/// Allows approving selected items while rejecting others
struct SelectiveQueueView: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss

    /// Currently selected action IDs
    @State private var selectedActions: Set<String> = []

    /// Haptic feedback triggers
    @State private var didApprove = false
    @State private var didReject = false

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Header with selection count
            header

            // Scrollable list of actions
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(service.state.pendingActions) { action in
                        SelectableActionRow(
                            action: action,
                            isSelected: selectedActions.contains(action.id),
                            onToggle: { toggleSelection(action.id) }
                        )
                    }
                }
            }

            // Batch action buttons
            batchButtons
        }
        .padding(Claude.Spacing.sm)
        .navigationTitle("Queue")
        .onAppear {
            // Pre-select all safe actions by default
            selectedActions = Set(
                service.state.pendingActions
                    .filter { !$0.isDangerous }
                    .map { $0.id }
            )
        }
        .sensoryFeedback(.success, trigger: didApprove)
        .sensoryFeedback(.error, trigger: didReject)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("\(service.state.pendingActions.count) Pending")
                .font(.claudeCaption)
                .fontWeight(.semibold)
                .foregroundColor(Claude.textPrimary)

            Spacer()

            Text("\(selectedActions.count) selected")
                .font(.claudeCaption)
                .foregroundColor(Claude.info)
        }
    }

    private var batchButtons: some View {
        HStack(spacing: Claude.Spacing.sm) {
            // Reject unselected
            Button {
                rejectUnselected()
            } label: {
                Text("Reject (\(unselectedCount))")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(unselectedCount > 0 ? Claude.danger : Claude.surface2)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(unselectedCount == 0)

            // Approve selected
            Button {
                approveSelected()
            } label: {
                Text("Approve (\(selectedActions.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(selectedActions.isEmpty ? Claude.surface2 : Claude.success)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(selectedActions.isEmpty)
        }
    }

    // MARK: - Helpers

    private var unselectedCount: Int {
        service.state.pendingActions.count - selectedActions.count
    }

    private func toggleSelection(_ id: String) {
        WKInterfaceDevice.current().play(.click)
        if selectedActions.contains(id) {
            selectedActions.remove(id)
        } else {
            selectedActions.insert(id)
        }
    }

    private func approveSelected() {
        guard !selectedActions.isEmpty else { return }

        Task { @MainActor in
            let actionsToApprove = service.state.pendingActions.filter { selectedActions.contains($0.id) }

            // Record all to history
            for action in actionsToApprove {
                HistoryManager.shared.record(action, outcome: .approved)
            }

            // Remove from pending
            service.state.pendingActions.removeAll { selectedActions.contains($0.id) }

            // Update status
            if service.state.pendingActions.isEmpty {
                service.state.status = .running
            }

            // Notify server for each
            for action in actionsToApprove {
                if service.useCloudMode && service.isPaired {
                    try? await service.respondToCloudRequest(action.id, approved: true)
                } else {
                    service.approveAction(action.id)
                }
            }

            service.playHaptic(.success)
            didApprove.toggle()
            AccessibilityNotification.Announcement("Approved \(actionsToApprove.count) actions").post()

            // Dismiss if no more actions
            if service.state.pendingActions.isEmpty {
                dismiss()
            } else {
                // Clear selection
                selectedActions.removeAll()
            }
        }
    }

    private func rejectUnselected() {
        guard unselectedCount > 0 else { return }

        Task { @MainActor in
            let actionsToReject = service.state.pendingActions.filter { !selectedActions.contains($0.id) }

            // Record all to history
            for action in actionsToReject {
                HistoryManager.shared.record(action, outcome: .rejected)
            }

            // Remove from pending
            service.state.pendingActions.removeAll { !selectedActions.contains($0.id) }

            // Notify server for each
            for action in actionsToReject {
                if service.useCloudMode && service.isPaired {
                    try? await service.respondToCloudRequest(action.id, approved: false)
                } else {
                    service.rejectAction(action.id)
                }
            }

            service.playHaptic(.failure)
            didReject.toggle()
            AccessibilityNotification.Announcement("Rejected \(actionsToReject.count) actions").post()

            // Now approve remaining selected
            if !selectedActions.isEmpty {
                approveSelected()
            } else if service.state.pendingActions.isEmpty {
                dismiss()
            }
        }
    }
}

/// Single row in the selective queue with checkbox
struct SelectableActionRow: View {
    let action: PendingAction
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Claude.orange : Claude.textSecondary)

                // Action icon
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                    .foregroundColor(action.isDangerous ? Claude.danger : Claude.orange)

                // Action info
                VStack(alignment: .leading, spacing: 2) {
                    Text(truncatedName)
                        .font(.claudeMono)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    Text(action.type.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 9))
                        .foregroundColor(action.isDangerous ? Claude.danger : Claude.textTertiary)
                }

                Spacer()

                // Danger indicator
                if action.isDangerous {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Claude.danger)
                }
            }
            .padding(8)
            .background(action.isDangerous ? Claude.dangerBackground : Claude.surface1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                action.isDangerous ?
                    RoundedRectangle(cornerRadius: 8).stroke(Claude.danger.opacity(0.4), lineWidth: 1)
                    : nil
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isSelected ? "Selected" : "Not selected"), \(action.title)\(action.isDangerous ? ", dangerous" : "")")
        .accessibilityHint("Double tap to toggle selection")
    }

    private var truncatedName: String {
        if let path = action.filePath {
            return path.split(separator: "/").last.map(String.init) ?? action.title
        }
        return action.title
    }
}

// MARK: - Previews

#Preview("Selective Queue") {
    NavigationStack {
        SelectiveQueueView()
    }
}

#Preview("Selectable Row - Safe") {
    VStack {
        SelectableActionRow(
            action: PendingAction(
                id: "1",
                type: "file_edit",
                title: "Edit App.tsx",
                description: "Update component",
                filePath: "/src/App.tsx",
                command: nil,
                timestamp: Date()
            ),
            isSelected: true,
            onToggle: {}
        )

        SelectableActionRow(
            action: PendingAction(
                id: "2",
                type: "file_create",
                title: "Create test.ts",
                description: "Add test file",
                filePath: "/src/test.ts",
                command: nil,
                timestamp: Date()
            ),
            isSelected: false,
            onToggle: {}
        )
    }
    .padding()
    .background(Claude.background)
}

#Preview("Selectable Row - Dangerous") {
    SelectableActionRow(
        action: PendingAction(
            id: "3",
            type: "file_delete",
            title: "Delete old-utils.ts",
            description: "Remove file",
            filePath: "/src/old-utils.ts",
            command: nil,
            timestamp: Date()
        ),
        isSelected: false,
        onToggle: {}
    )
    .padding()
    .background(Claude.background)
}
