import Foundation
import SwiftData

@Model
final class FarrierVisit {
    var date: Date = Date.now
    var farrierName: String = ""
    var serviceDescription: String = ""
    var cost: Double = 0
    var nextDueDate: Date? = nil

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    init(
        date: Date = .now,
        farrierName: String = "",
        serviceDescription: String = "",
        cost: Double = 0,
        nextDueDate: Date? = nil
    ) {
        self.date = date
        self.farrierName = farrierName
        self.serviceDescription = serviceDescription
        self.cost = cost
        self.nextDueDate = nextDueDate
    }
}
