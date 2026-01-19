//
//  ApprovalRequest.swift
//  ClaudeWatch
//
//  Type-safe structured parsing for incoming Claude Code actions
//  using Foundation Models' @Generable macro
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Parsed approval request from Claude Code using on-device AI
/// The @Generable macro enables type-safe structured output generation
@available(watchOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable(description: "Parsed approval request from Claude Code")
struct GenerableApprovalRequest {
    /// The type of action being requested
    @Guide(description: "Action type", .options(["file_edit", "file_create", "file_delete", "bash", "api_call"]))
    var actionType: String

    /// Risk level from 1 (safe) to 5 (dangerous)
    @Guide(description: "Risk level 1-5 where 1 is safe and 5 is dangerous", .range(1...5))
    var riskLevel: Int

    /// One sentence summary of the action
    @Guide(description: "One sentence summary of what this action does")
    var summary: String

    /// File path affected (if applicable)
    @Guide(description: "File path affected by this action, or empty if not applicable")
    var filePath: String

    /// Whether this action is reversible
    @Guide(description: "Whether this action can be undone")
    var isReversible: Bool
}

// MARK: - Session Extension for ApprovalRequest Parsing

@available(watchOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, *)
extension GenerableApprovalRequest {
    /// Parse an approval request from raw action data using on-device AI
    /// - Parameters:
    ///   - session: The LanguageModelSession to use for parsing
    ///   - actionData: Raw action data dictionary from the server
    /// - Returns: Parsed GenerableApprovalRequest with structured fields
    static func parse(
        using session: LanguageModelSession,
        from actionData: [String: Any]
    ) async throws -> GenerableApprovalRequest {
        let description = actionData["description"] as? String ?? ""
        let type = actionData["type"] as? String ?? "unknown"
        let filePath = actionData["file_path"] as? String ?? ""
        let command = actionData["command"] as? String ?? ""

        let prompt = """
        Parse this Claude Code action request:
        Type: \(type)
        Description: \(description)
        File: \(filePath)
        Command: \(command)

        Determine the action type, risk level, and provide a one-sentence summary.
        """

        return try await session.respond(to: prompt, generating: GenerableApprovalRequest.self)
    }
}
#endif

// MARK: - Cross-Platform ApprovalRequest

/// Approval request that works on all platforms
/// Uses on-device AI parsing when available, falls back to heuristics otherwise
struct ApprovalRequest {
    var actionType: String
    var riskLevel: Int
    var summary: String
    var filePath: String
    var isReversible: Bool

    /// Create from raw action data using heuristic-based parsing
    /// Used as fallback when Foundation Models unavailable
    static func from(actionData: [String: Any]) -> ApprovalRequest {
        let type = actionData["type"] as? String ?? "unknown"
        let description = actionData["description"] as? String ?? ""
        let filePath = actionData["file_path"] as? String ?? ""

        // Determine risk level heuristically
        let riskLevel: Int
        switch type {
        case "file_delete":
            riskLevel = 5
        case "bash":
            riskLevel = 4
        case "file_edit":
            riskLevel = 2
        case "file_create":
            riskLevel = 1
        case "api_call":
            riskLevel = 3
        default:
            riskLevel = 3
        }

        return ApprovalRequest(
            actionType: type,
            riskLevel: riskLevel,
            summary: description.isEmpty ? "Perform \(type) action" : description,
            filePath: filePath,
            isReversible: type != "file_delete"
        )
    }

    #if canImport(FoundationModels)
    /// Convert from GenerableApprovalRequest
    @available(watchOS 26.0, iOS 26.0, macOS 26.0, visionOS 26.0, *)
    init(from generable: GenerableApprovalRequest) {
        self.actionType = generable.actionType
        self.riskLevel = generable.riskLevel
        self.summary = generable.summary
        self.filePath = generable.filePath
        self.isReversible = generable.isReversible
    }
    #endif
}
