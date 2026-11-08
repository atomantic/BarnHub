import Foundation
import SwiftUI

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case lesson, boarding, training, vetBill, farrier, dentist, feed, supplies, tack, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lesson:    return appLocalized("Lesson",    comment: "Transaction category")
        case .boarding:  return appLocalized("Boarding",  comment: "Transaction category")
        case .training:  return appLocalized("Training",  comment: "Transaction category")
        case .vetBill:   return appLocalized("Vet Bill",  comment: "Transaction category")
        case .farrier:   return appLocalized("Farrier",   comment: "Transaction category")
        case .dentist:   return appLocalized("Dentist",   comment: "Transaction category")
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

enum HorseGender: String, Codable, CaseIterable, Identifiable {
    case mare, stallion, gelding
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mare:     return appLocalized("Mare",     comment: "Horse gender")
        case .stallion: return appLocalized("Stallion", comment: "Horse gender")
        case .gelding:  return appLocalized("Gelding",  comment: "Horse gender")
        }
    }
}

enum FeedUnit: String, Codable, CaseIterable, Identifiable {
    case scoops, flakes, lbs, cups, oz, quarts, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .scoops: return appLocalized("scoops",  comment: "Feed unit")
        case .flakes: return appLocalized("flakes",  comment: "Feed unit")
        case .lbs:    return appLocalized("lbs",     comment: "Feed unit")
        case .cups:   return appLocalized("cups",    comment: "Feed unit")
        case .oz:     return appLocalized("oz",      comment: "Feed unit")
        case .quarts: return appLocalized("quarts",  comment: "Feed unit")
        case .other:  return appLocalized("units",   comment: "Feed unit")
        }
    }

    /// The unit for a given amount: singular for exactly 1 ("1 scoop"), plural otherwise.
    func displayName(for amount: Double) -> String {
        guard amount == 1 else { return displayName }
        switch self {
        case .scoops: return appLocalized("scoop", comment: "Feed unit, singular (amount of 1)")
        case .flakes: return appLocalized("flake", comment: "Feed unit, singular (amount of 1)")
        case .lbs:    return appLocalized("lb",    comment: "Feed unit, singular (amount of 1)")
        case .cups:   return appLocalized("cup",   comment: "Feed unit, singular (amount of 1)")
        case .oz:     return displayName
        case .quarts: return appLocalized("quart", comment: "Feed unit, singular (amount of 1)")
        case .other:  return appLocalized("unit",  comment: "Feed unit, singular (amount of 1)")
        }
    }
}

enum FeedTime: String, Codable, CaseIterable, Identifiable, Comparable {
    case morning, midday, evening
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .morning: return appLocalized("Morning", comment: "Feed time of day")
        case .midday:  return appLocalized("Midday",  comment: "Feed time of day")
        case .evening: return appLocalized("Evening", comment: "Feed time of day")
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday:  return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .midday:  return 1
        case .evening: return 2
        }
    }

    static func < (lhs: FeedTime, rhs: FeedTime) -> Bool {
        lhs.sortOrder < rhs.sortOrder
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
