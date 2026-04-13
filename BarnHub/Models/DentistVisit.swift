import Foundation
import SwiftData

@Model
final class DentistVisit {
    var date: Date = Date.now
    var dentistName: String = ""
    var serviceDescription: String = ""
    var cost: Double = 0
    var nextDueDate: Date? = nil

    @Relationship(deleteRule: .nullify)
    var horse: Horse? = nil

    init(
        date: Date = .now,
        dentistName: String = "",
        serviceDescription: String = "",
        cost: Double = 0,
        nextDueDate: Date? = nil
    ) {
        self.date = date
        self.dentistName = dentistName
        self.serviceDescription = serviceDescription
        self.cost = cost
        self.nextDueDate = nextDueDate
    }
}
