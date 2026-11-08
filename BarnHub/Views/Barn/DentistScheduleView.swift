import SwiftUI
import SwiftData

struct DentistScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32).
    @Query(filter: #Predicate<DentistVisit> { $0.nextDueDate != nil }, sort: \DentistVisit.nextDueDate)
    private var scheduledVisits: [DentistVisit]

    var body: some View {
        ScheduleListView(
            records: scheduledVisits,
            horseName: { $0.horse?.name ?? appLocalized("Unknown Horse", comment: "Fallback horse name") },
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
