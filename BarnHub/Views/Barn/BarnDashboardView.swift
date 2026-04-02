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
    @Query(sort: \BarnNote.date, order: .reverse) private var barnNotes: [BarnNote]

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
        #if os(macOS)
        macOSDashboard
            .navigationTitle("Schedule")
        #else
        iosList
            .navigationTitle("Schedule")
            .inlineNavTitle()
        #endif
    }

    // MARK: - iOS: List Layout

    #if os(iOS)
    private var iosList: some View {
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
    }
    #endif

    // MARK: - macOS: Grid Dashboard

    #if os(macOS)
    private var macOSDashboard: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ScrollView {
                Group {
                    if w >= 800 {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) { remindersCard; vetCard }
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 16) { farrierCard; lessonsCard }
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 16) { barnNotesCard }
                                .frame(maxWidth: .infinity)
                        }
                    } else if w >= 500 {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) { remindersCard; farrierCard; barnNotesCard }
                                .frame(maxWidth: .infinity)
                            VStack(spacing: 16) { vetCard; lessonsCard }
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 16) { remindersCard; vetCard; farrierCard; lessonsCard; barnNotesCard }
                    }
                }
                .padding()
            }
        }
        .background(Color.barnOffWhite)
    }

    private var remindersCard: some View {
        dashboardCard(
            title: "Reminders",
            icon: "bell.fill",
            iconColor: .barnGreen,
            seeAllRoute: BarnRoute.reminders,
            addRoute: BarnRoute.reminderEdit(nil)
        ) {
            if upcomingReminders.isEmpty {
                cardEmptyState("All caught up!")
            } else {
                ForEach(upcomingReminders) { reminder in
                    NavigationLink(value: BarnRoute.reminderEdit(reminder.persistentModelID)) {
                        reminderRow(reminder)
                    }
                    .buttonStyle(.plain)
                    if reminder.persistentModelID != upcomingReminders.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
    }

    private var vetCard: some View {
        dashboardCard(
            title: "Vet Appointments",
            icon: "cross.case.fill",
            iconColor: .red,
            seeAllRoute: BarnRoute.vetSchedule,
            addRoute: BarnRoute.addVetRecord
        ) {
            let records = Array(upcomingVetRecords.prefix(5))
            if records.isEmpty {
                cardEmptyState("No scheduled vet appointments.")
            } else {
                ForEach(records) { record in
                    scheduleRow(
                        horseName: record.horse?.name ?? "Unknown Horse",
                        providerName: record.vetName,
                        nextDueDate: record.nextDueDate
                    )
                    if record.persistentModelID != records.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
    }

    private var farrierCard: some View {
        dashboardCard(
            title: "Farrier Visits",
            icon: "hammer.fill",
            iconColor: .orange,
            seeAllRoute: BarnRoute.farrierSchedule,
            addRoute: BarnRoute.addFarrierVisit
        ) {
            let visits = Array(upcomingFarrierVisits.prefix(5))
            if visits.isEmpty {
                cardEmptyState("No scheduled farrier visits.")
            } else {
                ForEach(visits) { visit in
                    scheduleRow(
                        horseName: visit.horse?.name ?? "Unknown Horse",
                        providerName: visit.farrierName,
                        nextDueDate: visit.nextDueDate
                    )
                    if visit.persistentModelID != visits.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
    }

    private var lessonsCard: some View {
        dashboardCard(
            title: "Lessons",
            icon: "book.fill",
            iconColor: .blue,
            seeAllRoute: BarnRoute.lessons,
            addRoute: BarnRoute.lessonEdit(nil)
        ) {
            let upcoming = Array(upcomingLessons.prefix(5))
            if upcoming.isEmpty {
                cardEmptyState("No scheduled lessons.")
            } else {
                ForEach(upcoming) { lesson in
                    NavigationLink(value: BarnRoute.lessonEdit(lesson.persistentModelID)) {
                        lessonRow(lesson)
                    }
                    .buttonStyle(.plain)
                    if lesson.persistentModelID != upcoming.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
    }

    private var barnNotesCard: some View {
        dashboardCard(
            title: "Barn Notes",
            icon: "note.text",
            iconColor: .barnTan,
            seeAllRoute: BarnRoute.barnNotes,
            addRoute: BarnRoute.barnNoteEdit(nil)
        ) {
            let recent = Array(barnNotes.prefix(5))
            if recent.isEmpty {
                cardEmptyState("No barn notes yet.")
            } else {
                ForEach(recent) { note in
                    NavigationLink(value: BarnRoute.barnNoteEdit(note.persistentModelID)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.content.prefix(60))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text(note.category.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.barnGreen)
                                Text(note.date.shortFormatted)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    if note.persistentModelID != recent.last?.persistentModelID {
                        Divider()
                    }
                }
            }
        }
    }

    private func dashboardCard<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        seeAllRoute: BarnRoute,
        addRoute: BarnRoute,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                NavigationLink(value: addRoute) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.barnGreen)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
            }

            Divider()

            content()

            Divider()

            NavigationLink(value: seeAllRoute) {
                Text("See All")
                    .font(.caption)
                    .foregroundStyle(.barnGreen)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func cardEmptyState(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 16)
    }
    #endif

    // MARK: - Shared Row Views

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline.weight(.medium))
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
        .padding(.vertical, 2)
    }

    private func scheduleRow(horseName: String, providerName: String, nextDueDate: Date?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(horseName)
                    .font(.subheadline.weight(.medium))
                Text(providerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let nextDue = nextDueDate {
                Text(nextDue.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.client?.fullName ?? "No Client")
                    .font(.subheadline.weight(.medium))
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
        .padding(.vertical, 2)
    }
}
