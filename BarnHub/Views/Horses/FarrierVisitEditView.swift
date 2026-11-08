import SwiftUI
import SwiftData

typealias FarrierVisitEditView = CareVisitEditView<FarrierVisit>

extension FarrierVisit: CareVisit {
    var providerName: String {
        get { farrierName }
        set { farrierName = newValue }
    }

    static func makeNew() -> FarrierVisit { FarrierVisit() }

    static var providerNameLabel: LocalizedStringKey { "Farrier Name" }
    static var newTitle: LocalizedStringKey { "New Farrier Visit" }
    static var editTitle: LocalizedStringKey { "Edit Farrier Visit" }
    static var deleteTitle: LocalizedStringKey { "Delete Farrier Visit" }
    static var deleteMessage: LocalizedStringKey { "Are you sure you want to delete this farrier visit?" }
    static var savedToast: String { appLocalized("Farrier visit saved", comment: "Toast after saving a farrier visit") }
    static var deletedToast: String { appLocalized("Farrier visit deleted", comment: "Toast after deleting a farrier visit") }
    static var logName: String { "farrier visit" }
}
