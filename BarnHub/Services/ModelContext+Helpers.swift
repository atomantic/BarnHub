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

    func existingModel<T: PersistentModel>(for id: PersistentIdentifier?) -> T? {
        guard let id else { return nil }
        return model(for: id) as? T
    }
}
