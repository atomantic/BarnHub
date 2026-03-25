import SwiftUI
import SwiftData

struct FarrierScheduleView: View {
    @Environment(Router.self) private var router

    @Query(sort: \FarrierVisit.date, order: .reverse) private var allFarrierVisits: [FarrierVisit]

    private var scheduledVisits: [FarrierVisit] {
        allFarrierVisits
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            if scheduledVisits.isEmpty {
                EmptyStateView(
                    icon: "hammer",
                    title: "No Scheduled Farrier Visits",
                    subtitle: "Farrier visits with a next due date will appear here."
                )
            } else {
                ForEach(scheduledVisits) { visit in
                    Button {
                        guard let horseID = visit.horse?.persistentModelID else { return }
                        router.navigate(to: HorseRoute.detail(horseID))
                    } label: {
                        ScheduleRecordRow(
                            horseName: visit.horse?.name ?? "Unknown Horse",
                            providerName: visit.farrierName,
                            description: visit.serviceDescription,
                            nextDueDate: visit.nextDueDate
                        )
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle("Farrier Schedule")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: BarnRoute.addFarrierVisit) {
                    Label("Add Farrier Visit", systemImage: "plus")
                }
            }
        }
    }

}
