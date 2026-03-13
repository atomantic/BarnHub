import Foundation
import SwiftData

@Model
final class VetRecord {
    var date: Date = Date.now
    var vetName: String = ""
    var descriptionText: String = ""
    var cost: Double = 0
    var nextDueDate: Date? = nil
    var reminderFrequencyRaw: String = ReminderFrequency.once.rawValue

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    var reminderFrequency: ReminderFrequency {
        get { ReminderFrequency(rawValue: reminderFrequencyRaw) ?? .once }
        set { reminderFrequencyRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        vetName: String = "",
        descriptionText: String = "",
        cost: Double = 0,
        nextDueDate: Date? = nil,
        reminderFrequency: ReminderFrequency = .once
    ) {
        self.date = date
        self.vetName = vetName
        self.descriptionText = descriptionText
        self.cost = cost
        self.nextDueDate = nextDueDate
        self.reminderFrequencyRaw = reminderFrequency.rawValue
    }
}
