import SwiftUI
import SwiftData

struct VetRecordEditView: View {
    let horseID: PersistentIdentifier?
    var recordID: PersistentIdentifier? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var vetName = ""
    @State private var descriptionText = ""
    @State private var cost: Double = 0
    @State private var followUp = VetFollowUp()
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false

    @State private var toast = ToastState()

    private var isNew: Bool { recordID == nil }
    private var existingRecord: VetRecord? { modelContext.existingModel(for: recordID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(recordID, as: VetRecord.self) }

    private var resolvedHorseID: PersistentIdentifier? {
        horseID ?? existingRecord?.horse?.persistentModelID ?? selectedHorseID
    }

    private var horse: Horse? {
        modelContext.existingModel(for: resolvedHorseID)
    }

    // User edits only, so loading a record doesn't fill in a suggested date.
    private var visitDate: Binding<Date> {
        Binding(get: { date }, set: { date = $0; followUp.visitDateChanged(to: $0) })
    }

    private var reminderFrequency: Binding<ReminderFrequency> {
        Binding(get: { followUp.frequency }, set: { followUp.setFrequency($0, visitDate: date) })
    }

    var body: some View {
        Form {
            if horseID == nil && isNew {
                HorsePickerSection(selectedHorseID: $selectedHorseID, placeholder: "Select a horse")
            }

            Section("Visit Details") {
                DatePicker("Date", selection: visitDate, displayedComponents: .date)
                TextField("Vet Name", text: $vetName)
                TextField("Description", text: $descriptionText, axis: .vertical)
                    .lineLimit(3...6)
                CurrencyField(label: "Cost", value: $cost)
            }

            Section("Follow-up") {
                // Outside the toggle: picking a frequency turns Next Due on (#37).
                Picker("Reminder Frequency", selection: reminderFrequency) {
                    ForEach(ReminderFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                Toggle("Schedule Follow-up", isOn: $followUp.hasNextDue)
                if followUp.hasNextDue {
                    DatePicker("Next Due Date", selection: $followUp.nextDueDate, displayedComponents: .date)
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
        .deletedRecordNotice(wasDeletedElsewhere)
        .toast(toast)
    }

    private func loadExisting() {
        guard let record = existingRecord else { return }
        date = record.date
        vetName = record.vetName
        descriptionText = record.descriptionText
        cost = record.cost
        followUp = VetFollowUp(
            hasNextDue: record.nextDueDate != nil,
            nextDueDate: record.nextDueDate ?? .now,
            frequency: record.reminderFrequency
        )
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        guard let horse else { return }
        let trimmedName = vetName.trimmingCharacters(in: .whitespaces)
        let record: VetRecord
        if let existing = existingRecord {
            record = existing
            BarnHubLogger.info("Updating vet record")
        } else {
            record = VetRecord()
            record.horse = horse
            modelContext.insert(record)
            BarnHubLogger.info("Adding vet record")
        }
        record.date = date
        record.vetName = trimmedName
        record.descriptionText = descriptionText
        record.cost = cost
        record.nextDueDate = followUp.hasNextDue ? followUp.nextDueDate : nil
        record.reminderFrequency = followUp.frequency

        modelContext.saveWithLogging()
        toast.showAndDismiss(appLocalized("Vet record saved", comment: "Toast after saving a vet record"), dismiss: dismiss)
    }

    private func deleteRecord() {
        guard let record = existingRecord else { return }
        BarnHubLogger.info("Deleting vet record")
        modelContext.delete(record)
        modelContext.saveWithLogging()
        toast.showAndDismiss(appLocalized("Vet record deleted", comment: "Toast after deleting a vet record"), dismiss: dismiss)
    }
}

/// The vet record form's follow-up fields. Picking a Reminder Frequency fills
/// in Next Due one step after the visit (#37), the same step a repeating
/// reminder takes, unless the user has picked a next due date of their own.
/// Notifications follow each horse's newest record, so logging the next visit
/// (with its own suggested date) carries the cycle on.
struct VetFollowUp {
    var hasNextDue = false
    var nextDueDate = Date.now
    private(set) var frequency: ReminderFrequency = .once
    /// The date last filled in from the frequency. While Next Due still equals
    /// it, the user hasn't changed it by hand and it follows the visit date.
    private(set) var suggestedDate: Date?

    init(hasNextDue: Bool = false, nextDueDate: Date = .now, frequency: ReminderFrequency = .once) {
        self.hasNextDue = hasNextDue
        self.nextDueDate = nextDueDate
        self.frequency = frequency
    }

    private var followsSuggestion: Bool { hasNextDue && nextDueDate == suggestedDate }

    /// The user picked a frequency: suggest a next due date when Next Due is
    /// off or still the previous suggestion. Once leaves Next Due as it is.
    mutating func setFrequency(_ newValue: ReminderFrequency, visitDate: Date, calendar: Calendar = .current) {
        frequency = newValue
        guard !hasNextDue || followsSuggestion,
              let suggestion = newValue.advance(visitDate, calendar: calendar) else { return }
        hasNextDue = true
        nextDueDate = suggestion
        suggestedDate = suggestion
    }

    /// The user changed the visit date: move a suggested next due date with it.
    mutating func visitDateChanged(to visitDate: Date, calendar: Calendar = .current) {
        guard followsSuggestion, let suggestion = frequency.advance(visitDate, calendar: calendar) else { return }
        nextDueDate = suggestion
        suggestedDate = suggestion
    }
}
