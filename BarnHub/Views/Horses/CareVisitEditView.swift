import SwiftUI
import SwiftData

/// The add/edit form for a farrier or dentist visit. The two share every field
/// but the provider's name; `CareVisit` supplies that and the form's wording.
struct CareVisitEditView<Visit: CareVisit>: View {
    let horseID: PersistentIdentifier?
    var visitID: PersistentIdentifier? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var providerName = ""
    @State private var serviceDescription = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now
    @State private var selectedHorseID: PersistentIdentifier?
    @State private var showDeleteConfirmation = false

    @State private var toast = ToastState()

    private var isNew: Bool { visitID == nil }
    private var existingVisit: Visit? { modelContext.existingModel(for: visitID) }
    /// Editing a record that was deleted meanwhile (here or on another device).
    private var wasDeletedElsewhere: Bool { modelContext.isDeletedRecord(visitID, as: Visit.self) }

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
                TextField(Visit.providerNameLabel, text: $providerName)
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
                    Button(Visit.deleteTitle, role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isNew ? Visit.newTitle : Visit.editTitle)
        .toolbar {
            // In the bar rather than at the bottom of the form, so it's always
            // reachable and sits next to Cancel when the form opens as a sheet.
            ToolbarItem(placement: .pinnedConfirmation) {
                Button(isNew ? "Add" : "Save") { save() }
                    .disabled(providerName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
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
                title: Visit.deleteTitle,
                message: Visit.deleteMessage,
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
        providerName = visit.providerName
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
        let trimmedName = providerName.trimmingCharacters(in: .whitespaces)
        let visit: Visit
        if let existing = existingVisit {
            visit = existing
            BarnHubLogger.info("Updating \(Visit.logName)")
        } else {
            visit = Visit.makeNew()
            visit.horse = horse
            modelContext.insert(visit)
            BarnHubLogger.info("Adding \(Visit.logName)")
        }
        visit.date = date
        visit.providerName = trimmedName
        visit.serviceDescription = serviceDescription
        visit.cost = cost
        visit.nextDueDate = hasNextDue ? nextDueDate : nil

        modelContext.saveWithLogging()
        toast.showAndDismiss(Visit.savedToast, dismiss: dismiss)
    }

    private func deleteVisit() {
        guard let visit = existingVisit else { return }
        BarnHubLogger.info("Deleting \(Visit.logName)")
        modelContext.delete(visit)
        modelContext.saveWithLogging()
        toast.showAndDismiss(Visit.deletedToast, dismiss: dismiss)
    }
}

/// A dated care visit with a provider, service, cost and optional follow-up,
/// edited by `CareVisitEditView`.
protocol CareVisit: PersistentModel {
    var date: Date { get set }
    /// The farrier's or dentist's name.
    var providerName: String { get set }
    var serviceDescription: String { get set }
    var cost: Double { get set }
    var nextDueDate: Date? { get set }
    var horse: Horse? { get set }

    static func makeNew() -> Self

    static var providerNameLabel: LocalizedStringKey { get }
    static var newTitle: LocalizedStringKey { get }
    static var editTitle: LocalizedStringKey { get }
    static var deleteTitle: LocalizedStringKey { get }
    static var deleteMessage: LocalizedStringKey { get }
    static var savedToast: String { get }
    static var deletedToast: String { get }
    /// What the log calls this record (no personal data).
    static var logName: String { get }
}
