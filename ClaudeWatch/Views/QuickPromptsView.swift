import SwiftUI
import WatchKit

struct QuickPromptsView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showingVoiceInput = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Voice Input Button
                VoiceInputButton {
                    showingVoiceInput = true
                }

                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)

                    Text("OR")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 4)

                // Quick Prompts by Category
                ForEach(PromptCategory.allCases, id: \.self) { category in
                    let prompts = sessionManager.quickPrompts.filter { $0.category == category }
                    if !prompts.isEmpty {
                        PromptCategorySection(category: category, prompts: prompts)
                    }
                }

                // Recent Prompts
                if !sessionManager.recentPrompts.isEmpty {
                    RecentPromptsSection()
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Prompts")
        .sheet(isPresented: $showingVoiceInput) {
            VoiceInputView()
        }
    }
}

// MARK: - Voice Input Button
struct VoiceInputButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18))

                Text("VOICE INPUT")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Prompt Category Section
struct PromptCategorySection: View {
    @EnvironmentObject var sessionManager: SessionManager
    let category: PromptCategory
    let prompts: [QuickPrompt]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(category.color)
                .padding(.leading, 4)

            FlowLayout(spacing: 4) {
                ForEach(prompts) { prompt in
                    QuickPromptChip(prompt: prompt) {
                        sessionManager.sendPrompt(prompt)
                    }
                }
            }
        }
    }
}

// MARK: - Quick Prompt Chip
struct QuickPromptChip: View {
    let prompt: QuickPrompt
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: prompt.icon)
                    .font(.system(size: 10))

                Text(prompt.text)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(prompt.category.color.opacity(0.2))
            .foregroundColor(prompt.category.color)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Prompts Section
struct RecentPromptsSection: View {
    @EnvironmentObject var sessionManager: SessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RECENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    sessionManager.recentPrompts.removeAll()
                } label: {
                    Text("Clear")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 4)

            ForEach(sessionManager.recentPrompts) { prompt in
                Button {
                    sessionManager.sendPrompt(prompt)
                } label: {
                    HStack {
                        Image(systemName: prompt.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        Text(prompt.text)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Flow Layout for Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            height = y + rowHeight
        }
    }
}

#Preview {
    QuickPromptsView()
        .environmentObject(SessionManager())
}
