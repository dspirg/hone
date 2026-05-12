import CoreData
import Foundation

// MARK: - WorkoutPlanRepository
// CRUD operations for CoreData workout plan persistence.
// Uses rawJSON as a defensive fallback: the full plan JSON is stored alongside
// the normalized entity graph, so the plan can be re-decoded if the entity
// graph is partially corrupted or migrated.
//
// Ordering: ordered relationships (NSOrderedSet) preserve the day and exercise
// sequence from the AI-generated plan.
//
// Thread safety: all methods run on @MainActor with the view context.
// For background imports, inject a private queue context via the init parameter.

@MainActor
final class WorkoutPlanRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    // MARK: - Save

    /// Saves a WorkoutPlan to CoreData. Populates the full entity graph (plan → days → exercises)
    /// and stores the rawJSON blob for defensive fallback decoding.
    func save(plan: WorkoutPlan, supabaseId: String, userId: String) throws {
        let cdPlan = CDWorkoutPlan(context: context)
        cdPlan.id = UUID()
        cdPlan.supabaseId = supabaseId
        cdPlan.userId = userId
        cdPlan.planName = plan.planName
        cdPlan.goalSummary = plan.goalSummary
        cdPlan.rawJSON = try JSONEncoder().encode(plan)
        cdPlan.createdAt = Date()
        cdPlan.isActive = true

        for (index, day) in plan.weeklyDays.enumerated() {
            let cdDay = CDWorkoutDay(context: context)
            cdDay.id = UUID()
            cdDay.dayLabel = day.dayLabel
            cdDay.sessionName = day.sessionName
            // WR-05: Clamp to Int16.max before casting. exercise.sets and sortOrder come from
            // AI-generated data — an unexpected model response could return a value that
            // silently truncates (wraps) on cast, producing corrupt CoreData records.
            cdDay.sortOrder = Int16(min(index, Int(Int16.max)))

            for (exIndex, exercise) in day.exercises.enumerated() {
                let cdExercise = CDPlannedExercise(context: context)
                cdExercise.id = UUID()
                cdExercise.exerciseName = exercise.exerciseName
                cdExercise.sets = Int16(min(exercise.sets, Int(Int16.max)))
                cdExercise.reps = exercise.reps
                cdExercise.restSeconds = Int32(exercise.restSeconds)
                cdExercise.rationale = exercise.rationale
                cdExercise.sortOrder = Int16(min(exIndex, Int(Int16.max)))
                cdDay.addToExercises(cdExercise)
            }
            cdPlan.addToDays(cdDay)
        }

        try context.save()
    }

    // MARK: - Fetch

    /// Fetches the most recently created active plan for the given userId.
    /// Returns nil if no active plan exists.
    /// Decodes from rawJSON (defensive fallback) rather than re-assembling the entity graph.
    func fetchActivePlan(userId: String) throws -> WorkoutPlan? {
        let request = CDWorkoutPlan.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        guard let cdPlan = try context.fetch(request).first,
              let rawJSON = cdPlan.rawJSON else { return nil }

        // Prefer decoding from rawJSON (defensive fallback avoids entity graph issues)
        return try JSONDecoder().decode(WorkoutPlan.self, from: rawJSON)
    }

    // MARK: - Deactivate

    /// Sets isActive = false on all active plans for the given userId.
    /// Call before saving a new plan to maintain a single active plan invariant.
    func deactivateAllPlans(userId: String) throws {
        let request = CDWorkoutPlan.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
        let plans = try context.fetch(request)
        for plan in plans {
            plan.isActive = false
        }
        if !plans.isEmpty {
            try context.save()
        }
    }

    // MARK: - Swap Exercise

    /// Replaces a single exercise in the active plan and persists the change.
    /// Rebuilds the immutable WorkoutPlan/WorkoutDay/PlannedExercise chain and re-encodes rawJSON.
    func swapExercise(userId: String, dayLabel: String, exerciseIndex: Int, replacement: PlannedExercise) throws {
        let request = CDWorkoutPlan.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND isActive == YES", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.fetchLimit = 1

        guard let cdPlan = try context.fetch(request).first,
              let rawJSON = cdPlan.rawJSON else { return }

        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: rawJSON)

        let updatedDays = plan.weeklyDays.map { day -> WorkoutDay in
            guard day.dayLabel == dayLabel else { return day }
            var updatedExercises = day.exercises
            guard exerciseIndex >= 0, exerciseIndex < updatedExercises.count else { return day }
            updatedExercises[exerciseIndex] = replacement
            return WorkoutDay(dayLabel: day.dayLabel, sessionName: day.sessionName, exercises: updatedExercises)
        }

        let updatedPlan = WorkoutPlan(planName: plan.planName, goalSummary: plan.goalSummary, weeklyDays: updatedDays)
        cdPlan.rawJSON = try JSONEncoder().encode(updatedPlan)
        try context.save()
    }
}
