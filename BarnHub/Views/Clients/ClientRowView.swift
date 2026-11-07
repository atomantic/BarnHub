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

                // Side by side when there's room; stacked on narrow widths such as
                // the iPhone Duo outer display, so the phone number never wraps.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { contactLabels }
                    VStack(alignment: .leading, spacing: 2) { contactLabels }
                }
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
                .fixedSize(horizontal: true, vertical: false)
        }
        if !client.email.isEmpty {
            Label(client.email, systemImage: "envelope")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
