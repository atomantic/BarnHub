import SwiftUI

// MARK: - Dashboard Widget Primitives

struct DashboardEvent: Identifiable {
    let id: ScheduleEventID
    let date: Date
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let action: () -> Void
}

struct DashboardWidget<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let accent: Color
    var seeAll: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.barnBrown)
                Spacer()
                if let seeAll {
                    Button(action: seeAll) {
                        HStack(spacing: 2) {
                            Text("See all")
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.barnGreen)
                    }
                    .buttonStyle(.plain)
                }
            }
            content
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.barnCardBackground)
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        )
    }
}

struct DashboardStatCard: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.barnBrown)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.barnCardBackground)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DashboardEventRow: View {
    let event: DashboardEvent

    var body: some View {
        Button(action: event.action) {
            HStack(spacing: 10) {
                Image(systemName: event.icon)
                    .font(.caption)
                    .foregroundStyle(event.iconColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let subtitle = event.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Text(event.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DashboardActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DashboardEmptyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

struct FinanceMetric: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount.asCurrency)
                .font(.subheadline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IncomeExpenseBar: View {
    let income: Double
    let expenses: Double

    var body: some View {
        let total = max(income + expenses, 0.0001)
        let incomeFraction = income / total
        return GeometryReader { geo in
            HStack(spacing: 2) {
                Rectangle()
                    .fill(Color.barnGreen)
                    .frame(width: max(0, geo.size.width * incomeFraction))
                Rectangle()
                    .fill(Color.red.opacity(0.85))
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .opacity(income + expenses > 0 ? 1 : 0.15)
    }
}
