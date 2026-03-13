import SwiftUI
import SwiftData

struct HorseRowView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(horse.isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)

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
