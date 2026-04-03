import Foundation

extension Bundle {
    private static var cachedLocaleID: String?
    private static var cachedBundle: Bundle?

    /// The .lproj bundle for the user's chosen language.
    /// Cached until the locale preference changes.
    static var app: Bundle {
        let id = UserDefaults.standard.string(forKey: "net.shadowpuppet.BarnBook.appLocale") ?? ""
        if id == cachedLocaleID, let cached = cachedBundle { return cached }
        cachedLocaleID = id
        guard !id.isEmpty,
              let path = Bundle.main.path(forResource: id, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            cachedBundle = .main
            return .main
        }
        cachedBundle = bundle
        return bundle
    }

    /// Call when the user changes their language preference to invalidate the cache.
    static func resetAppBundleCache() {
        cachedLocaleID = nil
        cachedBundle = nil
    }
}

/// Resolves a localized string using the user's chosen app language bundle.
/// Use instead of `String(localized:comment:)` so in-app language switching works
/// without requiring a restart.
func appLocalized(_ key: String.LocalizationValue, comment: StaticString = "") -> String {
    String(localized: key, bundle: .app, comment: comment)
}
