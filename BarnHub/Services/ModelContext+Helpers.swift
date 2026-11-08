import Foundation
import SwiftData

extension ModelContext {
    func saveWithLogging() {
        do {
            try save()
            BarnHubLogger.success("ModelContext saved")
            NotificationCenter.default.post(name: .barnHubModelContextDidSave, object: self)
        } catch {
            BarnHubLogger.error("ModelContext save failed error=\(error.localizedDescription)")
        }
    }

    func deleteWithLogging(_ model: any PersistentModel) {
        delete(model)
        do {
            try save()
            BarnHubLogger.success("ModelContext deleted and saved")
            NotificationCenter.default.post(name: .barnHubModelContextDidSave, object: self)
        } catch {
            BarnHubLogger.error("ModelContext delete+save failed error=\(error.localizedDescription)")
        }
    }

    /// The live model for `id`, or nil once it has been deleted (or never existed).
    /// Use this instead of `model(for:)`, which returns a placeholder for a deleted
    /// ID: reading any property of it traps (`_InvalidFutureBackingData`), e.g. a
    /// detail view re-rendering right after its horse was deleted.
    func existingModel<T: PersistentModel>(for id: PersistentIdentifier?) -> T? {
        guard let id else { return nil }
        if let registered: T = registeredModel(for: id) {
            return registered.isDeleted ? nil : registered
        }
        var descriptor = FetchDescriptor<T>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        return try? fetch(descriptor).first
    }
}

/// A record waiting on a delete confirmation, held by ID (plus the name the dialog
/// shows) rather than by model: it may be deleted on another device before the
/// user answers, and reading a deleted model traps. Resolve the ID with
/// `existingModel(for:)` on confirm.
struct PendingDeletion {
    let id: PersistentIdentifier
    let name: String
}

// MARK: - Schema

enum BarnHubSchema {
    /// Every SwiftData model type in the app, in one place, so the container and
    /// Delete All Data can't drift apart when a model is added.
    static let models: [any PersistentModel.Type] = [
        Horse.self, Client.self, Transaction.self,
        VetRecord.self, FarrierVisit.self, DentistVisit.self, SupplyItem.self, Reminder.self,
        Invoice.self, WeightEntry.self, ClientDocument.self, HorseDocument.self,
        FeedProduct.self, FeedPlanEntry.self, BarnNote.self, Lesson.self,
    ]

    /// The current schema, versioned so later model changes can migrate.
    static var schema: Schema { Schema(versionedSchema: BarnHubSchemaV1.self) }
}

/// The schema as shipped before versioning was added. It names the live model
/// types, so it adds a version identifier without changing any entity, attribute
/// or version hash: stores created before it open unchanged.
///
/// Before the next model change, copy today's model definitions into this enum
/// as nested types (`BarnHubSchemaV1.Horse`, …) so V1 stays frozen, add
/// `BarnHubSchemaV2` naming the live types, and add a stage to the plan. CloudKit
/// stores only allow lightweight (additive) stages.
enum BarnHubSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { BarnHubSchema.models }
}

/// No stages yet: V1 is the only version.
enum BarnHubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BarnHubSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Removing records

/// Removes records the way the user chose (#30), deleting each model explicitly
/// instead of relying on delete rules.
enum RecordRemoval {
    /// Records deleted per save in `deleteAllData`.
    static let deletesPerSave = 1_000

    /// Deletes every record of every model type, one by one (not a batch delete),
    /// so each delete syncs to iCloud. With `keepDocuments`, horse and client
    /// documents survive along with the horses and clients they belong to, since
    /// a document is only visible through its owner.
    ///
    /// Runs in fresh contexts of `container`, so call it off the main actor
    /// (`CSVDataActor.deleteAllData`). Deleting a child while its owner still
    /// lists it makes SwiftData rewrite the owner's whole list for each row,
    /// which took minutes for tens of thousands of weigh-ins on one horse
    /// (#83). So every owner's lists are emptied first, in one assignment per
    /// list, then the children are deleted in batches with no owner left to
    /// update, and the horses, clients and feed products go last. `progress`
    /// goes from 0 to 1.
    static func deleteAllData(in container: ModelContainer, keepDocuments: Bool,
                              progress: ((Double) -> Void)? = nil) throws {
        var keep = Set<PersistentIdentifier>()
        let scan = makeContext(container)
        if keepDocuments {
            for document in try scan.fetch(FetchDescriptor<HorseDocument>()) {
                keep.insert(document.persistentModelID)
                if let horse = document.horse { keep.insert(horse.persistentModelID) }
            }
            for document in try scan.fetch(FetchDescriptor<ClientDocument>()) {
                keep.insert(document.persistentModelID)
                if let client = document.client { keep.insert(client.persistentModelID) }
            }
        }
        let owners: [any PersistentModel.Type] = [Horse.self, Client.self, FeedProduct.self]
        let children = BarnHubSchema.models.filter { type in !owners.contains { $0 == type } }
        func ids(_ types: [any PersistentModel.Type]) throws -> [[PersistentIdentifier]] {
            try types.map { type in try identifiers(type, in: scan).filter { !keep.contains($0) } }
        }
        let childIDs = try ids(children)
        let ownerIDs = try ids(owners)
        let childCount = childIDs.reduce(0) { $0 + $1.count }
        // Unlinking a child costs about as much as deleting it.
        let total = Double(max(1, 2 * childCount + ownerIDs.reduce(0) { $0 + $1.count }))
        var done = 0
        func advance(_ count: Int) {
            done += count
            progress?(min(1, Double(done) / total))
        }

        try unlinkChildren(in: container, keeping: keep, progress: advance)
        for ids in childIDs + ownerIDs {
            try delete(ids, in: container, progress: advance)
        }
        progress?(1)
    }

