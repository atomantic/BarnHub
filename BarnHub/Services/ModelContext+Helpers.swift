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
