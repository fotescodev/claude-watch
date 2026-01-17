import SwiftUI
import WatchKit

// MARK: - Action Queue
struct ActionQueue: View {
    @ObservedObject private var service = WatchService.shared

    // Spring animation state
    @State private var approveAllPressed = false

    var body: some View {
        VStack(spacing: 8) {
            // Primary action card
            if let action = service.state.pendingActions.first {
                PrimaryActionCard(action: action)
            }

            // Additional pending items
            if service.state.pendingActions.count > 1 {
                VStack(spacing: 6) {
                    ForEach(service.state.pendingActions.dropFirst().prefix(2)) { action in
                        CompactActionCard(action: action)
                    }

                    if service.state.pendingActions.count > 3 {
                        Text("+\(service.state.pendingActions.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(Claude.textTertiary)
                    }
                }

                // Approve All button
                Button {
                    service.approveAll()
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    Text("Approve All (\(service.state.pendingActions.count))")
                        .font(.body.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Claude.success, Claude.success.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .scaleEffect(approveAllPressed ? 0.95 : 1.0)
                        .animation(.bouncySpring, value: approveAllPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in approveAllPressed = true }
                        .onEnded { _ in approveAllPressed = false }
                )
                .accessibilityLabel("Approve all \(service.state.pendingActions.count) pending actions")
            }
        }
    }
}

// MARK: - Primary Action Card
struct PrimaryActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction

    // Dynamic Type support
    @ScaledMetric(relativeTo: .body) private var iconContainerSize: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18

    // Spring animation states for buttons
    @State private var rejectPressed = false
    @State private var approvePressed = false

    var body: some View {
        VStack(spacing: 12) {
            // Action info
            HStack(spacing: 10) {
                // Type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [typeColor, typeColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: iconContainerSize, height: iconContainerSize)

                    Image(systemName: action.icon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.headline)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    if let path = action.filePath {
                        Text(truncatePath(path))
                            .font(.caption2.monospaced())
                            .foregroundColor(Claude.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                // Reject
                Button {
                    Task {
                        if service.useCloudMode && service.isPaired {
                            try? await service.respondToCloudRequest(action.id, approved: false)
                        } else {
                            service.rejectAction(action.id)
                        }
                    }
                    WKInterfaceDevice.current().play(.failure)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                        Text("Reject")
                            .font(.body.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Claude.danger, Claude.danger.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .scaleEffect(rejectPressed ? 0.92 : 1.0)
                    .animation(.buttonSpring, value: rejectPressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in rejectPressed = true }
                        .onEnded { _ in rejectPressed = false }
                )
                .accessibilityLabel("Reject \(action.title)")

                // Approve
                Button {
                    Task {
                        if service.useCloudMode && service.isPaired {
                            try? await service.respondToCloudRequest(action.id, approved: true)
                        } else {
                            service.approveAction(action.id)
                        }
                    }
                    WKInterfaceDevice.current().play(.success)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                        Text("Approve")
                            .font(.body.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(
                        LinearGradient(
                            colors: [Claude.success, Claude.success.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                    .scaleEffect(approvePressed ? 0.92 : 1.0)
                    .animation(.buttonSpring, value: approvePressed)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in approvePressed = true }
                        .onEnded { _ in approvePressed = false }
                )
                .accessibilityLabel("Approve \(action.title)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.thinMaterial)
        )
    }

    private var typeColor: Color {
        switch action.type {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }

    private func truncatePath(_ path: String) -> String {
        let components = path.split(separator: "/")
        if let last = components.last {
            return String(last)
        }
        return path
    }
}

// MARK: - Compact Action Card
struct CompactActionCard: View {
    let action: PendingAction

    // Dynamic Type support
    @ScaledMetric(relativeTo: .footnote) private var iconContainerSize: CGFloat = 28
    @ScaledMetric(relativeTo: .footnote) private var iconSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(typeColor.opacity(0.2))
                    .frame(width: iconContainerSize, height: iconContainerSize)

                Image(systemName: action.icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(typeColor)
            }

            Text(action.title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Claude.textPrimary)
                .lineLimit(1)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
    }

    private var typeColor: Color {
        switch action.type {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }
}

// MARK: - Previews
#Preview("Action Queue") {
    ActionQueue()
}

#Preview("Primary Action Card") {
    PrimaryActionCard(action: PendingAction(
        id: "1",
        type: "file_edit",
        title: "Edit MainView.swift",
        description: "Updating the main view layout",
        filePath: "/path/to/MainView.swift",
        command: nil,
        timestamp: Date()
    ))
    .padding()
}

#Preview("Compact Action Card") {
    CompactActionCard(action: PendingAction(
        id: "2",
        type: "bash",
        title: "npm install",
        description: "Installing dependencies",
        filePath: nil,
        command: "npm install",
        timestamp: Date()
    ))
    .padding()
}
