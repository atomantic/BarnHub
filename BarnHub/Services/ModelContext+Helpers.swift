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
