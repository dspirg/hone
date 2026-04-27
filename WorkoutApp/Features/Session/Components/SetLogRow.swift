import SwiftUI

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
    @Binding var repsLogged: Int
    let onComplete: () -> Void

    @State private var showNumberPad = false

    var body: some View {
        HStack(spacing: 0) {
            // Completed indicator: 3pt accent bar on leading edge (UI-SPEC color contract)
            if isCompleted {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 3)
            }

            HStack(spacing: 16) {
                // "Set N" label — 48pt wide, subheadline, primary color
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .frame(width: 48, alignment: .leading)

                Spacer()

                // Stepper: minus | rep count (tappable) | plus
                HStack(spacing: 12) {
                    // Minus button
                    Button {
                        repsLogged = max(0, repsLogged - 1)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 28))
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Decrease reps")
                    .accessibilityHint("Current: \(repsLogged) reps")

                    // Rep count — tappable to open number pad
                    Button {
                        showNumberPad = true
                    } label: {
                        Text("\(repsLogged)")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                            .frame(minWidth: 48)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minHeight: 44)
                    .accessibilityLabel("\(repsLogged) reps, tap to edit")

                    // Plus button
                    Button {
                        repsLogged = min(999, repsLogged + 1)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28))
                    }
                    .disabled(isCompleted)
                    .contentShape(Rectangle())
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Increase reps")
                    .accessibilityHint("Current: \(repsLogged) reps")
                }

                // Target reps hint — subheadline, secondary, right-aligned
                Text("Target: \(targetReps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)

                // Checkmark button
                Button {
                    onComplete()
                } label: {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(isCompleted ? Theme.accent : .secondary)
                }
                .disabled(isCompleted)
                .contentShape(Rectangle())
                .frame(width: 44, height: 44)
                .accessibilityLabel(isCompleted ? "Set \(setNumber) complete" : "Mark set \(setNumber) complete")
                .accessibilityAddTraits(isCompleted ? .isSelected : [])
            }
            .padding(.horizontal, 16)
        }
        .frame(minHeight: 52)
        .background(Theme.surface)
        // T-04-09: number pad sheet validates 0–999 before committing
        .sheet(isPresented: $showNumberPad) {
            NumberPadSheet(reps: $repsLogged)
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

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        SetLogRow(
            setNumber: 1,
            targetReps: "8-12",
            isCompleted: false,
            repsLogged: .constant(10),
            onComplete: {}
        )
        Divider()
        SetLogRow(
            setNumber: 2,
            targetReps: "8-12",
            isCompleted: true,
            repsLogged: .constant(10),
            onComplete: {}
        )
    }
    .padding()
}
#endif
