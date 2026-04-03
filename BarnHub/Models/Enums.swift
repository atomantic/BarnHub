import Foundation

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
    var displayName: String {
        switch self {
        case .income:  return String(localized: "Income",  comment: "Transaction type")
        case .expense: return String(localized: "Expense", comment: "Transaction type")
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
    var displayName: String {
        switch self {
        case .once:        return String(localized: "Once",        comment: "Reminder frequency")
        case .daily:       return String(localized: "Daily",       comment: "Reminder frequency")
        case .weekly:      return String(localized: "Weekly",      comment: "Reminder frequency")
        case .monthly:     return String(localized: "Monthly",     comment: "Reminder frequency")
        case .quarterly:   return String(localized: "Quarterly",   comment: "Reminder frequency")
        case .biannually:  return String(localized: "Biannually",  comment: "Reminder frequency")
        case .annually:    return String(localized: "Annually",    comment: "Reminder frequency")
        }
    }
}

enum BarnNoteCategory: String, Codable, CaseIterable, Identifiable {
    case general, observation, incident, maintenance, health, weather
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .general:     return String(localized: "General",     comment: "Barn note category")
        case .observation: return String(localized: "Observation", comment: "Barn note category")
        case .incident:    return String(localized: "Incident",    comment: "Barn note category")
        case .maintenance: return String(localized: "Maintenance", comment: "Barn note category")
        case .health:      return String(localized: "Health",      comment: "Barn note category")
        case .weather:     return String(localized: "Weather",     comment: "Barn note category")
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
