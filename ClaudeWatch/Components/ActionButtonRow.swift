//
//  ActionButtonRow.swift
//  Remmy
//
//  V2: Standardized Yes/No button pair for binary decisions
//  Used in QuestionResponseView for quick approve/reject responses
//

import SwiftUI

// MARK: - Action Button Row
/// A horizontal row of Yes/No action buttons for binary decisions
/// Used primarily in QuestionResponseView for quick responses
struct ActionButtonRow: View {
    let onYes: () -> Void
    let onNo: () -> Void
    var yesLabel: String
    var noLabel: String

    /// Creates an action row with customizable labels
    /// - Parameters:
    ///   - yesLabel: Label for the affirmative button (default: "Yes")
    ///   - noLabel: Label for the negative button (default: "No")
    ///   - onYes: Action to perform when Yes is tapped
    ///   - onNo: Action to perform when No is tapped
    init(
        yesLabel: String = "Yes",
        noLabel: String = "No",
        onYes: @escaping () -> Void,
        onNo: @escaping () -> Void
    ) {
        self.yesLabel = yesLabel
        self.noLabel = noLabel
        self.onYes = onYes
        self.onNo = onNo
    }

    var body: some View {
        HStack(spacing: 12) {
            // Yes button - primary action (green)
            Button {
                onYes()
            } label: {
                Text(yesLabel)
                    .font(.claudeBodyMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Claude.success)

            // No button - secondary action (bordered)
            Button {
                onNo()
            } label: {
                Text(noLabel)
                    .font(.claudeBodyMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Preview
#Preview("Action Button Row") {
    VStack(spacing: 20) {
        ActionButtonRow(
            onYes: { print("Yes tapped") },
            onNo: { print("No tapped") }
        )

        ActionButtonRow(
            yesLabel: "Accept",
            noLabel: "Decline",
            onYes: { },
            onNo: { }
        )
    }
    .padding()
}
