import Foundation

extension URL {
    static var privacyPolicy: URL {
        let locale = barnhubLocalePrefix
        if locale.isEmpty {
            return URL(string: "https://barnhub.online/privacy")!
        }
        return URL(string: "https://barnhub.online/\(locale)/privacy.html")!
    }

    static var termsOfUse: URL {
        let locale = barnhubLocalePrefix
        if locale.isEmpty {
            return URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        }
        return URL(string: "https://barnhub.online/\(locale)/terms.html")!
    }

    /// Returns the barnhub.online locale path segment for the current app language,
    /// or "" for English (which uses the default URLs).
    private static var barnhubLocalePrefix: String {
        let supported = ["de", "fr", "nl", "sv", "es-ES", "es-MX", "pt-BR", "it"]
        // preferredLocalizations reflects the language set via AppleLanguages after restart
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let normalized = lang.replacingOccurrences(of: "_", with: "-")
        if supported.contains(normalized) { return normalized }
        // Fall back to language-only (e.g. "de-AT" → "de")
        let base = String(normalized.split(separator: "-").first ?? Substring(normalized))
        return supported.contains(base) ? base : ""
    }
}
