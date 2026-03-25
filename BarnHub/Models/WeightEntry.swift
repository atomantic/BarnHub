import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date = Date.now
    var weight: Double = 0

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    init(
        date: Date = .now,
        weight: Double = 0
    ) {
        self.date = date
        self.weight = weight
    }
}
