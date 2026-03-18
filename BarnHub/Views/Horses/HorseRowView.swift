import SwiftUI
import SwiftData

struct HorseRowView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: horse.isActive ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(horse.isActive ? Color.green : Color.gray)
                .font(.subheadline)
                .accessibilityLabel(horse.isActive ? "Active" : "Inactive")

            VStack(alignment: .leading, spacing: 2) {
                Text(horse.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    if !horse.breed.isEmpty {
                        Text(horse.breed)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !horse.stallNumber.isEmpty {
                        Text("Stall \(horse.stallNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.15))
                            )
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
