import SwiftUI

struct ActionsListView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("PENDING")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)

                    Spacer()

                    Text("\(sessionManager.pendingActions.count)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 4)

                if sessionManager.pendingActions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundColor(.green.opacity(0.5))

                        Text("All clear!")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Actions List
                    ForEach(sessionManager.pendingActions) { action in
                        PendingActionRow(action: action)
                    }

                    // Approve All Button
                    Button {
                        sessionManager.approveAll()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("APPROVE ALL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Actions")
    }
}

struct PendingActionRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    let action: PendingAction

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: action.type.icon)
                .font(.system(size: 14))
                .foregroundColor(action.type.color)
                .frame(width: 24, height: 24)
                .background(action.type.color.opacity(0.2))
                .cornerRadius(6)

            // Description
            VStack(alignment: .leading, spacing: 2) {
                Text(action.type.rawValue)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(action.type.color)

                Text(action.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let path = action.filePath {
                    Text(path.components(separatedBy: "/").last ?? path)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation {
                    if let index = sessionManager.pendingActions.firstIndex(where: { $0.id == action.id }) {
                        sessionManager.pendingActions.remove(at: index)
                    }
                }
            } label: {
                Label("Discard", systemImage: "xmark")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                sessionManager.acceptChanges()
            } label: {
                Label("Accept", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
}

#Preview {
    ActionsListView()
        .environmentObject(SessionManager())
}
