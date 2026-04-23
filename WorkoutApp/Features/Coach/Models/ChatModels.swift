import Foundation

// MARK: - Chat Display Model
// In-memory model for UI display. Created from CDChatMessage records.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: ChatRole
    let content: String
    let createdAt: Date
    var planModificationJSON: String?
    var planModificationState: PlanModificationState?

    enum ChatRole: String, Sendable {
        case user
        case coach
    }

    enum PlanModificationState: String, Sendable {
        case pending
        case confirmed
        case dismissed
    }
}

// MARK: - Chat Payload (sent to Edge Function per D-28, D-29, D-30)
struct ChatPayload: Encodable, Sendable {
    let message: String
    let messageHistory: [HistoryMessage]
    let profile: ChatProfile
    let currentPlan: AnyCodable  // Full WorkoutPlan JSON
    let sessionSummaries: [SessionSummary]
    let messageCount: Int
    let action: String?  // "execute_modify" on [Confirm] tap (D-09)
    let pendingModification: AnyCodable?  // Proposed change to execute

    enum CodingKeys: String, CodingKey {
        case message
        case messageHistory = "message_history"
        case profile
        case currentPlan = "current_plan"
        case sessionSummaries = "session_summaries"
        case messageCount = "message_count"
        case action
        case pendingModification = "pending_modification"
    }

    struct HistoryMessage: Encodable, Sendable {
        let role: String  // "user" or "assistant"
        let content: String
    }

    struct ChatProfile: Encodable, Sendable {
        let goal: String
        let fitnessLevel: String
        let equipment: [String]
        let injuries: String
        let name: String?

        enum CodingKeys: String, CodingKey {
            case goal
            case fitnessLevel = "fitness_level"
            case equipment
            case injuries
            case name
        }
    }

    struct SessionSummary: Encodable, Sendable {
        let date: String
        let workoutName: String
        let exercisesCompleted: Int
        let setsLogged: Int

        enum CodingKeys: String, CodingKey {
            case date
            case workoutName = "workout_name"
            case exercisesCompleted = "exercises_completed"
            case setsLogged = "sets_logged"
        }
    }
}

// MARK: - AnyCodable helper for untyped JSON passthrough
// Used to pass CDWorkoutPlan.rawJSON Data blob through ChatPayload without decoding.
struct AnyCodable: Encodable, Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let data = value as? Data {
            // Pass raw JSON data through by deserializing then re-encoding
            if let json = try? JSONSerialization.jsonObject(with: data),
               let encodable = json as? [String: Any] {
                try container.encode(encodable.mapValues { AnyCodableValue($0) })
            } else {
                try container.encodeNil()
            }
        } else if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// Helper for encoding arbitrary JSON values (supports nested objects/arrays)
private struct AnyCodableValue: Encodable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodableValue($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyCodableValue($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Coach SSE Response Envelope (per RESEARCH Pattern 4)
// Decoded from [ACTION]{...} prefix in SSE data lines.
struct CoachResponseEnvelope: Decodable, Sendable {
    let action: String  // "chat" | "modify_plan" | "execute_modify"
    let planDelta: String?  // JSON string of the full modified plan (non-nil for execute_modify)

    enum CodingKeys: String, CodingKey {
        case action
        case planDelta = "plan_delta"
    }
}
