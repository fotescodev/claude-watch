//
//  HistoryItem.swift
//  ClaudeWatch
//
//  Model for tracking action history (audit trail)
//  Addresses Sam's need for session audit capability
//

import Foundation
import SwiftUI

/// Represents a historical action that was approved or rejected
struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let actionType: String
    let fileName: String
    let outcome: Outcome
    let wasAutoApproved: Bool
    let timestamp: Date

    /// The outcome of the action
    enum Outcome: String, Codable {
        case approved
        case rejected

        var color: Color {
            switch self {
            case .approved: return Claude.success
            case .rejected: return Claude.danger
            }
        }

        var icon: String {
            switch self {
            case .approved: return "checkmark.circle.fill"
            case .rejected: return "xmark.circle.fill"
            }
        }
    }

    /// Create from a pending action and its outcome
    init(from action: PendingAction, outcome: Outcome, wasAutoApproved: Bool = false) {
        self.id = UUID()
        self.actionType = action.type
        // Extract just the filename from the path
        if let path = action.filePath {
            self.fileName = path.split(separator: "/").last.map(String.init) ?? action.title
        } else {
            self.fileName = action.title
        }
        self.outcome = outcome
        self.wasAutoApproved = wasAutoApproved
        self.timestamp = Date()
    }

    /// Direct initializer for decoding/testing
    init(id: UUID = UUID(), actionType: String, fileName: String, outcome: Outcome, wasAutoApproved: Bool, timestamp: Date) {
        self.id = id
        self.actionType = actionType
        self.fileName = fileName
        self.outcome = outcome
        self.wasAutoApproved = wasAutoApproved
        self.timestamp = timestamp
    }

    /// Action type icon
    var icon: String {
        switch actionType {
        case "file_edit": return "pencil"
        case "file_create": return "doc.badge.plus"
        case "file_delete": return "trash"
        case "bash": return "terminal"
        default: return "gear"
        }
    }

    /// Action type color
    var typeColor: Color {
        switch actionType {
        case "file_edit": return Claude.orange
        case "file_create": return Claude.info
        case "file_delete": return Claude.danger
        case "bash": return Color.purple
        default: return Claude.orange
        }
    }

    /// Formatted relative time
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - History Manager

/// Manages action history with persistence
class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published private(set) var items: [HistoryItem] = []

    private let maxItems = 50
    private let storageKey = "actionHistory"

    private init() {
        load()
    }

    /// Record an action outcome
    func record(_ action: PendingAction, outcome: HistoryItem.Outcome, wasAutoApproved: Bool = false) {
        let item = HistoryItem(from: action, outcome: outcome, wasAutoApproved: wasAutoApproved)
        items.insert(item, at: 0)

        // Trim if needed
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    /// Clear all history
    func clear() {
        items = []
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
}

// MARK: - Demo Data

extension HistoryItem {
    static let samples: [HistoryItem] = [
        HistoryItem(actionType: "file_edit", fileName: "App.tsx", outcome: .approved, wasAutoApproved: false, timestamp: Date().addingTimeInterval(-120)),
        HistoryItem(actionType: "file_edit", fileName: "utils.ts", outcome: .approved, wasAutoApproved: true, timestamp: Date().addingTimeInterval(-300)),
        HistoryItem(actionType: "file_create", fileName: "test.ts", outcome: .approved, wasAutoApproved: true, timestamp: Date().addingTimeInterval(-480)),
        HistoryItem(actionType: "file_delete", fileName: "config.ts", outcome: .rejected, wasAutoApproved: false, timestamp: Date().addingTimeInterval(-720)),
        HistoryItem(actionType: "file_edit", fileName: "index.ts", outcome: .approved, wasAutoApproved: true, timestamp: Date().addingTimeInterval(-900)),
    ]
}
