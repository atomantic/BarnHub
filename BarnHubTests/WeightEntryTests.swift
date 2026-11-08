import XCTest
import SwiftData
@testable import BarnHub

final class WeightEntryTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: BarnHubSchema.schema,
            configurations: config
        )
        context = ModelContext(container)
    }

    func testWeightEntryCreation() {
        let entry = WeightEntry(date: .now, weight: 1100)
        context.insert(entry)
        try! context.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weight, 1100)
    }

    func testWeightEntryHorseRelationship() {
        let horse = Horse(name: "Arrow", breed: "Thoroughbred")
        let entry = WeightEntry(date: .now, weight: 1100)
        entry.horse = horse
        context.insert(horse)
        context.insert(entry)
        try! context.save()

        XCTAssertEqual(entry.horse?.name, "Arrow")
        XCTAssertEqual(horse.weightEntries?.count, 1)
    }

    func testWeightEntryCascadeDelete() {
        let horse = Horse(name: "Bella")
        context.insert(horse)
        let e1 = WeightEntry(date: .now, weight: 1050)
        e1.horse = horse
        let e2 = WeightEntry(date: .now, weight: 1060)
        e2.horse = horse
        context.insert(e1)
        context.insert(e2)
        try! context.save()

        XCTAssertEqual(horse.weightEntries?.count, 2)

        context.delete(horse)
        try! context.save()

        let descriptor = FetchDescriptor<WeightEntry>()
        let entries = try! context.fetch(descriptor)
        XCTAssertEqual(entries.count, 0)
    }

    func testMultipleWeightEntries() {
        let horse = Horse(name: "Storm")
        context.insert(horse)

        let calendar = Calendar.current
        for i in 0..<5 {
            let entry = WeightEntry(
                date: calendar.date(byAdding: .month, value: -i, to: .now)!,
                weight: 1200 + Double(i * 10)
            )
            entry.horse = horse
            context.insert(entry)
        }
        try! context.save()

        XCTAssertEqual(horse.weightEntries?.count, 5)
        let sorted = (horse.weightEntries ?? []).sorted { $0.date > $1.date }
        XCTAssertEqual(sorted.first?.weight, 1200)
        XCTAssertEqual(sorted.last?.weight, 1240)
    }
}