    private static func makeContext(_ container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private static func identifiers<T: PersistentModel>(_: T.Type, in context: ModelContext) throws -> [PersistentIdentifier] {
        try context.fetchIdentifiers(FetchDescriptor<T>())
    }

    /// Takes every child that isn't kept out of its horse's, client's or feed
    /// product's lists, one assignment per list, saving every
    /// `deletesPerSave` children. `progress` is told how many were taken out.
    private static func unlinkChildren(in container: ModelContainer, keeping keep: Set<PersistentIdentifier>,
                                       progress: (Int) -> Void) throws {
        var context = makeContext(container)
        var pending = 0
        func saveIfNeeded(force: Bool = false) throws {
            guard pending > 0, force || pending >= deletesPerSave else { return }
            try context.save()
            progress(pending)
            pending = 0
            context = makeContext(container)
        }
        func unlink<Owner: PersistentModel, Child: PersistentModel>(
            _ owner: Owner, _ list: ReferenceWritableKeyPath<Owner, [Child]?>
        ) {
            guard let current = owner[keyPath: list], !current.isEmpty else { return }
            let kept = current.filter { keep.contains($0.persistentModelID) }
            guard kept.count < current.count else { return }
            owner[keyPath: list] = kept
            pending += current.count - kept.count
        }
        // Owners are few, so fetching them unbatched is cheap (batched fetches
        // lose relationships before iOS 27, #69). Each is re-read in the
        // current context, since saving replaces it.
        for id in try identifiers(Horse.self, in: context) {
            guard let horse: Horse = context.existingModel(for: id) else { continue }
            unlink(horse, \.vetRecords)
            unlink(horse, \.farrierVisits)
            unlink(horse, \.dentistVisits)
            unlink(horse, \.reminders)
            unlink(horse, \.weightEntries)
            unlink(horse, \.lessons)
            unlink(horse, \.barnNotes)
            unlink(horse, \.documents)
            unlink(horse, \.feedPlanEntries)
            try saveIfNeeded()
        }
        for id in try identifiers(Client.self, in: context) {
            guard let client: Client = context.existingModel(for: id) else { continue }
            unlink(client, \.transactions)
            unlink(client, \.invoices)
            unlink(client, \.documents)
            unlink(client, \.lessons)
            try saveIfNeeded()
        }
        for id in try identifiers(FeedProduct.self, in: context) {
            guard let product: FeedProduct = context.existingModel(for: id) else { continue }
            unlink(product, \.planEntries)
            try saveIfNeeded()
        }
        try saveIfNeeded(force: true)
    }

    /// Deletes the records with `ids` one by one, `deletesPerSave` per save
    /// and fresh context, so each delete still syncs to iCloud and memory
    /// stays flat.
    private static func delete(_ ids: [PersistentIdentifier], in container: ModelContainer, progress: (Int) -> Void) throws {
        for start in stride(from: 0, to: ids.count, by: deletesPerSave) {
            let batch = ids[start..<min(start + deletesPerSave, ids.count)]
            let context = makeContext(container)
            for id in batch {
                context.delete(context.model(for: id))
            }
            try context.save()
            progress(batch.count)
        }
    }
}

extension CSVDataActor {
    /// Delete All Data off the main actor (see `RecordRemoval.deleteAllData`).
    func deleteAllData(keepDocuments: Bool, progress: CSVProgressHandler?) throws {
        try RecordRemoval.deleteAllData(in: modelContainer, keepDocuments: keepDocuments, progress: progress)
        BarnHubLogger.success("Deleted all data keepDocuments=\(keepDocuments)")
    }
}

/// Removing one client or horse. Their history is unlinked in code before the
/// delete, so accounting records survive whatever delete rule the relationship has.
extension RecordRemoval {
    /// Hides the client from the list; every invoice, transaction, lesson and
    /// document stays linked, so Reports and history are unchanged.
    static func deactivate(_ client: Client, in context: ModelContext) {
        client.isActive = false
        context.saveWithLogging()
    }

    /// Deletes the client with its invoices and documents (they're only reachable
    /// through the client). Transactions and lessons are kept, without a client,
    /// so income stays in Reports.
    static func delete(_ client: Client, in context: ModelContext) {
        for transaction in client.transactions ?? [] { transaction.client = nil }
        for lesson in client.lessons ?? [] { lesson.client = nil }
        // Save the unlinks before deleting, so the delete can't cascade to them.
        context.saveWithLogging()
        for invoice in client.invoices ?? [] { context.delete(invoice) }
        for document in client.documents ?? [] { context.delete(document) }
        context.deleteWithLogging(client)
    }

    /// Hides the horse from the list; all of its records stay.
    static func markInactive(_ horse: Horse, in context: ModelContext) {
        horse.isActive = false
        context.saveWithLogging()
    }

    /// Deletes the horse with its health records, reminders, weights, barn notes,
    /// documents and feed plan. Lessons carry client billing, so they're kept
    /// without a horse.
    static func delete(_ horse: Horse, in context: ModelContext) {
        for lesson in horse.lessons ?? [] { lesson.horse = nil }
        // Save the unlink before deleting, so the delete can't cascade to them.
        context.saveWithLogging()
        context.deleteWithLogging(horse)
    }
}

extension ModelContext {
    /// True when `id` names a record that no longer exists: it was deleted on this
    /// device or another one while a form was editing it. Edit forms check this
    /// before saving so they never insert a replacement for a deleted record.
    /// A nil `id` (a new record) is never "deleted".
    func isDeletedRecord<T: PersistentModel>(_ id: PersistentIdentifier?, as _: T.Type) -> Bool {
        guard let id else { return false }
        let model: T? = existingModel(for: id)
        return model == nil
    }
}
