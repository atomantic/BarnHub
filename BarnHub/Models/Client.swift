import Foundation
import SwiftData

@Model
final class Client {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var emergencyContact: String = ""
    var emergencyPhone: String = ""
    var notes: String = ""
    var isActive: Bool = true

    @Relationship(deleteRule: .nullify)
    var horses: [Horse]? = nil

    @Relationship(deleteRule: .cascade)
    var transactions: [Transaction]? = nil

    @Relationship(deleteRule: .cascade)
    var invoices: [Invoice]? = nil

    @Relationship(deleteRule: .cascade)
    var documents: [ClientDocument]? = nil

    @Relationship(deleteRule: .cascade)
    var lessons: [Lesson]? = nil

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    init(
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        phone: String = "",
        emergencyContact: String = "",
        emergencyPhone: String = "",
        notes: String = "",
        isActive: Bool = true
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.emergencyContact = emergencyContact
        self.emergencyPhone = emergencyPhone
        self.notes = notes
        self.isActive = isActive
    }
}
