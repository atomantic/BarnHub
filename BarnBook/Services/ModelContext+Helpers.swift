import Foundation
import SwiftData

extension ModelContext {
    func saveWithLogging() {
        do {
            try save()
            BarnBookLogger.success("ModelContext saved")
        } catch {
            BarnBookLogger.error("ModelContext save failed error=\(error.localizedDescription)")
        }
    }

    func deleteWithLogging(_ model: any PersistentModel) {
        delete(model)
        do {
            try save()
            BarnBookLogger.success("ModelContext deleted and saved")
        } catch {
            BarnBookLogger.error("ModelContext delete+save failed error=\(error.localizedDescription)")
        }
    }
}
