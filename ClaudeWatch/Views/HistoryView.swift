//
//  HistoryView.swift
//  ClaudeWatch
//
//  Session history / audit trail view
//  Addresses Sam's need for tracking what Claude did
//

import SwiftUI

/// Main history view showing action audit trail
struct HistoryView: View {
    @ObservedObject private var historyManager = HistoryManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            if historyManager.items.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: Claude.Spacing.md) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(Claude.textTertiary)

            Text("No History")
                .font(.claudeHeadline)
                .foregroundColor(Claude.textPrimary)

            Text("Actions you approve or reject will appear here")
                .font(.claudeCaption)
                .foregroundColor(Claude.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var historyList: some View {
        List {
            ForEach(historyManager.items) { item in
                HistoryRow(item: item)
            }
            .listRowBackground(Color.clear)

            // Clear button at bottom
            if historyManager.items.count > 5 {
                Button(role: .destructive) {
                    historyManager.clear()
                } label: {
                    Label("Clear History", systemImage: "trash")
                        .font(.claudeCaption)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }
}

/// Single history row item
struct HistoryRow: View {
    let item: HistoryItem

    var body: some View {
        HStack(spacing: 8) {
            // Outcome indicator
            Circle()
                .fill(item.outcome.color)
                .frame(width: 6, height: 6)

            // Action info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.fileName)
                        .font(.claudeMono)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)

                    if item.wasAutoApproved {
                        AutoBadge()
                    }
                }

                Text(item.outcome.rawValue.capitalized)
                    .font(.system(size: 10))
                    .foregroundColor(item.outcome.color)
            }

            Spacer()

            // Time
            Text(item.relativeTime)
                .font(.system(size: 9))
                .foregroundColor(Claude.textTertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.fileName), \(item.outcome.rawValue)\(item.wasAutoApproved ? ", auto-approved" : ""), \(item.relativeTime)")
    }
}

/// Small "auto" badge for auto-approved actions
struct AutoBadge: View {
    var body: some View {
        Text("auto")
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(Claude.textSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Claude.surface2)
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("History View") {
    NavigationStack {
        HistoryView()
    }
}

#Preview("History Row") {
    VStack(spacing: 12) {
        ForEach(HistoryItem.samples) { item in
            HistoryRow(item: item)
        }
    }
    .padding()
    .background(Claude.surface1)
}

#Preview("History Row - Auto") {
    HistoryRow(item: HistoryItem(
        actionType: "file_edit",
        fileName: "App.tsx",
        outcome: .approved,
        wasAutoApproved: true,
        timestamp: Date().addingTimeInterval(-300)
    ))
    .padding()
    .background(Claude.surface1)
}
