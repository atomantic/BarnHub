import Foundation
import SwiftData

extension ModelContext {
    func saveWithLogging() {
        do {
            try save()
            BarnHubLogger.success("ModelContext saved")
        } catch {
            BarnHubLogger.error("ModelContext save failed error=\(error.localizedDescription)")
        }
    }

    func deleteWithLogging(_ model: any PersistentModel) {
        delete(model)
        do {
            try save()
            BarnHubLogger.success("ModelContext deleted and saved")
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

    static var schema: Schema { Schema(models) }
}

// MARK: - Removing records

/// Removes records the way the user chose (#30), deleting each model explicitly
/// instead of relying on delete rules.
enum RecordRemoval {
    /// Deletes every record of every model type, one by one (not a batch delete),
    /// so each delete syncs to iCloud. With `keepDocuments`, horse and client
    /// documents survive along with the horses and clients they belong to, since
    /// a document is only visible through its owner.
    static func deleteAllData(in context: ModelContext, keepDocuments: Bool) throws {
        var keep = Set<PersistentIdentifier>()
        if keepDocuments {
            for document in try context.fetch(FetchDescriptor<HorseDocument>()) {
                keep.insert(document.persistentModelID)
                if let horse = document.horse { keep.insert(horse.persistentModelID) }
            }
            for document in try context.fetch(FetchDescriptor<ClientDocument>()) {
                keep.insert(document.persistentModelID)
                if let client = document.client { keep.insert(client.persistentModelID) }
            }
        }
        for type in BarnHubSchema.models {
            try deleteEach(type, keeping: keep, in: context)
        }
        try context.save()
    }

    private static func deleteEach<T: PersistentModel>(
        _: T.Type, keeping keep: Set<PersistentIdentifier>, in context: ModelContext
    ) throws {
        for model in try context.fetch(FetchDescriptor<T>()) where !keep.contains(model.persistentModelID) {
            context.delete(model)
        }
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
