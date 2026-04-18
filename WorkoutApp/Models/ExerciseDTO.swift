import Foundation

// MARK: - ExerciseDTO
// Decodable DTO for Supabase exercises table response.
// CodingKeys map Swift camelCase to PostgreSQL snake_case column names.
// Requirements: EXRC-01, EXRC-02
//
// muxPlaybackId is nullable — NULL means video not yet licensed (placeholder state).
// updatedAt drives stale-while-revalidate cache invalidation in ExerciseRepository.

struct ExerciseDTO: Decodable {
    let id: UUID
    let name: String
    let primaryMuscle: String
    let equipmentTag: String
    let difficulty: String
    let howToSteps: [String]
    let formTips: String?
    let muxPlaybackId: String?
    let thumbnailUrl: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, difficulty
        case primaryMuscle  = "primary_muscle"
        case equipmentTag   = "equipment_tag"
        case howToSteps     = "how_to_steps"
        case formTips       = "form_tips"
        case muxPlaybackId  = "mux_playback_id"
        case thumbnailUrl   = "thumbnail_url"
        case updatedAt      = "updated_at"
    }
}
