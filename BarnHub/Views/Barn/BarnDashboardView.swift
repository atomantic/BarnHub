import SwiftUI
import SwiftData

// MARK: - Calendar View Mode

enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

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

// MARK: - Schedule Event

struct ScheduleEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String?
    let type: ScheduleEventType
    let modelID: PersistentIdentifier?
    let durationMinutes: Int
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

    @State private var viewMode: CalendarViewMode = .month
    @State private var selectedDate: Date = .now

    var body: some View {
        #if os(macOS)
        macOSCalendar
            .navigationTitle("Schedule")
        #else
        iOSCalendar
            .navigationTitle("Schedule")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .trailingBar) { categoriesMenu }
                ToolbarItem(placement: .trailingBar) { addEventMenu }
            }
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
                modelID: reminder.persistentModelID,
                durationMinutes: 30
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
                modelID: record.persistentModelID,
                durationMinutes: 60
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
                modelID: visit.persistentModelID,
                durationMinutes: 60
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
                modelID: lesson.persistentModelID,
                durationMinutes: lesson.duration
            ))
        }

        return events
    }

    private var eventsByDay: [Date: [ScheduleEvent]] {
        let cal = Calendar.current
        var grouped: [Date: [ScheduleEvent]] = [:]
        for event in allEvents {
            let day = cal.startOfDay(for: event.date)
            grouped[day, default: []].append(event)
        }
        return grouped
    }

    private func eventsForDay(_ date: Date) -> [ScheduleEvent] {
        let day = Calendar.current.startOfDay(for: date)
        return (eventsByDay[day] ?? []).sorted { $0.date < $1.date }
    }

    // MARK: - Navigation Helpers

    private var monthStart: Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
    }

    private var weekStart: Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        return cal.date(byAdding: .day, value: -(weekday - 1), to: cal.startOfDay(for: selectedDate)) ?? selectedDate
    }

    private var calendarTitle: String {
        switch viewMode {
        case .day:
            let weekday = selectedDate.formatted(.dateTime.weekday(.wide))
            let monthDay = selectedDate.formatted(.dateTime.month(.abbreviated).day())
            return "\(weekday), \(monthDay)"
        case .week:
            let start = weekStart
            guard let end = Calendar.current.date(byAdding: .day, value: 6, to: start) else { return "" }
            let startStr = start.formatted(.dateTime.month(.abbreviated).day())
            let cal = Calendar.current
            let sameMonth = cal.component(.month, from: start) == cal.component(.month, from: end)
            let endStr = sameMonth
                ? "\(cal.component(.day, from: end))"
                : end.formatted(.dateTime.month(.abbreviated).day())
            return "\(startStr) – \(endStr)"
        case .month:
            return selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private func navigate(by step: Int) {
        let cal = Calendar.current
        let component: Calendar.Component
        switch viewMode {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        selectedDate = cal.date(byAdding: component, value: step, to: selectedDate) ?? selectedDate
    }

    private func navigateToEvent(_ event: ScheduleEvent) {
        guard let id = event.modelID else { return }
        switch event.type {
        case .reminder: router.navigate(to: BarnRoute.reminderEdit(id), tab: .schedule)
        case .lesson: router.navigate(to: BarnRoute.lessonEdit(id), tab: .schedule)
        case .vet: router.navigate(to: BarnRoute.vetSchedule, tab: .schedule)
        case .farrier: router.navigate(to: BarnRoute.farrierSchedule, tab: .schedule)
        }
    }

    // MARK: - iOS Calendar

    #if os(iOS)

    private var iOSCalendar: some View {
        VStack(spacing: 0) {
            calendarControlBar
            Divider()
            calendarContent
                .frame(maxHeight: .infinity)
        }
        .background(Color.barnOffWhite)
    }

    private var calendarControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                Button { navigate(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(calendarTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Button("Today") { selectedDate = .now }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.barnGreen)
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)

                Button { navigate(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)

            Picker("View", selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Color.systemBackground)
    }

    @ViewBuilder
    private var calendarContent: some View {
        switch viewMode {
        case .month:
            CalendarMonthView(
                eventsByDay: eventsByDay,
                monthStart: monthStart,
                selectedDate: selectedDate,
                onDateSelected: { selectedDate = $0 },
                onEventTapped: navigateToEvent
            )
        case .week:
            CalendarWeekView(
                eventsByDay: eventsByDay,
                weekStart: weekStart,
                selectedDate: selectedDate,
                onDateSelected: { date in selectedDate = date; viewMode = .day },
                onEventTapped: navigateToEvent
            )
        case .day:
            CalendarDayView(
                events: eventsForDay(selectedDate),
                date: selectedDate,
                onEventTapped: navigateToEvent
            )
        }
    }

    private var categoriesMenu: some View {
        Menu {
            Button { router.navigate(to: BarnRoute.reminders, tab: .schedule) } label: {
                Label("Reminders", systemImage: "bell.fill")
            }
            Button { router.navigate(to: BarnRoute.vetSchedule, tab: .schedule) } label: {
                Label("Vet Schedule", systemImage: "cross.case.fill")
            }
            Button { router.navigate(to: BarnRoute.farrierSchedule, tab: .schedule) } label: {
                Label("Farrier Schedule", systemImage: "hammer.fill")
            }
            Button { router.navigate(to: BarnRoute.barnNotes, tab: .schedule) } label: {
                Label("Barn Notes", systemImage: "note.text")
            }
            Button { router.navigate(to: BarnRoute.lessons, tab: .schedule) } label: {
                Label("Lessons", systemImage: "book.fill")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
    }

    private var addEventMenu: some View {
        Menu {
            Button { router.navigate(to: BarnRoute.reminderEdit(nil), tab: .schedule) } label: {
                Label("Reminder", systemImage: "bell.fill")
            }
            Button { router.navigate(to: BarnRoute.addVetRecord, tab: .schedule) } label: {
                Label("Vet Appointment", systemImage: "cross.case.fill")
            }
            Button { router.navigate(to: BarnRoute.addFarrierVisit, tab: .schedule) } label: {
                Label("Farrier Visit", systemImage: "hammer.fill")
            }
            Button { router.navigate(to: BarnRoute.lessonEdit(nil), tab: .schedule) } label: {
                Label("Lesson", systemImage: "book.fill")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    #endif

    // MARK: - macOS Calendar

    #if os(macOS)

    private var macOSCalendar: some View {
        VStack(spacing: 0) {
            macOSCalendarHeader
            Divider()
            macOSCalendarContent
        }
        .background(Color.barnOffWhite)
    }

    private var macOSCalendarHeader: some View {
        HStack(spacing: 12) {
            Button { navigate(by: -1) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Text(calendarTitle)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 180)

            Button { navigate(by: 1) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Button("Today") { selectedDate = .now }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Spacer()

            Picker("View", selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            if viewMode == .month {
                HStack(spacing: 12) {
                    ForEach(ScheduleEventType.allCases, id: \.self) { type in
                        HStack(spacing: 4) {
                            Circle().fill(type.color).frame(width: 8, height: 8)
                            Text(type.label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var macOSCalendarContent: some View {
        switch viewMode {
        case .month:
            HStack(spacing: 0) {
                CalendarMonthView(
                    eventsByDay: eventsByDay,
                    monthStart: monthStart,
                    selectedDate: selectedDate,
                    onDateSelected: { selectedDate = $0 },
                    onEventTapped: navigateToEvent,
                    showEventsList: false
                )
                .frame(maxWidth: .infinity)

                Divider()

                dayDetailPanel
                    .frame(width: 280)
            }
        case .week:
            CalendarWeekView(
                eventsByDay: eventsByDay,
                weekStart: weekStart,
                selectedDate: selectedDate,
                onDateSelected: { date in selectedDate = date; viewMode = .day },
                onEventTapped: navigateToEvent
            )
        case .day:
            CalendarDayView(
                events: eventsForDay(selectedDate),
                date: selectedDate,
                onEventTapped: navigateToEvent
            )
        }
    }

    // MARK: Day Detail Panel (macOS month view)

    private var dayDetailPanel: some View {
        let cal = Calendar.current
        let selected = cal.startOfDay(for: selectedDate)
        let dayEvents = (eventsByDay[selected] ?? []).sorted { $0.date < $1.date }

        return VStack(alignment: .leading, spacing: 0) {
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
                            macOSEventRow(event)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }

            Divider()

            Menu {
                Button { router.navigate(to: BarnRoute.reminderEdit(nil), tab: .schedule) } label: {
                    Label("Reminder", systemImage: "bell.fill")
                }
                Button { router.navigate(to: BarnRoute.addVetRecord, tab: .schedule) } label: {
                    Label("Vet Appointment", systemImage: "cross.case.fill")
                }
                Button { router.navigate(to: BarnRoute.addFarrierVisit, tab: .schedule) } label: {
                    Label("Farrier Visit", systemImage: "hammer.fill")
                }
                Button { router.navigate(to: BarnRoute.lessonEdit(nil), tab: .schedule) } label: {
                    Label("Lesson", systemImage: "book.fill")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Event")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.barnGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .background(Color.barnCardBackground)
    }

    private func macOSEventRow(_ event: ScheduleEvent) -> some View {
        ScheduleEventRow(event: event, onTap: { navigateToEvent(event) }, showTime: false, verticalPadding: 6)
    }

    #endif
}
