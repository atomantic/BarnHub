import SwiftUI
import SwiftData

struct FarrierScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32);
    // ScheduleListView drops the superseded ones (#50).
    @Query(DashboardQueries.farrierScheduled)
    private var scheduledVisits: [FarrierVisit]

    var body: some View {
        ScheduleListView(
            records: scheduledVisits,
            newest: \.farrier,
            providerName: { $0.farrierName },
            description: { $0.serviceDescription },
            navigationTitle: "Farrier Schedule",
            emptyIcon: "hammer",
            emptyTitle: "No Scheduled Farrier Visits",
            emptySubtitle: "Farrier visits with a next due date will appear here.",
            addRoute: .addFarrierVisit,
            addLabel: "Add Farrier Visit"
        )
    }
}
