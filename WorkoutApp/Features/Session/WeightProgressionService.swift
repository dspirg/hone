import Foundation
import Supabase

// MARK: - WeightProgressionService
// Auto-adjusts exercise weights after a session based on the user's difficulty rating.
//
// Rules:
//   - "too_easy" + all sets hit target reps lower bound: increase weight
//   - "too_hard": decrease weight
//   - "just_right": no change
//   - Bodyweight exercises are skipped
//   - Upper body: +/- 5 lbs or +/- 2.5 kg
//   - Lower body (Legs, Glutes): +/- 10 lbs or +/- 5 kg
//
// Uses the Supabase `exercise_weights` table to read current weight and upsert new weight.

@MainActor
enum WeightProgressionService {

    // MARK: - Adjust Weights (Post-Session)

    /// Adjusts stored weights for all exercises based on difficulty rating.
    /// Called after the user submits their difficulty rating on the summary screen.
    static func adjustWeights(
        rating: DifficultyRating,
        exercises: [PlannedExercise],
        completedSets: [Int: [Int: Int]],
        weightUnit: String,
        userId: String
    ) async {
        guard rating != .justRight else { return }

        for (index, exercise) in exercises.enumerated() {
            // Look up equipment tag to skip bodyweight exercises
            let repo = ExerciseRepository.shared
            let entity = try? repo.fetchByName(exercise.exerciseName) ?? repo.fetchByNameContains(exercise.exerciseName)
            let equipmentTag = entity?.value(forKey: "equipmentTag") as? String ?? "Bodyweight"
            guard equipmentTag != "Bodyweight" else { continue }

            // Determine muscle group for increment size
            let primaryMuscle = (entity?.value(forKey: "primaryMuscle") as? String ?? "").lowercased()
            let isLowerBody = primaryMuscle.contains("leg") || primaryMuscle.contains("glute")
                || primaryMuscle.contains("quad") || primaryMuscle.contains("hamstring")
                || primaryMuscle.contains("calf") || primaryMuscle.contains("calves")

            let increment: Double
            if weightUnit == "kg" {
                increment = isLowerBody ? 5.0 : 2.5
            } else {
                increment = isLowerBody ? 10.0 : 5.0
            }

            // Fetch current weight from Supabase
            guard let currentWeight = await fetchCurrentWeight(
                exerciseName: exercise.exerciseName,
                userId: userId
            ), currentWeight > 0 else { continue }

            var newWeight = currentWeight

            switch rating {
            case .tooEasy:
                // Only increase if all sets hit target reps lower bound
                let setsCompleted = completedSets[index] ?? [:]
                let targetLower = Int(
                    exercise.reps
                        .split(separator: "-")
                        .first
                        .flatMap { Int(String($0)) }
                        ?? Int(exercise.reps)
                        ?? 0
                ) ?? 0
                let allHitTarget = setsCompleted.count == exercise.sets
                    && setsCompleted.values.allSatisfy { $0 >= targetLower }
                if allHitTarget {
                    newWeight = currentWeight + increment
                }
            case .tooHard:
                newWeight = max(0, currentWeight - increment)
            case .justRight:
                break
            }

            if newWeight != currentWeight {
                await upsertWeight(
                    exerciseName: exercise.exerciseName,
                    weight: newWeight,
                    weightUnit: weightUnit,
                    userId: userId
                )
            }
        }
    }

    // MARK: - Supabase Operations

    /// Fetches the current stored weight for an exercise from the exercise_weights table.
    private static func fetchCurrentWeight(exerciseName: String, userId: String) async -> Double? {
        struct WeightRow: Decodable {
            let weight: Double
        }
        do {
            let rows: [WeightRow] = try await supabase
                .from("exercise_weights")
                .select("weight")
                .eq("user_id", value: userId)
                .ilike("exercise_name", pattern: exerciseName)
                .limit(1)
                .execute()
                .value
            return rows.first?.weight
        } catch {
            return nil
        }
    }

    /// Upserts the weight for an exercise in the exercise_weights table.
    /// Called both during set completion (to save last-used weight) and after
    /// difficulty rating (to apply auto-progression).
    static func upsertWeight(
        exerciseName: String,
        weight: Double,
        weightUnit: String,
        userId: String
    ) async {
        struct WeightUpsert: Encodable {
            let userId: String
            let exerciseName: String
            let weight: Double
            let weightUnit: String
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case exerciseName = "exercise_name"
                case weight
                case weightUnit = "weight_unit"
                case updatedAt = "updated_at"
            }
        }

        let formatter = ISO8601DateFormatter()
        let payload = WeightUpsert(
            userId: userId,
            exerciseName: exerciseName,
            weight: weight,
            weightUnit: weightUnit,
            updatedAt: formatter.string(from: Date())
        )

        do {
            try await supabase
                .from("exercise_weights")
                .upsert(payload, onConflict: "user_id,exercise_name")
                .execute()
        } catch {
            // Non-fatal — weight will be saved on next successful upsert
            print("WeightProgressionService: upsertWeight failed: \(error)")
        }
    }
}
