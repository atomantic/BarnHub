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
