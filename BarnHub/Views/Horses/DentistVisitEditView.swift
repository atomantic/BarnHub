import SwiftUI
import SwiftData

typealias DentistVisitEditView = CareVisitEditView<DentistVisit>

extension DentistVisit: CareVisit {
    var providerName: String {
        get { dentistName }
        set { dentistName = newValue }
    }

    static func makeNew() -> DentistVisit { DentistVisit() }

    static var providerNameLabel: LocalizedStringKey { "Dentist Name" }
    static var newTitle: LocalizedStringKey { "New Dentist Visit" }
    static var editTitle: LocalizedStringKey { "Edit Dentist Visit" }
    static var deleteTitle: LocalizedStringKey { "Delete Dentist Visit" }
    static var deleteMessage: LocalizedStringKey { "Are you sure you want to delete this dentist visit?" }
    static var savedToast: String { appLocalized("Dentist visit saved", comment: "Toast after saving a dentist visit") }
    static var deletedToast: String { appLocalized("Dentist visit deleted", comment: "Toast after deleting a dentist visit") }
    static var logName: String { "dentist visit" }
}
