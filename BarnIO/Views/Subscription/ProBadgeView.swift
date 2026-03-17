import SwiftUI

struct ProBadgeView: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(Color.barnGreen)
            )
    }
}
