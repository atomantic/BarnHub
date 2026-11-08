import XCTest
import SwiftData
import ObjectiveC
import CoreData
@testable import BarnHub

/// Verifies the shared schema lists every SwiftData model type, and that each
/// type can be inserted and persisted in an in-memory container.
final class ModelSchemaTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: BarnHubSchema.schema,
            configurations: config
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Shared model list

    /// Every `@Model` class compiled into the app, found through the runtime so a
    /// new model can't be left out of `BarnHubSchema.models` unnoticed.
    private func modelTypesInApp() throws -> Set<String> {
        let image = try XCTUnwrap(class_getImageName(Horse.self))
        var count: UInt32 = 0
        let names = try XCTUnwrap(objc_copyClassNamesForImage(image, &count))
        defer { free(names) }
        var found = Set<String>()
        for index in 0..<Int(count) {
            guard let cls = objc_getClass(names[index]) as? AnyClass,
                  cls is any PersistentModel.Type else { continue }
            found.insert(String(describing: cls))
        }
        return found
    }

    func test_sharedModelList_matchesEveryModelType() throws {
        let inApp = try modelTypesInApp()
        let listed = BarnHubSchema.models.map { String(describing: $0) }
        XCTAssertTrue(inApp.contains("Horse"), "runtime lookup found no models: \(inApp)")
        XCTAssertEqual(Set(listed), inApp, "BarnHubSchema.models must list every @Model type")
        XCTAssertEqual(Set(listed).count, listed.count, "BarnHubSchema.models lists a type twice")
    }

    func test_container_hasAnEntityPerListedModel() {
        let entities = Set(container.schema.entities.map(\.name))
        XCTAssertEqual(entities, Set(BarnHubSchema.models.map { String(describing: $0) }))
    }

    // MARK: - Insert and fetch

    func test_Horse_canBeInsertedAndFetched() throws {
        let h = Horse(name: "Blaze")
        context.insert(h)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Blaze")
    }

    func test_Client_canBeInsertedAndFetched() throws {
        let c = Client(firstName: "Anna", lastName: "Smith")
        context.insert(c)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Client>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.fullName, "Anna Smith")
    }

    func test_Transaction_canBeInsertedAndFetched() throws {
        let t = Transaction(amount: 250.0, memo: "Boarding fee", category: .boarding, type: .income)
        context.insert(t)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.amount, 250.0)
    }

    func test_VetRecord_canBeInsertedAndFetched() throws {
        let v = VetRecord(vetName: "Dr. Hooves", descriptionText: "Annual checkup")
        context.insert(v)
        try context.save()
        let results = try context.fetch(FetchDescriptor<VetRecord>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.vetName, "Dr. Hooves")
    }

    func test_FarrierVisit_canBeInsertedAndFetched() throws {
        let f = FarrierVisit(farrierName: "Joe", serviceDescription: "Trim")
        context.insert(f)
        try context.save()
        let results = try context.fetch(FetchDescriptor<FarrierVisit>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.farrierName, "Joe")
    }

    func test_SupplyItem_canBeInsertedAndFetched() throws {
        let s = SupplyItem(name: "Hay", quantity: 50, reorderThreshold: 10)
        context.insert(s)
        try context.save()
        let results = try context.fetch(FetchDescriptor<SupplyItem>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Hay")
    }

    func test_Reminder_canBeInsertedAndFetched() throws {
        let r = Reminder(title: "Deworming")
        context.insert(r)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Reminder>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Deworming")
    }

    func test_Invoice_canBeInsertedAndFetched() throws {
        let i = Invoice(totalAmount: 500.0)
        context.insert(i)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Invoice>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.totalAmount, 500.0)
    }

    func test_WeightEntry_canBeInsertedAndFetched() throws {
        let w = WeightEntry(weight: 1100.0)
        context.insert(w)
        try context.save()
        let results = try context.fetch(FetchDescriptor<WeightEntry>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.weight, 1100.0)
    }

    func test_ClientDocument_canBeInsertedAndFetched() throws {
        let d = ClientDocument(title: "Contract 2026", documentType: .pdf)
        context.insert(d)
        try context.save()
        let results = try context.fetch(FetchDescriptor<ClientDocument>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Contract 2026")
    }

    func test_BarnNote_canBeInsertedAndFetched() throws {
        let n = BarnNote(content: "Barn door needs repair", category: .maintenance)
        context.insert(n)
        try context.save()
        let results = try context.fetch(FetchDescriptor<BarnNote>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.content, "Barn door needs repair")
        XCTAssertEqual(results.first?.category, .maintenance)
    }

    func test_Lesson_canBeInsertedAndFetched() throws {
        let l = Lesson(duration: 45, lessonType: .group, cost: 80.0)
        context.insert(l)
        try context.save()
        let results = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.duration, 45)
        XCTAssertEqual(results.first?.lessonType, .group)
    }

    func test_DentistVisit_canBeInsertedAndFetched() throws {
        context.insert(DentistVisit(dentistName: "Dr. Float", serviceDescription: "Float"))
        try context.save()
        let results = try context.fetch(FetchDescriptor<DentistVisit>())
        XCTAssertEqual(results.map(\.dentistName), ["Dr. Float"])
    }

    func test_HorseDocument_canBeInsertedAndFetched() throws {
        context.insert(HorseDocument(title: "Coggins", documentType: .pdf))
        try context.save()
        let results = try context.fetch(FetchDescriptor<HorseDocument>())
        XCTAssertEqual(results.map(\.title), ["Coggins"])
    }

    func test_FeedProduct_canBeInsertedAndFetched() throws {
        context.insert(FeedProduct(name: "Senior Feed", defaultUnit: .scoops))
        try context.save()
        let results = try context.fetch(FetchDescriptor<FeedProduct>())
        XCTAssertEqual(results.map(\.name), ["Senior Feed"])
    }

    func test_FeedPlanEntry_canBeInsertedAndFetched() throws {
        context.insert(FeedPlanEntry(amount: 2, unit: .scoops, feedTime: .evening))
        try context.save()
        let results = try context.fetch(FetchDescriptor<FeedPlanEntry>())
        XCTAssertEqual(results.map(\.amount), [2])
        XCTAssertEqual(results.first?.feedTime, .evening)
    }

    /// #28: onboarding inserts a horse, then links clients. With a `= nil` default on
    /// the many-to-many, early macOS 14 / iOS 17 asserted inside Horse.init.
    func test_Horse_insertThenLinkClient_saves() throws {
        let horse = Horse(name: "First Horse")
        context.insert(horse)
        let client = Client(firstName: "Owner")
        context.insert(client)
        horse.clients = [client]
        try context.save()

        let horses = try context.fetch(FetchDescriptor<Horse>())
        XCTAssertEqual(horses.count, 1)
        XCTAssertEqual(horses.first?.clients?.map(\.firstName), ["Owner"])
        XCTAssertEqual(client.horses?.map(\.name), ["First Horse"])
    }

    func test_Horse_newInstance_hasNoClients() {
        XCTAssertNil(Horse(name: "Unlinked").clients)
        XCTAssertNil(Client(firstName: "Solo").horses)
    }

    // MARK: - CareVisit (shared farrier / dentist edit form)

    /// `CareVisitEditView` writes the provider through `providerName`; it must land
    /// in each model's own stored field so saved visits read back unchanged.
    func test_careVisit_providerNameMapsOntoEachModelsField() throws {
        let dentist = DentistVisit.makeNew()
        dentist.providerName = "Dr. Molar"
        let farrier = FarrierVisit.makeNew()
        farrier.providerName = "Sam Shoe"
        context.insert(dentist)
        context.insert(farrier)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<DentistVisit>()).first?.dentistName, "Dr. Molar")
        XCTAssertEqual(try context.fetch(FetchDescriptor<FarrierVisit>()).first?.farrierName, "Sam Shoe")
        XCTAssertNotNil(dentist.notificationKey)
        XCTAssertNotNil(farrier.notificationKey)
    }
}

