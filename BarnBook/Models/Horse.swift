import Foundation
import SwiftData

@Model
final class Horse {
    var name: String = ""
    var breed: String = ""
    var dateOfBirth: Date = Date.now
    var colorMarkings: String = ""
    var weight: Double = 0
    var medicalNotes: String = ""
    var feedingSchedule: String = ""
    var stallNumber: String = ""
    var isActive: Bool = true

    @Relationship(deleteRule: .nullify, inverse: \Client.horses)
    var clients: [Client]? = nil

    @Relationship(deleteRule: .cascade)
    var vetRecords: [VetRecord]? = nil

    @Relationship(deleteRule: .cascade)
    var farrierVisits: [FarrierVisit]? = nil

    @Relationship(deleteRule: .cascade)
    var reminders: [Reminder]? = nil

    init(
        name: String = "",
        breed: String = "",
        dateOfBirth: Date = .now,
        colorMarkings: String = "",
        weight: Double = 0,
        medicalNotes: String = "",
        feedingSchedule: String = "",
        stallNumber: String = "",
        isActive: Bool = true
    ) {
        self.name = name
        self.breed = breed
        self.dateOfBirth = dateOfBirth
        self.colorMarkings = colorMarkings
        self.weight = weight
        self.medicalNotes = medicalNotes
        self.feedingSchedule = feedingSchedule
        self.stallNumber = stallNumber
        self.isActive = isActive
    }
}
