import Foundation
import SwiftUI

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case lesson, boarding, training, vetBill, farrier, feed, supplies, tack, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lesson:    return appLocalized("Lesson",    comment: "Transaction category")
        case .boarding:  return appLocalized("Boarding",  comment: "Transaction category")
        case .training:  return appLocalized("Training",  comment: "Transaction category")
        case .vetBill:   return appLocalized("Vet Bill",  comment: "Transaction category")
        case .farrier:   return appLocalized("Farrier",   comment: "Transaction category")
        case .feed:      return appLocalized("Feed",      comment: "Transaction category")
        case .supplies:  return appLocalized("Supplies",  comment: "Transaction category")
        case .tack:      return appLocalized("Tack",      comment: "Transaction category")
        case .other:     return appLocalized("Other",     comment: "Transaction category")
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .income:  return appLocalized("Income",  comment: "Transaction type")
        case .expense: return appLocalized("Expense", comment: "Transaction type")
        }
    }
}

enum LessonType: String, Codable, CaseIterable, Identifiable {
    case privateLesson = "private"
    case group, training, evaluation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .privateLesson: return appLocalized("Private",    comment: "Lesson type")
        case .group:         return appLocalized("Group",      comment: "Lesson type")
        case .training:      return appLocalized("Training",   comment: "Lesson type")
        case .evaluation:    return appLocalized("Evaluation", comment: "Lesson type")
        }
    }
}

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, monthly, quarterly, biannually, annually
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .once:        return appLocalized("Once",        comment: "Reminder frequency")
        case .daily:       return appLocalized("Daily",       comment: "Reminder frequency")
        case .weekly:      return appLocalized("Weekly",      comment: "Reminder frequency")
        case .monthly:     return appLocalized("Monthly",     comment: "Reminder frequency")
        case .quarterly:   return appLocalized("Quarterly",   comment: "Reminder frequency")
        case .biannually:  return appLocalized("Biannually",  comment: "Reminder frequency")
        case .annually:    return appLocalized("Annually",    comment: "Reminder frequency")
        }
    }
}

enum BarnNoteCategory: String, Codable, CaseIterable, Identifiable {
    case general, observation, incident, maintenance, health, weather
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .general:     return appLocalized("General",     comment: "Barn note category")
        case .observation: return appLocalized("Observation", comment: "Barn note category")
        case .incident:    return appLocalized("Incident",    comment: "Barn note category")
        case .maintenance: return appLocalized("Maintenance", comment: "Barn note category")
        case .health:      return appLocalized("Health",      comment: "Barn note category")
        case .weather:     return appLocalized("Weather",     comment: "Barn note category")
        }
    }
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .observation: return "eye"
        case .incident: return "exclamationmark.triangle"
        case .maintenance: return "wrench.and.screwdriver"
        case .health: return "heart"
        case .weather: return "cloud.sun"
        }
    }
}
