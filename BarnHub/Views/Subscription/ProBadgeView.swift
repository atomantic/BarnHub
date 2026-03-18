import SwiftUI

struct ProBadgeView: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.heavy))
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.barnGreen)
            )
    }
}
