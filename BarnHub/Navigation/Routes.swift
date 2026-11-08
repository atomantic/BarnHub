import Foundation
import SwiftData

enum HomeRoute: Hashable {
    case horses
    case clients
    case schedule
    case supplies
    case accounting
    case reports
    case barnNotes
    case settings
    case dataManagement
}

enum HorseRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case edit(PersistentIdentifier?)
    case addVetRecord(PersistentIdentifier)
    case addFarrierVisit(PersistentIdentifier)
    case addDentistVisit(PersistentIdentifier)
    case editVetRecord(PersistentIdentifier)
    case editFarrierVisit(PersistentIdentifier)
    case editDentistVisit(PersistentIdentifier)
    case healthTimeline(PersistentIdentifier)
    case weightChart(PersistentIdentifier)
    case documents(PersistentIdentifier)
    case feedPlan(PersistentIdentifier)
    case editFeedEntry(PersistentIdentifier, PersistentIdentifier?)
}

enum ClientRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case edit(PersistentIdentifier?)
    case manageHorses(PersistentIdentifier)
    case invoiceHistory(PersistentIdentifier)
    case paymentHistory(PersistentIdentifier)
    case documents(PersistentIdentifier)
}

enum AccountingRoute: Hashable {
    case list
    case edit(PersistentIdentifier?)
}

enum SubscriptionRoute: Hashable {
    case paywall
}

enum BarnRoute: Hashable {
    case supplies
    case supplyEdit(PersistentIdentifier?)
    case reminders
    case reminderEdit(PersistentIdentifier?)
    case barnNotes
    case barnNoteEdit(PersistentIdentifier?)
    case vetSchedule
    case addVetRecord
    case farrierSchedule
    case addFarrierVisit
    case dentistSchedule
    case addDentistVisit
    case lessons
    case lessonEdit(PersistentIdentifier?)
    case feedProducts
    case feedProductEdit(PersistentIdentifier?)
}

// MARK: - Forms

// Add/edit screens open as a sheet when `Router.presentsFormsAsSheets`. Each
// switch is exhaustive (no `default`) so a new route has to be classified.

extension HomeRoute {
    var isForm: Bool {
        switch self {
        case .horses, .clients, .schedule, .supplies, .accounting, .reports,
             .barnNotes, .settings, .dataManagement:
            false
        }
    }
}

extension HorseRoute {
    var isForm: Bool {
        switch self {
        case .edit, .addVetRecord, .addFarrierVisit, .addDentistVisit,
             .editVetRecord, .editFarrierVisit, .editDentistVisit:
            true
        case .list, .detail, .healthTimeline, .weightChart, .documents, .feedPlan:
            false
        case .editFeedEntry:
            // Already opens in its own sheet from the feed plan.
            false
        }
    }
}

extension ClientRoute {
    var isForm: Bool {
        switch self {
        case .edit:
            true
        case .list, .detail, .manageHorses, .invoiceHistory, .paymentHistory, .documents:
            false
        }
    }
}

extension AccountingRoute {
    var isForm: Bool {
        switch self {
        case .edit: true
        case .list: false
        }
    }
}

extension SubscriptionRoute {
    var isForm: Bool {
        switch self {
        case .paywall: false
        }
    }
}

extension BarnRoute {
    var isForm: Bool {
        switch self {
        case .supplyEdit, .reminderEdit, .barnNoteEdit, .addVetRecord, .addFarrierVisit,
             .addDentistVisit, .lessonEdit, .feedProductEdit:
            true
        case .supplies, .reminders, .barnNotes, .vetSchedule, .farrierSchedule,
             .dentistSchedule, .lessons, .feedProducts:
            false
        }
    }
}

// MARK: - Pro features

// Checked where each route's screen is built (see `ProGated`). Exhaustive, like
// `isForm`, so a new route has to say whether it needs Pro.

extension HomeRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .clients:
            .clients
        case .horses, .schedule, .supplies, .accounting, .barnNotes, .settings, .dataManagement:
            nil
        case .reports:
            // Free users get the basic reports; ReportsView locks the rest itself.
            nil
        }
    }
}

extension HorseRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .documents:
            .documents
        case .list, .detail, .edit, .addVetRecord, .addFarrierVisit, .addDentistVisit,
             .editVetRecord, .editFarrierVisit, .editDentistVisit, .healthTimeline,
             .weightChart, .feedPlan, .editFeedEntry:
            nil
        }
    }
}

extension ClientRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .list, .detail, .edit, .manageHorses, .paymentHistory:
            .clients
        case .invoiceHistory:
            .invoices
        case .documents:
            .documents
        }
    }
}

extension AccountingRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .list, .edit: nil
        }
    }
}

extension SubscriptionRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .paywall: nil
        }
    }
}

extension BarnRoute {
    var requiredProFeature: ProFeature? {
        switch self {
        case .supplies, .supplyEdit, .reminders, .reminderEdit, .barnNotes, .barnNoteEdit,
             .vetSchedule, .addVetRecord, .farrierSchedule, .addFarrierVisit,
             .dentistSchedule, .addDentistVisit, .lessons, .lessonEdit,
             .feedProducts, .feedProductEdit:
            nil
        }
    }
}
