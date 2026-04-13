import Foundation
import SwiftData

@Model
final class FeedProduct {
    var name: String = ""
    var brand: String = ""
    var notes: String = ""
    var defaultUnitRaw: String = FeedUnit.scoops.rawValue

    @Attribute(.externalStorage)
    var photoData: Data? = nil

    @Relationship(deleteRule: .nullify)
    var planEntries: [FeedPlanEntry]? = nil

    var defaultUnit: FeedUnit {
        get { FeedUnit(rawValue: defaultUnitRaw) ?? .scoops }
        set { defaultUnitRaw = newValue.rawValue }
    }

    init(name: String = "", brand: String = "", notes: String = "", defaultUnit: FeedUnit = .scoops, photoData: Data? = nil) {
        self.name = name
        self.brand = brand
        self.notes = notes
        self.defaultUnitRaw = defaultUnit.rawValue
        self.photoData = photoData
    }
}
