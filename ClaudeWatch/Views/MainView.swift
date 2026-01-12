import SwiftUI
import WatchKit

/// Main single-screen view for Claude Watch
/// Designed for quick glances and one-tap actions
struct MainView: View {
    @StateObject private var service = WatchService.shared
    @State private var showingVoiceInput = false
    @State private var showingSettings = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Status Header
                StatusHeader()

                // Pending Actions (if any)
                if !service.state.pendingActions.isEmpty {
                    PendingActionsSection()
                }

                // Quick Actions
                QuickActionsBar()

                // Voice Input Button
                VoiceButton(showingVoiceInput: $showingVoiceInput)

                // YOLO Toggle
                YoloToggle()
            }
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputSheet()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .onAppear {
            service.connect()
        }
    }
}

// MARK: - Status Header
struct StatusHeader: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        VStack(spacing: 4) {
            // Connection indicator + Task name
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 6, height: 6)

                if service.state.taskName.isEmpty {
                    Text("CLAUDE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                } else {
                    Text(service.state.taskName.uppercased().prefix(18))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .lineLimit(1)
                }

                Spacer()

                // Progress percentage
                if service.state.status == .running || service.state.status == .waiting {
                    Text("\(Int(service.state.progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            // Progress bar
            if service.state.status == .running || service.state.status == .waiting {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.2))

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geo.size.width * service.state.progress)
                    }
                }
                .frame(height: 3)
                .cornerRadius(1.5)
            }

            // Status line
            HStack {
                Text(service.state.status.displayName)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(statusColor)

                Spacer()

                if service.state.yoloMode {
                    Text("YOLO")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(2)
                }

                if !service.state.pendingActions.isEmpty {
                    Text("\(service.state.pendingActions.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
            }
        }
        .padding(8)
        .background(Color.black)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
    }

    private var connectionColor: Color {
        switch service.connectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        }
    }

    private var statusColor: Color {
        switch service.state.status {
        case .idle: return .gray
        case .running: return .green
        case .waiting: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Pending Actions Section
struct PendingActionsSection: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        VStack(spacing: 6) {
            // First action (most prominent)
            if let action = service.state.pendingActions.first {
                ActionCard(action: action, isFirst: true)
            }

            // Remaining actions (smaller)
            if service.state.pendingActions.count > 1 {
                ForEach(service.state.pendingActions.dropFirst()) { action in
                    ActionCard(action: action, isFirst: false)
                }
            }

            // Approve All button
            if service.state.pendingActions.count > 1 {
                Button {
                    service.approveAll()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                        Text("APPROVE ALL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Action Card
struct ActionCard: View {
    @ObservedObject private var service = WatchService.shared
    let action: PendingAction
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: action.icon)
                    .font(.system(size: isFirst ? 14 : 10))
                    .foregroundColor(Color(action.typeColor))

                VStack(alignment: .leading, spacing: 1) {
                    Text(action.title)
                        .font(.system(size: isFirst ? 11 : 9, weight: .medium))
                        .lineLimit(1)

                    if isFirst, let path = action.filePath {
                        Text(path.split(separator: "/").last.map(String.init) ?? path)
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            if isFirst {
                HStack(spacing: 8) {
                    Button {
                        service.approveAction(action.id)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Approve")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        service.rejectAction(action.id)
                    } label: {
                        HStack {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Reject")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(isFirst ? 10 : 6)
        .background(Color.orange.opacity(isFirst ? 0.15 : 0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: isFirst ? 1 : 0)
        )
    }
}

// MARK: - Quick Actions Bar
struct QuickActionsBar: View {
    @ObservedObject private var service = WatchService.shared

    let quickPrompts = [
        ("Continue", "arrow.right"),
        ("Run tests", "checkmark.diamond"),
        ("Fix errors", "ant"),
        ("Stop", "stop.fill"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(quickPrompts, id: \.0) { prompt, icon in
                    Button {
                        service.sendPrompt(prompt)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                            Text(prompt)
                                .font(.system(size: 8, weight: .medium))
                        }
                        .frame(width: 50, height: 44)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Voice Button
struct VoiceButton: View {
    @ObservedObject private var service = WatchService.shared
    @Binding var showingVoiceInput: Bool

    var body: some View {
        Button {
            showingVoiceInput = true
        } label: {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                Text("Voice Command")
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.2))
            .foregroundColor(.blue)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - YOLO Toggle
struct YoloToggle: View {
    @ObservedObject private var service = WatchService.shared

    var body: some View {
        Button {
            service.toggleYolo()
        } label: {
            HStack {
                Image(systemName: service.state.yoloMode ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 12))

                Text("YOLO")
                    .font(.system(size: 10, weight: .black, design: .monospaced))

                Spacer()

                Text(service.state.yoloMode ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                service.state.yoloMode
                    ? LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(service.state.yoloMode ? .white : .gray)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Input Sheet
struct VoiceInputSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var transcribedText = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("VOICE COMMAND")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.blue)

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text(transcribedText.isEmpty ? "Tap mic to speak" : transcribedText)
                .font(.system(size: 11))
                .foregroundColor(transcribedText.isEmpty ? .gray : .white)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.red)

                if !transcribedText.isEmpty {
                    Button("Send") {
                        service.sendPrompt(transcribedText)
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
            }
            .font(.system(size: 11, weight: .medium))
        }
        .padding()
        .onAppear {
            presentTextInputController()
        }
    }

    private func presentTextInputController() {
        WKExtension.shared().visibleInterfaceController?.presentTextInputController(
            withSuggestions: ["Continue", "Run tests", "Fix errors", "Explain", "Commit"],
            allowedInputMode: .allowEmoji
        ) { results in
            if let result = results?.first as? String {
                transcribedText = result
            }
        }
    }
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject private var service = WatchService.shared
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)

                    TextField("ws://...", text: $serverURL)
                        .font(.system(size: 10, design: .monospaced))
                        .textContentType(.URL)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                HStack {
                    Circle()
                        .fill(service.connectionStatus == .connected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)

                    Text(service.connectionStatus.rawValue.capitalized)
                        .font(.system(size: 10))
                }

                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)

                    Button("Save") {
                        service.serverURLString = serverURL
                        service.connect()
                        dismiss()
                    }
                    .foregroundColor(.green)
                }
                .font(.system(size: 11, weight: .medium))
            }
            .padding()
        }
        .onAppear {
            serverURL = service.serverURLString
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(_ name: String) {
        switch name {
        case "green": self = .green
        case "red": self = .red
        case "orange": self = .orange
        case "blue": self = .blue
        case "purple": self = .purple
        case "gray": self = .gray
        default: self = .white
        }
    }
}

#Preview {
    MainView()
}
