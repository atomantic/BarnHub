import Foundation
import SwiftData

// Fetch descriptors and the derived values built from them for Home, Schedule
// and Accounting (#32). Each screen fetches only the rows it shows (a date range,
// a limit, a predicate) instead of loading whole tables and filtering in Swift,
// and builds its derived values once per render. The descriptors live here so
// the views' `@Query`s and the performance tests run the same fetches.

// MARK: - Date ranges

extension Calendar {
    /// The calendar month containing `date`, as `[start, end)`.
    func monthInterval(containing date: Date) -> DateInterval {
        let start = self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
        let end = self.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// The days picked in a pair of date-only pickers, `start` day through `end`
    /// day, as `[startOfDay(start), startOfDay(end) + 1 day)`. Date pickers keep
    /// the time of day they were created with, so comparing the raw dates would
    /// drop records later on the end day or earlier on the start day. Empty (at
    /// the start day) when `end` is before `start`.
    func dayRange(from start: Date, through end: Date) -> DateInterval {
        let first = startOfDay(for: start)
        let afterLast = date(byAdding: .day, value: 1, to: startOfDay(for: end)) ?? first
        return DateInterval(start: first, end: max(first, afterLast))
    }
}

// MARK: - Transactions

extension Transaction {
    /// Stored raw value of an income transaction. Anything else reads back as an
    /// expense (see `type`), so expense predicates test `!= incomeRaw`.
    static let incomeRaw = TransactionType.income.rawValue

    /// Transactions dated in `[start, end)`.
    static func dated(from start: Date, before end: Date) -> Predicate<Transaction> {
        #Predicate<Transaction> { $0.date >= start && $0.date < end }
    }

    /// The All Transactions filters: optional type and category, and dates in
    /// `range` (`[start, end)`, see `Calendar.dayRange`). Unknown stored raw values
    /// match the same filters their computed `type` / `category` fall back to
    /// (expense / other).
    static func listPredicate(
        type: TransactionType?,
        category: TransactionCategory?,
        in range: DateInterval
    ) -> Predicate<Transaction> {
        let start = range.start
        let end = range.end
        let incomeRaw = Self.incomeRaw
        let anyType = type == nil
        let wantsIncome = type == .income
        let wantsExpense = type == .expense
        let anyCategory = category == nil
        let categoryRaw = category?.rawValue ?? ""
        let matchesUnknownCategory = category == .other
        let knownCategories = TransactionCategory.allCases.map(\.rawValue)
        return #Predicate<Transaction> { txn in
            txn.date >= start && txn.date < end
                && (anyType
                    || (wantsIncome && txn.typeRaw == incomeRaw)
                    || (wantsExpense && txn.typeRaw != incomeRaw))
                && (anyCategory
                    || txn.categoryRaw == categoryRaw
                    || (matchesUnknownCategory && !knownCategories.contains(txn.categoryRaw)))
        }
    }

    /// A client's transactions.
    static func forClient(_ clientID: PersistentIdentifier) -> Predicate<Transaction> {
        #Predicate<Transaction> { $0.client?.persistentModelID == clientID }
    }
}

/// Income, expenses and balance of a set of transactions, in one pass.
struct TransactionTotals: Equatable {
    var income: Double = 0
    var expenses: Double = 0
    var balance: Double { income - expenses }

    init(income: Double = 0, expenses: Double = 0) {
        self.income = income
        self.expenses = expenses
    }

    init(_ transactions: [Transaction]) {
        for txn in transactions {
            if txn.type == .income { income += txn.amount } else { expenses += txn.amount }
        }
    }

    /// Every transaction in the store. Fetches only the amount and type columns,
    /// so it stays cheap enough to run after a save rather than on every render.
    static func allTime(in context: ModelContext) -> TransactionTotals {
        var descriptor = FetchDescriptor<Transaction>()
        descriptor.propertiesToFetch = [\.amount, \.typeRaw]
        let all = (try? context.fetch(descriptor)) ?? []
        return TransactionTotals(all)
    }
}

/// The all-time balance, recomputed only when the data has changed since the
/// last read (`version` is bumped on every save and CloudKit import). A class so
/// a view's body can fill it on demand without invalidating its own state.
final class AllTimeBalanceCache {
    private var cached: (version: Int, balance: Double)?

    func balance(version: Int, context: ModelContext) -> Double {
        if let cached, cached.version == version { return cached.balance }
        let balance = TransactionTotals.allTime(in: context).balance
        cached = (version, balance)
        return balance
    }
}

