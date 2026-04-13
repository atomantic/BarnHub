import SwiftUI
import SwiftData

struct DentistScheduleView: View {
    @Query(sort: \DentistVisit.date, order: .reverse) private var allDentistVisits: [DentistVisit]

    private var scheduledVisits: [DentistVisit] {
        allDentistVisits
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        ScheduleListView(
            records: scheduledVisits,
            horseName: { $0.horse?.name ?? "Unknown Horse" },
            horseID: { $0.horse?.persistentModelID },
            providerName: { $0.dentistName },
            description: { $0.serviceDescription },
            nextDueDate: { $0.nextDueDate },
            navigationTitle: "Dentist Schedule",
            emptyIcon: "mouth",
            emptyTitle: "No Scheduled Dentist Visits",
            emptySubtitle: "Dentist visits with a next due date will appear here.",
            addRoute: .addDentistVisit,
            addLabel: "Add Dentist Visit"
        )
    }
}
