import SwiftUI

extension Color {
    static let barnGreen = Color(light: Color(red: 74/255, green: 124/255, blue: 63/255),
                                  dark: Color(red: 100/255, green: 164/255, blue: 84/255))
    static let barnBrown = Color(light: Color(red: 92/255, green: 61/255, blue: 30/255),
                                  dark: Color(red: 210/255, green: 180/255, blue: 140/255))
    static let barnTan = Color(light: Color(red: 196/255, green: 162/255, blue: 101/255),
                                dark: Color(red: 178/255, green: 148/255, blue: 92/255))
    static let barnOffWhite = Color(light: Color(red: 245/255, green: 242/255, blue: 237/255),
                                     dark: Color(red: 28/255, green: 28/255, blue: 30/255))
    static let barnCardBackground = Color(light: .white,
                                           dark: Color(red: 44/255, green: 44/255, blue: 46/255))

    init(light: Color, dark: Color) {
#if os(iOS) || targetEnvironment(macCatalyst)
        let lightUI = UIColor(light)
        let darkUI = UIColor(dark)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkUI : lightUI
        })
#else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
#endif
    }

    static var systemBackground: Color {
#if os(iOS) || targetEnvironment(macCatalyst)
        Color(UIColor.systemBackground)
#else
        Color(NSColor.windowBackgroundColor)
#endif
    }

    static var secondarySystemBackground: Color {
#if os(iOS) || targetEnvironment(macCatalyst)
        Color(UIColor.secondarySystemBackground)
#else
        Color(NSColor.controlBackgroundColor)
#endif
    }
}

extension ShapeStyle where Self == Color {
    static var barnGreen: Color { .barnGreen }
    static var barnBrown: Color { .barnBrown }
    static var barnTan: Color { .barnTan }
    static var barnOffWhite: Color { .barnOffWhite }
    static var barnCardBackground: Color { .barnCardBackground }
}
