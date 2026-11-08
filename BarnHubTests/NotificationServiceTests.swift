import XCTest
import SwiftData
import UserNotifications
@testable import BarnHub

/// In-memory stand-in for `UNUserNotificationCenter`. Unlike iOS it keeps every
/// request, so tests can assert that the service itself stays under the limit.
final class FakeNotificationCenter: NotificationCenterScheduling {
    var status: UNAuthorizationStatus = .authorized
    private(set) var requests: [String: UNNotificationRequest] = [:]
    private(set) var addCount = 0
    private(set) var removeCount = 0

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { status == .authorized }
    func currentAuthorizationStatus() async -> UNAuthorizationStatus { status }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { Array(requests.values) }

    func add(_ request: UNNotificationRequest) async throws {
        requests[request.identifier] = request
        addCount += 1
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers where requests.removeValue(forKey: identifier) != nil {
            removeCount += 1
        }
    }

    /// Simulates the system firing a request.
    func deliver(_ identifier: String) {
        requests[identifier] = nil
    }

    func resetCounters() {
        addCount = 0
        removeCount = 0
    }
}

@MainActor
final class NotificationServiceTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// 10:00 UTC on a fixed day: after the 8:00 item hour and the 7:00 summary hour.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 10))!
    }

    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "NotificationServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, DentistVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self,
            BarnNote.self, Lesson.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeService(_ center: FakeNotificationCenter) -> NotificationService {
        let fixedNow = now
        return NotificationService(center: center, defaults: defaults, calendar: calendar, now: { fixedNow })
    }

    private func day(_ offset: Int, hour: Int = 0, minute: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        let shifted = calendar.date(byAdding: .day, value: offset, to: start)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shifted)!
    }

    private func fireDate(_ request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
        return calendar.date(from: trigger.dateComponents)
    }

    private func itemRequests(_ center: FakeNotificationCenter) -> [UNNotificationRequest] {
        center.requests.values.filter { $0.identifier != NotificationPlanner.summaryIdentifier }
    }

    @discardableResult
    private func addHorse(_ name: String, to context: ModelContext) -> Horse {
        let horse = Horse(name: name)
        context.insert(horse)
        return horse
    }

    // MARK: - Cap

    func test_hundredHorsesWithThreeDueDates_staysUnderLimitAndKeepsSoonest() async throws {
        let context = try makeContext()
        var expected: [Date] = []
        for index in 0..<100 {
            let horse = addHorse("Horse \(index)", to: context)
            let vet = VetRecord(date: day(-10), vetName: "Vet", nextDueDate: day(1 + index, hour: 15))
            let farrier = FarrierVisit(date: day(-10), farrierName: "Farrier", nextDueDate: day(40 + index, hour: 9))
            let dentist = DentistVisit(date: day(-10), dentistName: "Dentist", nextDueDate: day(90 + index))
            context.insert(vet); context.insert(farrier); context.insert(dentist)
            vet.horse = horse; farrier.horse = horse; dentist.horse = horse
            expected += [1 + index, 40 + index, 90 + index].map { day($0, hour: NotificationPlanner.itemHour) }
        }
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        XCTAssertLessThanOrEqual(center.requests.count, 64)
        XCTAssertEqual(itemRequests(center).count, NotificationPlanner.maxItemRequests)
        let scheduled = itemRequests(center).compactMap(fireDate).sorted()
        XCTAssertEqual(scheduled, Array(expected.sorted().prefix(NotificationPlanner.maxItemRequests)),
                       "Only the soonest due dates are kept")
        XCTAssertNotNil(center.requests[NotificationPlanner.summaryIdentifier],
                        "Room is left for the morning summary")
    }

    // MARK: - Diffing

    func test_deletingHorse_removesItsRequestsOnNextSync() async throws {
        let context = try makeContext()
        let keep = addHorse("Keep", to: context)
        let remove = addHorse("Remove", to: context)
        for horse in [keep, remove] {
            let record = VetRecord(date: day(-5), vetName: "Dr. \(horse.name)", nextDueDate: day(10))
            context.insert(record)
            record.horse = horse
        }
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)
        XCTAssertEqual(itemRequests(center).count, 2)

        context.delete(remove)
        try context.save()
        await service.sync(context: context)

        XCTAssertEqual(itemRequests(center).map(\.content.body), ["Keep — Dr. Keep"])
    }

    func test_unchangedStore_isLeftAloneOnResync() async throws {
        let context = try makeContext()
        context.insert(Reminder(title: "Deworm", dueDate: day(3)))
        let horse = addHorse("Bella", to: context)
        let visit = FarrierVisit(date: day(-20), farrierName: "Joe", nextDueDate: day(15))
        context.insert(visit)
        visit.horse = horse
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)
        let firstIDs = Set(center.requests.keys)
        center.resetCounters()

        await service.sync(context: context)

        XCTAssertEqual(Set(center.requests.keys), firstIDs, "Identifiers are stable across syncs")
        XCTAssertEqual(center.addCount, 0)
        XCTAssertEqual(center.removeCount, 0)
    }

    func test_identifiersUseStoredKey() async throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Vaccinate", dueDate: day(2))
        context.insert(reminder)
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        let key = try XCTUnwrap(reminder.notificationKey)
        let stamp = NotificationPlanner.dayStamp(day(2), calendar: calendar)
        XCTAssertNotNil(center.requests["reminder-\(key.uuidString)-\(stamp)"])
    }

    func test_recordWithoutKey_getsOneAssignedAndKeepsIt() async throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Legacy row", dueDate: day(2))
        reminder.notificationKey = nil // as migrated from before the attribute existed
        context.insert(reminder)
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)
        let assigned = try XCTUnwrap(reminder.notificationKey)
        await service.sync(context: context)

        XCTAssertEqual(reminder.notificationKey, assigned)
        XCTAssertEqual(itemRequests(center).count, 1)
    }

    func test_editingDueDate_replacesRequest() async throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Clip", dueDate: day(2))
        context.insert(reminder)
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)
        reminder.dueDate = day(5)
        try context.save()
        await service.sync(context: context)

        XCTAssertEqual(itemRequests(center).compactMap(fireDate), [day(5, hour: NotificationPlanner.itemHour)])
    }

    func test_completedReminders_areNotScheduled() async throws {
        let context = try makeContext()
        context.insert(Reminder(title: "Done", dueDate: day(2), isCompleted: true))
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        XCTAssertTrue(center.requests.isEmpty)
    }

    func test_notAuthorized_schedulesNothing() async throws {
        let context = try makeContext()
        context.insert(Reminder(title: "Deworm", dueDate: day(3)))
        try context.save()

        let center = FakeNotificationCenter()
        center.status = .denied
        let service = makeService(center)
        await service.sync(context: context)

        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertFalse(service.isAuthorized)
    }

    // MARK: - Superseded records

    func test_supersededRecords_areNotScheduled() async throws {
        let context = try makeContext()
        let horse = addHorse("Storm", to: context)
        let old = VetRecord(date: day(-60), vetName: "Old", nextDueDate: day(5))
        let latest = VetRecord(date: day(-1), vetName: "New", nextDueDate: day(30))
        context.insert(old); context.insert(latest)
        old.horse = horse; latest.horse = horse
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        let items = itemRequests(center)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.content.body, "Storm — New")
        XCTAssertEqual(items.first.flatMap(fireDate), day(30, hour: NotificationPlanner.itemHour))
    }

    func test_latestRecordWithoutNextDue_supersedesOlderDueDate() async throws {
        let context = try makeContext()
        let horse = addHorse("Cleo", to: context)
        let old = DentistVisit(date: day(-200), dentistName: "Old", nextDueDate: day(4))
        let latest = DentistVisit(date: day(-2), dentistName: "New", nextDueDate: nil)
        context.insert(old); context.insert(latest)
        old.horse = horse; latest.horse = horse
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        XCTAssertTrue(center.requests.isEmpty)
    }

    // MARK: - Fire times

    func test_dueDateTime_isNormalizedToEightAM() async throws {
        let context = try makeContext()
        context.insert(Reminder(title: "Late edit", dueDate: day(3, hour: 23, minute: 52)))
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        XCTAssertEqual(itemRequests(center).compactMap(fireDate), [day(3, hour: 8)])
    }

    func test_dueTodayAfterFireHour_firesSoonOnce() async throws {
        let context = try makeContext()
        context.insert(Reminder(title: "Today", dueDate: day(0, hour: 1)))
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)

        let late = try XCTUnwrap(itemRequests(center).first)
        XCTAssertTrue(late.identifier.hasSuffix("-late"))
        XCTAssertTrue(late.trigger is UNTimeIntervalNotificationTrigger)

        // Still pending: left alone.
        center.resetCounters()
        await service.sync(context: context)
        XCTAssertEqual(center.addCount, 0)

        // Delivered: not scheduled again on later activations.
        center.deliver(late.identifier)
        await service.sync(context: context)
        XCTAssertTrue(itemRequests(center).isEmpty)
    }

    // MARK: - Morning summary

    func test_morningSummary_isSingleShotAtNextSevenAndCountsCurrentItemsOnly() async throws {
        let context = try makeContext()
        let horse = addHorse("Daisy", to: context)
        // Superseded overdue date: must not be counted.
        let old = VetRecord(date: day(-90), vetName: "Old", nextDueDate: day(-30))
        let latest = VetRecord(date: day(-3), vetName: "New", nextDueDate: day(-1))
        context.insert(old); context.insert(latest)
        old.horse = horse; latest.horse = horse
        context.insert(Reminder(title: "Tomorrow", dueDate: day(1)))
        context.insert(Reminder(title: "Done", dueDate: day(-2), isCompleted: true))
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        let summary = try XCTUnwrap(center.requests[NotificationPlanner.summaryIdentifier])
        let trigger = try XCTUnwrap(summary.trigger as? UNCalendarNotificationTrigger)
        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(fireDate(summary), day(1, hour: NotificationPlanner.summaryHour),
                       "It is 10:00, so the next summary is tomorrow at 7:00")
        XCTAssertEqual(summary.content.body, NotificationPlanner.summaryBody(overdue: 1, dueToday: 1))
        XCTAssertEqual(summary.content.userInfo["deepLink"] as? String, "barnhub://home")
    }

    func test_morningSummary_isRemovedWhenNothingIsDue() async throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Overdue", dueDate: day(-1))
        context.insert(reminder)
        try context.save()

        let center = FakeNotificationCenter()
        let service = makeService(center)
        await service.sync(context: context)
        XCTAssertNotNil(center.requests[NotificationPlanner.summaryIdentifier])

        reminder.isCompleted = true
        try context.save()
        await service.sync(context: context)
        XCTAssertNil(center.requests[NotificationPlanner.summaryIdentifier])
    }

    func test_summaryBody_variesByCount() {
        XCTAssertEqual(NotificationPlanner.summaryBody(overdue: 1, dueToday: 0), "You have 1 overdue task.")
        XCTAssertEqual(NotificationPlanner.summaryBody(overdue: 3, dueToday: 0), "You have 3 overdue tasks.")
        XCTAssertEqual(NotificationPlanner.summaryBody(overdue: 0, dueToday: 1), "You have 1 task due today.")
        XCTAssertEqual(NotificationPlanner.summaryBody(overdue: 2, dueToday: 1),
                       "You have 2 overdue tasks and 1 task due today.")
    }

    func test_requestsCarryDeepLinks() async throws {
        let context = try makeContext()
        let horse = addHorse("Arrow", to: context)
        let visit = FarrierVisit(date: day(-1), farrierName: "Joe", nextDueDate: day(6))
        context.insert(visit)
        visit.horse = horse
        context.insert(Reminder(title: "Deworm", dueDate: day(2)))
        try context.save()

        let center = FakeNotificationCenter()
        await makeService(center).sync(context: context)

        let links = Set(itemRequests(center).compactMap { $0.content.userInfo["deepLink"] as? String })
        XCTAssertEqual(links, ["barnhub://schedule/farrier", "barnhub://schedule/reminders"])
    }

    // MARK: - Delegate

    func test_delegate_holdsTappedDeepLinkUntilConsumed() {
        let delegate = NotificationDelegate.shared
        delegate.receive(deepLink: "barnhub://schedule/reminders")
        XCTAssertEqual(delegate.consumeDeepLink(), URL(string: "barnhub://schedule/reminders"))
        XCTAssertNil(delegate.consumeDeepLink())
    }

    func test_notificationService_initialState_isNotAuthorized() {
        let service = NotificationService(center: FakeNotificationCenter(), defaults: defaults)
        XCTAssertFalse(service.isAuthorized)
    }
}
