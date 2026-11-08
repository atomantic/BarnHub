import SwiftUI
import SwiftData

struct FarrierVisitEditView: View {
    let horseID: PersistentIdentifier?
    var visitID: PersistentIdentifier? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var farrierName = ""
    @State private var serviceDescription = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false

    @State private var toast = ToastState()

    private var isNew: Bool { visitID == nil }
    private var existingVisit: FarrierVisit? { modelContext.existingModel(for: visitID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(visitID, as: FarrierVisit.self) }

    private var resolvedHorseID: PersistentIdentifier? {
        horseID ?? existingVisit?.horse?.persistentModelID ?? selectedHorseID
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
                TextField("Farrier Name", text: $farrierName)
                TextField("Service Description", text: $serviceDescription, axis: .vertical)
                    .lineLimit(3...6)
                CurrencyField(label: "Cost", value: $cost)
            }

            Section("Follow-up") {
                Toggle("Schedule Follow-up", isOn: $hasNextDue)
                if hasNextDue {
                    DatePicker("Next Due Date", selection: $nextDueDate, displayedComponents: .date)
                }
            }


            if !isNew {
                Section {
                    Button("Delete Farrier Visit", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isNew ? "New Farrier Visit" : "Edit Farrier Visit")
        .toolbar {
            // In the bar rather than at the bottom of the form, so it's always
            // reachable and sits next to Cancel when the form opens as a sheet.
            ToolbarItem(placement: .pinnedConfirmation) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(farrierName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
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
                title: "Delete Farrier Visit",
                message: "Are you sure you want to delete this farrier visit?",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deleteVisit
            )
        }
        .deletedRecordNotice(wasDeletedElsewhere)
        .toast(toast)
    }

    private func loadExisting() {
        guard let visit = existingVisit else { return }
        date = visit.date
        farrierName = visit.farrierName
        serviceDescription = visit.serviceDescription
        cost = visit.cost
        hasNextDue = visit.nextDueDate != nil
        nextDueDate = visit.nextDueDate ?? .now
    }

    private func save() {
        // Never insert a replacement for a record deleted while the form was open.
        guard !wasDeletedElsewhere else {
            toast.showAndDismiss(appLocalized("This item was deleted", comment: "Toast when saving a record that was deleted elsewhere"), isError: true, dismiss: dismiss)
            return
        }
        guard let horse else { return }
        let trimmedName = farrierName.trimmingCharacters(in: .whitespaces)
        let visit: FarrierVisit
        if let existing = existingVisit {
            visit = existing
            BarnHubLogger.info("Updating farrier visit")
        } else {
            visit = FarrierVisit()
            visit.horse = horse
            modelContext.insert(visit)
            BarnHubLogger.info("Adding farrier visit")
        }
        visit.date = date
        visit.farrierName = trimmedName
        visit.serviceDescription = serviceDescription
        visit.cost = cost
        visit.nextDueDate = hasNextDue ? nextDueDate : nil

        modelContext.saveWithLogging()
        toast.showAndDismiss(appLocalized("Farrier visit saved", comment: "Toast after saving a farrier visit"), dismiss: dismiss)
    }

    private func deleteVisit() {
        guard let visit = existingVisit else { return }
        BarnHubLogger.info("Deleting farrier visit")
        modelContext.delete(visit)
        modelContext.saveWithLogging()
        toast.showAndDismiss(appLocalized("Farrier visit deleted", comment: "Toast after deleting a farrier visit"), dismiss: dismiss)
    }
}
