//
//  ActivityStore.swift
//  ClaudeWatch
//
//  F22: Session Activity Dashboard
//  Event recording, persistence, and query service
//

import Foundation
import SwiftUI

// MARK: - Activity Store

/// Singleton service for recording and querying session activity events
/// Persists events to UserDefaults with automatic pruning
@MainActor
class ActivityStore: ObservableObject {

    // MARK: - Singleton

    static let shared = ActivityStore()

    // MARK: - Published Properties

    @Published private(set) var events: [ActivityEvent] = []
    @Published private(set) var currentSessionId: UUID?

    // MARK: - Configuration

    /// Maximum number of events to retain
    private let maxEventCount = 100

    /// Events older than this are pruned (24 hours)
    private let maxEventAge: TimeInterval = 24 * 60 * 60

    /// UserDefaults key for persistence
    private let storageKey = "activity_events"

    /// App group for shared storage
    private let sharedDefaults = UserDefaults(suiteName: "group.com.claudewatch")

    // MARK: - Initialization

    private init() {
        loadEvents()
        pruneOldEvents()
    }

    // MARK: - Recording Methods

    /// Record that a new session has started
    func recordSessionStarted() {
        let sessionId = UUID()
        currentSessionId = sessionId

        let event = ActivityEvent(
            type: .sessionStarted,
            title: "Session Started",
            sessionId: sessionId
        )
        addEvent(event)
    }

    /// Record that the current session has ended
    func recordSessionEnded() {
        guard let sessionId = currentSessionId else { return }

        let event = ActivityEvent(
            type: .sessionEnded,
            title: "Session Ended",
            sessionId: sessionId
        )
        addEvent(event)
        currentSessionId = nil
    }

    /// Record that a task has started
    /// - Parameter taskName: Name/description of the task
    func recordTaskStarted(_ taskName: String) {
        let event = ActivityEvent(
            type: .taskStarted,
            title: truncate(taskName),
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    /// Record that a task has been completed
    /// - Parameters:
    ///   - taskName: Name/description of the completed task
    ///   - filesChanged: Optional count of files changed
    func recordTaskCompleted(_ taskName: String, filesChanged: Int? = nil) {
        let subtitle: String? = filesChanged.map { "\($0) file\($0 == 1 ? "" : "s") changed" }

        let event = ActivityEvent(
            type: .taskCompleted,
            title: truncate(taskName),
            subtitle: subtitle,
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    /// Record an approval action response
    /// - Parameters:
    ///   - type: Type of action (e.g., "Bash", "Write")
    ///   - title: Description of the action
    ///   - approved: Whether it was approved or rejected
    func recordApproval(type: String, title: String, approved: Bool) {
        let event = ActivityEvent(
            type: approved ? .approvalApproved : .approvalRejected,
            title: truncate(title),
            subtitle: type,
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    /// Record a question was answered
    /// - Parameter question: The question that was answered
    func recordQuestion(_ question: String) {
        let event = ActivityEvent(
            type: .questionAnswered,
            title: truncate(question),
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    /// Record a context warning
    /// - Parameter percentage: Current context usage percentage
    func recordContextWarning(percentage: Int) {
        let event = ActivityEvent(
            type: .contextWarning,
            title: "Context at \(percentage)%",
            subtitle: "Consider summarizing",
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    /// Record an error event
    /// - Parameter message: Error description
    func recordError(_ message: String) {
        let event = ActivityEvent(
            type: .error,
            title: truncate(message),
            sessionId: currentSessionId
        )
        addEvent(event)
    }

    // MARK: - Computed Queries

    /// Most recent activity event
    var lastActivity: ActivityEvent? {
        events.first
    }

    /// Time since last activity (for idle detection)
    var timeSinceLastActivity: TimeInterval? {
        guard let lastEvent = lastActivity else { return nil }
        return Date().timeIntervalSince(lastEvent.timestamp)
    }

    /// Check if session has been idle for longer than specified duration
    func isIdleFor(minutes: Int) -> Bool {
        guard let elapsed = timeSinceLastActivity else { return false }
        return elapsed > TimeInterval(minutes * 60)
    }

    /// Stats for the current session
    var currentSessionStats: (tasks: Int, approvals: Int)? {
        guard currentSessionId != nil else {
            // If no active session, return stats from most recent events
            let recentEvents = eventsFromToday
            if recentEvents.isEmpty { return nil }

            let tasks = recentEvents.filter { $0.type == .taskCompleted }.count
            let approvals = recentEvents.filter {
                $0.type == .approvalApproved || $0.type == .approvalRejected
            }.count

            if tasks == 0 && approvals == 0 { return nil }
            return (tasks: tasks, approvals: approvals)
        }

        let sessionEvents = events.filter { $0.sessionId == currentSessionId }
        let tasks = sessionEvents.filter { $0.type == .taskCompleted }.count
        let approvals = sessionEvents.filter {
            $0.type == .approvalApproved || $0.type == .approvalRejected
        }.count

        return (tasks: tasks, approvals: approvals)
    }

    /// Events from today only
    var eventsFromToday: [ActivityEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return events.filter { $0.timestamp >= today }
    }

    /// Events grouped by day (for timeline display)
    var eventsByDay: [(date: Date, events: [ActivityEvent])] {
        let calendar = Calendar.current
        var grouped: [Date: [ActivityEvent]] = [:]

        for event in events {
            let dayStart = calendar.startOfDay(for: event.timestamp)
            grouped[dayStart, default: []].append(event)
        }

        return grouped
            .map { (date: $0.key, events: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Returns formatted day header text
    func dayHeaderText(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Clear / Reset

    /// Clear all events (for testing or reset)
    func clearAllEvents() {
        events.removeAll()
        currentSessionId = nil
        saveEvents()
    }

    /// Clear events for a specific session
    func clearEventsForSession(_ sessionId: UUID) {
        events.removeAll { $0.sessionId == sessionId }
        saveEvents()
    }

    // MARK: - Private Helpers

    private func addEvent(_ event: ActivityEvent) {
        // Insert at beginning (newest first)
        events.insert(event, at: 0)

        // Enforce max count
        if events.count > maxEventCount {
            events = Array(events.prefix(maxEventCount))
        }

        saveEvents()
    }

    private func truncate(_ text: String, maxLength: Int = 30) -> String {
        if text.count > maxLength {
            return String(text.prefix(maxLength - 3)) + "..."
        }
        return text
    }

    private func pruneOldEvents() {
        let cutoff = Date().addingTimeInterval(-maxEventAge)
        events.removeAll { $0.timestamp < cutoff }
        saveEvents()
    }

    // MARK: - Persistence

    private func saveEvents() {
        guard let defaults = sharedDefaults else { return }

        do {
            let data = try JSONEncoder().encode(events)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("ActivityStore: Failed to save events: \(error)")
        }
    }

    private func loadEvents() {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: storageKey) else {
            return
        }

        do {
            events = try JSONDecoder().decode([ActivityEvent].self, from: data)
        } catch {
            print("ActivityStore: Failed to load events: \(error)")
            events = []
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ActivityStore {
    /// Create a preview store with sample data
    static var preview: ActivityStore {
        let store = ActivityStore.shared
        store.events = ActivityEvent.previewEvents
        store.currentSessionId = UUID()
        return store
    }
}
#endif
