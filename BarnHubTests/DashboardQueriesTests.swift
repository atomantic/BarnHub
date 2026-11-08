import XCTest
import SwiftData
@testable import BarnHub

/// #32: Home, Schedule and Accounting fetch only what they show. These check the
/// predicates against a real (in-memory SQLite) store and that the bounded
/// fetches give the same answers as filtering every record in Swift did.
@MainActor
final class DashboardQueriesTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = Calendar.current

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func days(_ n: Double, from date: Date = .now) -> Date {
        date.addingTimeInterval(n * 86_400)
    }

    // MARK: - Transactions

    func testListPredicateFiltersTypeCategoryAndPickedDays() throws {
        // The pickers keep a time of day; the filter covers whole days.
        let start = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: days(-10))!
        let end = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: days(-1))!
        let range = calendar.dayRange(from: start, through: end)
        let income = Transaction(amount: 10, date: days(-5), category: .lesson, type: .income)
        let expense = Transaction(amount: 20, date: days(-5), category: .feed, type: .expense)
        let earlyOnStartDay = Transaction(amount: 30, date: calendar.startOfDay(for: start), category: .feed, type: .expense)
        let lateOnEndDay = Transaction(amount: 40, date: range.end.addingTimeInterval(-1), category: .feed, type: .expense)
        let tooOld = Transaction(amount: 50, date: range.start.addingTimeInterval(-1), category: .feed, type: .expense)
        let dayAfter = Transaction(amount: 70, date: range.end, category: .feed, type: .expense)
        // Unknown raw values read back as expense / other, and filter that way.
        let unknown = Transaction(amount: 60, date: days(-5))
        unknown.typeRaw = "refund"
        unknown.categoryRaw = "mystery"
        for txn in [income, expense, earlyOnStartDay, lateOnEndDay, tooOld, dayAfter, unknown] { context.insert(txn) }
        try context.save()

        func amounts(_ type: TransactionType?, _ category: TransactionCategory?) throws -> Set<Double> {
            let descriptor = FetchDescriptor(predicate: Transaction.listPredicate(type: type, category: category, in: range))
            return Set(try context.fetch(descriptor).map(\.amount))
        }
        XCTAssertEqual(try amounts(nil, nil), [10, 20, 30, 40, 60])
        XCTAssertEqual(try amounts(.income, nil), [10])
        XCTAssertEqual(try amounts(.expense, nil), [20, 30, 40, 60])
        XCTAssertEqual(try amounts(nil, .feed), [20, 30, 40])
        XCTAssertEqual(try amounts(nil, .other), [60])
        XCTAssertEqual(try amounts(.income, .feed), [])

        // Same answers as filtering in Swift.
        let all = try context.fetch(FetchDescriptor<Transaction>())
        for type in [nil] + TransactionType.allCases.map(Optional.some) {
            for category in [nil, .feed, .other, .lesson] as [TransactionCategory?] {
                let expected = Set(all.filter { txn in
                    if let type, txn.type != type { return false }
                    if let category, txn.category != category { return false }
                    return range.start <= txn.date && txn.date < range.end
                }.map(\.amount))
                XCTAssertEqual(try amounts(type, category), expected, "type \(String(describing: type)) category \(String(describing: category))")
            }
        }
    }

    func testClientPredicateAndTotals() throws {
        let client = Client(firstName: "Ann", lastName: "Lee")
        let other = Client(firstName: "Bo", lastName: "Ray")
        context.insert(client)
        context.insert(other)
        for (index, owner) in [client, client, client, other, nil].enumerated() {
            let txn = Transaction(amount: Double(index + 1), type: index == 0 ? .income : .expense)
            context.insert(txn)
            txn.client = owner
        }
        try context.save()

        let mine = try context.fetch(FetchDescriptor(predicate: Transaction.forClient(client.persistentModelID)))
        XCTAssertEqual(Set(mine.map(\.amount)), [1, 2, 3])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor(predicate: Transaction.forClient(other.persistentModelID))), 1)

        let totals = TransactionTotals(mine)
        XCTAssertEqual(totals, TransactionTotals(income: 1, expenses: 5))
        XCTAssertEqual(totals.balance, -4)
        XCTAssertEqual(TransactionTotals.allTime(in: context).balance, 1 - (2 + 3 + 4 + 5))
    }

    func testAllTimeBalanceCacheRecomputesOnlyForANewVersion() throws {
        context.insert(Transaction(amount: 100, type: .income))
        try context.save()
        let cache = AllTimeBalanceCache()
        XCTAssertEqual(cache.balance(version: 0, context: context), 100)
        context.insert(Transaction(amount: 30, type: .expense))
        try context.save()
        XCTAssertEqual(cache.balance(version: 0, context: context), 100, "same version: cached")
        XCTAssertEqual(cache.balance(version: 1, context: context), 70)
    }

    func testReportDescriptorMatchesPeriods() throws {
        let now = Date.now
        let month = calendar.monthInterval(containing: now)
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: month.start)!
        let inThisMonth = Transaction(amount: 1, date: month.start)
        let future = Transaction(amount: 2, date: days(1, from: now))
        let lastMonth = Transaction(amount: 3, date: lastMonthStart.addingTimeInterval(3600))
        let lastYear = Transaction(amount: 4, date: calendar.date(byAdding: .year, value: -1, to: month.start)!)
        for txn in [inThisMonth, future, lastMonth, lastYear] { context.insert(txn) }
        try context.save()

        func amounts(_ period: ReportPeriod) throws -> Set<Double> {
            Set(try context.fetch(ReportData.descriptor(for: period, now: now)).map(\.amount))
        }
        XCTAssertEqual(try amounts(.thisMonth), [1])
        XCTAssertEqual(try amounts(.lastMonth), [3])
        XCTAssertEqual(try amounts(.allTime), [1, 2, 3, 4])
        XCTAssertTrue(try amounts(.thisYear).isSuperset(of: [1]))
        XCTAssertFalse(try amounts(.thisYear).contains(4))
    }

    // MARK: - Supplies and lessons

    func testLowStockPredicateComparesQuantityToThreshold() throws {
        context.insert(SupplyItem(name: "Hay", quantity: 2, reorderThreshold: 5))
        context.insert(SupplyItem(name: "Oats", quantity: 5, reorderThreshold: 5))
        context.insert(SupplyItem(name: "Salt", quantity: 9, reorderThreshold: 5))
        try context.save()
        let low = try context.fetch(DashboardQueries.lowStockSupplies)
        XCTAssertEqual(Set(low.map(\.name)), ["Hay", "Oats"])
    }

    func testCalendarLessonsIncludeRecurringSeriesAndOneOffsInWindow() throws {
        let window = DateInterval(start: days(-3), end: days(3))
        let inWindow = Lesson(notes: "in", nextDate: days(1))
        let outOfWindow = Lesson(notes: "out", nextDate: days(10))
        let noNextDate = Lesson(notes: "none")
        let weekly = Lesson(date: days(-30), notes: "weekly", frequency: .weekly)
        let futureSeries = Lesson(date: days(20), notes: "later", frequency: .weekly)
        for lesson in [inWindow, outOfWindow, noNextDate, weekly, futureSeries] { context.insert(lesson) }
        try context.save()

        let fetched = try context.fetch(DashboardQueries.calendarLessons(from: window.start, through: window.end))
        XCTAssertEqual(Set(fetched.map(\.notes)), ["in", "weekly"])

        // Nothing the old whole-table build would have shown is missing.
        let all = try context.fetch(FetchDescriptor<Lesson>())
        let shown = Set(all.filter { !$0.occurrences(from: window.start, to: window.end).isEmpty }.map(\.notes))
        XCTAssertTrue(shown.isSubset(of: Set(fetched.map(\.notes))))
    }

    func testHomeLessonsUseLessonDateForOneOffs() throws {
        let start = calendar.startOfDay(for: .now)
        let end = days(2, from: start)
        let today = Lesson(date: start.addingTimeInterval(3600), notes: "today")
        let nextWeek = Lesson(date: days(7, from: start), notes: "nextWeek")
        let daily = Lesson(date: days(-10, from: start), notes: "daily", frequency: .daily)
        for lesson in [today, nextWeek, daily] { context.insert(lesson) }
        try context.save()
        let fetched = try context.fetch(DashboardQueries.homeLessons(from: start, before: end))
        XCTAssertEqual(Set(fetched.map(\.notes)), ["today", "daily"])
    }

    // MARK: - Superseded due dates

    func testNewestCareRecordsDropSupersededRecordsPerHorse() throws {
        let horse = Horse(name: "Storm")
        let other = Horse(name: "Bella")
        context.insert(horse)
        context.insert(other)
        let old = VetRecord(date: days(-60), vetName: "old", nextDueDate: days(2))
        let latest = VetRecord(date: days(-5), vetName: "latest", nextDueDate: days(30))
        let otherHorse = VetRecord(date: days(-90), vetName: "other", nextDueDate: days(2))
        let noHorse = VetRecord(date: days(-90), vetName: "none", nextDueDate: days(2))
        for record in [old, latest, otherHorse, noHorse] { context.insert(record) }
        old.horse = horse
        latest.horse = horse
        otherHorse.horse = other
        try context.save()

        let due = try context.fetch(DashboardQueries.vetDue(from: days(-1), through: days(40)))
        XCTAssertEqual(Set(due.map(\.vetName)), ["old", "latest", "other", "none"])
        let newest = NewestCareRecords.fetch(in: context)
        XCTAssertEqual(newest.vet.count, 2, "one entry per horse")
        XCTAssertEqual(Set(NewestCareRecords.current(due, newest: newest.vet).map(\.vetName)), ["latest", "other", "none"])
        // The same records NotificationService schedules.
        let notified = NotificationService.latestPerHorse(due, horse: { $0.horse }, date: { $0.date }, due: { $0.nextDueDate })
        XCTAssertEqual(Set(notified.map(\.vetName)), ["latest", "other", "none"])
    }

    func testCalendarLeavesOutSupersededDueDates() throws {
        let horse = Horse(name: "Storm")
        context.insert(horse)
        let old = FarrierVisit(date: days(-50), farrierName: "old", nextDueDate: days(1))
        let latest = FarrierVisit(date: days(-2), farrierName: "latest", nextDueDate: days(2))
        context.insert(old)
        context.insert(latest)
        old.horse = horse
        latest.horse = horse
        try context.save()

        let window = ScheduleEventIndex.window(around: .now)
        let index = ScheduleEventIndex(try ScheduleEventIndex.fetchInputs(in: context, window: window), window: window)
        let farrier = index.byDay.values.flatMap { $0 }.filter { $0.type == .farrier }
        XCTAssertEqual(farrier.map(\.subtitle), ["latest"])
    }

    // MARK: - Schedule index

    func testScheduleIndexGroupsByDaySortedWithStableIDs() throws {
        let reminderLate = Reminder(title: "late", dueDate: calendar.startOfDay(for: .now).addingTimeInterval(20 * 3600))
        let reminderEarly = Reminder(title: "early", dueDate: calendar.startOfDay(for: .now).addingTimeInterval(8 * 3600))
        let done = Reminder(title: "done", dueDate: .now, isCompleted: true)
        let farOff = Reminder(title: "far", dueDate: days(120))
        let weekly = Lesson(date: days(-14), notes: "weekly", frequency: .weekly)
        for reminder in [reminderLate, reminderEarly, done, farOff] { context.insert(reminder) }
        context.insert(weekly)
        try context.save()

        let window = ScheduleEventIndex.window(around: .now)
        let index = ScheduleEventIndex(try ScheduleEventIndex.fetchInputs(in: context, window: window), window: window)
        let today = index.events(on: .now).filter { $0.type == .reminder }
        XCTAssertEqual(today.map(\.title), ["early", "late"])
        let all = index.byDay.values.flatMap { $0 }
        XCTAssertFalse(all.contains { $0.title == "done" || $0.title == "far" })
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "ids are unique")
        // A recurring lesson gets one event per occurrence, keyed by date.
        let lessonEvents = all.filter { $0.type == .lesson }
        XCTAssertGreaterThanOrEqual(lessonEvents.count, 4)
        XCTAssertTrue(lessonEvents.allSatisfy { $0.id.occurrence == $0.date })

        // Rebuilding gives the same ids.
        let again = ScheduleEventIndex(try ScheduleEventIndex.fetchInputs(in: context, window: window), window: window)
        XCTAssertEqual(Set(again.byDay.values.flatMap { $0 }.map(\.id)), Set(all.map(\.id)))
    }

    // MARK: - Home summary

    /// The bounded fetches give Home the same numbers and lists as filtering
    /// every record did (one record per horse and type, so nothing is superseded).
    func testHomeSummaryMatchesWholeTableComputation() throws {
        let seed = PerformanceSeed(horses: 12, clients: 6, transactions: 300, careRecordsPerKind: 1, lessons: 40, reminders: 40)
        try seed.insert(into: context)
        let now = Date.now
        let window = HomeSummary.Window(anchor: now)
        let summary = HomeSummary(try HomeSummary.fetchInputs(in: context, window: window), now: now)

        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let month = calendar.monthInterval(containing: now)
        let monthTxns = transactions.filter { month.start <= $0.date && $0.date < month.end }
        XCTAssertEqual(summary.month.income, monthTxns.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }, accuracy: 0.001)
        XCTAssertEqual(summary.month.expenses, monthTxns.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }, accuracy: 0.001)

        let reminders = try context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { !$0.isCompleted }, sortBy: [SortDescriptor(\.dueDate)]))
        XCTAssertEqual(summary.overdueReminders.map(\.persistentModelID), reminders.filter { $0.dueDate < now }.map(\.persistentModelID))
        XCTAssertEqual(
            summary.todayReminders.map(\.persistentModelID),
            Array(reminders.filter { $0.dueDate >= now && (calendar.isDateInToday($0.dueDate) || calendar.isDateInTomorrow($0.dueDate)) }.prefix(3)).map(\.persistentModelID)
        )

        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        let unpaid = lessons.filter { !$0.isPaid && $0.date <= now && $0.cost > 0 }.sorted { $0.date > $1.date }
        XCTAssertEqual(summary.unpaidLessons.map(\.persistentModelID), Array(unpaid.prefix(HomeSummary.unpaidLimit)).map(\.persistentModelID))

        let supplies = try context.fetch(FetchDescriptor<SupplyItem>())
        XCTAssertEqual(Set(summary.lowStock.map(\.persistentModelID)), Set(supplies.filter(\.isLowStock).map(\.persistentModelID)))

        let weekOut = calendar.date(byAdding: .day, value: 7, to: now)!
        let vet = try context.fetch(FetchDescriptor<VetRecord>())
        XCTAssertEqual(
            Set(summary.upcomingVet.map(\.persistentModelID)),
            Set(vet.filter { $0.nextDueDate.map { $0 >= now && $0 <= weekOut } ?? false }.map(\.persistentModelID))
        )

        // Today & Tomorrow: lessons, vet, farrier and reminders in the next two days.
        let cutoff = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))!
        var expected = 0
        for lesson in lessons { expected += lesson.homeDates(from: now, before: cutoff).count }
        expected += vet.filter { $0.nextDueDate.map { $0 >= now && $0 < cutoff } ?? false }.count
        expected += try context.fetch(FetchDescriptor<FarrierVisit>()).filter { $0.nextDueDate.map { $0 >= now && $0 < cutoff } ?? false }.count
        expected += reminders.filter { $0.dueDate >= now && $0.dueDate < cutoff }.count
        XCTAssertEqual(summary.upcoming.count, expected)
        XCTAssertEqual(summary.upcoming.map(\.date), summary.upcoming.map(\.date).sorted())
    }
}

