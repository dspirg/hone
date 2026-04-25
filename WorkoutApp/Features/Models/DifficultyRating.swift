import Foundation

/// Difficulty rating captured after each session (D-01, D-02).
/// Raw values match Supabase CHECK constraint and Edge Function expectations exactly.
enum DifficultyRating: String, CaseIterable, Codable {
    case tooEasy   = "too_easy"
    case justRight = "just_right"
    case tooHard   = "too_hard"

    var emoji: String {
        switch self {
        case .tooEasy:   return "😴"
        case .justRight: return "💪"
        case .tooHard:   return "😤"
        }
    }

    var label: String {
        switch self {
        case .tooEasy:   return "Too Easy"
        case .justRight: return "Just Right"
        case .tooHard:   return "Too Hard"
        }
    }
}
