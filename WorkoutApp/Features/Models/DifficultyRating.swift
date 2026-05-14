import SwiftUI

/// Difficulty rating captured after each session (D-01, D-02).
/// Raw values match Supabase CHECK constraint and Edge Function expectations exactly.
enum DifficultyRating: String, CaseIterable, Codable {
    case tooEasy   = "too_easy"
    case justRight = "just_right"
    case tooHard   = "too_hard"

    var iconName: String {
        switch self {
        case .tooEasy:   return "face.smiling"
        case .justRight: return "face.smiling"
        case .tooHard:   return "face.dashed"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .tooEasy:   return [Color(red: 0.65, green: 0.95, blue: 0.82), Color(red: 0.43, green: 0.91, blue: 0.74)]
        case .justRight: return [Color(red: 0.812, green: 0.769, blue: 0.992), Color(red: 0.655, green: 0.545, blue: 0.980)]
        case .tooHard:   return [Color(red: 0.99, green: 0.79, blue: 0.79), Color(red: 0.97, green: 0.44, blue: 0.44)]
        }
    }

    var strokeColor: Color {
        switch self {
        case .tooEasy:   return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .justRight: return Color(red: 0.29, green: 0.13, blue: 0.55)
        case .tooHard:   return Color(red: 0.50, green: 0.11, blue: 0.11)
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
