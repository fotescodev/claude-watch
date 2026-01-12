import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Text("MODEL SWITCHER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)

                    Spacer()
                }
                .padding(.horizontal, 4)

                // Model Options
                ForEach(ClaudeModel.allCases, id: \.self) { model in
                    ModelOptionRow(
                        model: model,
                        isSelected: sessionManager.config.selectedModel == model
                    ) {
                        sessionManager.selectModel(model)
                        dismiss()
                    }
                }

                // Info Text
                Text("Use Digital Crown to quick-switch")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Model")
    }
}

struct ModelOptionRow: View {
    let model: ClaudeModel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Model Icon
                ZStack {
                    Circle()
                        .fill(model.color.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Text(String(model.shortName.prefix(1)))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(model.color)
                }

                // Model Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Text(modelDescription(model))
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(model.color)
                }
            }
            .padding(10)
            .background(isSelected ? model.color.opacity(0.15) : Color.gray.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? model.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func modelDescription(_ model: ClaudeModel) -> String {
        switch model {
        case .opus: return "Most capable"
        case .sonnet: return "Balanced"
        case .haiku: return "Fast & light"
        }
    }
}

#Preview {
    ModelPickerView()
        .environmentObject(SessionManager())
}
