import SwiftUI
import SwiftData

struct VetScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32).
    @Query(filter: #Predicate<VetRecord> { $0.nextDueDate != nil }, sort: \VetRecord.nextDueDate)
    private var scheduledRecords: [VetRecord]

    var body: some View {
        ScheduleListView(
            records: scheduledRecords,
            horseName: { $0.horse?.name ?? appLocalized("Unknown Horse", comment: "Fallback horse name") },
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
