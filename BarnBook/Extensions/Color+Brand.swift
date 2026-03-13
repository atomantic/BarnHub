import SwiftUI

extension Color {
    static let barnGreen = Color(red: 74/255, green: 124/255, blue: 63/255)
    static let barnBrown = Color(red: 92/255, green: 61/255, blue: 30/255)
    static let barnTan = Color(red: 196/255, green: 162/255, blue: 101/255)
    static let barnOffWhite = Color(red: 245/255, green: 242/255, blue: 237/255)
}

extension ShapeStyle where Self == Color {
    static var barnGreen: Color { .barnGreen }
    static var barnBrown: Color { .barnBrown }
    static var barnTan: Color { .barnTan }
    static var barnOffWhite: Color { .barnOffWhite }
}
