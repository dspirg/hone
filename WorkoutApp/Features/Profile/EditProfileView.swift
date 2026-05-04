import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var goal: String
    @State private var fitnessLevel: String
    @State private var daysPerWeek: Int
    @State private var equipment: Set<String>
    @State private var injuries: String
    @State private var isSaving = false
    @State private var showRegenAlert = false

    private let goalOptions = ["Build Muscle", "Lose Fat", "Get Fitter", "Athletic Performance"]
    private let levelOptions = ["Beginner", "Intermediate", "Advanced"]
    private let dayOptions = [2, 3, 4, 5, 6]
    private let equipmentOptions = ["No equipment", "Dumbbells", "Barbell", "Machines", "Resistance Bands", "Full Gym"]

    init(profile: UserProfile) {
        _goal = State(initialValue: profile.goal)
        _fitnessLevel = State(initialValue: profile.fitnessLevel)
        _daysPerWeek = State(initialValue: profile.daysPerWeek)
        _equipment = State(initialValue: Set(profile.equipment))
        _injuries = State(initialValue: profile.injuries)
    }

    var body: some View {
        List {
            Section("Goal") {
                ForEach(goalOptions, id: \.self) { option in
                    Button {
                        goal = option
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(.primary)
                            Spacer()
                            if goal == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }

            Section("Fitness Level") {
                ForEach(levelOptions, id: \.self) { option in
                    Button {
                        fitnessLevel = option
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(.primary)
                            Spacer()
                            if fitnessLevel == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }

            Section("Days Per Week") {
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.self) { day in
                        Button {
                            daysPerWeek = day
                        } label: {
                            Text("\(day)")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(daysPerWeek == day ? Theme.accent : Theme.surface)
                                .foregroundStyle(daysPerWeek == day ? .black : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Equipment") {
                ForEach(equipmentOptions, id: \.self) { option in
                    Button {
                        toggleEquipment(option)
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(.primary)
                            Spacer()
                            if equipment.contains(option) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }

            Section("Injuries / Limitations") {
                TextField("None", text: $injuries, axis: .vertical)
                    .lineLimit(3)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showRegenAlert = true
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(isSaving)
            }
        }
        .alert("Update your plan?", isPresented: $showRegenAlert) {
            Button("Save Only") {
                Task { await saveProfile(regenerate: false) }
            }
            Button("Save & Regenerate Plan") {
                Task { await saveProfile(regenerate: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your profile will be saved. Would you also like Hone to generate a new plan based on your updated profile?")
        }
    }

    private func toggleEquipment(_ item: String) {
        if item == "No equipment" {
            equipment = ["No equipment"]
        } else {
            equipment.remove("No equipment")
            if equipment.contains(item) {
                equipment.remove(item)
            } else {
                equipment.insert(item)
            }
        }
    }

    private func saveProfile(regenerate: Bool) async {
        isSaving = true
        let profile = UserProfile(
            goal: goal,
            fitnessLevel: fitnessLevel,
            daysPerWeek: daysPerWeek,
            equipment: Array(equipment),
            injuries: injuries
        )
        let service = PlanGenerationService()
        do {
            try await service.saveProfile(profile)
            if regenerate {
                service.generatePlan(profile: profile)
            }
        } catch {
            // Silent — profile will be saved on next attempt
        }
        isSaving = false
        dismiss()
    }
}
