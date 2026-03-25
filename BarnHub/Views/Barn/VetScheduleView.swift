import SwiftUI
import SwiftData

struct VetScheduleView: View {
    @Environment(Router.self) private var router

    @Query(sort: \VetRecord.date, order: .reverse) private var allVetRecords: [VetRecord]

    private var scheduledRecords: [VetRecord] {
        allVetRecords
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            if scheduledRecords.isEmpty {
                EmptyStateView(
                    icon: "cross.case",
                    title: "No Scheduled Vet Visits",
                    subtitle: "Vet appointments with a next due date will appear here."
                )
            } else {
                ForEach(scheduledRecords) { record in
                    Button {
                        guard let horseID = record.horse?.persistentModelID else { return }
                        router.navigate(to: HorseRoute.detail(horseID))
                    } label: {
                        ScheduleRecordRow(
                            horseName: record.horse?.name ?? "Unknown Horse",
                            providerName: record.vetName,
                            description: record.descriptionText,
                            nextDueDate: record.nextDueDate
                        )
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle("Vet Schedule")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: BarnRoute.addVetRecord) {
                    Label("Add Vet Record", systemImage: "plus")
                }
            }
        }
    }

}
