import SwiftUI
import SwiftData

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(client.isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

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
