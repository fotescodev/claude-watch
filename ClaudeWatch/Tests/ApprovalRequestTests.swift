import XCTest
@testable import ClaudeWatch

final class ApprovalRequestTests: XCTestCase {

    // MARK: - Risk Level Heuristics

    func testFileDeleteHasHighestRiskLevel() {
        let data: [String: Any] = [
            "type": "file_delete",
            "description": "Delete a file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 5)
    }

    func testBashHasHighRiskLevel() {
        let data: [String: Any] = [
            "type": "bash",
            "description": "Run a command"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 4)
    }

    func testApiCallHasMediumRiskLevel() {
        let data: [String: Any] = [
            "type": "api_call",
            "description": "Make an API request"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 3)
    }

    func testFileEditHasLowRiskLevel() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Edit a file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 2)
    }

    func testFileCreateHasLowestRiskLevel() {
        let data: [String: Any] = [
            "type": "file_create",
            "description": "Create a new file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 1)
    }

    func testUnknownTypeHasMediumRiskLevel() {
        let data: [String: Any] = [
            "type": "something_else",
            "description": "Unknown action"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.riskLevel, 3)
    }

    // MARK: - Action Type Extraction

    func testActionTypeExtractedFromData() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Edit main.swift"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.actionType, "file_edit")
    }

    func testMissingTypeDefaultsToUnknown() {
        let data: [String: Any] = [
            "description": "Some action"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.actionType, "unknown")
    }

    // MARK: - Summary Generation

    func testSummaryUsesDescriptionWhenPresent() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Update authentication logic"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.summary, "Update authentication logic")
    }

    func testSummaryGeneratedWhenDescriptionEmpty() {
        let data: [String: Any] = [
            "type": "bash",
            "description": ""
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.summary, "Perform bash action")
    }

    func testSummaryGeneratedWhenDescriptionMissing() {
        let data: [String: Any] = [
            "type": "file_create"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.summary, "Perform file_create action")
    }

    // MARK: - File Path Extraction

    func testFilePathExtractedFromData() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Edit file",
            "file_path": "src/main.swift"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.filePath, "src/main.swift")
    }

    func testFilePathEmptyWhenMissing() {
        let data: [String: Any] = [
            "type": "bash",
            "description": "Run command"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.filePath, "")
    }

    // MARK: - Reversibility

    func testFileDeleteIsNotReversible() {
        let data: [String: Any] = [
            "type": "file_delete",
            "description": "Delete a file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertFalse(request.isReversible)
    }

    func testFileEditIsReversible() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Edit a file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertTrue(request.isReversible)
    }

    func testFileCreateIsReversible() {
        let data: [String: Any] = [
            "type": "file_create",
            "description": "Create a file"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertTrue(request.isReversible)
    }

    func testBashIsReversible() {
        let data: [String: Any] = [
            "type": "bash",
            "description": "Run a command"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertTrue(request.isReversible)
    }

    func testApiCallIsReversible() {
        let data: [String: Any] = [
            "type": "api_call",
            "description": "Make an API call"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertTrue(request.isReversible)
    }

    // MARK: - Complete Data Parsing

    func testCompleteDataParsing() {
        let data: [String: Any] = [
            "type": "file_edit",
            "description": "Update login handler",
            "file_path": "src/auth/login.swift"
        ]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.actionType, "file_edit")
        XCTAssertEqual(request.riskLevel, 2)
        XCTAssertEqual(request.summary, "Update login handler")
        XCTAssertEqual(request.filePath, "src/auth/login.swift")
        XCTAssertTrue(request.isReversible)
    }

    func testEmptyDataParsing() {
        let data: [String: Any] = [:]

        let request = ApprovalRequest.from(actionData: data)

        XCTAssertEqual(request.actionType, "unknown")
        XCTAssertEqual(request.riskLevel, 3)
        XCTAssertEqual(request.summary, "Perform unknown action")
        XCTAssertEqual(request.filePath, "")
        XCTAssertTrue(request.isReversible)
    }
}
