import SwiftUI
import SwiftData

struct VetScheduleView: View {
    @Query(sort: \VetRecord.date, order: .reverse) private var allVetRecords: [VetRecord]

    private var scheduledRecords: [VetRecord] {
        allVetRecords
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        ScheduleListView(
            records: scheduledRecords,
            horseName: { $0.horse?.name ?? "Unknown Horse" },
            horseID: { $0.horse?.persistentModelID },
            providerName: { $0.vetName },
            description: { $0.descriptionText },
            nextDueDate: { $0.nextDueDate },
            navigationTitle: "Vet Schedule",
            emptyIcon: "cross.case",
            emptyTitle: "No Scheduled Vet Visits",
            emptySubtitle: "Vet appointments with a next due date will appear here.",
            addRoute: .addVetRecord,
            addLabel: "Add Vet Record"
        )
    }
}
