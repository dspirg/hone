import XCTest
@testable import WorkoutApp

// MARK: - CoachSSEClientTests
// Unit tests for CoachSSEClient event types, CoachResponseEnvelope decoding,
// and CoachSSEError descriptions.
// Network-level streaming tests are excluded (require live Edge Function).

@MainActor
final class CoachSSEClientTests: XCTestCase {

    // MARK: - CoachSSEEvent Tests

    func testCoachSSEEventTokenCase() {
        let event = CoachSSEEvent.token("Hello, coach!")
        if case .token(let text) = event {
            XCTAssertEqual(text, "Hello, coach!", "token case should contain the string value")
        } else {
            XCTFail("Expected .token case")
        }
    }

    func testCoachSSEEventTokenCaseWithEmptyString() {
        let event = CoachSSEEvent.token("")
        if case .token(let text) = event {
            XCTAssertEqual(text, "", "token case should handle empty string")
        } else {
            XCTFail("Expected .token case with empty string")
        }
    }

    func testCoachSSEEventCompletedCase() {
        let event = CoachSSEEvent.completed
        if case .completed = event {
            // Pass — completed case exists and can be matched
        } else {
            XCTFail("Expected .completed case")
        }
    }

    func testCoachSSEEventActionCase() {
        let envelope = CoachResponseEnvelope(action: "chat", planDelta: nil)
        let event = CoachSSEEvent.action(envelope)
        if case .action(let env) = event {
            XCTAssertEqual(env.action, "chat", "action case should carry the CoachResponseEnvelope")
        } else {
            XCTFail("Expected .action case")
        }
    }

    // MARK: - CoachResponseEnvelope Decoding Tests

