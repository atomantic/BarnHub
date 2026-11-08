import SwiftUI
import SwiftData

struct HorseRowView: View {
    let horse: Horse

    var body: some View {
        HStack(spacing: 12) {
            CachedPhotoView(data: horse.thumbnailData) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } placeholder: {
                // Placeholder avatar, the same size as a photo.
                Image(systemName: "figure.equestrian.sports")
                    .font(.subheadline)
                    .foregroundStyle(horse.isActive ? Color.barnGreen : Color.gray)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill((horse.isActive ? Color.barnGreen : Color.gray).opacity(0.15)))
            }
            .accessibilityHidden(true)
            .backfillsThumbnail(for: horse)

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

            if !horse.isActive {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.gray)
                    .font(.caption)
                    .accessibilityLabel("Inactive")
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(horse.isActive ? "Active" : "Inactive")
    }
}
