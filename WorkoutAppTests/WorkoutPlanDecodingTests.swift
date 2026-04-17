import XCTest
import CoreData
@testable import WorkoutApp

// MARK: - WorkoutPlanDecodingTests
// Covers AIPL-01: WorkoutPlan struct decodes valid OpenAI Structured Output JSON
// Covers AIPL-02: Every exercise has a non-empty rationale string

final class WorkoutPlanDecodingTests: XCTestCase {

    // Fixture JSON matching the OpenAI Structured Outputs schema from generate-plan/index.ts.
    // snake_case keys match the CodingKeys mapping in WorkoutPlan.swift.
    private let fixtureJSON = """
    {
      "plan_name": "4-Day Muscle Builder",
      "goal_summary": "A progressive overload program targeting all major muscle groups with dumbbells and barbell",
      "weekly_days": [
        {
          "day_label": "Day 1 - Monday",
          "session_name": "Upper Body Push",
          "exercises": [
            {
              "exercise_name": "Bench Press",
              "sets": 4,
              "reps": "8-10",
              "rest_seconds": 90,
              "rationale": "Primary chest compound for muscle building with barbell"
            },
            {
              "exercise_name": "Overhead Press",
              "sets": 3,
              "reps": "8-12",
              "rest_seconds": 60,
              "rationale": "Builds anterior deltoids to support your muscle-building goal"
            }
          ]
        },
        {
          "day_label": "Day 2 - Wednesday",
          "session_name": "Lower Body",
          "exercises": [
            {
              "exercise_name": "Squat",
              "sets": 4,
              "reps": "6-8",
              "rest_seconds": 120,
              "rationale": "Foundational lower body compound for strength and hypertrophy"
            }
          ]
        }
      ]
    }
    """

    // MARK: - AIPL-01: Decode plan from fixture JSON

    func testDecodePlanFromJSON() throws {
        let data = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        XCTAssertEqual(plan.planName, "4-Day Muscle Builder")
        XCTAssertEqual(plan.weeklyDays.count, 2)
        XCTAssertEqual(plan.weeklyDays[0].sessionName, "Upper Body Push")
        XCTAssertEqual(plan.weeklyDays[0].exercises[0].sets, 4)
    }

    // MARK: - AIPL-02: Every exercise has a non-empty rationale

    func testEveryExerciseHasRationale() throws {
        let data = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        for day in plan.weeklyDays {
            for exercise in day.exercises {
                XCTAssertFalse(
                    exercise.rationale.isEmpty,
                    "Exercise '\(exercise.exerciseName)' has an empty rationale"
                )
            }
        }
    }

    // MARK: - Round-trip encode/decode

    func testRoundTripEncodeDecode() throws {
        let data = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let original = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorkoutPlan.self, from: encoded)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - CoreData save and fetch (in-memory store)

    @MainActor
    func testCoreDataSaveAndFetch() throws {
        let controller = PersistenceController(inMemory: true)
        let repository = WorkoutPlanRepository(context: controller.container.viewContext)

        let data = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        let testUserId = "test-user-123"
        let testSupabaseId = "supabase-plan-456"

        try repository.save(plan: plan, supabaseId: testSupabaseId, userId: testUserId)

        let fetched = try repository.fetchActivePlan(userId: testUserId)
        let fetchedPlan = try XCTUnwrap(fetched, "Expected to fetch a plan but got nil")

        XCTAssertEqual(fetchedPlan.planName, plan.planName)
        XCTAssertEqual(fetchedPlan.weeklyDays.count, plan.weeklyDays.count)
    }
}
