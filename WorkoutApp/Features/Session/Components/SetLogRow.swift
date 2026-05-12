import SwiftUI
import UIKit

// MARK: - SetLogRow
// Per-set stepper row with checkmark completion for ExerciseCardView.
//
// Layout (left to right, 52pt minimum height per UI-SPEC):
//   - Completed indicator: 3pt AccentColor leading bar when isCompleted
//   - "Set N" label: subheadline, 48pt wide
//   - Stepper: minus.circle | rep count (tappable → NumberPadSheet) | plus.circle
//   - Target reps hint: subheadline, secondary
//   - Checkmark: checkmark.circle / checkmark.circle.fill (AccentColor when complete)
//
// Completed state: row becomes non-interactive; rep count turns secondary; leading accent bar added.
// T-04-09: NumberPadSheet validates 0–999 range before committing to binding.
//
// Requirements: SESS-01, SESS-02
// UI-SPEC: Phase 4 "SetLogRow — Individual Set Row"

struct SetLogRow: View {
    let setNumber: Int        // 1-indexed
    let targetReps: String    // e.g., "8-12" — displayed as hint
    let isCompleted: Bool
    var isActive: Bool = false
    @Binding var repsLogged: Int
    @Binding var weightLogged: Double
    let showWeight: Bool      // false for bodyweight exercises
    let weightUnit: String    // "lbs" or "kg"
    let onComplete: () -> Void

    @State private var showNumberPad = false
    @State private var showWeightPad = false

    var body: some View {
        HStack(spacing: 0) {
            if isCompleted {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
            }

            HStack(spacing: 10) {
                Text("\(setNumber)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(
                        isCompleted ? Theme.accent :
                        isActive ? Theme.accent.opacity(0.15) :
                        Theme.surfaceElevated
                    )
                    .foregroundStyle(
                        isCompleted ? .black :
                        isActive ? Theme.accent :
                        .primary
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(isActive && !isCompleted ? Theme.accent : .clear, lineWidth: 2)
                    )
                    .shadow(color: isCompleted ? Theme.accent.opacity(0.4) : .clear, radius: 6)

                if showWeight {
                    Button {
                        showWeightPad = true
                    } label: {
                        Text(weightLogged > 0 ? "\(Int(weightLogged)) \(weightUnit)" : "-- \(weightUnit)")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .accessibilityLabel(weightLogged > 0 ? "\(Int(weightLogged)) \(weightUnit), tap to edit" : "No weight, tap to enter")
                }

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    Button {
                        repsLogged = max(0, repsLogged - 1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 22))
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minWidth: 36, minHeight: 44)
                    .accessibilityLabel("Decrease reps")

                    Button {
                        showNumberPad = true
                    } label: {
                        Text("\(repsLogged)")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .frame(minWidth: 32)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(repsLogged) reps, tap to edit")

                    Button {
                        repsLogged = min(999, repsLogged + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minWidth: 36, minHeight: 44)
                    .accessibilityLabel("Increase reps")
                }

                Text(isCompleted ? "Done" : targetReps)
                    .font(.caption)
                    .foregroundStyle(isCompleted ? Theme.successGreen : .secondary)
                    .lineLimit(1)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isCompleted ? Theme.accent : isActive ? Theme.accent : .secondary)
                        .shadow(color: isCompleted ? Theme.accent.opacity(0.3) : .clear, radius: 8)
                }
                .disabled(isCompleted)
                .contentShape(Rectangle())
                .frame(width: 36, height: 44)
                .accessibilityLabel(isCompleted ? "Set \(setNumber) complete" : "Mark set \(setNumber) complete")
            }
            .padding(.horizontal, 12)
        }
        .frame(minHeight: 52)
        .background(
            isActive && !isCompleted
                ? Theme.accent.opacity(0.03)
                : Theme.surface
        )
        .overlay(
            RoundedRectangle(cornerRadius: isActive && !isCompleted ? 12 : 0)
                .stroke(isActive && !isCompleted ? Theme.accent.opacity(0.3) : .clear, lineWidth: 1)
        )
        .sheet(isPresented: $showNumberPad) {
            NumberPadSheet(reps: $repsLogged)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showWeightPad) {
            WeightPadSheet(weight: $weightLogged, unit: weightUnit)
                .presentationDetents([.height(300)])
        }
    }
}

// MARK: - Number Pad Sheet

/// Bottom sheet for direct rep count entry.
/// T-04-09: validates Int(input) is in 0...999 before writing to binding.
private struct NumberPadSheet: View {
    @Binding var reps: Int
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Reps", text: $input)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .navigationTitle("Enter Reps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // T-04-09: clamp to 0–999 before binding write
                        if let value = Int(input), value >= 0, value <= 999 {
                            reps = value
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear { input = "\(reps)" }
    }
}

// MARK: - Weight Pad Sheet

/// Bottom sheet for direct weight entry.
/// Validates 0–9999 range before writing to binding.
private struct WeightPadSheet: View {
    @Binding var weight: Double
    let unit: String
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Weight (\(unit))", text: $input)
                    .keyboardType(.decimalPad)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            }
            .navigationTitle("Enter Weight (\(unit))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let value = Double(input), value >= 0, value <= 9999 {
                            weight = value
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear { input = weight > 0 ? "\(Int(weight))" : "" }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        SetLogRow(
            setNumber: 1,
            targetReps: "8-12",
            isCompleted: false,
            repsLogged: .constant(10),
            weightLogged: .constant(135),
            showWeight: true,
            weightUnit: "lbs",
            onComplete: {}
        )
        Divider()
        SetLogRow(
            setNumber: 2,
            targetReps: "8-12",
            isCompleted: true,
            repsLogged: .constant(10),
            weightLogged: .constant(135),
            showWeight: true,
            weightUnit: "lbs",
            onComplete: {}
        )
    }
    .padding()
}
#endif
