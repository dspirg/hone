import Foundation
import Network
import Observation
import CoreData
import Supabase

// MARK: - CoachViewModel
// Central state machine for the AI coach chat feature.
//
// Responsibilities:
//   1. Message sending with SSE streaming via CoachSSEClient (D-01 through D-04)
//   2. CoreData write-ahead persistence (D-20) — saves user message before streaming
//   3. Supabase coach_messages sync after stream completion (D-20)
//   4. NWPathMonitor offline detection — disables send when offline (D-32)
//   5. Plan modification confirm/dismiss flow (D-08 through D-12)
//   6. System prompt payload assembly with real user profile data (CHAT-03)
//   7. Message history pagination — loads last 50, supports loading older (D-19)
//
// Thread safety:
//   - All @Observable state mutations are on @MainActor
//   - NWPathMonitor starts on a dedicated background queue (never .main)
//   - isSyncing Bool guard prevents concurrent Supabase upserts (T-05-11)
//
// Security:
//   - Never calls OpenAI directly — all AI calls go through CoachSSEClient -> Edge Function
//   - JWT auth is managed by CoachSSEClient via supabase.auth.session
//
// Requirements: CHAT-01, CHAT-02, CHAT-03

@Observable
@MainActor
final class CoachViewModel {

    // MARK: - State

    enum ChatState: Equatable {
        case idle
        case streaming
        case error(String)
    }

    private(set) var chatState: ChatState = .idle
    private(set) var messages: [ChatMessage] = []
    private(set) var streamingText: String = ""
    private(set) var isOnline: Bool = true

    var isStreaming: Bool { chatState == .streaming }
    var canSend: Bool { !isStreaming && isOnline }

    // isSyncing guard — prevents concurrent Supabase upserts (T-05-11)
    private var isSyncing: Bool = false
    private var currentStreamTask: Task<Void, Never>?
    private var pendingEnvelope: CoachResponseEnvelope?

    // Cached user profile for payload assembly (CHAT-03)
    // Populated in onAppear via fetchUserProfile — never left as empty strings in payload
    private var cachedUserProfile: UserProfile?
    private var cachedDisplayName: String?

    // Cached user ID — set from AppState.currentUser on onAppear
    // Avoids needing async supabase.auth.session in sync CoreData predicates
    private var cachedUserId: String?

    // Store for tap-to-retry (D-33)
    private var lastFailedMessage: String?
    private var lastFailedAppState: AppState?

    // Total message count for summarization trigger tracking
    private var totalMessageCount: Int = 0

    // MARK: - Dependencies

    private let sseClient = CoachSSEClient()
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.workoutapp.coach-network-monitor")
    private let viewContext: NSManagedObjectContext

    // MARK: - Init

    init(context: NSManagedObjectContext? = nil) {
        self.viewContext = context ?? PersistenceController.shared.container.viewContext
    }

    // MARK: - Lifecycle

    func onAppear(appState: AppState) {
        // Cache the userId from AppState for sync CoreData predicates
        cachedUserId = appState.currentUser?.id.uuidString
        startMonitoring()
        loadMessages()
        // Fetch user profile for CHAT-03 payload assembly
        Task { await fetchUserProfile(appState: appState) }
    }

    func onDisappear() {
        monitor.cancel()
        currentStreamTask?.cancel()
    }

    // MARK: - User Profile Fetch (CHAT-03)
    //
    // The user's fitness profile (goal, fitnessLevel, equipment, injuries)
    // is stored in the Supabase profiles table. It was saved during onboarding
    // via PlanGenerationService.saveProfile(). We fetch it here so that every
    // coach chat payload includes real profile data per D-28.
    //
    // CRITICAL: Profile fields MUST NOT be empty strings in buildPayload.
    // Empty strings cause the coach to have no context about the user.
    // If the fetch fails, the coach still works but with degraded context.

    private func fetchUserProfile(appState: AppState) async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            struct ProfileRow: Decodable {
                let goal: String?
                let fitness_level: String?
                let days_per_week: Int?
                let equipment: [String]?
                let injuries: String?
                let display_name: String?
            }

            let response: [ProfileRow] = try await supabase
                .from("profiles")
                .select("goal, fitness_level, days_per_week, equipment, injuries, display_name")
                .eq("id", value: userId.uuidString)
                .execute()
                .value

