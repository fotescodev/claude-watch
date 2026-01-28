//
//  TaskChecklist.swift
//  ClaudeWatch
//
//  V2: Task progress display component
//  Shows done/active/pending items for WorkingView and PausedView
//

import SwiftUI

// MARK: - Task Check Status

/// Status of a task checklist item
enum TaskCheckStatus: String, CaseIterable {
    case done      // ✓ completed - green
    case active    // ● in progress - blue
    case pending   // ○ not started - gray

    var icon: String {
        switch self {
        case .done: return "checkmark.circle.fill"
        case .active: return "arrow.right.circle.fill"  // Distinct filled icon for active
        case .pending: return "circle"
        }
    }

    var color: Color {
        switch self {
        case .done: return Claude.success
        case .active: return Claude.info
        case .pending: return Color(white: 0.43)  // #6E6E73
        }
    }
}

// MARK: - Task Check Item

/// Single item in a task checklist
struct TaskCheckItem: View {
    let status: TaskCheckStatus
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
                .foregroundColor(status.color)

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(status == .pending ? Color(white: 0.43) : .white)
                .lineLimit(1)
        }
    }
}

// MARK: - Task Checklist

/// A vertical list of task items showing progress
struct TaskChecklist: View {
    let items: [(status: TaskCheckStatus, text: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                TaskCheckItem(status: item.status, text: item.text)
            }
        }
    }
}

// MARK: - Previews

#Preview("Task Checklist") {
    TaskChecklist(items: [
        (.done, "Research existing code"),
        (.active, "Update auth service"),
        (.pending, "Add unit tests"),
        (.pending, "Update documentation")
    ])
    .padding()
    .background(Color.black)
}

#Preview("Task Check Items") {
    VStack(alignment: .leading, spacing: 12) {
        TaskCheckItem(status: .done, text: "Completed task")
        TaskCheckItem(status: .active, text: "In progress task")
        TaskCheckItem(status: .pending, text: "Pending task")
    }
    .padding()
    .background(Color.black)
}
