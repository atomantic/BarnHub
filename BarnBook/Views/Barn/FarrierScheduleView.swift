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
                        router.navigate(to: HorseRoute.detail(horseID), tab: .horses)
                    } label: {
                        farrierRow(visit)
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle("Farrier Schedule")
    }

    private func farrierRow(_ visit: FarrierVisit) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(visit.horse?.name ?? "Unknown Horse")
                    .font(.headline)
                Text(visit.farrierName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !visit.serviceDescription.isEmpty {
                    Text(visit.serviceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let nextDue = visit.nextDueDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(nextDue.shortFormatted)
                        .font(.subheadline)
                        .foregroundStyle(nextDue.isOverdue ? .red : .primary)
                    Text(nextDue.relativeDateString)
                        .font(.caption)
                        .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
