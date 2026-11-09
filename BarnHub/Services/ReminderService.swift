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
            let existing = successors(of: reminder, dueThrough: nextDue, in: context, calendar: calendar)
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
            } else if let next = existing.first {
                // Completing created exactly one occurrence; remove only that one.
                context.delete(next)
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

    /// Incomplete reminders that look like `reminder`'s next occurrence, earliest first.
    ///
    /// The next occurrence was due on the first step on or after the day it was
    /// completed, and `last` is that step as of today, so the occurrence falls
    /// after `reminder` and no later than `last`'s day. Matching a window, not
    /// one exact day, finds it even when the reminder is un-completed (or
    /// completed again) on a later day than it was first completed.
    private static func successors(of reminder: Reminder, dueThrough last: Date, in context: ModelContext, calendar: Calendar) -> [Reminder] {
        let title = reminder.title
        let frequencyRaw = reminder.frequencyRaw
        let descriptor = FetchDescriptor<Reminder>(predicate: #Predicate {
            !$0.isCompleted && $0.title == title && $0.frequencyRaw == frequencyRaw
        })
        let candidates = (try? context.fetch(descriptor)) ?? []
        // [the day after `reminder`, the day after `last`)
        guard let start = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reminder.dueDate)),
              let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last))
        else { return [] }
        return candidates.filter {
            $0 !== reminder
                && $0.horse?.persistentModelID == reminder.horse?.persistentModelID
                && $0.dueDate >= start && $0.dueDate < end
        }
        .sorted { $0.dueDate < $1.dueDate }
    }
}
