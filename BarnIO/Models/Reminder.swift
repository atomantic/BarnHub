import Foundation
import SwiftData

@Model
final class Reminder {
    var title: String = ""
    var notes: String = ""
    var dueDate: Date = Date.now
    var isCompleted: Bool = false
    var frequencyRaw: String = ReminderFrequency.once.rawValue

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    var frequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: frequencyRaw) ?? .once }
        set { frequencyRaw = newValue.rawValue }
    }

    func nextOccurrence() -> Date? {
        let calendar = Calendar.current
        switch frequency {
        case .once:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: dueDate)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: dueDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: dueDate)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: dueDate)
        case .biannually:
            return calendar.date(byAdding: .month, value: 6, to: dueDate)
        case .annually:
            return calendar.date(byAdding: .year, value: 1, to: dueDate)
        }
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
    }
}
