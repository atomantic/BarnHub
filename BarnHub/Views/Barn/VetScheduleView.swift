import SwiftUI
import SwiftData

struct VetScheduleView: View {
    @Environment(Router.self) private var router

    @Query(sort: \VetRecord.date, order: .reverse) private var allVetRecords: [VetRecord]

    private var scheduledRecords: [VetRecord] {
        allVetRecords
            .filter { $0.nextDueDate != nil }
            .sorted { ($0.nextDueDate ?? .distantFuture) < ($1.nextDueDate ?? .distantFuture) }
    }

    var body: some View {
        List {
            if scheduledRecords.isEmpty {
                EmptyStateView(
                    icon: "cross.case",
                    title: "No Scheduled Vet Visits",
                    subtitle: "Vet appointments with a next due date will appear here."
                )
            } else {
                ForEach(scheduledRecords) { record in
                    Button {
                        guard let horseID = record.horse?.persistentModelID else { return }
                        router.navigate(to: HorseRoute.detail(horseID))
                    } label: {
                        vetRecordRow(record)
                    }
                    .tint(.primary)
                }
            }
        }
        .navigationTitle("Vet Schedule")
    }

    private func vetRecordRow(_ record: VetRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.horse?.name ?? "Unknown Horse")
                    .font(.headline)
                Text(record.vetName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !record.descriptionText.isEmpty {
                    Text(record.descriptionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let nextDue = record.nextDueDate {
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
