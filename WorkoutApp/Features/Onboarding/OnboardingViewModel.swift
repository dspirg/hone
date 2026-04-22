import SwiftUI
import Observation

// MARK: - OnboardingViewModel
// @Observable ViewModel (Swift 6 / iOS 17+ idiom — not @ObservableObject)
// Manages 5-step onboarding wizard: Goal, FitnessLevel, DaysPerWeek, Equipment, Injuries
// Steps: 0=Goal, 1=FitnessLevel, 2=DaysPerWeek, 3=Equipment, 4=Injuries
@Observable
@MainActor
final class OnboardingViewModel {

    // MARK: - Step State
    var currentStep: Int = 0
    var isGoingForward: Bool = true
    var showQuitConfirmation: Bool = false

    // MARK: - Answers
    var selectedGoal: String? = nil
    var selectedFitnessLevel: String? = nil
    var selectedDaysPerWeek: Int? = nil
    var selectedEquipment: Set<String> = []
    var injuriesText: String = ""

    // MARK: - Completion
    var isOnboardingComplete: Bool = false
    /// Wired by parent to bridge into plan generation flow
    var onComplete: ((UserProfile) -> Void)?

    // MARK: - Computed Properties

    var totalSteps: Int { 5 }

    /// Progress fraction 0.2 (step 0) through 1.0 (step 4) for the progress bar fill
    var progressFraction: Double { Double(currentStep + 1) / Double(totalSteps) }

    /// Enables the Continue button on card 4 (Equipment) — at least 1 selection required
    var canAdvanceEquipment: Bool { !selectedEquipment.isEmpty }

    /// "2 of 5" label for the progress pill
    var stepLabel: String { "\(currentStep + 1) of \(totalSteps)" }

    // MARK: - Single-Select Actions (auto-advance after 120ms visual delay per UI-SPEC)

    func selectGoal(_ goal: String) {
        selectedGoal = goal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.advance()
        }
    }

    func selectFitnessLevel(_ level: String) {
        selectedFitnessLevel = level
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.advance()
        }
    }

    func selectDaysPerWeek(_ days: Int) {
        selectedDaysPerWeek = days
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.advance()
        }
    }

    // MARK: - Equipment Multi-Select (mutual exclusivity per UI-SPEC EquipmentCardView contract)

    func toggleEquipment(_ item: String) {
        if item == "No equipment" {
            // "No equipment" is exclusive — clear all other selections
            selectedEquipment = ["No equipment"]
        } else {
            // Any gear chip deselects "No equipment" first
            selectedEquipment.remove("No equipment")
            if selectedEquipment.contains(item) {
                selectedEquipment.remove(item)
            } else {
                selectedEquipment.insert(item)
            }
        }
    }

    // MARK: - Navigation

    func advance() {
        guard currentStep < 4 else { return }
        isGoingForward = true
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            currentStep += 1
        }
    }

    func goBack() {
        guard currentStep > 0 else { return }
        isGoingForward = false
        withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
            currentStep -= 1
        }
    }

    // MARK: - Completion

    func completeOnboarding() {
        // WR-04: Idempotency guard — both the Skip button and Save & Continue button call
        // this method. If both fire rapidly (double-tap, keyboard dismiss timing), the
        // second call would invoke onComplete? a second time, triggering a duplicate
        // startGeneration() while PlanPreviewView is already presented.
        guard !isOnboardingComplete else { return }
        let profile = UserProfile(
            goal: selectedGoal ?? "",
            fitnessLevel: selectedFitnessLevel ?? "",
            daysPerWeek: selectedDaysPerWeek ?? 3,
            equipment: Array(selectedEquipment),
            injuries: injuriesText
        )
        isOnboardingComplete = true
        onComplete?(profile)
    }

    // MARK: - Quit Flow

    func requestQuitConfirmation() {
        showQuitConfirmation = true
    }
}