// MARK: - Superseded care records

/// A vet, farrier or dentist record. A horse's newest record (by visit date,
/// then next due date) supersedes the `nextDueDate` of every older one, the same
/// rule NotificationService uses when scheduling.
protocol HorseCareRecord: PersistentModel {
    var date: Date { get }
    var nextDueDate: Date? { get }
    var horse: Horse? { get }
}

extension VetRecord: HorseCareRecord {}
extension FarrierVisit: HorseCareRecord {}
extension DentistVisit: HorseCareRecord {}

extension HorseCareRecord {
    /// Orders a horse's records: visit date, then next due date.
    var supersedeKey: SupersedeKey { SupersedeKey(date: date, due: nextDueDate ?? .distantPast) }
}

struct SupersedeKey: Comparable {
    let date: Date
    let due: Date
    static func < (lhs: SupersedeKey, rhs: SupersedeKey) -> Bool { (lhs.date, lhs.due) < (rhs.date, rhs.due) }
}

/// Each horse's newest vet, farrier and dentist record key. Built from one
/// fetch per kind, which is far cheaper than walking every horse's to-many
/// relationships (and, measured, cheaper than a partial fetch with prefetching).
struct NewestCareRecords {
    var vet: [PersistentIdentifier: SupersedeKey] = [:]
    var farrier: [PersistentIdentifier: SupersedeKey] = [:]
    var dentist: [PersistentIdentifier: SupersedeKey] = [:]

    static func fetch(in context: ModelContext) -> NewestCareRecords {
        func newest<R: HorseCareRecord>(_ type: R.Type, _ descriptor: FetchDescriptor<R>) -> [PersistentIdentifier: SupersedeKey] {
            var result: [PersistentIdentifier: SupersedeKey] = [:]
            for record in (try? context.fetch(descriptor)) ?? [] {
                guard let horseID = record.horse?.persistentModelID else { continue }
                let key = record.supersedeKey
                if let current = result[horseID], current >= key { continue }
                result[horseID] = key
            }
            return result
        }
        return NewestCareRecords(
            vet: newest(VetRecord.self, FetchDescriptor()),
            farrier: newest(FarrierVisit.self, FetchDescriptor()),
            dentist: newest(DentistVisit.self, FetchDescriptor())
        )
    }

    /// `records` without the superseded ones, in the same order. A record whose
    /// horse isn't in `newest` (not saved yet) or that has no horse is current.
    static func current<R: HorseCareRecord>(_ records: [R], newest: [PersistentIdentifier: SupersedeKey]) -> [R] {
        records.filter { record in
            guard let horseID = record.horse?.persistentModelID, let latest = newest[horseID] else { return true }
            return record.supersedeKey >= latest
        }
    }
}

/// `NewestCareRecords`, rebuilt only when the data has changed since the last
/// read (`version` is bumped on every save and CloudKit import). A class so a
/// view's body can fill it on demand without invalidating its own state.
final class NewestCareRecordsCache {
    private var cached: (version: Int, value: NewestCareRecords)?

    func value(version: Int, context: ModelContext) -> NewestCareRecords {
        if let cached, cached.version == version { return cached.value }
        let value = NewestCareRecords.fetch(in: context)
        cached = (version, value)
        return value
    }
}

// MARK: - Fetch descriptors

enum DashboardQueries {
    static let onceRaw = ReminderFrequency.once.rawValue

