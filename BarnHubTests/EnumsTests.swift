import XCTest
@testable import BarnHub

final class EnumsTests: XCTestCase {

    // MARK: - LessonType

    func test_lessonType_rawValues() {
        XCTAssertEqual(LessonType.privateLesson.rawValue, "private")
        XCTAssertEqual(LessonType.group.rawValue, "group")
        XCTAssertEqual(LessonType.training.rawValue, "training")
        XCTAssertEqual(LessonType.evaluation.rawValue, "evaluation")
    }

    func test_lessonType_displayNames() {
        XCTAssertEqual(LessonType.privateLesson.displayName, "Private")
        XCTAssertEqual(LessonType.group.displayName, "Group")
        XCTAssertEqual(LessonType.training.displayName, "Training")
        XCTAssertEqual(LessonType.evaluation.displayName, "Evaluation")
    }

    func test_lessonType_roundTripCodable() throws {
        for type in LessonType.allCases {
            let encoded = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(LessonType.self, from: encoded)
            XCTAssertEqual(decoded, type)
        }
    }

    func test_lessonType_invalidRawValue_returnsNil() {
        XCTAssertNil(LessonType(rawValue: "bogus"))
    }

    // MARK: - BarnNoteCategory.icon

    func test_barnNoteCategory_icons() {
        XCTAssertEqual(BarnNoteCategory.general.icon, "note.text")
        XCTAssertEqual(BarnNoteCategory.observation.icon, "eye")
        XCTAssertEqual(BarnNoteCategory.incident.icon, "exclamationmark.triangle")
        XCTAssertEqual(BarnNoteCategory.maintenance.icon, "wrench.and.screwdriver")
        XCTAssertEqual(BarnNoteCategory.health.icon, "heart")
        XCTAssertEqual(BarnNoteCategory.weather.icon, "cloud.sun")
    }

    func test_barnNoteCategory_displayNames() {
        XCTAssertEqual(BarnNoteCategory.general.displayName, "General")
        XCTAssertEqual(BarnNoteCategory.observation.displayName, "Observation")
        XCTAssertEqual(BarnNoteCategory.incident.displayName, "Incident")
        XCTAssertEqual(BarnNoteCategory.maintenance.displayName, "Maintenance")
        XCTAssertEqual(BarnNoteCategory.health.displayName, "Health")
        XCTAssertEqual(BarnNoteCategory.weather.displayName, "Weather")
    }

    func test_barnNoteCategory_rawValues() {
        XCTAssertEqual(BarnNoteCategory.general.rawValue, "general")
        XCTAssertEqual(BarnNoteCategory.observation.rawValue, "observation")
        XCTAssertEqual(BarnNoteCategory.incident.rawValue, "incident")
        XCTAssertEqual(BarnNoteCategory.maintenance.rawValue, "maintenance")
        XCTAssertEqual(BarnNoteCategory.health.rawValue, "health")
        XCTAssertEqual(BarnNoteCategory.weather.rawValue, "weather")
    }

    func test_barnNoteCategory_roundTripCodable() throws {
        for category in BarnNoteCategory.allCases {
            let encoded = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(BarnNoteCategory.self, from: encoded)
            XCTAssertEqual(decoded, category)
        }
    }

    func test_barnNoteCategory_invalidRawValue_returnsNil() {
        XCTAssertNil(BarnNoteCategory(rawValue: "bogus"))
    }

    // MARK: - ReminderFrequency.displayName

    func test_reminderFrequency_displayNames() {
        XCTAssertEqual(ReminderFrequency.once.displayName, "Once")
        XCTAssertEqual(ReminderFrequency.daily.displayName, "Daily")
        XCTAssertEqual(ReminderFrequency.weekly.displayName, "Weekly")
        XCTAssertEqual(ReminderFrequency.monthly.displayName, "Monthly")
        XCTAssertEqual(ReminderFrequency.quarterly.displayName, "Quarterly")
        XCTAssertEqual(ReminderFrequency.biannually.displayName, "Biannually")
        XCTAssertEqual(ReminderFrequency.annually.displayName, "Annually")
    }

    func test_reminderFrequency_rawValues() {
        XCTAssertEqual(ReminderFrequency.once.rawValue, "once")
        XCTAssertEqual(ReminderFrequency.daily.rawValue, "daily")
        XCTAssertEqual(ReminderFrequency.weekly.rawValue, "weekly")
        XCTAssertEqual(ReminderFrequency.monthly.rawValue, "monthly")
        XCTAssertEqual(ReminderFrequency.quarterly.rawValue, "quarterly")
        XCTAssertEqual(ReminderFrequency.biannually.rawValue, "biannually")
        XCTAssertEqual(ReminderFrequency.annually.rawValue, "annually")
    }

    func test_reminderFrequency_roundTripCodable() throws {
        for freq in ReminderFrequency.allCases {
            let encoded = try JSONEncoder().encode(freq)
            let decoded = try JSONDecoder().decode(ReminderFrequency.self, from: encoded)
            XCTAssertEqual(decoded, freq)
        }
    }

    func test_reminderFrequency_invalidRawValue_returnsNil() {
        XCTAssertNil(ReminderFrequency(rawValue: "bogus"))
    }

    // MARK: - DocumentType

    func test_documentType_rawValues() {
        XCTAssertEqual(DocumentType.pdf.rawValue, "pdf")
        XCTAssertEqual(DocumentType.photo.rawValue, "photo")
    }

    func test_documentType_displayNames() {
        XCTAssertEqual(DocumentType.pdf.displayName, "PDF")
        XCTAssertEqual(DocumentType.photo.displayName, "Photo")
    }

    func test_documentType_icons() {
        XCTAssertEqual(DocumentType.pdf.icon, "doc.fill")
        XCTAssertEqual(DocumentType.photo.icon, "photo.fill")
    }
}
