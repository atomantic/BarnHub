import XCTest
import SwiftData
@testable import BarnHub

@MainActor
/// Recurring reminders (ReminderService) and recurring lessons.
final class RecurrenceTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 10))!
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func incomplete(in context: ModelContext) throws -> [Reminder] {
        try context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { !$0.isCompleted }))
    }

    private func day(_ offset: Int, hour: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        let shifted = calendar.date(byAdding: .day, value: offset, to: start)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted)!
    }

    // MARK: - Reminders

    func test_completingWeeklyReminder_leavesOneIncompleteDueSevenDaysLater() throws {
        let context = try makeContext()
        let horse = Horse(name: "Bella")
        context.insert(horse)
        let reminder = Reminder(title: "Deworm", notes: "Paste", dueDate: day(0, hour: 9), frequency: .weekly)
        context.insert(reminder)
        reminder.horse = horse
        try context.save()

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)

        let open = try incomplete(in: context)
        XCTAssertEqual(open.count, 1)
        let next = try XCTUnwrap(open.first)
        XCTAssertEqual(next.dueDate, calendar.date(byAdding: .day, value: 7, to: reminder.dueDate))
        XCTAssertEqual(next.title, "Deworm")
        XCTAssertEqual(next.notes, "Paste")
        XCTAssertEqual(next.frequency, .weekly)
        XCTAssertEqual(next.horse?.name, "Bella")
        XCTAssertNotEqual(next.notificationKey, reminder.notificationKey)
        XCTAssertTrue(reminder.isCompleted)
    }

    func test_completingOneOffReminder_createsNothing() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Call vet", dueDate: day(0), frequency: .once)
        context.insert(reminder)
        try context.save()

        XCTAssertNil(ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar))
        XCTAssertTrue(try incomplete(in: context).isEmpty)
    }

    func test_toggleCompleteThenIncompleteThenComplete_neverDuplicates() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Hay order", dueDate: day(0), frequency: .monthly)
        context.insert(reminder)
        try context.save()

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)
        ReminderService.setCompleted(reminder, false, in: context, now: now, calendar: calendar)
        XCTAssertEqual(try incomplete(in: context).map(\.dueDate), [day(0)],
                       "Un-completing removes the untouched next occurrence")

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)
        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)
        XCTAssertEqual(try incomplete(in: context).count, 1)
    }

    func test_uncompletingOnALaterDay_removesTheNextOccurrence() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Turnout", dueDate: day(0), frequency: .daily)
        context.insert(reminder)
        try context.save()

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)
        XCTAssertEqual(try incomplete(in: context).map(\.dueDate), [day(1)])

        // Two days later the next step as of today is day 2, not day 1.
        ReminderService.setCompleted(reminder, false, in: context, now: day(2, hour: 10), calendar: calendar)
        XCTAssertEqual(try incomplete(in: context).map(\.dueDate), [day(0)],
                       "The day-1 occurrence goes away even though it isn't today's next step")
    }

    func test_recompletingOnALaterDay_keepsTheExistingNextOccurrence() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Turnout", dueDate: day(0), frequency: .daily)
        context.insert(reminder)
        try context.save()

        let first = try XCTUnwrap(ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar))
        reminder.isCompleted = false  // reopened without going through the service
        try context.save()

        XCTAssertNil(ReminderService.setCompleted(reminder, true, in: context, now: day(2, hour: 10), calendar: calendar))
        XCTAssertEqual(try incomplete(in: context).map(\.dueDate), [first.dueDate])
    }

    func test_uncompleting_leavesUnrelatedLaterRemindersAlone() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Hay order", dueDate: day(0), frequency: .monthly)
        let later = Reminder(title: "Hay order", dueDate: day(60), frequency: .monthly)
        context.insert(reminder)
        context.insert(later)
        try context.save()

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)
        ReminderService.setCompleted(reminder, false, in: context, now: now, calendar: calendar)
        XCTAssertEqual(try incomplete(in: context).map(\.dueDate).sorted(), [day(0), day(60)])
    }

    func test_completingLongOverdueReminder_skipsMissedOccurrences() throws {
        let context = try makeContext()
        let reminder = Reminder(title: "Fly spray", dueDate: day(-20), frequency: .weekly)
        context.insert(reminder)
        try context.save()

        ReminderService.setCompleted(reminder, true, in: context, now: now, calendar: calendar)

        XCTAssertEqual(try incomplete(in: context).map(\.dueDate), [day(1)],
                       "Next weekly step on or after today (-20 + 21 = +1)")
    }

    func test_frequencyAdvance_keepsMonthEndAnchor() {
        let jan31 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let mar = ReminderFrequency.monthly.advance(jan31, by: 2, calendar: calendar)!
        XCTAssertEqual(calendar.component(.day, from: mar), 31)
    }

    // MARK: - Lessons

    func test_weeklyLesson_appearsOnFutureCalendarDates() {
        let lesson = Lesson(date: day(-14, hour: 16), frequency: .weekly)
        let dates = lesson.occurrences(from: day(0), to: day(22), calendar: calendar)
        XCTAssertEqual(dates, [day(0, hour: 16), day(7, hour: 16), day(14, hour: 16), day(21, hour: 16)])
    }

    func test_recurringLesson_usesNextDateAsAnchor() {
        let lesson = Lesson(date: day(-30, hour: 9), frequency: .weekly, nextDate: day(2, hour: 11))
        XCTAssertEqual(lesson.occurrences(from: day(-10), to: day(10), calendar: calendar),
                       [day(2, hour: 11), day(9, hour: 11)],
                       "Nothing before the anchor")
        XCTAssertEqual(lesson.scheduledDate(onOrAfter: now, calendar: calendar), day(2, hour: 11))
    }

    func test_recurringLesson_scheduledDateAdvancesPastToday() {
        let lesson = Lesson(date: day(-15, hour: 18), frequency: .weekly)
        XCTAssertEqual(lesson.scheduledDate(onOrAfter: now, calendar: calendar), day(6, hour: 18))
    }

    func test_oneOffLesson_onlyShowsItsNextDate() {
        let lesson = Lesson(date: day(-1), frequency: .once, nextDate: day(3))
        XCTAssertEqual(lesson.occurrences(from: day(0), to: day(30), calendar: calendar), [day(3)])
        XCTAssertEqual(lesson.scheduledDate(onOrAfter: now, calendar: calendar), day(3))
        XCTAssertEqual(Lesson(date: day(1), frequency: .once).occurrences(from: day(0), to: day(30), calendar: calendar), [])
    }

    func test_lessonHomeDates_coverOneOffAndRecurring() {
        let oneOff = Lesson(date: day(1, hour: 9), frequency: .once)
        let daily = Lesson(date: day(-3, hour: 12), frequency: .daily)
        XCTAssertEqual(oneOff.homeDates(from: now, before: day(2), calendar: calendar), [day(1, hour: 9)])
        XCTAssertEqual(daily.homeDates(from: now, before: day(2), calendar: calendar), [day(0, hour: 12), day(1, hour: 12)])
    }

    // MARK: - Vet record reminder frequency (#37)

    func testVetFrequencySuggestsNextDueOneStepAfterVisit() {
        let visit = now
        var followUp = VetFollowUp()
        followUp.setFrequency(.annually, visitDate: visit, calendar: calendar)
        XCTAssertTrue(followUp.hasNextDue, "picking a frequency turns Next Due on")
        XCTAssertEqual(followUp.nextDueDate, calendar.date(byAdding: .year, value: 1, to: visit))

        // A suggestion that wasn't edited follows the frequency and the visit date.
        followUp.setFrequency(.quarterly, visitDate: visit, calendar: calendar)
        XCTAssertEqual(followUp.nextDueDate, calendar.date(byAdding: .month, value: 3, to: visit))
        let laterVisit = calendar.date(byAdding: .day, value: 5, to: visit)!
        followUp.visitDateChanged(to: laterVisit, calendar: calendar)
        XCTAssertEqual(followUp.nextDueDate, calendar.date(byAdding: .month, value: 3, to: laterVisit))

        // Once leaves the date alone.
        let suggested = followUp.nextDueDate
        followUp.setFrequency(.once, visitDate: laterVisit, calendar: calendar)
        XCTAssertTrue(followUp.hasNextDue)
        XCTAssertEqual(followUp.nextDueDate, suggested)
        XCTAssertEqual(followUp.frequency, .once)
    }

    func testVetFrequencyKeepsANextDueDateTheUserPicked() {
        let visit = now
        let picked = calendar.date(byAdding: .day, value: 45, to: visit)!

        // Picked by hand after a suggestion.
        var followUp = VetFollowUp()
        followUp.setFrequency(.monthly, visitDate: visit, calendar: calendar)
        followUp.nextDueDate = picked
        followUp.setFrequency(.annually, visitDate: visit, calendar: calendar)
        XCTAssertEqual(followUp.nextDueDate, picked)
        followUp.visitDateChanged(to: calendar.date(byAdding: .day, value: 1, to: visit)!, calendar: calendar)
        XCTAssertEqual(followUp.nextDueDate, picked)
        XCTAssertEqual(followUp.frequency, .annually, "the frequency is still saved")

        // Loaded from an existing record.
        var existing = VetFollowUp(hasNextDue: true, nextDueDate: picked, frequency: .once)
        existing.setFrequency(.biannually, visitDate: visit, calendar: calendar)
        XCTAssertEqual(existing.nextDueDate, picked)

        // Next Due turned off: the frequency suggests a date again.
        existing.hasNextDue = false
        existing.setFrequency(.annually, visitDate: visit, calendar: calendar)
        XCTAssertTrue(existing.hasNextDue)
        XCTAssertEqual(existing.nextDueDate, calendar.date(byAdding: .year, value: 1, to: visit))
    }
}
