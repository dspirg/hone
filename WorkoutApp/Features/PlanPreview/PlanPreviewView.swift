import SwiftUI

// MARK: - PlanPreviewView
// The plan preview screen — the "aha moment" where users see their personalized
// weekly workout plan with AI rationale before being asked to subscribe (Phase 7).
//
// State routing:
//   .idle / .streaming (no plan yet) → PlanGenerationLoadingView
//   .error → PlanGenerationLoadingView with error overlay
//   .completed → plan content (header + scrollable day cards + sticky CTA)
//
// UI-SPEC: PlanPreviewView contract
// Requirements: ONBD-03 (plan preview), AIPL-02 (AI rationale), AIPL-03 (regeneration)
// Threat T-03-13: Regenerate button disabled during streaming (D-09)

struct PlanPreviewView: View {
    let viewModel: PlanPreviewViewModel
    var onStartTraining: (() -> Void)?

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if let plan = viewModel.plan {
                // Plan loaded — show plan content
                planContent(plan: plan)
            } else if let error = viewModel.errorMessage {
                // Error after second failure — show error overlay with retry
                PlanGenerationLoadingView(
                    errorMessage: error,
                    onRetry: { viewModel.retry() }
                )
            } else {
                // Loading (idle or streaming with no plan yet)
                PlanGenerationLoadingView(
                    errorMessage: nil,
                    onRetry: { }
                )
            }
        }
        .onAppear {
            // Auto-start generation if this is a fresh load (no plan, no error)
            if viewModel.plan == nil && viewModel.errorMessage == nil {
                viewModel.startGeneration()
            }
        }
    }

    // MARK: - Plan Content (shown after successful generation)

    private func planContent(plan: WorkoutPlan) -> some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Sticky header above the scrollable day cards
                planHeader(plan: plan)

                // Scrollable day cards
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(plan.weeklyDays) { day in
                            WorkoutDayCardView(day: day)
                        }
                    }
                    .padding(.top, 48)    // 2xl — vertical breathing room above first card
                    .padding(.bottom, 100) // clear the sticky CTA
                }
            }

            // Sticky "Start Training" CTA pinned to bottom
            startTrainingCTA
        }
    }

    // MARK: - Plan Header (sticky, not inside ScrollView)

    private func planHeader(plan: WorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Plan name — .title (28pt, semibold) per UI-SPEC
            Text(plan.planName)
                .font(.title.weight(.semibold))
                .padding(.top, 16)       // md below safe area
                .padding(.horizontal, 16)

            // Goal summary — .body regular, .secondary color, 3 line limit
            Text(plan.goalSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(.top, 8)        // sm
                .padding(.horizontal, 16)

            // Regeneration row: counter label + Regenerate button
            HStack {
                // Counter label — .subheadline regular, secondary/tertiary per D-09
                if viewModel.regenerationsRemaining > 0 {
                    Text("\(viewModel.regenerationsRemaining) regenerations remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Save regenerations for the app")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Regenerate plan button — Capsule, secondary style (T-03-13)
                Button(action: { viewModel.regenerate() }) {
                    HStack(spacing: 4) {
                        // Shows ProgressView spinner during active streaming (D-08)
                        if viewModel.isStreaming {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13))
                        }
                        Text("Regenerate plan")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 32)  // 32pt height per UI-SPEC
                    .foregroundStyle(viewModel.canRegenerate ? Color("AccentColor") : .tertiary)
                    .background(
                        viewModel.canRegenerate
                            ? Color("CardBackground")
                            : Color(.quaternaryLabel)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Group {
                            if viewModel.canRegenerate {
                                Capsule().stroke(Color("AccentColor"), lineWidth: 1)
                            }
                        }
                    )
                }
                .disabled(!viewModel.canRegenerate)
                .accessibilityLabel("Regenerate plan")
                .accessibilityValue("\(viewModel.regenerationsRemaining) regenerations remaining")
                .accessibilityHint(viewModel.canRegenerate ? "" : "Regeneration limit reached.")
            }
            .padding(.top, 8)        // sm
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)  // sm
            Divider()
        }
    }

    // MARK: - Sticky Start Training CTA

    private var startTrainingCTA: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 8)  // sm top padding

            // "Start Training" button — full width, 52pt height, 12pt corner radius (D-10)
            Button(action: { onStartTraining?() }) {
                Text("Start Training")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(viewModel.canStartTraining ? .white : .tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)  // 52pt per UI-SPEC
                    .background(
                        viewModel.canStartTraining
                            ? Color("AccentColor")
                            : Color(.quaternaryLabel)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))  // 12pt corner radius
            }
            .disabled(!viewModel.canStartTraining)
            .padding(.horizontal, 16)
            .accessibilityLabel("Start Training")
            .accessibilityHint(
                viewModel.canStartTraining
                    ? "Proceeds to subscription options."
                    : "Plan is still loading. Wait for the plan to finish before proceeding."
            )
        }
        .padding(.bottom, 8)  // sm above safe area bottom
        .background(Color("AppBackground"))  // opaque background so scroll content doesn't bleed through
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let service = PlanGenerationService()
    service.state = .completed(WorkoutPlan(
        planName: "Your 4-Day Strength Plan",
        goalSummary: "Built around compound lifts to maximize muscle gain with barbell and dumbbell equipment.",
        weeklyDays: [
            WorkoutDay(
                dayLabel: "Day 1",
                sessionName: "Upper Body Push",
                exercises: [
                    PlannedExercise(
                        exerciseName: "Bench Press",
                        sets: 4,
                        reps: "8-10",
                        restSeconds: 90,
                        rationale: "Primary chest compound; maximizes pectoral volume for your muscle-gain goal"
                    ),
                    PlannedExercise(
                        exerciseName: "Overhead Press",
                        sets: 3,
                        reps: "10-12",
                        restSeconds: 75,
                        rationale: "Builds anterior deltoid and tricep strength to support the bench press"
                    )
                ]
            ),
            WorkoutDay(
                dayLabel: "Day 2",
                sessionName: "Lower Body",
                exercises: [
                    PlannedExercise(
                        exerciseName: "Barbell Back Squat",
                        sets: 4,
                        reps: "6-8",
                        restSeconds: 120,
                        rationale: "King of lower body compounds; hits quads, glutes, and core simultaneously"
                    )
                ]
            )
        ]
    ))
    let profile = UserProfile(goal: "Build Muscle", fitnessLevel: "Intermediate", daysPerWeek: 4, equipment: ["Barbell"], injuries: "")
    let vm = PlanPreviewViewModel(service: service, profile: profile)
    return PlanPreviewView(viewModel: vm) { }
}
#endif
