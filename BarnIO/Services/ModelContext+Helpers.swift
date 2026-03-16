import Foundation
import SwiftData

extension ModelContext {
    func saveWithLogging() {
        do {
            try save()
            BarnIOLogger.success("ModelContext saved")
        } catch {
            BarnIOLogger.error("ModelContext save failed error=\(error.localizedDescription)")
        }
    }

    func deleteWithLogging(_ model: any PersistentModel) {
        delete(model)
        do {
            try save()
            BarnIOLogger.success("ModelContext deleted and saved")
        } catch {
            BarnIOLogger.error("ModelContext delete+save failed error=\(error.localizedDescription)")
        }
    }
}
