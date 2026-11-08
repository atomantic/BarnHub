import Foundation
import SwiftData

@Model
final class Lesson {
    var date: Date = Date.now
    var duration: Int = 60
    var lessonTypeRaw: String = LessonType.privateLesson.rawValue
    var notes: String = ""
    var cost: Double = 0
    var isPaid: Bool = false
    var frequencyRaw: String = ReminderFrequency.once.rawValue
    var nextDate: Date? = nil

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    @Relationship(deleteRule: .nullify)
    var client: Client? = nil

    var lessonType: LessonType {
        get { LessonType(rawValue: lessonTypeRaw) ?? .privateLesson }
        set { lessonTypeRaw = newValue.rawValue }
    }

    var frequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: frequencyRaw) ?? .once }
        set { frequencyRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        duration: Int = 60,
        lessonType: LessonType = .privateLesson,
        notes: String = "",
        cost: Double = 0,
        isPaid: Bool = false,
        frequency: ReminderFrequency = .once,
        nextDate: Date? = nil
    ) {
        self.date = date
        self.duration = duration
        self.lessonTypeRaw = lessonType.rawValue
        self.notes = notes
        self.cost = cost
        self.isPaid = isPaid
        self.frequencyRaw = frequency.rawValue
        self.nextDate = nextDate
    }
}

// MARK: - Recurrence

/// Recurring lessons are computed, not stored: a lesson with a frequency other
/// than `.once` repeats from its anchor (`nextDate`, or `date` when no next date
/// is set) for as long as it exists. Nothing is written back to the store, so
/// devices never race to advance the same lesson over CloudKit.
extension Lesson {
    var isRecurring: Bool { frequency != .once }

    /// The first date of the series.
    var recurrenceAnchor: Date { nextDate ?? date }

    /// Every date this lesson falls on within `start...end` (inclusive). A one-off
    /// lesson only has its `nextDate`.
    func occurrences(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        guard isRecurring else {
            guard let nextDate, nextDate >= start, nextDate <= end else { return [] }
            return [nextDate]
        }
        var result: [Date] = []
        var index = 0
        // Bounded so a corrupt anchor can't spin forever (10k daily steps ≈ 27 years).
        while index < 10_000, let occurrence = frequency.advance(recurrenceAnchor, by: index, calendar: calendar) {
            if occurrence > end { break }
            if occurrence >= start { result.append(occurrence) }
            index += 1
        }
        return result
    }

    /// When this lesson is next scheduled: the first occurrence on or after the
    /// start of `day` for a recurring lesson, otherwise its `nextDate` (which
    /// may be in the past).
    func scheduledDate(onOrAfter day: Date = .now, calendar: Calendar = .current) -> Date? {
        guard isRecurring else { return nextDate }
        let start = calendar.startOfDay(for: day)
        var index = 0
        while index < 10_000, let occurrence = frequency.advance(recurrenceAnchor, by: index, calendar: calendar) {
            if occurrence >= start { return occurrence }
            index += 1
        }
        return nil
    }

    /// Dates in `start..<end` for the Home screen, which lists one-off lessons by
    /// their lesson `date` and recurring ones by occurrence.
    func homeDates(from start: Date, before end: Date, calendar: Calendar = .current) -> [Date] {
        let dates = isRecurring ? occurrences(from: start, to: end, calendar: calendar) : [date]
        return dates.filter { $0 >= start && $0 < end }
    }
}
