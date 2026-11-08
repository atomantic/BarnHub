import SwiftUI
import SwiftData

struct DentistScheduleView: View {
    // Only records with a next due date, sorted by it in the store (#32);
    // ScheduleListView drops the superseded ones (#50).
    @Query(DashboardQueries.dentistScheduled)
    private var scheduledVisits: [DentistVisit]

    var body: some View {
        ScheduleListView(
            records: scheduledVisits,
            newest: \.dentist,
            providerName: { $0.dentistName },
            description: { $0.serviceDescription },
            navigationTitle: "Dentist Schedule",
            emptyIcon: "mouth",
            emptyTitle: "No Scheduled Dentist Visits",
            emptySubtitle: "Dentist visits with a next due date will appear here.",
            addRoute: .addDentistVisit,
            addLabel: "Add Dentist Visit"
        )
    }
}
