import CoreData
import Foundation

// MARK: - ExerciseRepository
// Fetches exercises from Supabase, upserts to CoreData, and returns typed ExerciseModel array.
// Provides offline fallback via loadFromCoreData() for sessions without network.
//
// Singleton pattern — shared instance used directly (consistent with SupabaseClient global pattern).
// All CoreData access on @MainActor via viewContext (NSMainQueueConcurrencyType).
//
// Requirements: EXRC-01, EXRC-02 (data layer enabling browse and search)
// Threat: T-02-02 — no INSERT/UPDATE/DELETE Supabase policy; fetch is read-only; upsert is local-only.

@MainActor
final class ExerciseRepository {
    static let shared = ExerciseRepository()
    private let context = PersistenceController.shared.container.viewContext

    private init() {}

    // MARK: - Fetch from Supabase + Upsert to CoreData

    /// Fetches all exercises from Supabase ordered by name, upserts to CoreData, returns [ExerciseModel].
    /// On network failure, throws — caller should fall back to loadFromCoreData().
    func fetchAndSync() async throws -> [ExerciseModel] {
        // 1. Fetch from Supabase (public read — anon + authenticated via RLS policy)
        let dtos: [ExerciseDTO] = try await supabase
            .from("exercises")
            .select()
            .order("name")
            .execute()
            .value

        // 2. Upsert each DTO into CoreData Exercise entity
        for dto in dtos {
            upsert(dto: dto)
        }

        // 3. Save context if there are pending changes
        if context.hasChanges {
            try context.save()
        }

        // 4. Return [ExerciseModel] mapped from DTOs (source of truth is server response)
        return dtos.map { ExerciseModel(from: $0) }
    }

    // MARK: - Load from CoreData (Offline)

    /// Returns all Exercise entities from CoreData ordered by name.
    /// Used when offline — returns cached data from last successful sync.
    func loadFromCoreData() -> [ExerciseModel] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let entities = try context.fetch(request)
            return entities.map { ExerciseModel(from: $0) }
        } catch {
            return []
        }
    }

    // MARK: - Update Last Viewed

    /// Updates lastViewedAt on CoreData entity for LRU cache eviction tracking (EXRC-04).
    func updateLastViewed(exerciseId: UUID) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        request.fetchLimit = 1
        do {
            if let entity = try context.fetch(request).first {
                entity.setValue(Date(), forKey: "lastViewedAt")
                try context.save()
            }
        } catch {
            // Non-fatal: cache tracking failure doesn't break the user experience
        }
    }

    // MARK: - Fetch by Name

    /// Looks up a single Exercise CoreData entity by name (case-insensitive, diacritic-insensitive).
    /// Used by ExerciseCardView to resolve muxPlaybackId and localAssetURL from PlannedExercise.exerciseName.
    /// Returns nil if no matching exercise is found in the local CoreData cache.
    func fetchByName(_ name: String) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Private Helpers

    /// Upserts a DTO into the CoreData Exercise entity.
    /// Finds existing entity by UUID id; creates new if not found.
    private func upsert(dto: ExerciseDTO) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
        request.fetchLimit = 1

        let entity: NSManagedObject
        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = NSEntityDescription.insertNewObject(forEntityName: "Exercise", into: context)
        }

        entity.setValue(dto.id, forKey: "id")
        entity.setValue(dto.name, forKey: "name")
        entity.setValue(dto.primaryMuscle, forKey: "primaryMuscle")
        entity.setValue(dto.equipmentTag, forKey: "equipmentTag")
        entity.setValue(dto.difficulty, forKey: "difficulty")
        entity.setValue(dto.howToSteps as NSArray, forKey: "howToSteps")
        entity.setValue(dto.formTips, forKey: "formTips")
        entity.setValue(dto.muxPlaybackId, forKey: "muxPlaybackId")
        entity.setValue(dto.thumbnailUrl, forKey: "thumbnailURL")
        entity.setValue(dto.videoUrl, forKey: "videoUrl")
        entity.setValue(Date(), forKey: "syncedAt")
        // Preserve localAssetURL and lastViewedAt — do NOT overwrite with nil from server
    }
}
