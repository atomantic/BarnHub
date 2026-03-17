import Foundation
import SwiftData

enum HomeRoute: Hashable {
    case horses
    case clients
    case schedule
    case supplies
    case accounting
    case reports
}

enum HorseRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case edit(PersistentIdentifier?)
    case addVetRecord(PersistentIdentifier)
    case addFarrierVisit(PersistentIdentifier)
}

enum ClientRoute: Hashable {
    case list
    case detail(PersistentIdentifier)
    case edit(PersistentIdentifier?)
    case manageHorses(PersistentIdentifier)
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
    case vetSchedule
    case farrierSchedule
}