    static func vetDue(from start: Date, through end: Date) -> FetchDescriptor<VetRecord> {
        let past = Date.distantPast
        return FetchDescriptor(
            predicate: #Predicate<VetRecord> { ($0.nextDueDate ?? past) >= start && ($0.nextDueDate ?? past) <= end },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
    }

    static func farrierDue(from start: Date, through end: Date) -> FetchDescriptor<FarrierVisit> {
        let past = Date.distantPast
        return FetchDescriptor(
            predicate: #Predicate<FarrierVisit> { ($0.nextDueDate ?? past) >= start && ($0.nextDueDate ?? past) <= end },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
    }

    static func dentistDue(from start: Date, through end: Date) -> FetchDescriptor<DentistVisit> {
        let past = Date.distantPast
        return FetchDescriptor(
            predicate: #Predicate<DentistVisit> { ($0.nextDueDate ?? past) >= start && ($0.nextDueDate ?? past) <= end },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
    }

    // Every record with a next due date, soonest first: the Vet, Farrier and
    // Dentist Schedule lists, before superseded records are dropped (#50).

    static var vetScheduled: FetchDescriptor<VetRecord> {
        FetchDescriptor(predicate: #Predicate<VetRecord> { $0.nextDueDate != nil }, sortBy: [SortDescriptor(\.nextDueDate)])
    }

    static var farrierScheduled: FetchDescriptor<FarrierVisit> {
        FetchDescriptor(predicate: #Predicate<FarrierVisit> { $0.nextDueDate != nil }, sortBy: [SortDescriptor(\.nextDueDate)])
    }

    static var dentistScheduled: FetchDescriptor<DentistVisit> {
        FetchDescriptor(predicate: #Predicate<DentistVisit> { $0.nextDueDate != nil }, sortBy: [SortDescriptor(\.nextDueDate)])
    }

    /// Incomplete reminders due in `[start, end]`.
    static func reminders(from start: Date, through end: Date) -> FetchDescriptor<Reminder> {
        FetchDescriptor(
            predicate: #Predicate<Reminder> { !$0.isCompleted && $0.dueDate >= start && $0.dueDate <= end },
            sortBy: [SortDescriptor(\.dueDate)]
        )
    }

    /// Incomplete reminders due before `end`, which includes every overdue one.
    static func reminders(before end: Date) -> FetchDescriptor<Reminder> {
        FetchDescriptor(
            predicate: #Predicate<Reminder> { !$0.isCompleted && $0.dueDate < end },
            sortBy: [SortDescriptor(\.dueDate)]
        )
    }

    /// Lessons that can have a calendar occurrence in `[start, end]`: one-off
    /// lessons whose `nextDate` falls in it, and recurring series that have
    /// started by `end`. Rows with an unknown frequency are included and then
    /// treated as one-off by `Lesson.occurrences`.
    static func calendarLessons(from start: Date, through end: Date) -> FetchDescriptor<Lesson> {
        let onceRaw = Self.onceRaw
        let past = Date.distantPast
        return FetchDescriptor(predicate: #Predicate<Lesson> { lesson in
            (lesson.frequencyRaw != onceRaw && (lesson.nextDate ?? lesson.date) <= end)
                || ((lesson.nextDate ?? past) >= start && (lesson.nextDate ?? past) <= end)
        })
    }

    /// Lessons Home can list in `[start, end)`: one-off lessons by their lesson
    /// `date` (see `Lesson.homeDates`) and recurring series started by `end`.
    static func homeLessons(from start: Date, before end: Date) -> FetchDescriptor<Lesson> {
        let onceRaw = Self.onceRaw
        return FetchDescriptor(
            predicate: #Predicate<Lesson> { lesson in
                (lesson.frequencyRaw != onceRaw && (lesson.nextDate ?? lesson.date) < end)
                    || (lesson.date >= start && lesson.date < end)
            },
            sortBy: [SortDescriptor(\.date)]
        )
    }

    /// Unpaid lessons that have happened (dated at or before `end`), newest first.
    static func unpaidLessons(through end: Date, limit: Int) -> FetchDescriptor<Lesson> {
        var descriptor = FetchDescriptor(
            predicate: #Predicate<Lesson> { !$0.isPaid && $0.cost > 0 && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    static var lowStockSupplies: FetchDescriptor<SupplyItem> {
        FetchDescriptor(predicate: #Predicate<SupplyItem> { $0.quantity <= $0.reorderThreshold })
    }

    static func transactions(in interval: DateInterval) -> FetchDescriptor<Transaction> {
        FetchDescriptor(
            predicate: Transaction.dated(from: interval.start, before: interval.end),
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
    }

    static func recentTransactions(limit: Int) -> FetchDescriptor<Transaction> {
        var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }
}

// MARK: - Home summary

/// Everything Home shows that is derived from records, computed once per render
/// from the bounded fetches Home runs (see `HomeSummary.Window`).
struct HomeSummary {
    /// The fetch bounds as of `anchor`. Home rebuilds its queries when it appears,
    /// returns to the foreground or the date changes; the exact "now" cut-offs
    /// are applied when the summary is computed, so a later render stays correct.
    struct Window: Equatable {
        let anchor: Date
        let today: Date
        let month: DateInterval
        /// Lessons and reminders for the "Today & Tomorrow" list.
        let soonEnd: Date
        /// Care records due within a week of any time today, with slack.
        let dueEnd: Date

        init(anchor: Date, calendar: Calendar = .current) {
            let start = calendar.startOfDay(for: anchor)
            self.anchor = anchor
            self.today = start
            self.month = FinanceSummary.currentMonth(asOf: start, calendar: calendar)
            self.soonEnd = calendar.date(byAdding: .day, value: 2, to: start) ?? start
            self.dueEnd = calendar.date(byAdding: .day, value: 8, to: start) ?? start
        }
    }

    enum UpcomingKind { case lesson, vet, farrier, reminder }

    struct Upcoming: Identifiable {
        let id: ScheduleEventID
        let kind: UpcomingKind
        let date: Date
        let title: String
        let subtitle: String?
    }

    struct Inputs {
        var monthTransactions: [Transaction] = []
        var reminders: [Reminder] = []
        var lessons: [Lesson] = []
        var unpaidLessons: [Lesson] = []
        var vetRecords: [VetRecord] = []
        var farrierVisits: [FarrierVisit] = []
        var dentistVisits: [DentistVisit] = []
        var lowStock: [SupplyItem] = []
        var newest = NewestCareRecords()
    }

    static let unpaidLimit = 4

    let month: TransactionTotals
    let nextScheduleItemToday: String?
    let upcoming: [Upcoming]
    let todayReminders: [Reminder]
    let overdueReminders: [Reminder]
    let unpaidLessons: [Lesson]
    let lowStock: [SupplyItem]
    let upcomingVet: [VetRecord]
    let upcomingFarrier: [FarrierVisit]

    init(_ inputs: Inputs, now: Date = .now, calendar: Calendar = .current) {
        month = TransactionTotals(inputs.monthTransactions)
        lowStock = inputs.lowStock
        unpaidLessons = inputs.unpaidLessons.filter { $0.date <= now }

        let vet = NewestCareRecords.current(inputs.vetRecords, newest: inputs.newest.vet)
        let farrier = NewestCareRecords.current(inputs.farrierVisits, newest: inputs.newest.farrier)
        let dentist = NewestCareRecords.current(inputs.dentistVisits, newest: inputs.newest.dentist)

        // Reminders: overdue for Action Items, today/tomorrow for the iPhone list.
        overdueReminders = inputs.reminders.filter { $0.dueDate < now }
        todayReminders = Array(inputs.reminders.lazy
            .filter { $0.dueDate >= now && (calendar.isDateInToday($0.dueDate) || calendar.isDateInTomorrow($0.dueDate)) }
            .prefix(3))

        // Alerts: care due within a week.
        let weekOut = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        upcomingVet = vet.filter { $0.nextDueDate.map { $0 >= now && $0 <= weekOut } ?? false }
        upcomingFarrier = farrier.filter { $0.nextDueDate.map { $0 >= now && $0 <= weekOut } ?? false }

        // Schedule tile: the next thing still to come today, e.g. "3:30 PM Lesson",
        // with the time in the app language's style (not cached; see CLAUDE.md).
        let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened, locale: .app, calendar: calendar, timeZone: calendar.timeZone)
        func time(_ date: Date) -> String { date.formatted(timeStyle) }
        let startOfToday = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        var next: (date: Date, label: String)?
        func consider(_ date: Date, _ label: String) {
            if next == nil || date < next!.date { next = (date, label) }
        }
        for lesson in inputs.lessons {
            for date in lesson.homeDates(from: now, before: tomorrow, calendar: calendar) {
                consider(date, appLocalized("\(time(date)) Lesson", comment: "Home Schedule tile: time of the next lesson today"))
            }
        }
        func considerDue(_ due: Date?, _ label: (String) -> String) {
            guard let due, calendar.isDateInToday(due), due >= now else { return }
            consider(due, label(time(due)))
        }
        for record in vet {
            considerDue(record.nextDueDate) { appLocalized("\($0) Vet", comment: "Home Schedule tile: time of the next vet visit due today") }
        }
        for visit in farrier {
            considerDue(visit.nextDueDate) { appLocalized("\($0) Farrier", comment: "Home Schedule tile: time of the next farrier visit due today") }
        }
        for visit in dentist {
            considerDue(visit.nextDueDate) { appLocalized("\($0) Dentist", comment: "Home Schedule tile: time of the next dentist visit due today") }
        }
        nextScheduleItemToday = next?.label

        // Today & Tomorrow widget.
        let cutoff = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? now
        var events: [Upcoming] = []
        let lessonTitle = appLocalized("Lesson", comment: "Dashboard event type")
        for lesson in inputs.lessons {
            let dates = lesson.homeDates(from: now, before: cutoff, calendar: calendar)
            guard !dates.isEmpty else { continue }
            let subtitle = [lesson.client?.fullName, lesson.horse?.name].compactMap { $0 }.joined(separator: " • ")
            for date in dates {
                events.append(Upcoming(
                    id: ScheduleEventID(lesson.persistentModelID, occurrence: date), kind: .lesson, date: date,
                    title: lessonTitle, subtitle: subtitle.isEmpty ? nil : subtitle
                ))
            }
        }
        let vetTitle = appLocalized("Vet", comment: "Dashboard event type")
        for record in vet {
            guard let due = record.nextDueDate, due >= now, due < cutoff else { continue }
            events.append(Upcoming(
                id: ScheduleEventID(record.persistentModelID), kind: .vet, date: due,
                title: vetTitle, subtitle: record.horse?.name
            ))
        }
        let farrierTitle = appLocalized("Farrier", comment: "Dashboard event type")
        for visit in farrier {
            guard let due = visit.nextDueDate, due >= now, due < cutoff else { continue }
            events.append(Upcoming(
                id: ScheduleEventID(visit.persistentModelID), kind: .farrier, date: due,
                title: farrierTitle, subtitle: visit.horse?.name
            ))
        }
        let reminderFallback = appLocalized("Reminder", comment: "Dashboard event type")
        for reminder in inputs.reminders where reminder.dueDate >= now && reminder.dueDate < cutoff {
            events.append(Upcoming(
                id: ScheduleEventID(reminder.persistentModelID), kind: .reminder, date: reminder.dueDate,
                title: reminder.title.isEmpty ? reminderFallback : reminder.title, subtitle: reminder.horse?.name
            ))
        }
        upcoming = events.sorted { $0.date < $1.date }
    }

    /// Runs Home's fetches directly, for tests and measurement.
    static func fetchInputs(in context: ModelContext, window: Window, newest: NewestCareRecords? = nil) throws -> Inputs {
        Inputs(
            monthTransactions: try context.fetch(DashboardQueries.transactions(in: window.month)),
            reminders: try context.fetch(DashboardQueries.reminders(before: window.soonEnd)),
            lessons: try context.fetch(DashboardQueries.homeLessons(from: window.today, before: window.soonEnd)),
            unpaidLessons: try context.fetch(DashboardQueries.unpaidLessons(through: window.anchor, limit: unpaidLimit)),
            vetRecords: try context.fetch(DashboardQueries.vetDue(from: window.today, through: window.dueEnd)),
            farrierVisits: try context.fetch(DashboardQueries.farrierDue(from: window.today, through: window.dueEnd)),
            dentistVisits: try context.fetch(DashboardQueries.dentistDue(from: window.today, through: window.dueEnd)),
            lowStock: try context.fetch(DashboardQueries.lowStockSupplies),
            newest: newest ?? NewestCareRecords.fetch(in: context)
        )
    }
}

// MARK: - Schedule events

/// Identity of a calendar or dashboard event: the record, plus the occurrence
/// date for a recurring lesson.
struct ScheduleEventID: Hashable {
    let modelID: PersistentIdentifier
    let occurrence: Date?

    init(_ modelID: PersistentIdentifier, occurrence: Date? = nil) {
        self.modelID = modelID
        self.occurrence = occurrence
    }
}

/// Calendar events grouped by start of day, each day sorted by time.
struct ScheduleEventIndex {
    let byDay: [Date: [ScheduleEvent]]

    func events(on date: Date, calendar: Calendar = .current) -> [ScheduleEvent] {
        byDay[calendar.startOfDay(for: date)] ?? []
    }

    struct Inputs {
        var reminders: [Reminder] = []
        var vetRecords: [VetRecord] = []
        var farrierVisits: [FarrierVisit] = []
        var dentistVisits: [DentistVisit] = []
        var lessons: [Lesson] = []
        var newest = NewestCareRecords()
    }

    /// The fetch window for the calendar showing `date`: its month plus a week
    /// either side, which covers the day, week and month grids.
    static func window(around date: Date, calendar: Calendar = .current) -> DateInterval {
        let month = calendar.monthInterval(containing: date)
        let start = calendar.date(byAdding: .day, value: -7, to: month.start) ?? month.start
        let end = calendar.date(byAdding: .day, value: 7, to: month.end) ?? month.end
        return DateInterval(start: start, end: end)
    }

    init(_ inputs: Inputs, window: DateInterval, calendar: Calendar = .current) {
        var events: [ScheduleEvent] = []
        events.reserveCapacity(inputs.reminders.count + inputs.vetRecords.count
            + inputs.farrierVisits.count + inputs.dentistVisits.count + inputs.lessons.count)

        for reminder in inputs.reminders {
            events.append(ScheduleEvent(
                id: ScheduleEventID(reminder.persistentModelID),
                date: reminder.dueDate,
                title: reminder.title,
                subtitle: reminder.horse?.name,
                type: .reminder,
                modelID: reminder.persistentModelID,
                durationMinutes: 30
            ))
        }

        let unknownHorse = appLocalized("Unknown Horse", comment: "Fallback horse name")
        let noClient = appLocalized("No Client", comment: "Calendar lesson title when the lesson has no client")
        func appendCare<R: HorseCareRecord>(
            _ records: [R], newest: [PersistentIdentifier: SupersedeKey], type: ScheduleEventType,
            title: (String) -> String, provider: (R) -> String
        ) {
            for record in NewestCareRecords.current(records, newest: newest) {
                guard let dueDate = record.nextDueDate else { continue }
                events.append(ScheduleEvent(
                    id: ScheduleEventID(record.persistentModelID),
                    date: dueDate,
                    title: title(record.horse?.name ?? unknownHorse),
                    subtitle: provider(record),
                    type: type,
                    modelID: record.persistentModelID,
                    durationMinutes: 60
                ))
            }
        }
        appendCare(inputs.vetRecords, newest: inputs.newest.vet, type: .vet,
                   title: { appLocalized("Vet: \($0)", comment: "Calendar event title for a vet visit coming due: the horse's name") }) { $0.vetName }
        appendCare(inputs.farrierVisits, newest: inputs.newest.farrier, type: .farrier,
                   title: { appLocalized("Farrier: \($0)", comment: "Calendar event title for a farrier visit coming due: the horse's name") }) { $0.farrierName }
        appendCare(inputs.dentistVisits, newest: inputs.newest.dentist, type: .dentist,
                   title: { appLocalized("Dentist: \($0)", comment: "Calendar event title for a dentist visit coming due: the horse's name") }) { $0.dentistName }

        for lesson in inputs.lessons {
            let occurrences = lesson.occurrences(from: window.start, to: window.end, calendar: calendar)
            guard !occurrences.isEmpty else { continue }
            let subtitle = lesson.horse.map {
                appLocalized("\(lesson.lessonType.displayName) on \($0.name)", comment: "Calendar lesson subtitle: lesson type, then the horse ridden (e.g. 'Private on Star')")
            } ?? lesson.lessonType.displayName
            let title = lesson.client?.fullName ?? noClient
            for occurrence in occurrences {
                events.append(ScheduleEvent(
                    id: ScheduleEventID(lesson.persistentModelID, occurrence: occurrence),
                    date: occurrence,
                    title: title,
                    subtitle: subtitle,
                    type: .lesson,
                    modelID: lesson.persistentModelID,
                    durationMinutes: lesson.duration
                ))
            }
        }

        var grouped: [Date: [ScheduleEvent]] = [:]
        for event in events {
            grouped[calendar.startOfDay(for: event.date), default: []].append(event)
        }
        for day in grouped.keys {
            grouped[day]?.sort { $0.date < $1.date }
        }
        byDay = grouped
    }

    /// Runs the calendar's fetches directly, for tests and measurement.
    static func fetchInputs(in context: ModelContext, window: DateInterval, newest: NewestCareRecords? = nil) throws -> Inputs {
        Inputs(
            reminders: try context.fetch(DashboardQueries.reminders(from: window.start, through: window.end)),
            vetRecords: try context.fetch(DashboardQueries.vetDue(from: window.start, through: window.end)),
            farrierVisits: try context.fetch(DashboardQueries.farrierDue(from: window.start, through: window.end)),
            dentistVisits: try context.fetch(DashboardQueries.dentistDue(from: window.start, through: window.end)),
            lessons: try context.fetch(DashboardQueries.calendarLessons(from: window.start, through: window.end)),
            newest: newest ?? NewestCareRecords.fetch(in: context)
        )
    }
}
