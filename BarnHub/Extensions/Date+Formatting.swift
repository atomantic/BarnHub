import Foundation

extension Date {
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    var shortFormatted: String {
        Self.shortDateFormatter.string(from: self)
    }

    var compactFormatted: String {
        Self.compactDateFormatter.string(from: self)
    }

    var isOverdue: Bool {
        self < .now
    }

    var relativeDateString: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
