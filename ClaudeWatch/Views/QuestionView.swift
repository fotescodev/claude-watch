import SwiftUI
import WatchKit

// MARK: - Question Model

/// Represents a question from Claude's AskUserQuestion tool
struct ClaudeQuestion: Identifiable, Equatable {
    let id: String
    let question: String
    let header: String?
    let options: [QuestionOption]
    let multiSelect: Bool
    let timestamp: Date

    struct QuestionOption: Identifiable, Equatable {
        let id: Int  // Index in options array
        let label: String
        let description: String?
        let isOther: Bool  // "Type something" / voice input option

        init(id: Int, label: String, description: String? = nil, isOther: Bool = false) {
            self.id = id
            self.label = label
            self.description = description
            self.isOther = isOther
        }
    }

    /// Create from server data
    static func from(_ data: [String: Any]) -> ClaudeQuestion? {
        // Debug: Log what we received
        print("[QuestionParse] Parsing data with keys: \(data.keys.sorted())")

        guard let id = data["id"] as? String else {
            print("[QuestionParse] FAILED: 'id' missing or not String. Got: \(type(of: data["id"])) = \(data["id"] ?? "nil")")
            return nil
        }
        guard let question = data["question"] as? String else {
            print("[QuestionParse] FAILED: 'question' missing or not String. Got: \(type(of: data["question"])) = \(data["question"] ?? "nil")")
            return nil
        }
        guard let optionsData = data["options"] as? [[String: Any]] else {
            print("[QuestionParse] FAILED: 'options' missing or not [[String: Any]]. Got: \(type(of: data["options"])) = \(data["options"] ?? "nil")")
            return nil
        }

        print("[QuestionParse] SUCCESS: id=\(id), question=\(question.prefix(30))..., options=\(optionsData.count)")

        let options = optionsData.enumerated().map { index, opt in
            QuestionOption(
                id: index,
                label: opt["label"] as? String ?? "Option \(index + 1)",
                description: opt["description"] as? String,
                isOther: (opt["label"] as? String)?.lowercased().contains("other") == true ||
                         (opt["label"] as? String)?.lowercased().contains("type") == true
            )
        }

        return ClaudeQuestion(
            id: id,
            question: question,
            header: data["header"] as? String,
            options: options,
            multiSelect: data["multiSelect"] as? Bool ?? false,
            timestamp: Date()
        )
    }
}

// MARK: - Question View

/// Displays a question from Claude with selectable options
/// Supports both single-select (tap to submit) and multi-select (checkboxes + submit)
struct QuestionView: View {
    let question: ClaudeQuestion
    let onAnswer: ([Int]) -> Void  // Selected option indices
    let onSkip: () -> Void         // Fallback to terminal (for "Other" options)

    @State private var selectedIndices: Set<Int> = []
    @State private var isSubmitting = false

