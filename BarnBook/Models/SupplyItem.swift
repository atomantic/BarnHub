import Foundation
import SwiftData

@Model
final class SupplyItem {
    var name: String = ""
    var categoryRaw: String = ""
    var quantity: Double = 0
    var unit: String = ""
    var reorderThreshold: Double = 0
    var lastOrderedDate: Date? = nil

    var isLowStock: Bool {
        quantity <= reorderThreshold
    }

    init(
        name: String = "",
        categoryRaw: String = "",
        quantity: Double = 0,
        unit: String = "",
        reorderThreshold: Double = 0,
        lastOrderedDate: Date? = nil
    ) {
        self.name = name
        self.categoryRaw = categoryRaw
        self.quantity = quantity
        self.unit = unit
        self.reorderThreshold = reorderThreshold
        self.lastOrderedDate = lastOrderedDate
    }
}
