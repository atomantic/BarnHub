import SwiftUI
import SwiftData

struct VetRecordEditView: View {
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var vetName = ""
    @State private var descriptionText = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now
    @State private var reminderFrequency: ReminderFrequency = .once
    @State private var selectedHorseID: PersistentIdentifier?

    @State private var toast = ToastState()

    private var resolvedHorseID: PersistentIdentifier? {
        horseID ?? selectedHorseID
    }

    private var horse: Horse? {
        guard let id = resolvedHorseID else { return nil }
        return modelContext.model(for: id) as? Horse
    }

    var body: some View {
        Form {
            if horseID == nil {
                HorsePickerSection(selectedHorseID: $selectedHorseID, placeholder: "Select a horse")
            }

            Section("Visit Details") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Vet Name", text: $vetName)
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...6)
                CurrencyField(label: "Cost", value: $cost)
            }

            Section("Follow-up") {
                Toggle("Schedule Follow-up", isOn: $hasNextDue)
                if hasNextDue {
                    DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
                    Picker("Reminder Frequency", selection: $reminderFrequency) {
                        ForEach(ReminderFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }
            }

            Section {
                Button("Save Vet Record") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(vetName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
            }
        }
        .navigationTitle("New Vet Record")
        .toast(toast)
    }

    private func save() {
        guard let horse else { return }
        let record = VetRecord(
            date: date,
            vetName: vetName.trimmingCharacters(in: .whitespaces),
            descriptionText: descriptionText,
            cost: cost,
            nextDueDate: hasNextDue ? nextDueDate : nil,
            reminderFrequency: reminderFrequency
        )
        record.horse = horse
        modelContext.insert(record)
        BarnHubLogger.info("Adding vet record horse=\(horse.name) vet=\(record.vetName)")
        modelContext.saveWithLogging()
        toast.show("Vet record saved")

        Task {
            try? await Task.sleep(for: .seconds(0.5))
            dismiss()
        }
    }
}
