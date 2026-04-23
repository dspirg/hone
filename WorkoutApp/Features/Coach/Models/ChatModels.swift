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
// Uses a recursive enum instead of Any to satisfy Swift 6 Sendable requirements.
enum AnyCodable: Encodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dict([String: AnyCodable])
    case array([AnyCodable])
    case null

    /// Create from raw JSON Data (e.g. CDWorkoutPlan.rawJSON)
    init(_ value: Data?) {
        guard let data = value,
              let json = try? JSONSerialization.jsonObject(with: data) else {
            self = .null
            return
        }
        self = Self.fromJSONObject(json)
    }

    /// Create from a String value
    init(_ value: String) {
        self = .string(value)
    }

    private static func fromJSONObject(_ obj: Any) -> AnyCodable {
        switch obj {
        case let string as String: return .string(string)
        case let int as Int: return .int(int)
        case let double as Double: return .double(double)
        case let bool as Bool: return .bool(bool)
        case let dict as [String: Any]:
            return .dict(dict.mapValues { fromJSONObject($0) })
        case let array as [Any]:
            return .array(array.map { fromJSONObject($0) })
        default: return .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .dict(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
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
