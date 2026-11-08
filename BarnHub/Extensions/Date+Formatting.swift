import Foundation

extension Date {
    /// Numeric day, month and year in the in-app language's order and
    /// separators (`Locale.app`): "01/15/2026" in English, "15.01.2026" in German.
    var shortFormatted: String {
        shortFormatted(locale: .app)
    }

    func shortFormatted(locale: Locale) -> String {
        formatted(Date.FormatStyle.dateTime.month(.twoDigits).day(.twoDigits).year().locale(locale))
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

    /// "2 days ago", "in 3 weeks", in the in-app language (`Locale.app`).
    var relativeDateString: String {
        relativeDateString(relativeTo: .now, locale: .app)
    }

    func relativeDateString(relativeTo now: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = locale
        return formatter.localizedString(for: self, relativeTo: now)
    }
}
