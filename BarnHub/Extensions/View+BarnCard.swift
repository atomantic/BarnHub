import SwiftUI

struct BarnCardModifier: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.barnCardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            )
    }
}

extension View {
    func barnCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(BarnCardModifier(cornerRadius: cornerRadius))
    }
}
