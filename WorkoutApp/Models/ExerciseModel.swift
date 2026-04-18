import CoreData
import Foundation

// MARK: - ExerciseModel
// Value type for the view layer — decoupled from CoreData NSManagedObject and Supabase DTO.
// Passed through NavigationLink from ExerciseLibraryView to ExerciseDetailView.
// Requirements: EXRC-01, EXRC-02, EXRC-03
//
// hasVideo: convenience computed property — drives VideoPlayerView vs ExercisePlaceholderView branch.
// localAssetURL: mutable — set after AVAssetDownloadTask completes (EXRC-04 offline caching).

struct ExerciseModel: Identifiable, Equatable {
    let id: UUID
    let name: String
    let primaryMuscle: String
    let equipmentTag: String
    let difficulty: String
    let howToSteps: [String]
    let formTips: String?
    let muxPlaybackId: String?
    let thumbnailURL: String?
    var localAssetURL: String?
    var lastViewedAt: Date?

    var hasVideo: Bool { muxPlaybackId != nil }

    // MARK: - Memberwise Init (for previews and tests)
    init(
        id: UUID = UUID(),
        name: String,
        primaryMuscle: String,
        equipmentTag: String,
        difficulty: String,
        howToSteps: [String] = [],
        formTips: String? = nil,
        muxPlaybackId: String? = nil,
        thumbnailURL: String? = nil,
        localAssetURL: String? = nil,
        lastViewedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.equipmentTag = equipmentTag
        self.difficulty = difficulty
        self.howToSteps = howToSteps
        self.formTips = formTips
        self.muxPlaybackId = muxPlaybackId
        self.thumbnailURL = thumbnailURL
        self.localAssetURL = localAssetURL
        self.lastViewedAt = lastViewedAt
    }

    // MARK: - Init from Supabase DTO
    init(from dto: ExerciseDTO) {
        self.id = dto.id
        self.name = dto.name
        self.primaryMuscle = dto.primaryMuscle
        self.equipmentTag = dto.equipmentTag
        self.difficulty = dto.difficulty
        self.howToSteps = dto.howToSteps
        self.formTips = dto.formTips
        self.muxPlaybackId = dto.muxPlaybackId
        self.thumbnailURL = dto.thumbnailUrl
        self.localAssetURL = nil
        self.lastViewedAt = nil
    }

    // MARK: - Init from CoreData Exercise entity
    // Used for offline loading via ExerciseRepository.loadFromCoreData()
    // howToSteps stored as NSArray Transformable — cast to [String] safely
    init(from entity: NSManagedObject) {
        self.id = (entity.value(forKey: "id") as? UUID) ?? {
            assertionFailure("Exercise entity missing id — data model may be corrupt")
            return UUID() // still needed for type safety; log to analytics in production
        }()
        self.name = entity.value(forKey: "name") as? String ?? ""
        self.primaryMuscle = entity.value(forKey: "primaryMuscle") as? String ?? ""
        self.equipmentTag = entity.value(forKey: "equipmentTag") as? String ?? ""
        self.difficulty = entity.value(forKey: "difficulty") as? String ?? ""
        self.howToSteps = (entity.value(forKey: "howToSteps") as? NSArray)?.compactMap { $0 as? String } ?? []
        self.formTips = entity.value(forKey: "formTips") as? String
        self.muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
        self.thumbnailURL = entity.value(forKey: "thumbnailURL") as? String
        self.localAssetURL = entity.value(forKey: "localAssetURL") as? String
        self.lastViewedAt = entity.value(forKey: "lastViewedAt") as? Date
    }
}
