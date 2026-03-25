import SwiftUI

struct ScheduleRecordRow: View {
    let horseName: String
    let providerName: String
    let description: String
    let nextDueDate: Date?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(horseName)
                    .font(.headline)
                Text(providerName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let nextDue = nextDueDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(nextDue.shortFormatted)
                        .font(.subheadline)
                        .foregroundStyle(nextDue.isOverdue ? .red : .primary)
                    Text(nextDue.relativeDateString)
                        .font(.caption)
                        .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
