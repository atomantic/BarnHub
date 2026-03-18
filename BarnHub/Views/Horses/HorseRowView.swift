import SwiftUI
import SwiftData

struct HorseRowView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 12) {
            if let photoData = horse.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Image(systemName: horse.isActive ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(horse.isActive ? Color.green : Color.gray)
                    .font(.subheadline)
                    .frame(width: 40, height: 40)
            }

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

            if horse.photoData != nil && !horse.isActive {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}
