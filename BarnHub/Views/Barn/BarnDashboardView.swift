import SwiftUI
import SwiftData
import Combine

// MARK: - Calendar View Mode

enum CalendarViewMode: String, CaseIterable {
    case day, week, month

    var displayName: String {
        switch self {
        case .day:   return appLocalized("Day",   comment: "Calendar view mode")
        case .week:  return appLocalized("Week",  comment: "Calendar view mode")
        case .month: return appLocalized("Month", comment: "Calendar view mode")
        }
    }
}

// MARK: - Schedule Event Types

enum ScheduleEventType: String, CaseIterable {
    case reminder, vet, farrier, dentist, lesson

    var color: Color {
        switch self {
        case .reminder: .barnGreen
        case .vet: .red
        case .farrier: .orange
        case .dentist: .purple
        case .lesson: .blue
        }
    }

    var icon: String {
        switch self {
        case .reminder: "bell.fill"
        case .vet: "cross.case.fill"
        case .farrier: "hammer.fill"
        case .dentist: "mouth.fill"
        case .lesson: "book.fill"
        }
    }

    var label: String {
        switch self {
        case .reminder: return appLocalized("Reminder", comment: "Schedule event type")
        case .vet:      return appLocalized("Vet",      comment: "Schedule event type")
        case .farrier:  return appLocalized("Farrier",  comment: "Schedule event type")
        case .dentist:  return appLocalized("Dentist",  comment: "Schedule event type")
        case .lesson:   return appLocalized("Lesson",   comment: "Schedule event type")
        }
    }
}

// MARK: - Schedule Event

struct ScheduleEvent: Identifiable {
    let id: ScheduleEventID
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

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    // Remembered across launches (and settable via launch argument for screenshots).
    @AppStorage("net.shadowpuppet.BarnBook.schedule.viewMode") private var viewMode: CalendarViewMode = .week
    @State private var selectedDate: Date = .now

