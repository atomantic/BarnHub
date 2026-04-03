import SwiftUI

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .system: return appLocalized("System", comment: "Appearance mode")
        case .light:  return appLocalized("Light",  comment: "Appearance mode")
        case .dark:   return appLocalized("Dark",   comment: "Appearance mode")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
final class AppearanceManager {
    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: AppearanceManager.defaultsKey) }
    }

    var colorScheme: ColorScheme? { mode.colorScheme }

    private static let defaultsKey = "net.shadowpuppet.BarnBook.appearanceMode"

    init() {
        let stored = UserDefaults.standard.integer(forKey: AppearanceManager.defaultsKey)
        mode = AppearanceMode(rawValue: stored) ?? .system
    }
}
