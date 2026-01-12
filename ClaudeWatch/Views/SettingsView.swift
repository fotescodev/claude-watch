import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Connection Section
                SettingsSection(title: "CONNECTION") {
                    ConnectionStatusRow()
                }

                // Model Section
                SettingsSection(title: "MODEL") {
                    NavigationLink {
                        ModelPickerView()
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.purple)

                            Text("Current Model")
                                .font(.system(size: 11))

                            Spacer()

                            Text(sessionManager.config.selectedModel.displayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(sessionManager.config.selectedModel.color)
                        }
                    }
                }

                // Preferences Section
                SettingsSection(title: "PREFERENCES") {
                    Toggle(isOn: $sessionManager.config.hapticFeedback) {
                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.orange)

                            Text("Haptic Feedback")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $sessionManager.config.autoSuggestPrompts) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.blue)

                            Text("Auto Suggest")
                                .font(.system(size: 11))
                        }
                    }
                    .toggleStyle(.switch)
                }

                // Danger Zone
                SettingsSection(title: "YOLO MODE") {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: $sessionManager.config.yoloMode) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.red)

                                Text("YOLO Mode")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.red)

                        Text("Auto-approve all actions")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }

                // Info Section
                SettingsSection(title: "INFO") {
                    HStack {
                        Text("Version")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)

                        Spacer()

                        Text("1.0.0")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Subscription")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)

                        Spacer()

                        Text("\(sessionManager.subscriptionPercent)% used")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(sessionManager.subscriptionPercent > 80 ? .orange : .green)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                content
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// MARK: - Connection Status Row
struct ConnectionStatusRow: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        HStack {
            Image(systemName: sessionManager.connectionStatus.icon)
                .foregroundColor(sessionManager.connectionStatus.color)

            Text(sessionManager.connectionStatus.rawValue)
                .font(.system(size: 11))

            Spacer()

            if sessionManager.isConnected {
                Button("Disconnect") {
                    sessionManager.disconnect()
                }
                .font(.system(size: 9))
                .foregroundColor(.red)
            } else {
                Button("Connect") {
                    sessionManager.connect()
                }
                .font(.system(size: 9))
                .foregroundColor(.green)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionManager())
}
