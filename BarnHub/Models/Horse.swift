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
    var genderRaw: String = HorseGender.mare.rawValue
    var purchasePrice: Double = 0
    var isActive: Bool = true

    var gender: HorseGender {
        get { HorseGender(rawValue: genderRaw) ?? .mare }
        set { genderRaw = newValue.rawValue }
    }

    @Attribute(.externalStorage)
    var photoData: Data? = nil

    /// ~256 px JPEG of `photoData` for rows and avatars. Kept inline (a few KB)
    /// so lists never load the full photo; nil until generated, and backfilled
    /// lazily for records saved before it existed.
    var thumbnailData: Data? = nil

    // No `= nil` default on either side of this many-to-many (#28): the macro turns
    // a default into an init accessor that maintains the inverse before the model
    // is registered, which asserts on macOS 14.0-14.3 / iOS 17.0-17.3. The
    // explicit inverse lives on this side only.
    @Relationship(deleteRule: .nullify, inverse: \Client.horses)
    var clients: [Client]?

    @Relationship(deleteRule: .cascade)
    var vetRecords: [VetRecord]? = nil

    @Relationship(deleteRule: .cascade)
    var farrierVisits: [FarrierVisit]? = nil

    @Relationship(deleteRule: .cascade)
    var dentistVisits: [DentistVisit]? = nil

    @Relationship(deleteRule: .cascade)
    var reminders: [Reminder]? = nil

    @Relationship(deleteRule: .cascade)
    var weightEntries: [WeightEntry]? = nil

    @Relationship(deleteRule: .cascade)
    var lessons: [Lesson]? = nil

    @Relationship(deleteRule: .cascade)
    var barnNotes: [BarnNote]? = nil

    @Relationship(deleteRule: .cascade)
    var documents: [HorseDocument]? = nil

    @Relationship(deleteRule: .cascade)
    var feedPlanEntries: [FeedPlanEntry]? = nil

    init(
        name: String = "",
        breed: String = "",
        dateOfBirth: Date = .now,
        colorMarkings: String = "",
        weight: Double = 0,
        purchasePrice: Double = 0,
        medicalNotes: String = "",
        feedingSchedule: String = "",
        stallNumber: String = "",
        gender: HorseGender = .mare,
        isActive: Bool = true,
        photoData: Data? = nil
    ) {
        self.name = name
        self.breed = breed
        self.dateOfBirth = dateOfBirth
        self.colorMarkings = colorMarkings
        self.weight = weight
        self.purchasePrice = purchasePrice
        self.medicalNotes = medicalNotes
        self.feedingSchedule = feedingSchedule
        self.stallNumber = stallNumber
        self.genderRaw = gender.rawValue
        self.isActive = isActive
        self.photoData = photoData
    }
}
