import Foundation

extension Date {
    var shortFormatted: String {
        formatted(Date.FormatStyle.dateTime.month(.twoDigits).day(.twoDigits).year())
    }

    private static let compactFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var compactFormatted: String {
        Self.compactFormatter.string(from: self)
    }

    var isOverdue: Bool {
        self < .now
    }

    var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
