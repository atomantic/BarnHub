import SwiftUI
import SwiftData

struct VetScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32);
    // ScheduleListView drops the superseded ones (#50).
    @Query(DashboardQueries.vetScheduled)
    private var scheduledRecords: [VetRecord]

    var body: some View {
        ScheduleListView(
            records: scheduledRecords,
            newest: \.vet,
            providerName: { $0.vetName },
            description: { $0.descriptionText },
            navigationTitle: "Vet Schedule",
            emptyIcon: "cross.case",
            emptyTitle: "No Scheduled Vet Visits",
            emptySubtitle: "Vet appointments with a next due date will appear here.",
            addRoute: .addVetRecord,
            addLabel: "Add Vet Record"
        )
    }
}