    func testCoachResponseEnvelopeDecodingModifyPlan() {
        let json = """
        {"action":"modify_plan","plan_delta":"{\\"plan_name\\":\\"Updated Plan\\"}"}
        """.data(using: .utf8)!

        let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: json)
        XCTAssertNotNil(envelope, "Should decode envelope with modify_plan action")
        XCTAssertEqual(envelope?.action, "modify_plan")
        XCTAssertNotNil(envelope?.planDelta, "planDelta should be non-nil for modify_plan")
    }

    func testCoachResponseEnvelopeChatAction() {
        let json = """
        {"action":"chat","plan_delta":null}
        """.data(using: .utf8)!

        let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: json)
        XCTAssertNotNil(envelope, "Should decode envelope with chat action")
        XCTAssertEqual(envelope?.action, "chat")
        XCTAssertNil(envelope?.planDelta, "planDelta should be nil for plain chat action")
    }

    func testCoachResponseEnvelopeExecuteModifyAction() {
        let json = """
        {"action":"execute_modify","plan_delta":"{\\"plan_name\\":\\"Executed Plan\\"}"}
        """.data(using: .utf8)!

        let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: json)
        XCTAssertNotNil(envelope, "Should decode envelope with execute_modify action")
        XCTAssertEqual(envelope?.action, "execute_modify")
        XCTAssertNotNil(envelope?.planDelta)
    }

    func testCoachResponseEnvelopeNoPlanDeltaField() {
        // plan_delta is optional — should decode without it
        let json = """
        {"action":"chat"}
        """.data(using: .utf8)!

        let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: json)
        XCTAssertNotNil(envelope, "Should decode envelope even when plan_delta is absent")
        XCTAssertEqual(envelope?.action, "chat")
        XCTAssertNil(envelope?.planDelta)
    }

    func testCoachResponseEnvelopeSnakeCaseCodingKey() {
        // Verify that plan_delta (snake_case) maps correctly to planDelta (camelCase)
        let json = """
        {"action":"modify_plan","plan_delta":"test_json"}
        """.data(using: .utf8)!

        let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: json)
        XCTAssertEqual(envelope?.planDelta, "test_json",
            "CodingKey plan_delta must map to planDelta property")
    }

    // MARK: - CoachSSEError Description Tests

    func testCoachSSEErrorNotAuthenticatedDescription() {
        let error = CoachSSEError.notAuthenticated
        XCTAssertNotNil(error.errorDescription,
            "notAuthenticated must have a non-nil error description")
        XCTAssertFalse(error.errorDescription!.isEmpty,
            "notAuthenticated error description must not be empty")
    }

    func testCoachSSEErrorInvalidURLDescription() {
        let error = CoachSSEError.invalidURL
        XCTAssertNotNil(error.errorDescription,
            "invalidURL must have a non-nil error description")
        XCTAssertFalse(error.errorDescription!.isEmpty,
            "invalidURL error description must not be empty")
    }

    func testCoachSSEErrorStreamFailedDescription() {
        let error = CoachSSEError.streamFailed(statusCode: 500)
        XCTAssertNotNil(error.errorDescription,
            "streamFailed must have a non-nil error description")
        XCTAssertTrue(error.errorDescription!.contains("500"),
            "streamFailed description should include the status code")
    }

    func testCoachSSEErrorStreamFailedWith401Description() {
        let error = CoachSSEError.streamFailed(statusCode: 401)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("401"),
            "streamFailed description should include HTTP 401")
    }

    func testCoachSSEErrorDecodingFailedDescription() {
        let underlying = NSError(domain: "TestDomain", code: 42,
                                  userInfo: [NSLocalizedDescriptionKey: "JSON parse error"])
        let error = CoachSSEError.decodingFailed(underlying: underlying)
        XCTAssertNotNil(error.errorDescription,
            "decodingFailed must have a non-nil error description")
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testCoachSSEErrorNetworkErrorDescription() {
        let underlying = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet,
                                  userInfo: [NSLocalizedDescriptionKey: "No network"])
        let error = CoachSSEError.networkError(underlying: underlying)
        XCTAssertNotNil(error.errorDescription,
            "networkError must have a non-nil error description")
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testAllCoachSSEErrorsHaveDescriptions() {
        let underlying = NSError(domain: "Test", code: 0)
        let errors: [CoachSSEError] = [
            .notAuthenticated,
            .invalidURL,
            .streamFailed(statusCode: 500),
            .decodingFailed(underlying: underlying),
            .networkError(underlying: underlying),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                "\(error) must have a non-nil errorDescription")
        }
    }

    // MARK: - CoachSSEClient Instantiation Tests

    func testCoachSSEClientCanBeInstantiated() {
        let client = CoachSSEClient()
        XCTAssertNotNil(client, "CoachSSEClient should initialize without crashing")
    }

    // MARK: - ChatMessage Model Tests

    func testChatMessageRoleCoach() {
        let msg = ChatMessage(
            id: UUID(),
            role: .coach,
            content: "Great work today!",
            createdAt: Date()
        )
        XCTAssertEqual(msg.role, .coach)
        XCTAssertEqual(msg.role.rawValue, "coach")
    }

    func testChatMessageRoleUser() {
        let msg = ChatMessage(
            id: UUID(),
            role: .user,
            content: "I finished my workout",
            createdAt: Date()
        )
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.role.rawValue, "user")
    }

    func testChatMessagePlanModificationStateRawValues() {
        XCTAssertEqual(ChatMessage.PlanModificationState.pending.rawValue, "pending")
        XCTAssertEqual(ChatMessage.PlanModificationState.confirmed.rawValue, "confirmed")
        XCTAssertEqual(ChatMessage.PlanModificationState.dismissed.rawValue, "dismissed")
    }

    func testChatMessagePlanModificationStateFromRawValue() {
        XCTAssertEqual(
            ChatMessage.PlanModificationState(rawValue: "pending"),
            .pending,
            "Should decode 'pending' raw value to .pending case"
        )
        XCTAssertEqual(
            ChatMessage.PlanModificationState(rawValue: "confirmed"),
            .confirmed,
            "Should decode 'confirmed' raw value to .confirmed case"
        )
        XCTAssertEqual(
            ChatMessage.PlanModificationState(rawValue: "dismissed"),
            .dismissed,
            "Should decode 'dismissed' raw value to .dismissed case"
        )
        XCTAssertNil(
            ChatMessage.PlanModificationState(rawValue: "unknown"),
            "Unknown raw value should return nil"
        )
    }

    func testChatMessageEquality() {
        let id = UUID()
        let date = Date()
        let msg1 = ChatMessage(id: id, role: .user, content: "Hello", createdAt: date)
        let msg2 = ChatMessage(id: id, role: .user, content: "Hello", createdAt: date)
        XCTAssertEqual(msg1, msg2, "ChatMessage should be Equatable")
    }
}
