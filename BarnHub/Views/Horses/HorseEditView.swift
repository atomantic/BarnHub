import SwiftUI
import SwiftData

struct HorseEditView: View {
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var breed = ""
    @State private var dateOfBirth = Date.now
    @State private var colorMarkings = ""
    @State private var weight: Double = 0
    @State private var medicalNotes = ""
    @State private var feedingSchedule = ""
    @State private var stallNumber = ""
    @State private var isActive = true

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var isNew: Bool { horseID == nil }

    private var existingHorse: Horse? {
        guard let horseID else { return nil }
        return modelContext.model(for: horseID) as? Horse
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                TextField("Breed", text: $breed)
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                TextField("Color/Markings", text: $colorMarkings)
            }

            Section("Details") {
                HStack {
                    Text("Weight (lbs)")
                    Spacer()
                    TextField("0", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                TextField("Stall Number", text: $stallNumber)
                Toggle("Active", isOn: $isActive)
            }

            Section("Medical Notes") {
                TextEditor(text: $medicalNotes)
                    .frame(minHeight: 80)
            }

            Section("Feeding Schedule") {
                TextEditor(text: $feedingSchedule)
                    .frame(minHeight: 80)
            }

            Section {
                Button(isNew ? "Add Horse" : "Save Changes") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle(isNew ? "New Horse" : "Edit Horse")
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        guard let horse = existingHorse else { return }
        name = horse.name
        breed = horse.breed
        dateOfBirth = horse.dateOfBirth
        colorMarkings = horse.colorMarkings
        weight = horse.weight
        medicalNotes = horse.medicalNotes
        feedingSchedule = horse.feedingSchedule
        stallNumber = horse.stallNumber
        isActive = horse.isActive
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let horse = existingHorse {
            horse.name = trimmedName
            horse.breed = breed
            horse.dateOfBirth = dateOfBirth
            horse.colorMarkings = colorMarkings
            horse.weight = weight
            horse.medicalNotes = medicalNotes
            horse.feedingSchedule = feedingSchedule
            horse.stallNumber = stallNumber
            horse.isActive = isActive
            BarnHubLogger.info("Updating horse name=\(trimmedName)")
        } else {
            let horse = Horse(
                name: trimmedName,
                breed: breed,
                dateOfBirth: dateOfBirth,
                colorMarkings: colorMarkings,
                weight: weight,
                medicalNotes: medicalNotes,
                feedingSchedule: feedingSchedule,
                stallNumber: stallNumber,
                isActive: isActive
            )
            modelContext.insert(horse)
            BarnHubLogger.info("Creating horse name=\(trimmedName)")
        }

        modelContext.saveWithLogging()
        toastMessage = isNew ? "Horse added" : "Horse updated"
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
