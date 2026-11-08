import SwiftUI
import SwiftData

struct VetRecordEditView: View {
    let horseID: PersistentIdentifier?
    var recordID: PersistentIdentifier? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService

    @State private var date = Date.now
    @State private var vetName = ""
    @State private var descriptionText = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now
    @State private var reminderFrequency: ReminderFrequency = .once
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false

    @State private var toast = ToastState()

    private var isNew: Bool { recordID == nil }
    private var existingRecord: VetRecord? { modelContext.existingModel(for: recordID) }

    private var resolvedHorseID: PersistentIdentifier? {
        horseID ?? existingRecord?.horse?.persistentModelID ?? selectedHorseID
    }

    private var horse: Horse? {
        modelContext.existingModel(for: resolvedHorseID)
    }

    var body: some View {
        Form {
            if horseID == nil && isNew {
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


            if !isNew {
                Section {
                    Button("Delete Vet Record", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isNew ? "New Vet Record" : "Edit Vet Record")
        .toolbar {
            // In the bar rather than at the bottom of the form, so it's always
            // reachable and sits next to Cancel when the form opens as a sheet.
            ToolbarItem(placement: .pinnedConfirmation) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(vetName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
            }
        }
        .inlineNavTitle()
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        #endif
        .task { loadExisting() }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Vet Record",
                message: "Are you sure you want to delete this vet record?",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deleteRecord
            )
        }
        .toast(toast)
    }

    private func loadExisting() {
        guard let record = existingRecord else { return }
        date = record.date
        vetName = record.vetName
        descriptionText = record.descriptionText
        cost = record.cost
        hasNextDue = record.nextDueDate != nil
        nextDueDate = record.nextDueDate ?? .now
        reminderFrequency = record.reminderFrequency
    }

    private func save() {
        guard let horse else { return }
        let trimmedName = vetName.trimmingCharacters(in: .whitespaces)
        let record: VetRecord
        if let existing = existingRecord {
            record = existing
            BarnHubLogger.info("Updating vet record horse=\(horse.name) vet=\(trimmedName)")
        } else {
            record = VetRecord()
            record.horse = horse
            modelContext.insert(record)
            BarnHubLogger.info("Adding vet record horse=\(horse.name) vet=\(trimmedName)")
        }
        record.date = date
        record.vetName = trimmedName
        record.descriptionText = descriptionText
        record.cost = cost
        record.nextDueDate = hasNextDue ? nextDueDate : nil
        record.reminderFrequency = reminderFrequency

        modelContext.saveWithLogging()
        notificationService.scheduleVetRecord(record)
        toast.showAndDismiss(appLocalized("Vet record saved", comment: "Toast after saving a vet record"), dismiss: dismiss)
    }

    private func deleteRecord() {
        guard let record = existingRecord else { return }
        BarnHubLogger.info("Deleting vet record vet=\(record.vetName)")
        notificationService.cancelVetRecord(record)
        modelContext.delete(record)
        modelContext.saveWithLogging()
        toast.showAndDismiss(appLocalized("Vet record deleted", comment: "Toast after deleting a vet record"), dismiss: dismiss)
    }
}
