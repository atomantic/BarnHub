import SwiftUI
import SwiftData

struct FarrierVisitEditView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var farrierName = ""
    @State private var serviceDescription = ""
    @State private var cost: Double = 0
    @State private var hasNextDue = false
    @State private var nextDueDate = Date.now

    @State private var showToast = false
    @State private var toastMessage = ""

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
    }

    var body: some View {
        Form {
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
                .disabled(farrierName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("New Farrier Visit")
        .toast(isPresented: $showToast, message: toastMessage)
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
        toastMessage = "Farrier visit saved"
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}
