import Foundation
import os

extension Bundle {
    /// The bundle last resolved by `app`, and the locale id it was resolved for.
    /// Behind a lock because `appLocalized` runs on any thread, for example while
    /// an invoice or contract PDF is built off the main actor (#41).
    private static let appBundleCache = OSAllocatedUnfairLock<AppBundleCacheEntry?>(initialState: nil)

    private struct AppBundleCacheEntry: @unchecked Sendable {
        let localeID: String
        let bundle: Bundle
    }

    /// The .lproj bundle for the user's chosen language.
    /// Cached until the locale preference changes. Safe to call from any thread.
    static var app: Bundle {
        let id = UserDefaults.standard.string(forKey: "net.shadowpuppet.BarnBook.appLocale") ?? ""
        return appBundleCache.withLock { cache in
            if let cache, cache.localeID == id { return cache.bundle }
            let bundle = resolveAppBundle(localeID: id)
            cache = AppBundleCacheEntry(localeID: id, bundle: bundle)
            return bundle
        }
    }

    private static func resolveAppBundle(localeID id: String) -> Bundle {
        guard !id.isEmpty,
              let path = Bundle.main.path(forResource: id, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    /// Call when the user changes their language preference to invalidate the cache.
    static func resetAppBundleCache() {
        appBundleCache.withLock { $0 = nil }
    }
}

/// Resolves a localized string using the user's chosen app language bundle.
/// Use instead of `String(localized:comment:)` so in-app language switching works
/// without requiring a restart.
func appLocalized(_ key: String.LocalizationValue, comment: StaticString = "") -> String {
    String(localized: key, bundle: .app, comment: comment)
}

extension Locale {
    /// The user's in-app language choice (Settings → Language), or the system
    /// locale when none is set. Matches the `\.locale` the root view injects, for
    /// formatting outside SwiftUI views.
    static var app: Locale {
        let id = UserDefaults.standard.string(forKey: "net.shadowpuppet.BarnBook.appLocale") ?? ""
        return id.isEmpty ? .current : Locale(identifier: id)
    }

    /// The locale's first day of the week as a `Calendar.firstWeekday` value
    /// (1 = Sunday … 7 = Saturday).
    var firstWeekdayNumber: Int {
        switch firstDayOfWeek {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        @unknown default: 1
        }
    }
}

extension Calendar {
    /// `Calendar.current` with weeks starting on `locale`'s first weekday, for
    /// month and week grids.
    static func weeks(startingAsIn locale: Locale) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = locale.firstWeekdayNumber
        return calendar
    }

    /// Start of the week containing `date`, honouring `firstWeekday`.
    func startOfWeek(containing date: Date) -> Date {
        let day = startOfDay(for: date)
        let offset = (component(.weekday, from: day) - firstWeekday + 7) % 7
        return self.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    /// Weekday symbols (e.g. `shortWeekdaySymbols`, which always start on Sunday)
    /// rotated to start on `firstWeekday`.
    func weekdaySymbolsStartingOnFirstWeekday(_ symbols: [String]) -> [String] {
        guard symbols.count == 7 else { return symbols }
        let shift = (firstWeekday - 1) % 7
        return Array(symbols[shift...] + symbols[..<shift])
    }

    /// Empty cells before day 1 in a month grid whose rows start on `firstWeekday`.
    func leadingBlankDays(forMonthStartingOn monthStart: Date) -> Int {
        (component(.weekday, from: monthStart) - firstWeekday + 7) % 7
    }
}
