import SwiftUI
import SwiftData

struct HorseDetailView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
    }

    var body: some View {
        Group {
            if let horse {
                horseContent(horse)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Horse Not Found",
                    subtitle: "This horse may have been deleted."
                )
            }
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showDeleteConfirmation,
                title: "Delete Horse",
                message: "Are you sure you want to delete this horse? All associated vet records and farrier visits will also be removed.",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: deleteHorse
            )
        }
        .toast(isPresented: $showToast, message: toastMessage, isError: toastIsError)
    }

    @ViewBuilder
    private func horseContent(_ horse: Horse) -> some View {
        List {
            Section("Info") {
                LabeledContent("Breed", value: horse.breed)
                LabeledContent("Date of Birth", value: horse.dateOfBirth.shortFormatted)
                LabeledContent("Color/Markings", value: horse.colorMarkings)
                LabeledContent("Weight", value: horse.weight > 0 ? "\(Int(horse.weight)) lbs" : "--")
                LabeledContent("Stall", value: horse.stallNumber.isEmpty ? "--" : horse.stallNumber)
                LabeledContent("Status", value: horse.isActive ? "Active" : "Inactive")
            }

            if !horse.medicalNotes.isEmpty {
                Section("Medical Notes") {
                    Text(horse.medicalNotes)
                }
            }

            if !horse.feedingSchedule.isEmpty {
                Section("Feeding Schedule") {
                    Text(horse.feedingSchedule)
                }
            }

            Section {
                let records = (horse.vetRecords ?? []).sorted { $0.date > $1.date }
                if records.isEmpty {
                    Text("No vet records")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(records, id: \.persistentModelID) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.date.shortFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(record.cost.asCurrency)
                                    .font(.subheadline)
                            }
                            Text(record.vetName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !record.descriptionText.isEmpty {
                                Text(record.descriptionText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let nextDue = record.nextDueDate {
                                Text("Next due: \(nextDue.shortFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Vet Records")
                    Spacer()
                    Button {
                        router.navigate(to: HorseRoute.addVetRecord(horseID), tab: .horses)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }

            Section {
                let visits = (horse.farrierVisits ?? []).sorted { $0.date > $1.date }
                if visits.isEmpty {
                    Text("No farrier visits")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visits, id: \.persistentModelID) { visit in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(visit.date.shortFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(visit.cost.asCurrency)
                                    .font(.subheadline)
                            }
                            Text(visit.farrierName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !visit.serviceDescription.isEmpty {
                                Text(visit.serviceDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let nextDue = visit.nextDueDate {
                                Text("Next due: \(nextDue.shortFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Farrier Visits")
                    Spacer()
                    Button {
                        router.navigate(to: HorseRoute.addFarrierVisit(horseID), tab: .horses)
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }

            Section("Clients") {
                let clients = (horse.clients ?? []).sorted { $0.fullName < $1.fullName }
                if clients.isEmpty {
                    Text("No assigned clients")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(clients, id: \.persistentModelID) { client in
                        NavigationLink(value: ClientRoute.detail(client.persistentModelID)) {
                            Text(client.fullName)
                        }
                    }
                }
            }
        }
        .navigationTitle(horse.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        router.navigate(to: HorseRoute.edit(horseID), tab: .horses)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func deleteHorse() {
        guard let horse else { return }
        BarnBookLogger.info("Deleting horse name=\(horse.name)")
        modelContext.deleteWithLogging(horse)
        dismiss()
    }
}
