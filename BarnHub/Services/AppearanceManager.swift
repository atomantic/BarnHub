import SwiftUI

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
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
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode") }
    }

    var colorScheme: ColorScheme? { mode.colorScheme }

    init() {
        let stored = UserDefaults.standard.integer(forKey: "appearanceMode")
        mode = AppearanceMode(rawValue: stored) ?? .system
    }
}