    // Accessibility
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        ScrollView {
            VStack(spacing: Claude.Spacing.md) {
                // Header
                questionHeader

                // Question text
                Text(question.question)
                    .font(.claudeHeadline)
                    .foregroundColor(Claude.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)

                // Options
                VStack(spacing: Claude.Spacing.sm) {
                    ForEach(question.options) { option in
                        if option.isOther {
                            // "Other" option - skips to terminal
                            otherOptionRow(option)
                        } else if question.multiSelect {
                            // Multi-select: checkbox
                            multiSelectOptionRow(option)
                        } else {
                            // Single-select: tap to submit
                            singleSelectOptionRow(option)
                        }
                    }
                }

                // Submit button for multi-select
                if question.multiSelect && !selectedIndices.isEmpty {
                    submitButton
                }
            }
            .padding(.horizontal, Claude.Spacing.md)
            .padding(.vertical, Claude.Spacing.sm)
        }
    }

    // MARK: - Subviews

    private var questionHeader: some View {
        HStack(spacing: Claude.Spacing.xs) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Claude.info)

            Text(question.header?.uppercased() ?? "QUESTION")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Claude.info)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Question from Claude")
    }

    private func singleSelectOptionRow(_ option: ClaudeQuestion.QuestionOption) -> some View {
        Button {
            withAnimation(.buttonSpring) {
                selectedIndices = [option.id]
            }
            // Haptic feedback
            WKInterfaceDevice.current().play(.click)
            // Submit immediately for single-select
            isSubmitting = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onAnswer([option.id])
            }
        } label: {
            OptionRowContent(
                option: option,
                isSelected: selectedIndices.contains(option.id),
                showRadio: true,
                colorSchemeContrast: colorSchemeContrast
            )
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityLabel("\(option.label). \(option.description ?? "")")
        .accessibilityHint("Double tap to select")
    }

    private func multiSelectOptionRow(_ option: ClaudeQuestion.QuestionOption) -> some View {
        Button {
            withAnimation(.buttonSpring) {
                if selectedIndices.contains(option.id) {
                    selectedIndices.remove(option.id)
                } else {
                    selectedIndices.insert(option.id)
                }
            }
            WKInterfaceDevice.current().play(.click)
        } label: {
            OptionRowContent(
                option: option,
                isSelected: selectedIndices.contains(option.id),
                showRadio: false,
                colorSchemeContrast: colorSchemeContrast
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label). \(option.description ?? "")")
        .accessibilityValue(selectedIndices.contains(option.id) ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to toggle selection")
    }

    private func otherOptionRow(_ option: ClaudeQuestion.QuestionOption) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            onSkip()
        } label: {
            HStack(spacing: Claude.Spacing.sm) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16))
                    .foregroundColor(Claude.textSecondary)

                Text(option.label)
                    .font(.claudeBody)
                    .foregroundColor(Claude.textSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Claude.textTertiary)
            }
            .padding(.horizontal, Claude.Spacing.md)
            .padding(.vertical, Claude.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Claude.Radius.medium)
                    .fill(Claude.surface1)
                    .overlay(
                        RoundedRectangle(cornerRadius: Claude.Radius.medium)
                            .strokeBorder(Claude.borderContrast(colorSchemeContrast), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.label). Opens in terminal")
        .accessibilityHint("Double tap to answer in terminal")
    }

    private var submitButton: some View {
        Button {
            isSubmitting = true
            WKInterfaceDevice.current().play(.success)
            onAnswer(Array(selectedIndices).sorted())
        } label: {
            Text("Submit (\(selectedIndices.count))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Claude.info)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
        .accessibilityLabel("Submit \(selectedIndices.count) selected options")
    }
}

// MARK: - Option Row Content

private struct OptionRowContent: View {
    let option: ClaudeQuestion.QuestionOption
    let isSelected: Bool
    let showRadio: Bool  // true = radio button, false = checkbox
    let colorSchemeContrast: ColorSchemeContrast

    var body: some View {
        HStack(spacing: Claude.Spacing.sm) {
            // Selection indicator
            if showRadio {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Claude.info : Claude.textTertiary)
            } else {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? Claude.info : Claude.textTertiary)
            }

            // Label and description
            VStack(alignment: .leading, spacing: 2) {
                Text(option.label)
                    .font(.claudeBody)
                    .foregroundColor(Claude.textPrimary)
                    .lineLimit(2)

                if let description = option.description, !description.isEmpty {
                    Text(description)
                        .font(.claudeCaption)
                        .foregroundColor(Claude.textSecondaryContrast(colorSchemeContrast))
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Claude.Spacing.md)
        .padding(.vertical, Claude.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Claude.Radius.medium)
                .fill(isSelected ? Claude.info.opacity(0.15) : Claude.surface1)
                .overlay(
                    RoundedRectangle(cornerRadius: Claude.Radius.medium)
                        .strokeBorder(
                            isSelected ? Claude.info : Claude.borderContrast(colorSchemeContrast),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        )
    }
}

// MARK: - Answer Confirmation View

/// Shown briefly after submitting an answer
struct QuestionAnsweredView: View {
    let selectedLabels: [String]

    var body: some View {
        VStack(spacing: Claude.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(Claude.success)

            Text("ANSWER SENT")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Claude.success)

            if !selectedLabels.isEmpty {
                Text(selectedLabels.joined(separator: ", "))
                    .font(.claudeCaption)
                    .foregroundColor(Claude.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Text("Claude will continue.")
                .font(.claudeCaption)
                .foregroundColor(Claude.textTertiary)
        }
        .padding(Claude.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Answer sent. \(selectedLabels.joined(separator: ", ")). Claude will continue.")
    }
}

// MARK: - Preview

#Preview("Single Select") {
    QuestionView(
        question: ClaudeQuestion(
            id: "q1",
            question: "Which testing framework would you like to use?",
            header: "Testing",
            options: [
                .init(id: 0, label: "Jest (Recommended)", description: "Standard for React"),
                .init(id: 1, label: "Vitest", description: "Fast, Vite-native"),
                .init(id: 2, label: "Mocha", description: "Flexible, configurable"),
                .init(id: 3, label: "Other...", description: nil, isOther: true)
            ],
            multiSelect: false,
            timestamp: Date()
        ),
        onAnswer: { indices in print("Selected: \(indices)") },
        onSkip: { print("Skipped to terminal") }
    )
}

#Preview("Multi Select") {
    QuestionView(
        question: ClaudeQuestion(
            id: "q2",
            question: "Which features do you want to enable?",
            header: "Features",
            options: [
                .init(id: 0, label: "Authentication", description: "User login and signup"),
                .init(id: 1, label: "Authorization", description: "Role-based access"),
                .init(id: 2, label: "Password Reset", description: "Email-based recovery")
            ],
            multiSelect: true,
            timestamp: Date()
        ),
        onAnswer: { indices in print("Selected: \(indices)") },
        onSkip: { print("Skipped") }
    )
}

#Preview("Answer Confirmed") {
    QuestionAnsweredView(selectedLabels: ["Jest"])
}
