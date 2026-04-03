import Foundation
import SwiftUI

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case lesson, boarding, training, vetBill, farrier, feed, supplies, tack, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lesson:    return String(localized: "Lesson",    comment: "Transaction category")
        case .boarding:  return String(localized: "Boarding",  comment: "Transaction category")
        case .training:  return String(localized: "Training",  comment: "Transaction category")
        case .vetBill:   return String(localized: "Vet Bill",  comment: "Transaction category")
        case .farrier:   return String(localized: "Farrier",   comment: "Transaction category")
        case .feed:      return String(localized: "Feed",      comment: "Transaction category")
        case .supplies:  return String(localized: "Supplies",  comment: "Transaction category")
        case .tack:      return String(localized: "Tack",      comment: "Transaction category")
        case .other:     return String(localized: "Other",     comment: "Transaction category")
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .income:  return "Income"
        case .expense: return "Expense"
        }
    }
}

enum LessonType: String, Codable, CaseIterable, Identifiable {
    case privateLesson = "private"
    case group, training, evaluation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .privateLesson: return String(localized: "Private",    comment: "Lesson type")
        case .group:         return String(localized: "Group",      comment: "Lesson type")
        case .training:      return String(localized: "Training",   comment: "Lesson type")
        case .evaluation:    return String(localized: "Evaluation", comment: "Lesson type")
        }
    }
}

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, monthly, quarterly, biannually, annually
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .once:        return "Once"
        case .daily:       return "Daily"
        case .weekly:      return "Weekly"
        case .monthly:     return "Monthly"
        case .quarterly:   return "Quarterly"
        case .biannually:  return "Biannually"
        case .annually:    return "Annually"
        }
    }
}

enum BarnNoteCategory: String, Codable, CaseIterable, Identifiable {
    case general, observation, incident, maintenance, health, weather
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .general:     return "General"
        case .observation: return "Observation"
        case .incident:    return "Incident"
        case .maintenance: return "Maintenance"
        case .health:      return "Health"
        case .weather:     return "Weather"
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
