//
//  ActionDetailView.swift
//  ClaudeWatch
//
//  Expanded detail view for pending actions (long-press to access)
//  Addresses Sam's need for full action information
//

import SwiftUI
import WatchKit

/// Detailed view showing full action information
/// Accessed via long-press on PrimaryActionCard
struct ActionDetailView: View {
    let action: PendingAction
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var service = WatchService.shared

    // Haptic feedback triggers
    @State private var didReject = false
    @State private var didApprove = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Claude.Spacing.md) {
                // Danger badge for destructive actions
                if action.isDangerous {
                    DangerBadge()
                }

                // Action type header
                actionTypeHeader

                // Full path section
                if let path = action.filePath {
                    DetailSection(title: "Full Path") {
                        Text(path)
                            .font(.claudeMono)
                            .foregroundColor(Claude.textPrimary)
                            .lineLimit(nil)
                    }
                }

                // Description section
                if !action.description.isEmpty {
                    DetailSection(title: "Description") {
                        Text(action.description)
                            .font(.claudeCaption)
                            .foregroundColor(Claude.textSecondary)
                    }
                }

                // Command section (for bash actions)
                if let command = action.command {
                    DetailSection(title: "Command") {
                        Text(command)
                            .font(.claudeMono)
                            .foregroundColor(action.isDangerous ? Claude.danger : Claude.textPrimary)
                            .lineLimit(nil)
                    }
                }

                // Timestamp
                DetailSection(title: "Received") {
                    Text(action.timestamp.formatted(.relative(presentation: .numeric)))
                        .font(.claudeCaption)
                        .foregroundColor(Claude.textSecondary)
                }

                // Action buttons
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private var actionTypeHeader: some View {
        HStack(spacing: Claude.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor)
                    .frame(width: 36, height: 36)

                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(typeLabel)
                    .font(.claudeHeadline)
                    .foregroundColor(typeColor)

                Text(action.title)
                    .font(.claudeCaption)
                    .foregroundColor(Claude.textPrimary)
                    .lineLimit(2)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: Claude.Spacing.sm) {
            // Reject button
            Button {
                Task { @MainActor in
                    service.state.pendingActions.removeAll { $0.id == action.id }
                    if service.state.pendingActions.isEmpty {
                        service.state.status = .idle
                    }
                    service.playHaptic(.failure)
                    didReject.toggle()

                    if service.useCloudMode && service.isPaired {
                        try? await service.respondToCloudRequest(action.id, approved: false)
                    } else {
                        service.rejectAction(action.id)
                    }

                    dismiss()
                }
            } label: {
                Label("Reject", systemImage: "xmark")
                    .font(.claudeCaption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(action.isDangerous ? Claude.danger : Claude.surface2)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.error, trigger: didReject)

            // Approve button
            Button {
                Task { @MainActor in
                    service.state.pendingActions.removeAll { $0.id == action.id }
                    if service.state.pendingActions.isEmpty {
                        service.state.status = .running
                    }
                    service.playHaptic(.success)
                    didApprove.toggle()

                    if service.useCloudMode && service.isPaired {
                        try? await service.respondToCloudRequest(action.id, approved: true)
                    } else {
                        service.approveAction(action.id)
                    }

                    dismiss()
                }
            } label: {
                Label("Approve", systemImage: "checkmark")
                    .font(.claudeCaption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(action.isDangerous ? Claude.surface2 : Claude.success)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: didApprove)
        }
    }

    // MARK: - Helpers

    private var typeColor: Color {
        switch action.type {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }

    private var typeLabel: String {
        switch action.type {
        case "file_edit": return "Edit File"
        case "file_create": return "Create File"
        case "file_delete": return "Delete File"
        case "bash": return "Run Command"
        default: return "Action"
        }
    }
}

// MARK: - Detail Section

/// Reusable section with title and content
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Claude.textTertiary)
                .textCase(.uppercase)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Action Detail - Edit") {
    NavigationStack {
        ActionDetailView(action: PendingAction(
            id: "1",
            type: "file_edit",
            title: "Edit MainView.swift",
            description: "Add dark mode toggle with system preference detection and localStorage persistence",
            filePath: "/Users/sam/projects/app/src/components/MainView.swift",
            command: nil,
            timestamp: Date()
        ))
    }
}

#Preview("Action Detail - Dangerous Delete") {
    NavigationStack {
        ActionDetailView(action: PendingAction(
            id: "2",
            type: "file_delete",
            title: "Delete old-utils.ts",
            description: "Remove deprecated utility file",
            filePath: "/Users/sam/projects/app/src/utils/old-utils.ts",
            command: nil,
            timestamp: Date()
        ))
    }
}

#Preview("Action Detail - Bash") {
    NavigationStack {
        ActionDetailView(action: PendingAction(
            id: "3",
            type: "bash",
            title: "Run cleanup",
            description: "Clean temporary files",
            filePath: nil,
            command: "rm -rf ./tmp/* && find . -name '*.log' -delete",
            timestamp: Date()
        ))
    }
}