/// Adding `BarnHubSchemaV1` and the migration plan must not change existing
/// stores: one written by a build without versioning opens with the same data
/// and the same entity version hashes (what Core Data and CloudKit compare).
final class SchemaVersioningTests: XCTestCase {

    private var storeDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaVersioningTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDirectory)
        storeDirectory = nil
        try super.tearDownWithError()
    }

    private var storeURL: URL { storeDirectory.appendingPathComponent("BarnHub.store") }

    private func storeVersionHashes() throws -> [String: Data] {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            type: .sqlite, at: storeURL
        )
        return try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
    }

    func test_versionedSchema_keepsEntityNamesAndAttributes() {
        let unversioned = Schema(BarnHubSchema.models)
        let versioned = BarnHubSchema.schema
        XCTAssertEqual(versioned.version, Schema.Version(1, 0, 0))
        func shape(_ schema: Schema) -> [String: [String]] {
            Dictionary(uniqueKeysWithValues: schema.entities.map { entity in
                (entity.name, (entity.attributes.map(\.name) + entity.relationships.map(\.name)).sorted())
            })
        }
        XCTAssertEqual(shape(versioned), shape(unversioned))
    }

    func test_storeFromUnversionedBuild_opensUnchangedWithMigrationPlan() throws {
        do {
            let legacy = try ModelContainer(
                for: Schema(BarnHubSchema.models),
                configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            )
            let context = ModelContext(legacy)
            let horse = Horse(name: "Legacy")
            let client = Client(firstName: "Owner")
            context.insert(horse)
            context.insert(client)
            horse.clients = [client]
            context.insert(Transaction(amount: 42, memo: "Hay", category: .feed, type: .expense))
            try context.save()
        }
        let hashesBefore = try storeVersionHashes()
        XCTAssertEqual(hashesBefore.count, BarnHubSchema.models.count)

        do {
            let current = try ModelContainer(
                for: BarnHubSchema.schema,
                migrationPlan: BarnHubMigrationPlan.self,
                configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
            )
            let context = ModelContext(current)
            let horses = try context.fetch(FetchDescriptor<Horse>())
            XCTAssertEqual(horses.map(\.name), ["Legacy"])
            XCTAssertEqual(horses.first?.clients?.map(\.firstName), ["Owner"])
            XCTAssertEqual(try context.fetch(FetchDescriptor<Transaction>()).map(\.amount), [42])
            context.insert(Horse(name: "Added after versioning"))
            try context.save()
        }
        XCTAssertEqual(try storeVersionHashes(), hashesBefore, "Versioning must not change any entity hash")

        // And an older (unversioned) build can still open the store afterwards.
        let reopened = try ModelContainer(
            for: Schema(BarnHubSchema.models),
            configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        )
        XCTAssertEqual(try ModelContext(reopened).fetchCount(FetchDescriptor<Horse>()), 2)
    }
}
