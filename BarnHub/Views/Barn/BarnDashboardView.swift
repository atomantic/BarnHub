import SwiftUI
import SwiftData

struct BarnDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]

    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]

    private var upcomingReminders: [Reminder] {
        Array(incompleteReminders.prefix(5))
    }

    private var upcomingVetRecords: [VetRecord] {
        vetRecords
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    private var upcomingFarrierVisits: [FarrierVisit] {
        farrierVisits
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: BarnRoute.reminders) {
                    Label("Reminders", systemImage: "bell.fill")
                }
                NavigationLink(value: BarnRoute.vetSchedule) {
                    Label("Vet Schedule", systemImage: "cross.case.fill")
                }
                NavigationLink(value: BarnRoute.farrierSchedule) {
                    Label("Farrier Schedule", systemImage: "hammer.fill")
                }
            }

            Section("Upcoming Reminders") {
                if upcomingReminders.isEmpty {
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No Reminders",
                        subtitle: "All caught up!"
                    )
                } else {
                    ForEach(upcomingReminders) { reminder in
                        NavigationLink(value: BarnRoute.reminderEdit(reminder.persistentModelID)) {
                            reminderRow(reminder)
                        }
                    }
                }
            }

            Section("Next Vet Appointments") {
                if upcomingVetRecords.isEmpty {
                    EmptyStateView(
                        icon: "cross.case",
                        title: "No Upcoming Vet Visits",
                        subtitle: "No scheduled vet appointments."
                    )
                } else {
                    ForEach(upcomingVetRecords.prefix(5)) { record in
                        vetRecordRow(record)
                    }
                }
            }

            Section("Next Farrier Visits") {
                if upcomingFarrierVisits.isEmpty {
                    EmptyStateView(
                        icon: "hammer",
                        title: "No Upcoming Farrier Visits",
                        subtitle: "No scheduled farrier appointments."
                    )
                } else {
                    ForEach(upcomingFarrierVisits.prefix(5)) { visit in
                        farrierVisitRow(visit)
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .navigationDestination(for: BarnRoute.self) { route in
            barnDestination(for: route)
        }
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.headline)
                if let horse = reminder.horse {
                    Text(horse.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(reminder.dueDate.shortFormatted)
                .font(.caption)
                .foregroundStyle(reminder.dueDate.isOverdue ? .red : .secondary)
        }
    }

    private func vetRecordRow(_ record: VetRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.horse?.name ?? "Unknown Horse")
                    .font(.headline)
                Text(record.vetName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let nextDue = record.nextDueDate {
                Text(nextDue.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
            }
        }
    }

    private func farrierVisitRow(_ visit: FarrierVisit) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.horse?.name ?? "Unknown Horse")
                    .font(.headline)
                Text(visit.farrierName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let nextDue = visit.nextDueDate {
                Text(nextDue.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
            }
        }
    }

    @ViewBuilder
    private func barnDestination(for route: BarnRoute) -> some View {
        switch route {
        case .supplies:
            SupplyListView()
        case .supplyEdit(let id):
            SupplyEditView(supplyItemID: id)
        case .reminders:
            ReminderListView()
        case .reminderEdit(let id):
            ReminderEditView(reminderID: id)
        case .vetSchedule:
            VetScheduleView()
        case .farrierSchedule:
            FarrierScheduleView()
        }
    }
}