// MARK: - Performance

/// Vet-scale data (#32): 100 horses, 50 clients, 5,000 transactions and ~1,000
/// care records. The store is seeded once for the class; each `measure` block
/// runs the same fetches and build the screen runs per render.
@MainActor
final class DashboardPerformanceTests: XCTestCase {

    private static var container: ModelContainer?

    private var context: ModelContext {
        get throws {
            if let container = Self.container { return container.mainContext }
            let container = try ModelContainer(
                for: BarnHubSchema.schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            try PerformanceSeed.vetScale.insert(into: container.mainContext)
            Self.container = container
            return container.mainContext
        }
    }

    override class func tearDown() {
        container = nil
        super.tearDown()
    }

    private var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 10
        return options
    }

    func testSeedSize() throws {
        let context = try context
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Horse>()), 100)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Client>()), 50)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Transaction>()), 5_000)
        let care = try context.fetchCount(FetchDescriptor<VetRecord>())
            + context.fetchCount(FetchDescriptor<FarrierVisit>())
            + context.fetchCount(FetchDescriptor<DentistVisit>())
        XCTAssertEqual(care, 1_000)
    }

    /// Home's fetches plus the summary build, as one render does. The newest-record
    /// map is cached between saves in the app, so it is built once here and
    /// measured on its own below.
    func testHomeSummaryPerformance() throws {
        let context = try context
        let window = HomeSummary.Window(anchor: .now)
        let newest = NewestCareRecords.fetch(in: context)
        measure(metrics: [XCTClockMetric()], options: options) {
            let summary = HomeSummary((try? HomeSummary.fetchInputs(in: context, window: window, newest: newest)) ?? .init())
            XCTAssertFalse(summary.lowStock.isEmpty)
        }
    }

    /// The Schedule tab's fetches plus the event index for one month.
    func testCalendarMonthEventBuildPerformance() throws {
        let context = try context
        let window = ScheduleEventIndex.window(around: .now)
        let newest = NewestCareRecords.fetch(in: context)
        measure(metrics: [XCTClockMetric()], options: options) {
            let index = ScheduleEventIndex((try? ScheduleEventIndex.fetchInputs(in: context, window: window, newest: newest)) ?? .init(), window: window)
            XCTAssertFalse(index.byDay.isEmpty)
        }
    }

    /// Rebuilding the newest-record map, which Home and Schedule do once after
    /// each save or CloudKit import.
    func testNewestCareRecordsPerformance() throws {
        let context = try context
        measure(metrics: [XCTClockMetric()], options: options) {
            XCTAssertEqual(NewestCareRecords.fetch(in: context).vet.count, 100)
        }
    }
}

