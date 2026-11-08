import Foundation
import SwiftData

/// The one place a reminder's completion changes, so recurring reminders recur
/// no matter which screen completes them.
@MainActor
enum ReminderService {
    /// Marks `reminder` complete or incomplete and saves.
    ///
    /// Completing a recurring reminder creates its next occurrence: the first
    /// step of its frequency that falls on or after today (missed occurrences of
    /// a long-overdue reminder are skipped rather than queued). Un-completing
    /// removes that untouched next occurrence again, so toggling back and forth
    /// never piles up duplicates. Saving goes through `saveWithLogging()`, which
    /// triggers a notification sync.
    ///
    /// - Returns: the next occurrence created, if any.
    @discardableResult
    static func setCompleted(
        _ reminder: Reminder,
        _ completed: Bool,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Reminder? {
        guard reminder.isCompleted != completed else { return nil }
        reminder.isCompleted = completed

        var created: Reminder?
        if let nextDue = nextDueDate(after: reminder, now: now, calendar: calendar) {
            let existing = successors(of: reminder, dueOn: nextDue, in: context, calendar: calendar)
            if completed {
                if existing.isEmpty {
                    let next = Reminder(
                        title: reminder.title,
                        notes: reminder.notes,
                        dueDate: nextDue,
                        frequency: reminder.frequency
                    )
                    context.insert(next)
                    next.horse = reminder.horse
                    created = next
                    BarnHubLogger.info("Created next occurrence of recurring reminder frequency=\(reminder.frequencyRaw)")
                }
            } else {
                existing.forEach { context.delete($0) }
            }
        }

        context.saveWithLogging()
        return created
    }

    /// The due date of the occurrence after `reminder`, or nil for a one-off.
    static func nextDueDate(after reminder: Reminder, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        var step = 1
        while step < 10_000, let candidate = reminder.frequency.advance(reminder.dueDate, by: step, calendar: calendar) {
            if candidate >= today { return candidate }
            step += 1
        }
        return nil
    }

    /// Incomplete reminders that look like `reminder`'s next occurrence.
    private static func successors(of reminder: Reminder, dueOn date: Date, in context: ModelContext, calendar: Calendar) -> [Reminder] {
        let title = reminder.title
        let frequencyRaw = reminder.frequencyRaw
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate {
            !$0.isCompleted && $0.title == title && $0.frequencyRaw == frequencyRaw
        })
        let candidates = (try? context.fetch(descriptor)) ?? []
        return candidates.filter {
            $0 !== reminder
                && $0.horse?.persistentModelID == reminder.horse?.persistentModelID
                && calendar.isDate($0.dueDate, inSameDayAs: date)
        }
    }
}
