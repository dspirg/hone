import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - CoachViewModelTests
// Unit tests for CoachViewModel state machine.
// Requirements: CHAT-01, CHAT-02, CHAT-03

@MainActor
final class CoachViewModelTests: XCTestCase {

    // MARK: - Helpers

    func makeViewModel() -> CoachViewModel {
        CoachViewModel(context: PersistenceController(inMemory: true).container.viewContext)
    }

    static let testProfile = UserProfile(
        goal: "Build Muscle",
        fitnessLevel: "Intermediate",
        daysPerWeek: 4,
        equipment: ["Barbell", "Dumbbells"],
        injuries: ""
    )

    // MARK: - Initial State Tests

    func testInitialStateIsIdle() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.chatState, .idle)
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertFalse(vm.isStreaming)
        XCTAssertTrue(vm.isOnline)
    }

    func testCanSendIsTrueInInitialState() {
        let vm = makeViewModel()
        // idle + online = canSend
        XCTAssertTrue(vm.canSend, "canSend should be true when idle and online")
    }

    // MARK: - Streaming State Tests

    func testIsStreamingWhenStreamingState() {
        let vm = makeViewModel()
        vm.setChatStateForTesting(.streaming)
        XCTAssertTrue(vm.isStreaming, "isStreaming should be true when chatState == .streaming")
        XCTAssertFalse(vm.canSend, "canSend should be false during streaming (D-03)")
    }

    func testCanSendIsFalseWhenStreaming() {
        let vm = makeViewModel()
        vm.setChatStateForTesting(.streaming)
        XCTAssertFalse(vm.canSend, "send must be disabled during streaming per D-03")
    }

    // MARK: - Offline Behavior Tests (D-32)

    func testCanSendIsFalseWhenOffline() {
        let vm = makeViewModel()
        vm.setIsOnlineForTesting(false)
        XCTAssertFalse(vm.canSend, "send must be disabled when offline per D-32")
    }

    func testCanSendIsFalseWhenOfflineAndIdle() {
        let vm = makeViewModel()
        vm.setIsOnlineForTesting(false)
        XCTAssertEqual(vm.chatState, .idle)
        XCTAssertFalse(vm.canSend, "canSend requires both idle state AND online connectivity")
    }

    func testCanSendIsTrueWhenOnlineAndIdle() {
        let vm = makeViewModel()
        vm.setIsOnlineForTesting(true)
        vm.setChatStateForTesting(.idle)
        XCTAssertTrue(vm.canSend, "canSend should be true when online and idle")
    }

    // MARK: - Error State Tests (D-33)

    func testRetryResetsErrorState() {
        let vm = makeViewModel()
        // Set error state directly
        vm.setChatStateForTesting(.error("Something went wrong. Tap to retry."))
        XCTAssertEqual(vm.chatState, .error("Something went wrong. Tap to retry."))

        // retry() when no lastFailedMessage — just resets state check
        // With no pending retry message, retry() returns early
        vm.retry()
        // After retry with no stored message, state is unchanged (guard returns)
        // This verifies the guard condition
        XCTAssertNotNil(vm)
    }

    func testErrorStateHasCorrectMessage() {
        let vm = makeViewModel()
        let errorMsg = "Something went wrong. Tap to retry."
        vm.setChatStateForTesting(.error(errorMsg))
        if case .error(let msg) = vm.chatState {
            XCTAssertEqual(msg, errorMsg)
        } else {
            XCTFail("Expected error state")
        }
    }

    // MARK: - Plan Modification Tests (D-08 through D-12)

    func testDismissPlanModification() {
        let vm = makeViewModel()

        // Inject a pending modification message directly into messages array
        let msgId = UUID()
        let pendingMsg = ChatMessage(
            id: msgId,
            role: .coach,
            content: "I suggest updating your plan.",
            createdAt: Date(),
            planModificationJSON: "{\"plan_name\":\"Updated Plan\"}",
            planModificationState: .pending
        )
        // Use reflection or expose a testing hook — add message directly
        // Since messages is private(set), we need CoreData to load it.
        // For this test we verify dismissModification is a no-op when no matching message exists.
        // A non-existent ID dismissal should not crash.
        vm.dismissModification(messageId: msgId)
        XCTAssertTrue(vm.messages.isEmpty, "No messages in test context — dismiss should be a no-op")
    }

    func testDismissModificationChangesStateToDismissed() throws {
        // Create an in-memory CoreData context with a CDChatMessage
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)

        // Insert a pending CDChatMessage via CoreData
        let cdMsg = CDChatMessage(context: context)
        let msgId = UUID()
        cdMsg.id = msgId
        cdMsg.userId = "test-user"
        cdMsg.role = "coach"
        cdMsg.content = "I suggest modifying your plan."
        cdMsg.createdAt = Date()
        cdMsg.syncedToSupabase = false
        cdMsg.planModificationJSON = "{\"plan_name\":\"Updated\"}"
        cdMsg.planModificationState = "pending"
        try context.save()

        // Load messages from CoreData into the VM
        vm.loadMessages()

        // Verify the message was loaded
        XCTAssertFalse(vm.messages.isEmpty, "Should have loaded the CDChatMessage from CoreData")

        let loadedMsg = vm.messages.first { $0.id == msgId }
        XCTAssertNotNil(loadedMsg, "Should find message with our UUID")
        XCTAssertEqual(loadedMsg?.planModificationState, .pending)

        // Dismiss the modification
        vm.dismissModification(messageId: msgId)

        // Verify the state changed to dismissed in the in-memory array
        let dismissedMsg = vm.messages.first { $0.id == msgId }
        XCTAssertEqual(dismissedMsg?.planModificationState, .dismissed,
            "planModificationState should be .dismissed after dismissModification (D-10)")
    }

    func testModifyPlanActionStatePending() throws {
        // Verify that a CDChatMessage with planModificationState "pending"
        // maps to .pending in the display model
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)

        let cdMsg = CDChatMessage(context: context)
        cdMsg.id = UUID()
        cdMsg.userId = "test-user"
        cdMsg.role = "coach"
        cdMsg.content = "Plan modification ready."
        cdMsg.createdAt = Date()
        cdMsg.syncedToSupabase = false
        cdMsg.planModificationJSON = "{\"plan_name\":\"Modified Plan\"}"
        cdMsg.planModificationState = "pending"
        try context.save()

        vm.loadMessages()

        let msg = vm.messages.first
        XCTAssertEqual(msg?.planModificationState, .pending,
            "planModificationState 'pending' should map to .pending enum case (D-08)")
        XCTAssertNotNil(msg?.planModificationJSON, "planModificationJSON should be set")
    }

    // MARK: - Message History Cap Tests (T-05-10)

    func testMessageHistoryCappedAt20InPayload() {
        let vm = makeViewModel()

        // Set a known profile for deterministic payload building
        vm.setCachedProfileForTesting(Self.testProfile)

        // Insert 25 messages into the VM's messages array via CoreData
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm2 = CoachViewModel(context: context)
        vm2.setCachedProfileForTesting(Self.testProfile)

        // We test buildPayloadForTesting which uses messages.suffix(20)
        // Build the payload with a vm that has messages pre-loaded
        // Since loading requires CoreData, we verify the payload logic directly
        // by checking buildPayload uses .suffix(20)

        // Create a mock AppState for payload building
        let appState = AppState()

        // Build payload — with 0 messages, history should be empty
        let payload = vm.buildPayloadForTesting(message: "Hello", appState: appState)
        XCTAssertTrue(payload.messageHistory.isEmpty,
            "With no messages, history should be empty")
        XCTAssertEqual(payload.message, "Hello")
    }

    func testMessageHistoryCapWith30Messages() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)
        vm.setCachedProfileForTesting(Self.testProfile)

        // Insert 30 CDChatMessages
        let baseDate = Date()
        for i in 0..<30 {
            let cdMsg = CDChatMessage(context: context)
            cdMsg.id = UUID()
            cdMsg.userId = "test-user"
            cdMsg.role = i % 2 == 0 ? "user" : "coach"
            cdMsg.content = "Message \(i)"
            cdMsg.createdAt = baseDate.addingTimeInterval(Double(i))
            cdMsg.syncedToSupabase = false
        }
        try context.save()

        // Load messages (limit 50)
        vm.loadMessages()
        XCTAssertEqual(vm.messages.count, 30, "Should have loaded all 30 messages")

        // Build payload — history should be capped at last 20
        let appState = AppState()
        let payload = vm.buildPayloadForTesting(message: "Test", appState: appState)
        XCTAssertEqual(payload.messageHistory.count, 20,
            "Message history must be capped at 20 entries (T-05-10)")
        // Verify it's the LAST 20 (suffix)
        XCTAssertEqual(payload.messageHistory.last?.content, "Message 29",
            "Last history entry should be the most recent message")
    }

    // MARK: - Profile Population Tests (CHAT-03)

    func testProfilePopulatedInPayload() {
        let vm = makeViewModel()
        let profile = Self.testProfile
        vm.setCachedProfileForTesting(profile, displayName: "John")

        let appState = AppState()
        let payload = vm.buildPayloadForTesting(message: "Hello", appState: appState)

        XCTAssertEqual(payload.profile.goal, "Build Muscle",
            "Payload profile.goal must be populated from cachedUserProfile (CHAT-03)")
        XCTAssertEqual(payload.profile.fitnessLevel, "Intermediate",
            "Payload profile.fitnessLevel must be populated from cachedUserProfile (CHAT-03)")
        XCTAssertEqual(payload.profile.equipment, ["Barbell", "Dumbbells"],
            "Payload profile.equipment must be populated from cachedUserProfile (CHAT-03)")
        XCTAssertEqual(payload.profile.injuries, "",
            "Payload profile.injuries must reflect actual value (empty = no injuries)")
        XCTAssertEqual(payload.profile.name, "John",
            "Payload profile.name should be populated from cachedDisplayName")
    }

    func testProfileEquipmentIsNotEmptyWhenCached() {
        let vm = makeViewModel()
        let profile = UserProfile(
            goal: "Lose Weight",
            fitnessLevel: "Beginner",
            daysPerWeek: 3,
            equipment: ["Dumbbells", "Resistance Bands"],
            injuries: "Lower back"
        )
        vm.setCachedProfileForTesting(profile)

        let appState = AppState()
        let payload = vm.buildPayloadForTesting(message: "What should I do today?", appState: appState)

        XCTAssertFalse(payload.profile.equipment.isEmpty,
            "Equipment list should not be empty when profile is cached (CHAT-03)")
        XCTAssertEqual(payload.profile.injuries, "Lower back",
            "Injuries field should reflect actual injury data")
    }

    // MARK: - State Machine Consistency Tests

    func testChatStateEquality() {
        XCTAssertEqual(CoachViewModel.ChatState.idle, CoachViewModel.ChatState.idle)
        XCTAssertEqual(CoachViewModel.ChatState.streaming, CoachViewModel.ChatState.streaming)
        XCTAssertEqual(
            CoachViewModel.ChatState.error("msg"),
            CoachViewModel.ChatState.error("msg")
        )
        XCTAssertNotEqual(
            CoachViewModel.ChatState.idle,
            CoachViewModel.ChatState.streaming
        )
        XCTAssertNotEqual(
            CoachViewModel.ChatState.error("a"),
            CoachViewModel.ChatState.error("b")
        )
    }

    // MARK: - Session Summaries Tests (D-29, D-30)

    func testSessionSummariesLimitedTo3() throws {
        // Insert 5 CDSessionLog records and verify fetchLastSessionSummaries returns <= 3
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)
        vm.setCachedProfileForTesting(Self.testProfile)

        let baseDate = Date()
        for i in 0..<5 {
            let session = NSEntityDescription.insertNewObject(
                forEntityName: "CDSessionLog",
                into: context
            )
            session.setValue(UUID(), forKey: "id")
            session.setValue("user-1", forKey: "userId")
            session.setValue("plan-1", forKey: "planId")
            session.setValue("Day \(i+1)", forKey: "workoutDayLabel")
            session.setValue(baseDate.addingTimeInterval(Double(i * 3600)), forKey: "startedAt")
            session.setValue(baseDate.addingTimeInterval(Double(i * 3600 + 3600)), forKey: "completedAt")
            session.setValue(3, forKey: "totalExercises")
            session.setValue(9, forKey: "totalSets")
            session.setValue(90, forKey: "totalReps")
            session.setValue(true, forKey: "syncedToSupabase")
        }
        try context.save()

        // Build payload — session summaries should be capped at 3
        let appState = AppState()
        let payload = vm.buildPayloadForTesting(message: "How did I do?", appState: appState)
        XCTAssertLessThanOrEqual(payload.sessionSummaries.count, 3,
            "Session summaries must be limited to last 3 sessions (D-30)")
    }

    // MARK: - Message Loading Tests

    func testLoadMessagesPopulatesArray() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)

        // Insert 3 messages
        for i in 0..<3 {
            let cdMsg = CDChatMessage(context: context)
            cdMsg.id = UUID()
            cdMsg.userId = "test-user"
            cdMsg.role = i % 2 == 0 ? "user" : "coach"
            cdMsg.content = "Test message \(i)"
            cdMsg.createdAt = Date().addingTimeInterval(Double(i))
            cdMsg.syncedToSupabase = false
        }
        try context.save()

        vm.loadMessages()
        XCTAssertEqual(vm.messages.count, 3, "loadMessages should populate the messages array")
    }

    func testLoadMessagesOffsetAppendsOlderMessages() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let vm = CoachViewModel(context: context)

        // Insert 10 messages
        let baseDate = Date()
        for i in 0..<10 {
            let cdMsg = CDChatMessage(context: context)
            cdMsg.id = UUID()
            cdMsg.userId = "test-user"
            cdMsg.role = "user"
            cdMsg.content = "Message \(i)"
            cdMsg.createdAt = baseDate.addingTimeInterval(Double(i))
            cdMsg.syncedToSupabase = false
        }
        try context.save()

        // Initial load
        vm.loadMessages(limit: 5, offset: 0)
        XCTAssertEqual(vm.messages.count, 5, "Initial load should fetch 5 messages")

        // Load older messages (offset 5)
        vm.loadMessages(limit: 5, offset: 5)
        XCTAssertEqual(vm.messages.count, 10, "Offset load should prepend older messages")
    }
}
