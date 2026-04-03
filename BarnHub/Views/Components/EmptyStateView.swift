import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            if let subtitle {
                Text(subtitle)
            }
        }
    }
}

#Preview {
    EmptyStateView(
        icon: "horse",
        title: "No Horses",
        subtitle: "Add your first horse to get started."
    )
}
