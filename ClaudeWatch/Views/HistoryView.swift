//
//  HistoryView.swift
//  ClaudeWatch
//
//  F22: Session Activity Dashboard
//  Timeline view showing activity history grouped by day
//

import SwiftUI

// MARK: - History View

/// Timeline view showing all session activity events
/// Events are grouped by day with newest first
struct HistoryView: View {
    @ObservedObject private var activityStore = ActivityStore.shared

    var body: some View {
        Group {
            if activityStore.events.isEmpty {
                emptyHistoryView
            } else {
                historyListView
            }
        }
        .navigationTitle("History")
    }

    // MARK: - Empty State

    private var emptyHistoryView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(Claude.textTertiary)

            Text("No Activity Yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Claude.textPrimary)

            Text("Your session activity will appear here")
                .font(.system(size: 11))
                .foregroundColor(Claude.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - History List

    private var historyListView: some View {
        List {
            ForEach(activityStore.eventsByDay, id: \.date) { dayGroup in
                Section {
                    ForEach(dayGroup.events) { event in
                        ActivityRow(event: event)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    DayHeader(date: dayGroup.date)
                }
            }
        }
        .listStyle(.plain)
        .focusable()  // Enable Digital Crown scrolling
    }
}

// MARK: - Day Header

/// Header for each day group in the timeline
struct DayHeader: View {
    let date: Date

    var body: some View {
        Text(dayText)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Claude.textSecondary)
            .textCase(.uppercase)
    }

    private var dayText: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Activity Row

/// A single row in the activity timeline
struct ActivityRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 8) {
            // Event type icon
            Image(systemName: event.icon)
                .font(.system(size: 12))
                .foregroundColor(event.color)
                .frame(width: 20)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.truncatedTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Claude.textPrimary)
                    .lineLimit(1)

                if let subtitle = event.subtitle {
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(Claude.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timestamp
            Text(event.formattedTime)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Claude.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("History View - Empty") {
    NavigationStack {
        HistoryView()
    }
}

#Preview("History View - With Events") {
    NavigationStack {
        HistoryView()
    }
}

#Preview("Activity Row") {
    VStack(spacing: 8) {
        ActivityRow(event: ActivityEvent(
            type: .taskCompleted,
            title: "Fixed authentication bug",
            subtitle: "3 files changed"
        ))

        ActivityRow(event: ActivityEvent(
            type: .approvalApproved,
            title: "Bash: npm install lodash",
            subtitle: "npm command"
        ))

        ActivityRow(event: ActivityEvent(
            type: .approvalRejected,
            title: "Write: /etc/hosts",
            subtitle: "File write"
        ))

        ActivityRow(event: ActivityEvent(
            type: .contextWarning,
            title: "Context at 80%"
        ))
    }
    .padding()
}

#Preview("Day Header") {
    VStack(spacing: 16) {
        DayHeader(date: Date())
        DayHeader(date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        DayHeader(date: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date())
    }
    .padding()
}
