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
    case healthTimeline(PersistentIdentifier)
}

enum ClientRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case edit(PersistentIdentifier?)
    case manageHorses(PersistentIdentifier)
    case invoiceHistory(PersistentIdentifier)
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
    case lessons
    case lessonEdit(PersistentIdentifier?)
}
