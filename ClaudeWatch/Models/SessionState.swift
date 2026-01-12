import Foundation
import SwiftUI

// MARK: - Task State
struct TaskState: Identifiable, Codable {
    let id: UUID
    var name: String
    var progress: Double // 0.0 to 1.0
    var status: TaskStatus
    var createdAt: Date

    init(id: UUID = UUID(), name: String, progress: Double = 0.0, status: TaskStatus = .running) {
        self.id = id
        self.name = name
        self.progress = progress
        self.status = status
        self.createdAt = Date()
    }
}

enum TaskStatus: String, Codable {
    case pending = "PENDING"
    case running = "RUNNING"
    case waitingApproval = "WAITING"
    case completed = "COMPLETED"
    case failed = "FAILED"

    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .blue
        case .waitingApproval: return .orange
        case .completed: return .green
        case .failed: return .red
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.fill"
        case .waitingApproval: return "hand.raised.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}

// MARK: - Pending Action
struct PendingAction: Identifiable, Codable {
    let id: UUID
    var type: ActionType
    var description: String
    var filePath: String?
    var timestamp: Date

    init(id: UUID = UUID(), type: ActionType, description: String, filePath: String? = nil) {
        self.id = id
        self.type = type
        self.description = description
        self.filePath = filePath
        self.timestamp = Date()
    }
}

enum ActionType: String, Codable {
    case fileEdit = "FILE_EDIT"
    case fileCreate = "FILE_CREATE"
    case fileDelete = "FILE_DELETE"
    case bashCommand = "BASH"
    case toolCall = "TOOL"

    var icon: String {
        switch self {
        case .fileEdit: return "pencil"
        case .fileCreate: return "doc.badge.plus"
        case .fileDelete: return "trash"
        case .bashCommand: return "terminal"
        case .toolCall: return "wrench.and.screwdriver"
        }
    }

    var color: Color {
        switch self {
        case .fileEdit: return .blue
        case .fileCreate: return .green
        case .fileDelete: return .red
        case .bashCommand: return .orange
        case .toolCall: return .purple
        }
    }
}

// MARK: - Model Configuration
enum ClaudeModel: String, CaseIterable, Codable {
    case opus = "opus"
    case sonnet = "sonnet"
    case haiku = "haiku"

    var displayName: String {
        switch self {
        case .opus: return "Opus 4.5"
        case .sonnet: return "Sonnet 4"
        case .haiku: return "Haiku"
        }
    }

    var shortName: String {
        rawValue.uppercased()
    }

    var color: Color {
        switch self {
        case .opus: return .purple
        case .sonnet: return .blue
        case .haiku: return .green
        }
    }
}

// MARK: - Session Configuration
struct SessionConfig: Codable {
    var yoloMode: Bool
    var selectedModel: ClaudeModel
    var hapticFeedback: Bool
    var autoSuggestPrompts: Bool

    static let `default` = SessionConfig(
        yoloMode: false,
        selectedModel: .sonnet,
        hapticFeedback: true,
        autoSuggestPrompts: true
    )
}

// MARK: - Quick Prompts
struct QuickPrompt: Identifiable, Codable {
    let id: UUID
    var text: String
    var icon: String
    var category: PromptCategory

    init(id: UUID = UUID(), text: String, icon: String, category: PromptCategory) {
        self.id = id
        self.text = text
        self.icon = icon
        self.category = category
    }
}

enum PromptCategory: String, Codable, CaseIterable {
    case action = "Action"
    case question = "Question"
    case navigation = "Navigation"

    var color: Color {
        switch self {
        case .action: return .orange
        case .question: return .blue
        case .navigation: return .green
        }
    }
}
