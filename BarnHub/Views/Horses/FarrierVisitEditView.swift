import SwiftUI
import SwiftData

struct FarrierVisitEditView: View {
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService

    @State private var date = Date.now
    @State private var farrierName = ""
    @State private var serviceDescription = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now
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

            Section {
                Button("Save Farrier Visit") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(farrierName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
            }
        }
        .navigationTitle("New Farrier Visit")
        .inlineNavTitle()
        .toast(toast)
    }

    private func save() {
        guard let horse else { return }
        let visit = FarrierVisit(
            date: date,
            farrierName: farrierName.trimmingCharacters(in: .whitespaces),
            serviceDescription: serviceDescription,
            cost: cost,
            nextDueDate: hasNextDue ? nextDueDate : nil
        )
        visit.horse = horse
        modelContext.insert(visit)
        BarnHubLogger.info("Adding farrier visit horse=\(horse.name) farrier=\(visit.farrierName)")
        modelContext.saveWithLogging()
        notificationService.scheduleFarrierVisit(visit)
        toast.showAndDismiss("Farrier visit saved", dismiss: dismiss)
    }
}
