import Foundation
import SwiftData

@Model
final class Reminder {
    var title: String = ""
    var notes: String = ""
    var dueDate: Date = Date.now
    var isCompleted: Bool = false
    var frequencyRaw: String = ReminderFrequency.once.rawValue
    /// Stable key for this reminder's local notification. Optional so existing
    /// rows and CloudKit records migrate without a default; NotificationService
    /// fills it in the first time it schedules the reminder.
    var notificationKey: UUID? = nil

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    var frequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: frequencyRaw) ?? .once }
        set { frequencyRaw = newValue.rawValue }
    }

    func nextOccurrence() -> Date? {
        frequency.advance(dueDate)
    }

    init(
        title: String = "",
        notes: String = "",
        dueDate: Date = .now,
        isCompleted: Bool = false,
        frequency: ReminderFrequency = .once
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.frequencyRaw = frequency.rawValue
        self.notificationKey = UUID()
    }
}

extension ReminderFrequency {
    /// The calendar step between occurrences, or nil for `.once`.
    var step: (component: Calendar.Component, value: Int)? {
        switch self {
        case .once:       return nil
        case .daily:      return (.day, 1)
        case .weekly:     return (.weekOfYear, 1)
        case .monthly:    return (.month, 1)
        case .quarterly:  return (.month, 3)
        case .biannually: return (.month, 6)
        case .annually:   return (.year, 1)
        }
    }

    /// `date` moved forward by `count` occurrences. Steps are always taken from
    /// the original date, so a monthly series anchored on the 31st stays on the
    /// last day of short months instead of drifting to the 28th.
    func advance(_ date: Date, by count: Int = 1, calendar: Calendar = .current) -> Date? {
        guard let step else { return nil }
        return calendar.date(byAdding: step.component, value: step.value * count, to: date)
    }
}
