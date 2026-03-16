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

enum ReminderFrequency: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, monthly, quarterly, biannually, annually
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}
