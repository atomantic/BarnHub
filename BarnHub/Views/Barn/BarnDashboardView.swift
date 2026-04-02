import SwiftUI
import SwiftData

// MARK: - Schedule Event Types

enum ScheduleEventType: String, CaseIterable {
    case reminder, vet, farrier, lesson

    var color: Color {
        switch self {
        case .reminder: .barnGreen
        case .vet: .red
        case .farrier: .orange
        case .lesson: .blue
        }
    }

    var icon: String {
        switch self {
        case .reminder: "bell.fill"
        case .vet: "cross.case.fill"
        case .farrier: "hammer.fill"
        case .lesson: "book.fill"
        }
    }

    var label: String {
        switch self {
        case .reminder: "Reminder"
        case .vet: "Vet"
        case .farrier: "Farrier"
        case .lesson: "Lesson"
        }
    }
}

struct ScheduleEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String?
    let type: ScheduleEventType
    let modelID: PersistentIdentifier?
}

// MARK: - Dashboard View

struct BarnDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @Query(filter: #Predicate<Reminder> { !$0.isCompleted }, sort: \Reminder.dueDate)
    private var incompleteReminders: [Reminder]

    @Query(sort: \VetRecord.date, order: .reverse) private var vetRecords: [VetRecord]
    @Query(sort: \FarrierVisit.date, order: .reverse) private var farrierVisits: [FarrierVisit]
    @Query(sort: \Lesson.date, order: .reverse) private var allLessons: [Lesson]

    #if os(macOS)
    @State private var displayedMonth = Date.now
    @State private var selectedDate = Date.now
    #endif

    var body: some View {
        #if os(macOS)
        macOSCalendar
            .navigationTitle("Schedule")
        #else
        iosList
            .navigationTitle("Schedule")
            .inlineNavTitle()
        #endif
    }

    // MARK: - Event Aggregation

    private var allEvents: [ScheduleEvent] {
        var events: [ScheduleEvent] = []

        for reminder in incompleteReminders {
            events.append(ScheduleEvent(
                id: "rem-\(reminder.persistentModelID.hashValue)",
                date: reminder.dueDate,
                title: reminder.title,
                subtitle: reminder.horse?.name,
                type: .reminder,
                modelID: reminder.persistentModelID
            ))
        }

        for record in vetRecords {
            guard let dueDate = record.nextDueDate else { continue }
            events.append(ScheduleEvent(
                id: "vet-\(record.persistentModelID.hashValue)",
                date: dueDate,
                title: record.horse?.name ?? "Unknown Horse",
                subtitle: record.vetName,
                type: .vet,
                modelID: record.persistentModelID
            ))
        }

        for visit in farrierVisits {
            guard let dueDate = visit.nextDueDate else { continue }
            events.append(ScheduleEvent(
                id: "far-\(visit.persistentModelID.hashValue)",
                date: dueDate,
                title: visit.horse?.name ?? "Unknown Horse",
                subtitle: visit.farrierName,
                type: .farrier,
                modelID: visit.persistentModelID
            ))
        }

        for lesson in allLessons {
            guard let nextDate = lesson.nextDate else { continue }
            events.append(ScheduleEvent(
                id: "les-\(lesson.persistentModelID.hashValue)",
                date: nextDate,
                title: lesson.client?.fullName ?? "No Client",
                subtitle: [lesson.lessonType.displayName, lesson.horse.map { "on \($0.name)" }]
                    .compactMap { $0 }.joined(separator: " "),
                type: .lesson,
                modelID: lesson.persistentModelID
            ))
        }

        return events
    }

    private var eventsByDay: [Date: [ScheduleEvent]] {
        let calendar = Calendar.current
        var grouped: [Date: [ScheduleEvent]] = [:]
        for event in allEvents {
            let day = calendar.startOfDay(for: event.date)
            grouped[day, default: []].append(event)
        }
        return grouped
    }

    // MARK: - iOS: List Layout

    #if os(iOS)
    private var upcomingReminders: [Reminder] { Array(incompleteReminders.prefix(5)) }

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

    private var upcomingLessons: [Lesson] {
        allLessons
            .filter { $0.nextDate != nil }
            .sorted { ($0.nextDate ?? .distantFuture) < ($1.nextDate ?? .distantFuture) }
    }

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
                    EmptyStateView(icon: "bell.slash", title: "No Reminders", subtitle: "All caught up!")
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
                    EmptyStateView(icon: "cross.case", title: "No Upcoming Vet Visits", subtitle: "No scheduled vet appointments.")
                } else {
                    ForEach(upcomingVetRecords.prefix(5)) { record in
                        scheduleRow(horseName: record.horse?.name ?? "Unknown Horse", providerName: record.vetName, nextDueDate: record.nextDueDate)
                    }
                }
            } header: {
                HStack {
                    Text("Next Vet Appointments")
                    Spacer()
                    NavigationLink(value: BarnRoute.addVetRecord) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.barnGreen)
                    }
                }
            }

            Section {
                if upcomingFarrierVisits.isEmpty {
                    EmptyStateView(icon: "hammer", title: "No Upcoming Farrier Visits", subtitle: "No scheduled farrier appointments.")
                } else {
                    ForEach(upcomingFarrierVisits.prefix(5)) { visit in
                        scheduleRow(horseName: visit.horse?.name ?? "Unknown Horse", providerName: visit.farrierName, nextDueDate: visit.nextDueDate)
                    }
                }
            } header: {
                HStack {
                    Text("Next Farrier Visits")
                    Spacer()
                    NavigationLink(value: BarnRoute.addFarrierVisit) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.barnGreen)
                    }
                }
            }

            Section {
                if upcomingLessons.isEmpty {
                    EmptyStateView(icon: "book", title: "No Upcoming Lessons", subtitle: "No scheduled lessons.")
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
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.barnGreen)
                    }
                }
            }
        }
    }
    #endif

    // MARK: - macOS: Calendar View

    #if os(macOS)
    private var macOSCalendar: some View {
        VStack(spacing: 0) {
            calendarHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            HStack(spacing: 0) {
                calendarGrid
                    .frame(maxWidth: .infinity)

                Divider()

                dayDetailPanel
                    .frame(width: 280)
            }
        }
        .background(Color.barnOffWhite)
    }

    // MARK: Header

    private var calendarHeader: some View {
        HStack(spacing: 12) {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Text(monthYearString)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 160)

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Button("Today") {
                displayedMonth = Date.now
                selectedDate = Date.now
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            // Color legend
            HStack(spacing: 12) {
                ForEach(ScheduleEventType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(type.color)
                            .frame(width: 8, height: 8)
                        Text(type.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private func shiftMonth(_ delta: Int) {
        guard let newDate = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = newDate
    }

    // MARK: Calendar Grid

    private var calendarGrid: some View {
        let calendar = Calendar.current
        let weeks = monthWeeks
        let today = calendar.startOfDay(for: Date.now)
        let selected = calendar.startOfDay(for: selectedDate)

        return VStack(spacing: 0) {
            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .background(Color.barnCardBackground.opacity(0.5))

            Divider()

            // Week rows
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let isToday = day == today
                            let isSelected = day == selected
                            let dayEvents = eventsByDay[day] ?? []

                            calendarCell(
                                date: day,
                                dayNumber: calendar.component(.day, from: day),
                                isToday: isToday,
                                isSelected: isSelected,
                                events: dayEvents
                            )
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                        }
                    }
                }
                Divider().opacity(0.3)
            }

            Spacer()
        }
    }

    private func calendarCell(date: Date, dayNumber: Int, isToday: Bool, isSelected: Bool, events: [ScheduleEvent]) -> some View {
        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.subheadline.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : .primary)
                    .frame(width: 26, height: 26)
                    .background {
                        if isToday {
                            Circle().fill(Color.barnGreen)
                        }
                    }

                // Event dots (max 4)
                let uniqueTypes = Array(Set(events.map(\.type))).sorted { $0.rawValue < $1.rawValue }
                if !uniqueTypes.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(uniqueTypes.prefix(4), id: \.self) { type in
                            Circle()
                                .fill(type.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                } else {
                    Spacer().frame(height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.barnGreen.opacity(0.1))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var monthWeeks: [[Date?]] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart) // 1=Sun

        var weeks: [[Date?]] = []
        var week: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            week.append(date)
            if week.count == 7 {
                weeks.append(week)
                week = []
            }
        }
        if !week.isEmpty {
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
        }

        return weeks
    }

    // MARK: Day Detail Panel

    private var dayDetailPanel: some View {
        let calendar = Calendar.current
        let selected = calendar.startOfDay(for: selectedDate)
        let dayEvents = (eventsByDay[selected] ?? []).sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 0) {
            // Date header
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if dayEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("No events")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(dayEvents) { event in
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            // Quick add buttons
            HStack(spacing: 8) {
                addButton("Reminder", icon: "bell.fill", color: .barnGreen) {
                    router.navigate(to: BarnRoute.reminderEdit(nil), tab: .schedule)
                }
                addButton("Vet", icon: "cross.case.fill", color: .red) {
                    router.navigate(to: BarnRoute.addVetRecord, tab: .schedule)
                }
                addButton("Farrier", icon: "hammer.fill", color: .orange) {
                    router.navigate(to: BarnRoute.addFarrierVisit, tab: .schedule)
                }
                addButton("Lesson", icon: "book.fill", color: .blue) {
                    router.navigate(to: BarnRoute.lessonEdit(nil), tab: .schedule)
                }
            }
            .padding(12)
        }
        .background(Color.barnCardBackground)
    }

    private func eventRow(_ event: ScheduleEvent) -> some View {
        Button {
            navigateToEvent(event)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.type.color)
                    .frame(width: 4, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    if let subtitle = event.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: event.type.icon)
                    .font(.caption)
                    .foregroundStyle(event.type.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }

    private func navigateToEvent(_ event: ScheduleEvent) {
        guard let id = event.modelID else { return }
        switch event.type {
        case .reminder:
            router.navigate(to: BarnRoute.reminderEdit(id), tab: .schedule)
        case .lesson:
            router.navigate(to: BarnRoute.lessonEdit(id), tab: .schedule)
        case .vet:
            router.navigate(to: BarnRoute.vetSchedule, tab: .schedule)
        case .farrier:
            router.navigate(to: BarnRoute.farrierSchedule, tab: .schedule)
        }
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
    }
}
