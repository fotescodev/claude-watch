import SwiftUI
import WatchKit

/// Binary question response for F18: AskUserQuestion flow
/// Shows recommended option with Accept/Mac buttons
/// User can either accept the recommendation or handle on Mac
struct QuestionResponseView: View {
    let question: String
    let recommendedAnswer: String
    let questionId: String

    @ObservedObject private var service = WatchService.shared
    @State private var isResponding = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            // Question header
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Claude.warning)

                Text("Question")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Question content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(question)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(4)

                    // Recommended answer
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommended:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Claude.textTertiary)

                        Text(recommendedAnswer)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ClaudeState.success.color)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .background(ClaudeState.success.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(12)
            }
            .glassEffectCompat(RoundedRectangle(cornerRadius: 12))

            // Action buttons
            HStack(spacing: 8) {
                // Handle on Mac button
                Button {
                    respondWithMac()
                } label: {
                    Text("Mac")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Claude.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Claude.surface2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isResponding)

                // Accept recommendation button
                Button {
                    acceptRecommendation()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                        Text("Accept")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ClaudeState.success.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isResponding)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        // Double tap accepts recommendation (watchOS 26+)
        .modifier(QuestionDoubleTapModifier())
    }

    private func acceptRecommendation() {
        guard !isResponding else { return }
        isResponding = true
        WKInterfaceDevice.current().play(.success)

        Task {
            await service.respondToQuestion(questionId, answer: recommendedAnswer, handleOnMac: false)
        }
    }

    private func respondWithMac() {
        guard !isResponding else { return }
        isResponding = true
        WKInterfaceDevice.current().play(.click)

        Task {
            await service.respondToQuestion(questionId, answer: nil, handleOnMac: true)
        }
    }
}

/// Conditionally applies hand gesture shortcut on watchOS 26+
private struct QuestionDoubleTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content.handGestureShortcut(.primaryAction)
        } else {
            content
        }
    }
}

#Preview("Question Response") {
    QuestionResponseView(
        question: "Which approach should we use for implementing the search feature?",
        recommendedAnswer: "Use Elasticsearch for full-text search",
        questionId: "q-123"
    )
}
