import SwiftUI

struct SummaryCard: View {
    let title: LocalizedStringKey
    let amount: Double
    let color: Color
    var icon: String? = nil

    var body: some View {
        if let icon {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .barnCard()
        } else {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount.asCurrency)
                    .font(.headline)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.1))
            )
        }
    }
}