// MARK: - Seed

/// Deterministic vet-scale sample data for performance tests. Dates spread over
/// the two years before and the months after now, so the current month holds a
/// realistic slice.
struct PerformanceSeed {
    var horses: Int
    var clients: Int
    var transactions: Int
    /// Records per horse for each of vet, farrier and dentist (the vet-scale seed
    /// sets explicit totals instead).
    var careRecordsPerKind: Int
    var lessons: Int
    var reminders: Int
    var vetTotal: Int? = nil
    var farrierTotal: Int? = nil
    var dentistTotal: Int? = nil

    static let vetScale = PerformanceSeed(
        horses: 100, clients: 50, transactions: 5_000, careRecordsPerKind: 0, lessons: 300, reminders: 200,
        vetTotal: 400, farrierTotal: 400, dentistTotal: 200
    )

    @MainActor
    func insert(into context: ModelContext) throws {
        var rng = SplitMix64(seed: 32)
        let now = Date.now
        func date(daysBack: Int, daysForward: Int) -> Date {
            let span = Double(daysBack + daysForward) * 86_400
            return now.addingTimeInterval(-Double(daysBack) * 86_400 + span * rng.nextUnit())
        }

        let horseModels = (0..<horses).map { Horse(name: "Horse \($0)", breed: "Breed \($0 % 7)") }
        horseModels.forEach(context.insert)
        let clientModels = (0..<clients).map { Client(firstName: "Client", lastName: "\($0)") }
        clientModels.forEach(context.insert)

        for index in 0..<transactions {
            let txn = Transaction(
                amount: Double(10 + Int(rng.nextUnit() * 490)),
                date: date(daysBack: 730, daysForward: 10),
                memo: "Txn \(index)",
                category: TransactionCategory.allCases[index % TransactionCategory.allCases.count],
                type: index % 3 == 0 ? .income : .expense,
                isPaid: index % 4 != 0
            )
            context.insert(txn)
            if index % 2 == 0, !clientModels.isEmpty { txn.client = clientModels[index % clientModels.count] }
        }

        func careCount(_ total: Int?) -> Int { total ?? careRecordsPerKind * horses }
        for index in 0..<careCount(vetTotal) {
            let record = VetRecord(date: date(daysBack: 365, daysForward: 0), vetName: "Vet \(index % 5)",
                                   nextDueDate: date(daysBack: 30, daysForward: 60))
            context.insert(record)
            record.horse = horseModels[index % horseModels.count]
        }
        for index in 0..<careCount(farrierTotal) {
            let visit = FarrierVisit(date: date(daysBack: 365, daysForward: 0), farrierName: "Farrier \(index % 3)",
                                     nextDueDate: date(daysBack: 30, daysForward: 60))
            context.insert(visit)
            visit.horse = horseModels[index % horseModels.count]
        }
        for index in 0..<careCount(dentistTotal) {
            let visit = DentistVisit(date: date(daysBack: 365, daysForward: 0), dentistName: "Dentist \(index % 2)",
                                     nextDueDate: date(daysBack: 30, daysForward: 60))
            context.insert(visit)
            visit.horse = horseModels[index % horseModels.count]
        }

        for index in 0..<lessons {
            let recurring = index % 10 == 0
            let lessonDate = date(daysBack: 120, daysForward: 30)
            let lesson = Lesson(
                date: lessonDate, cost: index % 5 == 0 ? 0 : 60, isPaid: index % 3 != 0,
                frequency: recurring ? .weekly : .once, nextDate: recurring ? nil : lessonDate
            )
            context.insert(lesson)
            lesson.horse = horseModels[index % horseModels.count]
            if !clientModels.isEmpty { lesson.client = clientModels[index % clientModels.count] }
        }

        for index in 0..<reminders {
            let reminder = Reminder(title: "Reminder \(index)", dueDate: date(daysBack: 20, daysForward: 40),
                                    isCompleted: index % 4 == 0)
            context.insert(reminder)
            reminder.horse = horseModels[index % horseModels.count]
        }

        for index in 0..<20 {
            context.insert(SupplyItem(name: "Supply \(index)", quantity: Double(index), reorderThreshold: 8))
        }
        try context.save()
    }
}

/// Small deterministic PRNG so the seed is the same on every run.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

