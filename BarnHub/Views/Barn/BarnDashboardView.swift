import SwiftUI
import SwiftData

struct BarnDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]

    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]
    @Query(sort: \Lesson.date, order: .reverse) private var allLessons: [Lesson]

    private var upcomingReminders: [Reminder] {
        Array(incompleteReminders.prefix(5))
    }

    private var upcomingVetRecords: [VetRecord] {
        filterSortByDueDate(vetRecords, dueDate: \.nextDueDate)
    }

    private var upcomingLessons: [Lesson] {
        allLessons
            .filter { $0.nextDate != nil }
            .sorted { ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
    }

    private var upcomingFarrierVisits: [FarrierVisit] {
        filterSortByDueDate(farrierVisits, dueDate: \.nextDueDate)
    }

    private func filterSortByDueDate<T>(_ records: [T], dueDate: KeyPath<T, Date?>) -> [T] {
        records
            .filter { $0[keyPath: dueDate] != nil }
            .sorted { ($0[keyPath: dueDate] ?? .distantFuture) < ($1[keyPath: dueDate] ?? .distantFuture) }
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
                NavigationLink(value: BarnRoute.barnNotes) {
                    Label("Barn Notes", systemImage: "note.text")
                }
                NavigationLink(value: BarnRoute.lessons) {
                    Label("Lessons", systemImage: "book.fill")
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

            Section {
                if upcomingVetRecords.isEmpty {
                    EmptyStateView(
                        icon: "cross.case",
                        title: "No Upcoming Vet Visits",
                        subtitle: "No scheduled vet appointments."
                    )
                } else {
                    ForEach(upcomingVetRecords.prefix(5)) { record in
                        scheduleRow(
                            horseName: record.horse?.name ?? "Unknown Horse",
                            providerName: record.vetName,
                            nextDueDate: record.nextDueDate
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Next Vet Appointments")
                    Spacer()
                    NavigationLink(value: BarnRoute.addVetRecord) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.barnGreen)
                    }
                }
            }

            Section {
                if upcomingFarrierVisits.isEmpty {
                    EmptyStateView(
                        icon: "hammer",
                        title: "No Upcoming Farrier Visits",
                        subtitle: "No scheduled farrier appointments."
                    )
                } else {
                    ForEach(upcomingFarrierVisits.prefix(5)) { visit in
                        scheduleRow(
                            horseName: visit.horse?.name ?? "Unknown Horse",
                            providerName: visit.farrierName,
                            nextDueDate: visit.nextDueDate
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Next Farrier Visits")
                    Spacer()
                    NavigationLink(value: BarnRoute.addFarrierVisit) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.barnGreen)
                    }
                }
            }

            Section {
                if upcomingLessons.isEmpty {
                    EmptyStateView(
                        icon: "book",
                        title: "No Upcoming Lessons",
                        subtitle: "No scheduled lessons."
                    )
                } else {
                    ForEach(upcomingLessons.prefix(5)) { lesson in
                        NavigationLink(value: BarnRoute.lessonEdit(lesson.persistentModelID)) {
                            lessonRow(lesson)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Upcoming Lessons")
                    Spacer()
                    NavigationLink(value: BarnRoute.lessonEdit(nil)) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.barnGreen)
                    }
                }
            }
        }
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
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

    private func scheduleRow(horseName: String, providerName: String, nextDueDate: Date?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(horseName)
                    .font(.headline)
                Text(providerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let nextDue = nextDueDate {
                Text(nextDue.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.client?.fullName ?? "No Client")
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(lesson.lessonType.displayName)
                        .font(.caption)
                    if let horse = lesson.horse {
                        Text("on \(horse.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if let nextDate = lesson.nextDate {
                Text(nextDate.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(nextDate.isOverdue ? .red : .secondary)
            }
        }
    }

}
