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

                HStack(spacing: 12) {
                    if !client.phone.isEmpty {
                        Label(client.phone, systemImage: "phone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
