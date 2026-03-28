import Foundation
import SwiftData

@Model
final class BarnNote {
    var content: String = ""
    var date: Date = Date.now
    var categoryRaw: String = BarnNoteCategory.general.rawValue

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    var category: BarnNoteCategory {
        get { BarnNoteCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        content: String = "",
        date: Date = .now,
        category: BarnNoteCategory = .general,
        horse: Horse? = nil
    ) {
        self.content = content
        self.date = date
        self.categoryRaw = category.rawValue
        self.horse = horse
    }
}
