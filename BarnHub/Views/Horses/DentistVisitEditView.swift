import SwiftUI
import SwiftData

struct DentistVisitEditView: View {
    let horseID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationService.self) private var notificationService

    @State private var date = Date.now
    @State private var dentistName = ""
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
                TextField("Dentist Name", text: $dentistName)
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
                Button("Save Dentist Visit") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .disabled(dentistName.trimmingCharacters(in: .whitespaces).isEmpty || resolvedHorseID == nil)
            }
        }
        .navigationTitle("New Dentist Visit")
        .inlineNavTitle()
        #if os(macOS)
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        #endif
        .toast(toast)
    }

    private func save() {
        guard let horse else { return }
        let visit = DentistVisit(
            date: date,
            dentistName: dentistName.trimmingCharacters(in: .whitespaces),
            serviceDescription: serviceDescription,
            cost: cost,
            nextDueDate: hasNextDue ? nextDueDate : nil
        )
        visit.horse = horse
        modelContext.insert(visit)
        BarnHubLogger.info("Adding dentist visit horse=\(horse.name) dentist=\(visit.dentistName)")
        modelContext.saveWithLogging()
        notificationService.scheduleDentistVisit(visit)
        toast.showAndDismiss("Dentist visit saved", dismiss: dismiss)
    }
}