            if let row = response.first {
                cachedUserProfile = UserProfile(
                    goal: row.goal ?? "",
                    fitnessLevel: row.fitness_level ?? "",
                    daysPerWeek: row.days_per_week ?? 3,
                    equipment: row.equipment ?? [],
                    injuries: row.injuries ?? ""
                )
                cachedDisplayName = row.display_name
            }
        } catch {
            // Fallback: profile fields will be empty, but coach still works
            // Coach will function without personalized context
            print("CoachViewModel: Failed to fetch user profile: \(error)")
        }
    }

    // MARK: - Network Monitoring (D-32)
    //
    // NWPathMonitor MUST start on a background queue, never .main.
    // Swift 6 actor isolation requires bridging back to @MainActor for state updates.

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Message Loading (D-19)

    func loadMessages(limit: Int = 50, offset: Int = 0) {
        let request = NSFetchRequest<CDChatMessage>(entityName: "CDChatMessage")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        request.fetchLimit = limit
        request.fetchOffset = offset

        if let userId = getCurrentUserId() {
            request.predicate = NSPredicate(format: "userId == %@", userId)
        }

        do {
            let cdMessages = try viewContext.fetch(request)
            if offset == 0 {
                messages = cdMessages.map { mapToDisplayMessage($0) }
            } else {
                // Prepend older messages for pagination
                let older = cdMessages.map { mapToDisplayMessage($0) }
                messages = older + messages
            }
            totalMessageCount = countTotalMessages()
        } catch {
            print("CoachViewModel: Failed to load messages: \(error)")
        }
    }

    /// Load older messages when user scrolls to top (D-19 pagination)
    func loadOlderMessages() {
        loadMessages(limit: 50, offset: messages.count)
    }

    private func countTotalMessages() -> Int {
        let request = NSFetchRequest<CDChatMessage>(entityName: "CDChatMessage")
        if let userId = getCurrentUserId() {
            request.predicate = NSPredicate(format: "userId == %@", userId)
        }
        return (try? viewContext.count(for: request)) ?? 0
    }

    private func mapToDisplayMessage(_ cd: CDChatMessage) -> ChatMessage {
        ChatMessage(
            id: cd.id ?? UUID(),
            role: cd.role == "coach" ? .coach : .user,
            content: cd.content ?? "",
            createdAt: cd.createdAt ?? Date(),
            planModificationJSON: cd.planModificationJSON,
            planModificationState: cd.planModificationState.flatMap {
                ChatMessage.PlanModificationState(rawValue: $0)
            }
        )
    }

    // MARK: - Send Message (D-01, D-02, D-03, D-04)

    func sendMessage(_ text: String, appState: AppState) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canSend else { return }

        // 1. Save user message to CoreData immediately (write-ahead per D-20)
        let userMsgId = UUID()
        let userCDMsg = saveMessageToCoreData(
            id: userMsgId, role: "user", content: trimmed
        )

        // 2. Add to display messages
        let userDisplayMsg = ChatMessage(
            id: userMsgId, role: .user, content: trimmed, createdAt: Date()
        )
        messages.append(userDisplayMsg)

        // 3. Start streaming
        currentStreamTask?.cancel()
        chatState = .streaming
        streamingText = ""
        pendingEnvelope = nil

        currentStreamTask = Task {
            defer {
                if !Task.isCancelled {
                    chatState = .idle
                    streamingText = ""
                }
            }

            do {
                let payload = buildPayload(message: trimmed, appState: appState)
                var accumulatedText = ""

                for try await event in sseClient.streamChat(payload: payload) {
                    if Task.isCancelled { return }

                    switch event {
                    case .token(let chunk):
                        accumulatedText += chunk
                        streamingText = accumulatedText

                    case .action(let envelope):
                        pendingEnvelope = envelope

                    case .completed:
                        await handleStreamCompleted(
                            accumulatedText: accumulatedText,
                            userCDMsg: userCDMsg
                        )
                    }
                }
            } catch {
                if Task.isCancelled { return }
                // D-33: inline error bubble — tap to retry
                chatState = .error("Something went wrong. Tap to retry.")
                lastFailedMessage = trimmed
                lastFailedAppState = appState
            }
        }
    }

    /// Retry last failed message (D-33 tap-to-retry)
    func retry() {
        guard let msg = lastFailedMessage, let state = lastFailedAppState else { return }
        chatState = .idle
        lastFailedMessage = nil

        // Remove the last user message (already saved to CoreData) before re-sending
        if let lastUserMsg = messages.last(where: { $0.role == .user }) {
            messages.removeAll { $0.id == lastUserMsg.id }
            deleteMessageFromCoreData(id: lastUserMsg.id)
        }

        sendMessage(msg, appState: state)
    }

    // MARK: - Stream Completion

    private func handleStreamCompleted(
        accumulatedText: String,
        userCDMsg: CDChatMessage?
    ) async {
        // Clean the accumulated text — strip [MODIFICATION] tag if present
        var displayText = accumulatedText
        if let regex = try? NSRegularExpression(pattern: "\\[MODIFICATION\\]\\{.*\\}\\s*$"),
           let match = regex.firstMatch(
               in: displayText,
               range: NSRange(displayText.startIndex..., in: displayText)
           ),
           let matchRange = Range(match.range, in: displayText) {
            displayText = String(displayText[displayText.startIndex..<matchRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let isModification = pendingEnvelope?.action == "modify_plan"

        // Save coach message to CoreData
        let coachMsgId = UUID()
        let coachCDMsg = saveMessageToCoreData(
            id: coachMsgId,
            role: "coach",
            content: displayText,
            planModificationJSON: isModification ? pendingEnvelope?.planDelta : nil,
            planModificationState: isModification ? "pending" : nil
        )

        // Add to display messages
        let coachDisplayMsg = ChatMessage(
            id: coachMsgId,
            role: .coach,
            content: displayText,
            createdAt: Date(),
            planModificationJSON: isModification ? pendingEnvelope?.planDelta : nil,
            planModificationState: isModification ? .pending : nil
        )
        messages.append(coachDisplayMsg)
        totalMessageCount += 2  // user + coach

        // Sync both messages to Supabase (D-20)
        if let userMsg = userCDMsg {
            await syncMessagesToSupabase(userMsg: userMsg, coachMsg: coachCDMsg)
        }
    }

    // MARK: - Plan Modification (D-08, D-09, D-10, D-11, D-12)

    /// User taps [Confirm] on plan modification card (D-09)
    func confirmModification(messageId: UUID, appState: AppState) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              messages[index].planModificationState == .pending,
              let modJSON = messages[index].planModificationJSON else { return }

        // Update local state immediately
        messages[index].planModificationState = .confirmed
        updateModificationState(messageId: messageId, state: "confirmed")

        // Execute the plan modification via Edge Function (D-09, D-14)
        Task {
            do {
                let payload = buildModifyPayload(modificationJSON: modJSON, appState: appState)
                let session = try await supabase.auth.session
                let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
                let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""

                guard let url = URL(string: "\(supabaseURL)/functions/v1/coach-chat") else { return }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.httpBody = try JSONEncoder().encode(payload)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    // Revert to pending on HTTP error
                    if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                        messages[idx].planModificationState = .pending
                    }
                    updateModificationState(messageId: messageId, state: "pending")
                    return
                }

                let envelope = try JSONDecoder().decode(CoachResponseEnvelope.self, from: data)
                if let planJSON = envelope.planDelta {
                    await applyPlanUpdate(planJSON: planJSON, appState: appState)
                }
            } catch {
                // Revert to pending on any error
                if let idx = messages.firstIndex(where: { $0.id == messageId }) {
                    messages[idx].planModificationState = .pending
                }
                updateModificationState(messageId: messageId, state: "pending")
                print("CoachViewModel: confirmModification failed: \(error)")
            }
        }
    }

    /// User taps [Dismiss] on plan modification card (D-10)
    func dismissModification(messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }),
              messages[index].planModificationState == .pending else { return }

        messages[index].planModificationState = .dismissed
        updateModificationState(messageId: messageId, state: "dismissed")
    }

    /// Apply updated plan JSON to CoreData and mark the active plan updated (D-09)
    private func applyPlanUpdate(planJSON: String, appState: AppState) async {
        guard let jsonData = planJSON.data(using: .utf8) else { return }

        do {
            let updatedPlan = try JSONDecoder().decode(WorkoutPlan.self, from: jsonData)
            let userId = try await supabase.auth.session.user.id.uuidString

            let repo = WorkoutPlanRepository(context: viewContext)
            // Deactivate existing plans before saving new one (single-active-plan invariant)
            try repo.deactivateAllPlans(userId: userId)
            // Save with a placeholder supabaseId since this is an AI-modified plan
            // The plan will be synced to Supabase by the existing sync infrastructure
            try repo.save(plan: updatedPlan, supabaseId: UUID().uuidString, userId: userId)
        } catch {
            print("CoachViewModel: Failed to apply plan update: \(error)")
        }
    }

    // MARK: - CoreData Operations

    @discardableResult
    private func saveMessageToCoreData(
        id: UUID,
        role: String,
        content: String,
        planModificationJSON: String? = nil,
        planModificationState: String? = nil
    ) -> CDChatMessage? {
        let cdMsg = CDChatMessage(context: viewContext)
        cdMsg.id = id
        cdMsg.userId = getCurrentUserId() ?? ""
        cdMsg.role = role
        cdMsg.content = content
        cdMsg.createdAt = Date()
        cdMsg.syncedToSupabase = false
        cdMsg.planModificationJSON = planModificationJSON
        cdMsg.planModificationState = planModificationState

        do {
            try viewContext.save()
            return cdMsg
        } catch {
            print("CoachViewModel: CoreData save failed: \(error)")
            return nil
        }
    }

    private func updateModificationState(messageId: UUID, state: String) {
        let request = NSFetchRequest<CDChatMessage>(entityName: "CDChatMessage")
        request.predicate = NSPredicate(format: "id == %@", messageId as CVarArg)

        if let msg = try? viewContext.fetch(request).first {
            msg.planModificationState = state
            try? viewContext.save()
        }
    }

    private func deleteMessageFromCoreData(id: UUID) {
        let request = NSFetchRequest<CDChatMessage>(entityName: "CDChatMessage")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let msg = try? viewContext.fetch(request).first {
            viewContext.delete(msg)
            try? viewContext.save()
        }
    }

    private func getCurrentUserId() -> String? {
        // Uses cachedUserId set in onAppear from AppState.currentUser
        // Avoids async supabase.auth.session in sync CoreData predicate contexts
        return cachedUserId
    }

    // MARK: - Supabase Sync (D-20)
    //
    // isSyncing guard prevents concurrent upserts (T-05-11 mitigation).
    // Only syncs after stream completes — never during streaming.

    private func syncMessagesToSupabase(userMsg: CDChatMessage, coachMsg: CDChatMessage?) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // snake_case properties match Supabase column names — same convention as SessionLogRow
        struct MessageRow: Encodable {
            let id: String
            let user_id: String
            let role: String
            let content: String
            let created_at: String
            let plan_modification_json: String?
            let plan_modification_state: String?
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var rows: [MessageRow] = []

        rows.append(MessageRow(
            id: (userMsg.id ?? UUID()).uuidString,
            user_id: userMsg.userId ?? "",
            role: userMsg.role ?? "user",
            content: userMsg.content ?? "",
            created_at: formatter.string(from: userMsg.createdAt ?? Date()),
            plan_modification_json: nil,
            plan_modification_state: nil
        ))

        if let coach = coachMsg {
            rows.append(MessageRow(
                id: (coach.id ?? UUID()).uuidString,
                user_id: coach.userId ?? "",
                role: coach.role ?? "coach",
                content: coach.content ?? "",
                created_at: formatter.string(from: coach.createdAt ?? Date()),
                plan_modification_json: coach.planModificationJSON,
                plan_modification_state: coach.planModificationState
            ))
        }

        do {
            try await supabase
                .from("coach_messages")
                .upsert(rows, onConflict: "id")
                .execute()

            // Mark as synced in CoreData
            userMsg.syncedToSupabase = true
            coachMsg?.syncedToSupabase = true
            try? viewContext.save()
        } catch {
            // Sync failure is non-fatal — messages are already in CoreData
            // Will retry on next send or app foreground
            print("CoachViewModel: Supabase sync failed: \(error)")
        }
    }

    // MARK: - Payload Assembly (D-28, D-29, D-30)
    //
    // CRITICAL (CHAT-03): The profile fields MUST be populated from cachedUserProfile
    // (fetched from Supabase profiles table in fetchUserProfile). Empty strings cause
    // the coach to have no context about the user's fitness goals and equipment.

    private func buildPayload(message: String, appState: AppState) -> ChatPayload {
        // Cap message history at 20 entries (T-05-10 message history cap)
        let historyMessages = messages.suffix(20).map { msg in
            ChatPayload.HistoryMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.content
            )
        }

        // Build profile from cached UserProfile — fetched from Supabase profiles table
        // If cachedUserProfile is nil (fetch failed), fall back to empty strings
        let profile = ChatPayload.ChatProfile(
            goal: cachedUserProfile?.goal ?? "",
            fitnessLevel: cachedUserProfile?.fitnessLevel ?? "",
            equipment: cachedUserProfile?.equipment ?? [],
            injuries: cachedUserProfile?.injuries ?? "",
            name: cachedDisplayName
        )

        // Build session summaries from last 3 CDSessionLog records (D-29, D-30)
        let summaries = fetchLastSessionSummaries(limit: 3)

        // Current plan from CDWorkoutPlan.rawJSON
        let planData = fetchActivePlanJSON()

        return ChatPayload(
            message: message,
            messageHistory: historyMessages,
            profile: profile,
            currentPlan: AnyCodable(planData as Any),
            sessionSummaries: summaries,
            messageCount: totalMessageCount,
            action: nil,
            pendingModification: nil
        )
    }

    private func buildModifyPayload(modificationJSON: String, appState: AppState) -> ChatPayload {
        let profile = ChatPayload.ChatProfile(
            goal: cachedUserProfile?.goal ?? "",
            fitnessLevel: cachedUserProfile?.fitnessLevel ?? "",
            equipment: cachedUserProfile?.equipment ?? [],
            injuries: cachedUserProfile?.injuries ?? "",
            name: cachedDisplayName
        )
        let planData = fetchActivePlanJSON()

        return ChatPayload(
            message: "",
            messageHistory: [],
            profile: profile,
            currentPlan: AnyCodable(planData as Any),
            sessionSummaries: [],
            messageCount: 0,
            action: "execute_modify",
            pendingModification: AnyCodable(modificationJSON)
        )
    }

    // MARK: - Data Fetch Helpers

    /// Fetch last N session summaries from CoreData for the chat payload (D-29, D-30)
    private func fetchLastSessionSummaries(limit: Int) -> [ChatPayload.SessionSummary] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSessionLog")
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        request.fetchLimit = limit

        guard let sessions = try? viewContext.fetch(request) else { return [] }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return sessions.compactMap { session in
            guard let completedAt = session.value(forKey: "completedAt") as? Date,
                  let workoutName = session.value(forKey: "workoutDayLabel") as? String else {
                return nil
            }

            // Count set logs for this session
            let setRequest = NSFetchRequest<NSManagedObject>(entityName: "CDSetLog")
            if let sessionId = session.value(forKey: "id") as? UUID {
                setRequest.predicate = NSPredicate(format: "sessionId == %@", sessionId as CVarArg)
            }
            let sets = (try? viewContext.fetch(setRequest)) ?? []
            let uniqueExercises = Set(sets.compactMap { $0.value(forKey: "exerciseName") as? String })

            return ChatPayload.SessionSummary(
                date: formatter.string(from: completedAt),
                workoutName: workoutName,
                exercisesCompleted: uniqueExercises.count,
                setsLogged: sets.count
            )
        }
    }

    /// Fetch active plan JSON blob from CoreData for payload context
    private func fetchActivePlanJSON() -> Data? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDWorkoutPlan")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1

        guard let plan = try? viewContext.fetch(request).first,
              let rawJSON = plan.value(forKey: "rawJSON") as? Data else {
            return nil
        }
        return rawJSON
    }

    // MARK: - Testing Helpers

    /// For unit tests only — set internal state directly for state machine testing
    func setChatStateForTesting(_ state: ChatState) {
        chatState = state
    }

    /// For unit tests only — set isOnline state directly
    func setIsOnlineForTesting(_ value: Bool) {
        isOnline = value
    }

    /// For unit tests only — set cached profile directly
    func setCachedProfileForTesting(_ profile: UserProfile, displayName: String? = nil) {
        cachedUserProfile = profile
        cachedDisplayName = displayName
    }

    /// For unit tests only — access buildPayload for payload assembly testing
    func buildPayloadForTesting(message: String, appState: AppState) -> ChatPayload {
        buildPayload(message: message, appState: appState)
    }
}
