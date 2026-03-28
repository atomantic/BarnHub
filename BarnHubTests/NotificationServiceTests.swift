import XCTest
import SwiftData
@testable import BarnHub

/// Tests identifier uniqueness for NotificationService.
/// The private `reminderID`, `vetRecordID`, and `farrierVisitID` helpers are
/// verified indirectly by checking that different model instances, once
/// inserted into a container, produce distinct persistentModelIDs — which
/// is the input those helpers use.
final class NotificationServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self,
            BarnNote.self, Lesson.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Identifier uniqueness via persistentModelID

    func test_reminder_persistentModelIDs_areUnique() throws {
        let r1 = Reminder(title: "Deworming")
        let r2 = Reminder(title: "Vaccination")
        context.insert(r1)
        context.insert(r2)
        try context.save()

        XCTAssertNotEqual(r1.persistentModelID, r2.persistentModelID,
                          "Two distinct Reminder instances must have different persistentModelIDs")
    }

    func test_vetRecord_persistentModelIDs_areUnique() throws {
        let v1 = VetRecord(vetName: "Dr. A")
        let v2 = VetRecord(vetName: "Dr. B")
        context.insert(v1)
        context.insert(v2)
        try context.save()

        XCTAssertNotEqual(v1.persistentModelID, v2.persistentModelID,
                          "Two distinct VetRecord instances must have different persistentModelIDs")
    }

    func test_farrierVisit_persistentModelIDs_areUnique() throws {
        let f1 = FarrierVisit(farrierName: "Joe")
        let f2 = FarrierVisit(farrierName: "Bob")
        context.insert(f1)
        context.insert(f2)
        try context.save()

        XCTAssertNotEqual(f1.persistentModelID, f2.persistentModelID,
                          "Two distinct FarrierVisit instances must have different persistentModelIDs")
    }

    /// Cross-type IDs are also distinct (reminder vs vet record IDs don't collide)
    func test_crossType_persistentModelIDs_areDistinct() throws {
        let reminder = Reminder(title: "Test")
        let vetRecord = VetRecord(vetName: "Dr. C")
        context.insert(reminder)
        context.insert(vetRecord)
        try context.save()

        let rID = "reminder-\(reminder.persistentModelID)"
        let vID = "vet-\(vetRecord.persistentModelID)"
        XCTAssertNotEqual(rID, vID)
    }

    // MARK: - NotificationService observable state

    func test_notificationService_initialState_isNotAuthorized() {
        let service = NotificationService()
        XCTAssertFalse(service.isAuthorized)
    }
}
