import SwiftUI
import SwiftData

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: client.isActive ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(client.isActive ? Color.barnGreen : Color.gray)
                .font(.subheadline)
                .accessibilityLabel(client.isActive ? "Active" : "Inactive")

            VStack(alignment: .leading, spacing: 2) {
                Text(client.fullName)
                    .font(.headline)

                HStack(spacing: 12) { contactLabels }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var contactLabels: some View {
        if !client.phone.isEmpty {
            Label(client.phone, systemImage: "phone")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // Keep the phone number whole on narrow widths (e.g. the iPhone Duo
                // outer display); the email truncates instead.
                .layoutPriority(1)
        }
        if !client.email.isEmpty {
            Label(client.email, systemImage: "envelope")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
