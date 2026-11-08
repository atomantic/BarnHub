import SwiftUI
import SwiftData

struct FarrierScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32).
    @Query(filter: #Predicate<FarrierVisit> { $0.nextDueDate != nil }, sort: \FarrierVisit.nextDueDate)
    private var scheduledVisits: [FarrierVisit]

    var body: some View {
        ScheduleListView(
            records: scheduledVisits,
            horseName: { $0.horse?.name ?? "Unknown Horse" },
            horseID: { $0.horse?.persistentModelID },
            providerName: { $0.farrierName },
            description: { $0.serviceDescription },
            nextDueDate: { $0.nextDueDate },
            navigationTitle: "Farrier Schedule",
            emptyIcon: "hammer",
            emptyTitle: "No Scheduled Farrier Visits",
            emptySubtitle: "Farrier visits with a next due date will appear here.",
            addRoute: .addFarrierVisit,
            addLabel: "Add Farrier Visit"
        )
    }
}
