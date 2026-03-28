import SwiftUI
import SwiftData

struct FarrierScheduleView: View {
    @Query(sort: \FarrierVisit.date, order: .reverse) private var allFarrierVisits: [FarrierVisit]

    private var scheduledVisits: [FarrierVisit] {
        allFarrierVisits
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

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
