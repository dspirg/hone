import XCTest
@testable import WorkoutApp

// MARK: - WorkoutPlanParserTests
// Tests JSON decoding from accumulated SSE stream data.
//
// These tests validate two critical behaviors:
// 1. Complete JSON (received after [DONE] SSE event) decodes successfully into WorkoutPlan
// 2. Partial JSON (chunks during streaming) CANNOT be decoded — proving Pitfall 3 enforcement
//
// The fixture JSON matches the OpenAI Structured Outputs schema from generate-plan/index.ts.

final class WorkoutPlanParserTests: XCTestCase {

    // Fixture JSON matching the OpenAI Structured Outputs schema (snake_case keys).
    // Same plan as WorkoutPlanDecodingTests for cross-test consistency.
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

    // MARK: - Test 1: Complete JSON decodes to WorkoutPlan

    func testDecodeCompletedJSON() throws {
        let data = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)

        XCTAssertEqual(plan.planName, "4-Day Muscle Builder")
        XCTAssertEqual(plan.weeklyDays.count, 2)
        // Verify first exercise rationale is non-empty (AIPL-02)
        let firstExercise = try XCTUnwrap(plan.weeklyDays.first?.exercises.first)
        XCTAssertFalse(firstExercise.rationale.isEmpty, "First exercise rationale must be non-empty")
    }

    // MARK: - Test 2: Accumulated chunks form valid JSON when concatenated

    func testAccumulatedTokensFormValidJSON() throws {
        // Simulate SSE streaming: split JSON into 5 arbitrary chunks
        let chars = Array(fixtureJSON)
        let chunkSize = chars.count / 5
        var chunks: [String] = []
        for i in 0..<4 {
            let slice = chars[(i * chunkSize)..<((i + 1) * chunkSize)]
            chunks.append(String(slice))
        }
        // Last chunk gets the remainder
        chunks.append(String(chars[(4 * chunkSize)...]))

        // Concatenate all chunks (simulates accumulatedJSON after [DONE])
        let concatenated = chunks.joined()
        let concatenatedData = try XCTUnwrap(concatenated.data(using: .utf8))
        let decodedFromChunks = try JSONDecoder().decode(WorkoutPlan.self, from: concatenatedData)

        // Decode from original fixture for equality comparison
        let originalData = try XCTUnwrap(fixtureJSON.data(using: .utf8))
        let original = try JSONDecoder().decode(WorkoutPlan.self, from: originalData)

        XCTAssertEqual(decodedFromChunks, original,
            "Plan decoded from concatenated chunks must equal plan decoded from original JSON")
    }

    // MARK: - Test 3: Empty string throws decoding error

    func testEmptyStringThrowsDecodingError() {
        let emptyString = ""
        // Empty string cannot be converted to valid Data for JSON decoding
        if let data = emptyString.data(using: .utf8) {
            XCTAssertThrowsError(
                try JSONDecoder().decode(WorkoutPlan.self, from: data),
                "Decoding empty string as WorkoutPlan must throw"
            )
        } else {
            // data(using: .utf8) on empty string returns empty Data, which also fails decode
            XCTAssertThrowsError(
                try JSONDecoder().decode(WorkoutPlan.self, from: Data()),
                "Decoding empty Data as WorkoutPlan must throw"
            )
        }
    }

    // MARK: - Test 4: Malformed JSON throws DecodingError

    func testMalformedJSONThrowsDecodingError() {
        let malformedJSON = "{ invalid json"
        guard let data = malformedJSON.data(using: .utf8) else {
            XCTFail("Could not encode malformed JSON string to Data")
            return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(WorkoutPlan.self, from: data),
            "Decoding malformed JSON as WorkoutPlan must throw DecodingError"
        )
    }

    // MARK: - Test 5: Partial JSON throws (Pitfall 3 validation)
    // This test proves that partial streaming JSON cannot be parsed into WorkoutPlan.
    // The SSE client only yields .completed after [DONE] -- never during streaming.

    func testPartialJSONThrowsDecodingError() {
        // Take the first 50 characters of the fixture JSON -- clearly incomplete
        let partialJSON = String(fixtureJSON.prefix(50))
        guard let data = partialJSON.data(using: .utf8) else {
            XCTFail("Could not encode partial JSON string to Data")
            return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(WorkoutPlan.self, from: data),
            "Decoding partial streaming JSON must throw -- partial JSON cannot be parsed (Pitfall 3)"
        )
    }
}
