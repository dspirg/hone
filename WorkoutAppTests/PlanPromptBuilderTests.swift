import XCTest
@testable import WorkoutApp

// MARK: - PlanPromptBuilderTests
// Covers AIPL-04: Equipment array from user profile appears in the AI system prompt text
// Covers SAFE-02: Safety guardrail instructs model not to provide medical advice

final class PlanPromptBuilderTests: XCTestCase {

    // Helper to create a test profile
    private func makeProfile(
        goal: String = "Build Muscle",
        fitnessLevel: String = "Intermediate",
        daysPerWeek: Int = 4,
        equipment: [String] = ["Dumbbells", "Barbell"],
        injuries: String = ""
    ) -> UserProfile {
        UserProfile(
            goal: goal,
            fitnessLevel: fitnessLevel,
            daysPerWeek: daysPerWeek,
            equipment: equipment,
            injuries: injuries
        )
    }

    // MARK: - AIPL-04: Equipment appears in prompt

    func testPromptContainsEquipment() {
        let profile = makeProfile(equipment: ["Dumbbells", "Barbell"])
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        XCTAssertTrue(prompt.contains("Dumbbells"), "Prompt should contain 'Dumbbells'")
        XCTAssertTrue(prompt.contains("Barbell"), "Prompt should contain 'Barbell'")
    }

    // MARK: - Goal appears in prompt

    func testPromptContainsGoal() {
        let profile = makeProfile(goal: "Build Muscle")
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        XCTAssertTrue(prompt.contains("Build Muscle"), "Prompt should contain the goal text")
    }

    // MARK: - Injuries section omitted when empty (D-12)

    func testPromptOmitsInjuriesWhenEmpty() {
        let profile = makeProfile(injuries: "")
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        XCTAssertFalse(
            prompt.contains("Areas to avoid"),
            "Prompt should not contain 'Areas to avoid' when injuries is empty"
        )
    }

    // MARK: - Injuries section included when present (D-12)

    func testPromptIncludesInjuriesWhenPresent() {
        let profile = makeProfile(injuries: "lower back")
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        XCTAssertTrue(
            prompt.contains("lower back"),
            "Prompt should contain the injuries text when present"
        )
    }

    // MARK: - Days per week appears in prompt

    func testPromptContainsDaysPerWeek() {
        let profile = makeProfile(daysPerWeek: 4)
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        XCTAssertTrue(prompt.contains("4"), "Prompt should contain the number of training days")
    }

    // MARK: - SAFE-02: Safety disclaimer present

    func testPromptContainsSafetyDisclaimer() {
        let profile = makeProfile()
        let prompt = PlanPromptBuilder.buildSystemPrompt(profile: profile)

        let hasMedicalDisclaimer = prompt.contains("not a medical professional") || prompt.contains("physician")
        XCTAssertTrue(
            hasMedicalDisclaimer,
            "Prompt should contain a safety disclaimer referencing 'not a medical professional' or 'physician'"
        )
    }
}
