import SwiftUI
import WatchKit

/// Binary question response for F18: AskUserQuestion flow
/// V2: Shows exactly 2 options - NO "Handle on Mac" escape hatch
/// Double tap selects the recommended option
struct QuestionResponseView: View {
    let question: String
    let options: [QuestionOption]
    let questionId: String

    @ObservedObject private var service = WatchService.shared
    @State private var isResponding = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// First option is always recommended
    private var recommendedOption: QuestionOption? {
        options.first
    }

    /// Second option (alternative)
    private var alternativeOption: QuestionOption? {
        options.count > 1 ? options[1] : nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // V3: Question header with purple dot
            HStack(spacing: 6) {
                Circle()
                    .fill(Claude.question)
                    .frame(width: 8, height: 8)

                Text("Question")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Claude.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            // V3: Question card with icon and text
            VStack(spacing: 8) {
                // Question mark icon
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Claude.question)

                // Question text - prominent
                Text(question)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Claude.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Claude.surface1)
            .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.large))

            // V3: Full-width option buttons
            VStack(spacing: 6) {
                // Recommended option (Yes)
                if let recommended = recommendedOption {
                    Button {
                        selectOption(recommended)
                    } label: {
                        Text(recommended.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Claude.question)
                            .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.button))
                    }
                    .buttonStyle(.plain)
                    .disabled(isResponding)
                }

                // Alternative option (No)
                if let alternative = alternativeOption {
                    Button {
                        selectOption(alternative)
                    } label: {
                        Text(alternative.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Claude.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Claude.surface2)
                            .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.button))
                    }
                    .buttonStyle(.plain)
                    .disabled(isResponding)
                }
            }
            .padding(.horizontal, 8)

            // V3: Handle on Mac hint
            Text("Handle on Mac")
                .font(.system(size: 9))
                .foregroundColor(Claude.textTertiary)
                .padding(.bottom, 4)
        }
        // Double tap selects recommended option (watchOS 26+)
        .modifier(QuestionDoubleTapModifier(onSelect: {
            if let recommended = recommendedOption {
                selectOption(recommended)
            }
        }))
    }

    private func selectOption(_ option: QuestionOption) {
        guard !isResponding else { return }
        isResponding = true
        WKInterfaceDevice.current().play(.success)

        Task {
            await service.respondToQuestion(questionId, answer: option.value, handleOnMac: false)
        }
    }
}

// MARK: - Question Option Model

/// Represents an option for a question
struct QuestionOption: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let description: String?

    init(id: String = UUID().uuidString, label: String, value: String? = nil, description: String? = nil) {
        self.id = id
        self.label = label
        self.value = value ?? label
        self.description = description
    }
}

// MARK: - Legacy Compatibility

/// Legacy initializer for backward compatibility
extension QuestionResponseView {
    init(question: String, recommendedAnswer: String, questionId: String) {
        self.question = question
        self.questionId = questionId
        // Convert legacy format to new options format
        self.options = [
            QuestionOption(label: recommendedAnswer, value: recommendedAnswer)
        ]
    }

    init(question: String, recommendedAnswer: String, alternativeAnswer: String?, questionId: String) {
        self.question = question
        self.questionId = questionId

        var opts = [QuestionOption(label: recommendedAnswer, value: recommendedAnswer)]
        if let alt = alternativeAnswer {
            opts.append(QuestionOption(label: alt, value: alt))
        }
        self.options = opts
    }
}

// MARK: - Double Tap Modifier

/// Applies hand gesture shortcut on watchOS 26+
private struct QuestionDoubleTapModifier: ViewModifier {
    let onSelect: () -> Void

    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .handGestureShortcut(.primaryAction)
                .onTapGesture(count: 2) {
                    onSelect()
                }
        } else {
            content
                .onTapGesture(count: 2) {
                    onSelect()
                }
        }
    }
}

// MARK: - Previews

#Preview("Question Response - 2 Options") {
    QuestionResponseView(
        question: "Which database should we use?",
        options: [
            QuestionOption(label: "PostgreSQL", description: "Best for complex queries"),
            QuestionOption(label: "MySQL", description: "Simpler setup")
        ],
        questionId: "q-123"
    )
}

#Preview("Question Response - Single Option") {
    QuestionResponseView(
        question: "Should we proceed with the recommended approach?",
        recommendedAnswer: "Use REST API pattern",
        questionId: "q-456"
    )
}

#Preview("Question Response - Legacy") {
    QuestionResponseView(
        question: "Which approach should we use?",
        recommendedAnswer: "Elasticsearch",
        alternativeAnswer: "PostgreSQL full-text",
        questionId: "q-789"
    )
}
