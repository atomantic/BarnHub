import Foundation

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case lesson, boarding, training, vetBill, farrier, feed, supplies, tack, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .vetBill: return "Vet Bill"
        default: return rawValue.capitalized
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum LessonType: String, Codable, CaseIterable, Identifiable {
    case privateLesson = "private"
    case group, training, evaluation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .privateLesson: return "Private"
        default: return rawValue.capitalized
        }
    }
}

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, monthly, quarterly, biannually, annually
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum BarnNoteCategory: String, Codable, CaseIterable, Identifiable {
    case general, observation, incident, maintenance, health, weather
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
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
