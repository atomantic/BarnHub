import XCTest
@testable import BarnHub

final class TimelineEventTests: XCTestCase {
    func testTimelineEventTypeProperties() {
        XCTAssertEqual(TimelineEventType.vet.label, "Vet")
        XCTAssertEqual(TimelineEventType.farrier.label, "Farrier")
        XCTAssertEqual(TimelineEventType.dentist.label, "Dentist")
        XCTAssertEqual(TimelineEventType.weight.label, "Weight")

        XCTAssertEqual(TimelineEventType.vet.icon, "cross.case.fill")
        XCTAssertEqual(TimelineEventType.farrier.icon, "hammer.fill")
        XCTAssertEqual(TimelineEventType.dentist.icon, "mouth.fill")
        XCTAssertEqual(TimelineEventType.weight.icon, "scalemass.fill")
    }

    func testAllCasesIncludesAll() {
        XCTAssertEqual(TimelineEventType.allCases.count, 4)
        XCTAssertTrue(TimelineEventType.allCases.contains(.vet))
        XCTAssertTrue(TimelineEventType.allCases.contains(.farrier))
        XCTAssertTrue(TimelineEventType.allCases.contains(.dentist))
        XCTAssertTrue(TimelineEventType.allCases.contains(.weight))
    }

    func testTimelineEventCreation() {
        let event = TimelineEvent(
            id: "vet-123",
            date: .now,
            type: .vet,
            title: "Annual Vaccines",
            subtitle: "Dr. Chen",
            detail: "Next due: 03/01/2027",
            cost: 250.0
        )

        XCTAssertEqual(event.id, "vet-123")
        XCTAssertEqual(event.type, .vet)
        XCTAssertEqual(event.title, "Annual Vaccines")
        XCTAssertEqual(event.subtitle, "Dr. Chen")
        XCTAssertEqual(event.detail, "Next due: 03/01/2027")
        XCTAssertEqual(event.cost, 250.0)
    }

    func testTimelineEventNilOptionals() {
        let event = TimelineEvent(
            id: "weight-456",
            date: .now,
            type: .weight,
            title: "1100 lbs",
            subtitle: "Weight recorded",
            detail: nil,
            cost: nil
        )

        XCTAssertNil(event.detail)
        XCTAssertNil(event.cost)
    }
}
