import SwiftUI

struct ControlDeckView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showingModelPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Status Display (OLED-style)
                StatusDisplayView()

                // Quick Action Buttons
                ActionButtonsGrid()

                // YOLO Mode Button
                YoloModeButton()
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Claude")
        .sheet(isPresented: $showingModelPicker) {
            ModelPickerView()
        }
        // Digital Crown controls model selection
        .focusable()
        .digitalCrownRotation(
            detent: $sessionManager.config.selectedModel,
            from: ClaudeModel.haiku,
            through: ClaudeModel.opus,
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        ) { _ in
            // Model changed via crown
        }
    }
}

// MARK: - Status Display (OLED Style)
struct StatusDisplayView: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 4) {
            // Task Info
            if let task = sessionManager.currentTask {
                HStack {
                    Text("TASK:")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))

                    Text(task.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .lineLimit(1)

                    Spacer()

                    Text("\(Int(task.progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.green.opacity(0.2))
                            .frame(height: 4)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * task.progress, height: 4)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 4)
            } else {
                Text("NO ACTIVE TASK")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.5))
            }

            Divider()
                .background(Color.green.opacity(0.3))

            // Model & Subscription Info
            HStack {
                Text("MODEL:")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))

                Text(sessionManager.config.selectedModel.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(sessionManager.config.selectedModel.color)

                Spacer()

                Text("SUB: \(sessionManager.subscriptionPercent)%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
            }

            // Connection Status
            HStack {
                Image(systemName: sessionManager.connectionStatus.icon)
                    .font(.system(size: 8))
                    .foregroundColor(sessionManager.connectionStatus.color)

                Text(sessionManager.connectionStatus.rawValue.uppercased())
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(sessionManager.connectionStatus.color)

                Spacer()

                if sessionManager.config.yoloMode {
                    Text("YOLO")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.3))
                        .cornerRadius(2)
                }
            }
        }
        .padding(8)
        .background(Color.black)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Action Buttons Grid
struct ActionButtonsGrid: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 6) {
            // Top Row: Accept & Approve
            HStack(spacing: 6) {
                ActionButton(
                    icon: "checkmark",
                    label: "ACCEPT",
                    color: .green,
                    isEnabled: !sessionManager.pendingActions.isEmpty
                ) {
                    sessionManager.acceptChanges()
                }

                ActionButton(
                    icon: "hand.thumbsup.fill",
                    label: "APPROVE",
                    color: .blue,
                    isEnabled: !sessionManager.pendingActions.isEmpty
                ) {
                    sessionManager.approveAction()
                }
            }

            // Bottom Row: Discard & Retry
            HStack(spacing: 6) {
                ActionButton(
                    icon: "xmark",
                    label: "DISCARD",
                    color: .red,
                    isEnabled: !sessionManager.pendingActions.isEmpty
                ) {
                    sessionManager.discardChanges()
                }

                ActionButton(
                    icon: "arrow.clockwise",
                    label: "RETRY",
                    color: .orange,
                    isEnabled: !sessionManager.pendingActions.isEmpty
                ) {
                    sessionManager.retryAction()
                }
            }
        }
    }
}

// MARK: - Action Button Component
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))

                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isEnabled ? color.opacity(0.2) : Color.gray.opacity(0.1)
            )
            .foregroundColor(isEnabled ? color : .gray)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? color.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - YOLO Mode Button
struct YoloModeButton: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        Button {
            sessionManager.toggleYoloMode()
        } label: {
            HStack {
                Image(systemName: sessionManager.config.yoloMode ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 14, weight: .bold))

                Text("YOLO MODE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))

                Spacer()

                Text(sessionManager.config.yoloMode ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                sessionManager.config.yoloMode
                    ? LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(sessionManager.config.yoloMode ? .white : .gray)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(sessionManager.config.yoloMode ? Color.red : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ControlDeckView()
        .environmentObject(SessionManager())
}