    var body: some View {
        // Events are fetched for the visible month (plus a week either side) and
        // built once per render, not from every record in the store (#32).
        ScheduleEventsQuery(window: ScheduleEventIndex.window(around: selectedDate)) { index in
            #if os(macOS)
            macOSCalendar(index)
            #else
            iOSCalendar(index)
            #endif
        }
        .navigationTitle("Schedule")
        #if !os(macOS)
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) { categoriesMenu }
        }
        .prioritizedToolbarItem(.high, placement: .trailingBar) { addEventMenu }
        #endif
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

    @ViewBuilder
    private var calendarTitleView: some View {
        switch viewMode {
        case .day:
            Text(selectedDate, format: .dateTime.weekday(.wide)) + Text(", ") + Text(selectedDate, format: .dateTime.month(.abbreviated).day())
        case .week:
            let start = weekStart
            let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
            let sameMonth = Calendar.current.component(.month, from: start) == Calendar.current.component(.month, from: end)
            if sameMonth {
                Text(start, format: .dateTime.month(.abbreviated).day()) + Text(" – ") + Text(end, format: .dateTime.day())
            } else {
                Text(start, format: .dateTime.month(.abbreviated).day()) + Text(" – ") + Text(end, format: .dateTime.month(.abbreviated).day())
            }
        case .month:
            Text(selectedDate, format: .dateTime.month(.wide).year())
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
        case .dentist: router.navigate(to: BarnRoute.dentistSchedule, tab: .schedule)
        }
    }

    // MARK: - iOS Calendar

    #if os(iOS)

    /// At regular width (iPad, iPhone Duo inner display) Month and Week show the
    /// selected day's events beside the calendar instead of drilling into Day view.
    private var showsDayPanel: Bool {
        sizeClass == .regular && viewMode != .day
    }

    @ViewBuilder
    private func iOSCalendar(_ index: ScheduleEventIndex) -> some View {
        if showsDayPanel, #available(iOS 27.1, *) {
            // ArrangementView places the split on the hinge (and accounts for the
            // vertical tab bar), which a plain HStack of equal halves can't do.
            // Allow both axes: side by side when wide, calendar above the day
            // panel when tall (inner display in portrait). Limiting it to the
            // horizontal axis hid the day panel in portrait (#19).
            ArrangementView {
                calendarColumn(index)
            } secondary: {
                dayDetailPanel(index)
            }
            .arrangementViewStyle(.split)
            .background(Color.barnOffWhite)
        } else {
            HStack(spacing: 0) {
                calendarColumn(index)
                    .frame(maxWidth: .infinity)

                if showsDayPanel {
                    Divider()
                    dayDetailPanel(index)
                        .frame(maxWidth: .infinity)
                }
            }
            .background(Color.barnOffWhite)
        }
    }

    private func calendarColumn(_ index: ScheduleEventIndex) -> some View {
        VStack(spacing: 0) {
            calendarControlBar
            Divider()
            calendarContent(index)
                .frame(maxHeight: .infinity)
        }
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

                calendarTitleView
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

            Picker(selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 10)
        .background(Color.systemBackground)
    }

    @ViewBuilder
    private func calendarContent(_ index: ScheduleEventIndex) -> some View {
        switch viewMode {
        case .month:
            CalendarMonthView(
                eventsByDay: index.byDay,
                monthStart: monthStart,
                selectedDate: selectedDate,
                onDateSelected: { selectedDate = $0 },
                onEventTapped: navigateToEvent,
                showEventsList: !showsDayPanel
            )
        case .week:
            CalendarWeekView(
                eventsByDay: index.byDay,
                weekStart: weekStart,
                selectedDate: selectedDate,
                onDateSelected: { date in
                    selectedDate = date
                    if !showsDayPanel { viewMode = .day }
                },
                onEventTapped: navigateToEvent
            )
        case .day:
            CalendarDayView(
                events: index.events(on: selectedDate),
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
            Button { router.navigate(to: BarnRoute.dentistSchedule, tab: .schedule) } label: {
                Label("Dentist Schedule", systemImage: "mouth.fill")
            }
            Button { router.navigate(to: BarnRoute.barnNotes, tab: .schedule) } label: {
                Label("Barn Notes", systemImage: "note.text")
            }
            Button { router.navigate(to: BarnRoute.lessons, tab: .schedule) } label: {
                Label("Lessons", systemImage: "book.fill")
            }
            Button { router.navigate(to: BarnRoute.feedProducts, tab: .schedule) } label: {
                Label("Feed Products", systemImage: "leaf.fill")
            }
        } label: {
            Label("Browse", systemImage: "line.3.horizontal")
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
            Button { router.navigate(to: BarnRoute.addDentistVisit, tab: .schedule) } label: {
                Label("Dentist Visit", systemImage: "mouth.fill")
            }
            Button { router.navigate(to: BarnRoute.lessonEdit(nil), tab: .schedule) } label: {
                Label("Lesson", systemImage: "book.fill")
            }
        } label: {
            Label("Add Event", systemImage: "plus")
        }
    }

    #endif

    // MARK: - macOS Calendar

    #if os(macOS)

    private func macOSCalendar(_ index: ScheduleEventIndex) -> some View {
        VStack(spacing: 0) {
            macOSCalendarHeader
            Divider()
            macOSCalendarContent(index)
        }
        .background(Color.barnOffWhite)
    }

    private var macOSCalendarHeader: some View {
        HStack(spacing: 12) {
            Button { navigate(by: -1) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            calendarTitleView
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

            Picker(selection: $viewMode) {
                ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            HStack(spacing: 12) {
                ForEach(ScheduleEventType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Circle().fill(type.color).frame(width: 8, height: 8)
                        Text(type.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func macOSCalendarContent(_ index: ScheduleEventIndex) -> some View {
        HStack(spacing: 0) {
            Group {
                switch viewMode {
                case .month:
                    CalendarMonthView(
                        eventsByDay: index.byDay,
                        monthStart: monthStart,
                        selectedDate: selectedDate,
                        onDateSelected: { selectedDate = $0 },
                        onEventTapped: navigateToEvent,
                        showEventsList: false
                    )
                case .week:
                    CalendarWeekView(
                        eventsByDay: index.byDay,
                        weekStart: weekStart,
                        selectedDate: selectedDate,
                        onDateSelected: { selectedDate = $0 },
                        onEventTapped: navigateToEvent
                    )
                case .day:
                    CalendarDayView(
                        events: index.events(on: selectedDate),
                        date: selectedDate,
                        onEventTapped: navigateToEvent
                    )
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            dayDetailPanel(index)
                .frame(width: 280)
        }
    }

    #endif

    // MARK: Day Detail Panel (macOS, and iOS at regular width — e.g. iPhone Duo inner display)

    private func dayDetailPanel(_ index: ScheduleEventIndex) -> some View {
        let dayEvents = index.events(on: selectedDate)

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(selectedDate, format: .dateTime.month(.wide).day())
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
                            dayPanelEventRow(event)
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
                Button { router.navigate(to: BarnRoute.addDentistVisit, tab: .schedule) } label: {
                    Label("Dentist Visit", systemImage: "mouth.fill")
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

    private func dayPanelEventRow(_ event: ScheduleEvent) -> some View {
        ScheduleEventRow(event: event, onTap: { navigateToEvent(event) }, showTime: false, verticalPadding: 6)
    }
}

// MARK: - Event Query

/// Fetches the calendar's records for `window` only and builds the event index
/// once per render. Superseded vet, farrier and dentist due dates (an older
/// visit whose horse has had a newer one) are left out, as in notifications.
private struct ScheduleEventsQuery<Content: View>: View {
    let window: DateInterval
    private let content: (ScheduleEventIndex) -> Content

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncMonitor.self) private var syncMonitor
    /// Bumped on every save and CloudKit import, so the newest-record map (not a
    /// `@Query`) is rebuilt only when the data changes, not on every render.
    @State private var dataVersion = 0
    @State private var newestCare = NewestCareRecordsCache()

    @Query private var reminders: [Reminder]
    @Query private var vetRecords: [VetRecord]
    @Query private var farrierVisits: [FarrierVisit]
    @Query private var dentistVisits: [DentistVisit]
    @Query private var lessons: [Lesson]

    init(window: DateInterval, @ViewBuilder content: @escaping (ScheduleEventIndex) -> Content) {
        self.window = window
        self.content = content
        _reminders = Query(DashboardQueries.reminders(from: window.start, through: window.end))
        _vetRecords = Query(DashboardQueries.vetDue(from: window.start, through: window.end))
        _farrierVisits = Query(DashboardQueries.farrierDue(from: window.start, through: window.end))
        _dentistVisits = Query(DashboardQueries.dentistDue(from: window.start, through: window.end))
        _lessons = Query(DashboardQueries.calendarLessons(from: window.start, through: window.end))
    }

    var body: some View {
        content(ScheduleEventIndex(
            ScheduleEventIndex.Inputs(
                reminders: reminders,
                vetRecords: vetRecords,
                farrierVisits: farrierVisits,
                dentistVisits: dentistVisits,
                lessons: lessons,
                newest: newestCare.value(version: dataVersion, context: modelContext)
            ),
            window: window
        ))
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave).receive(on: RunLoop.main)) { _ in
            dataVersion &+= 1
        }
        .onChange(of: syncMonitor.lastSuccessfulSync) { dataVersion &+= 1 }
    }
}
