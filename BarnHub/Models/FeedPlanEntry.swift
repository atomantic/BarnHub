import Foundation
import SwiftData

@Model
final class FeedPlanEntry {
    var amount: Double = 1.0
    var unitRaw: String = FeedUnit.scoops.rawValue
    var feedTimeRaw: String = FeedTime.morning.rawValue
    var assignedPerson: String = ""
    var notes: String = ""

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    @Relationship(deleteRule: .nullify)
    var product: FeedProduct? = nil

    var unit: FeedUnit {
        get { FeedUnit(rawValue: unitRaw) ?? .scoops }
        set { unitRaw = newValue.rawValue }
    }

    var feedTime: FeedTime {
        get { FeedTime(rawValue: feedTimeRaw) ?? .morning }
        set { feedTimeRaw = newValue.rawValue }
    }

    var summary: String {
        let qty = amount == Double(Int(amount)) ? "\(Int(amount))" : String(format: "%.1f", amount)
        let productName = product?.name ?? appLocalized("Unknown", comment: "Unknown feed product")
        return "\(qty) \(unit.displayName(for: amount)) \(productName)"
    }

    init(
        amount: Double = 1.0,
        unit: FeedUnit = .scoops,
        feedTime: FeedTime = .morning,
        assignedPerson: String = "",
        notes: String = ""
    ) {
        self.amount = amount
        self.unitRaw = unit.rawValue
        self.feedTimeRaw = feedTime.rawValue
        self.assignedPerson = assignedPerson
        self.notes = notes
    }
}
