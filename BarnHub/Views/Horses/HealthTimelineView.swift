import SwiftUI
import SwiftData

enum TimelineEventType: String, CaseIterable {
    case vet, farrier, dentist, weight

    var label: String {
        switch self {
        case .vet: return appLocalized("Vet", comment: "Schedule event type")
        case .farrier: return appLocalized("Farrier", comment: "Schedule event type")
        case .dentist: return appLocalized("Dentist", comment: "Schedule event type")
        case .weight: return appLocalized("Weight", comment: "Health timeline filter: weight entries")
        }
    }

    var icon: String {
        switch self {
        case .vet: return "cross.case.fill"
        case .farrier: return "hammer.fill"
        case .dentist: return "mouth.fill"
        case .weight: return "scalemass.fill"
        }
    }

    var color: Color {
        switch self {
        case .vet: return .blue
        case .farrier: return .orange
        case .dentist: return .purple
        case .weight: return .green
        }
    }
}

struct TimelineEvent: Identifiable {
    let id: String
    let date: Date
    let type: TimelineEventType
    let title: String
    let subtitle: String
    let detail: String?
    let cost: Double?
}

struct HealthTimelineView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router

    @State private var activeFilters: Set<TimelineEventType> = Set(TimelineEventType.allCases)
    @State private var showAddWeight = false
    @State private var newWeight: String = ""
    @State private var toast = ToastState()

    private var horse: Horse? {
        modelContext.existingModel(for: horseID)
    }

    private func computeEvents() -> [TimelineEvent] {
        guard let horse else { return [] }
        var result: [TimelineEvent] = []

        if activeFilters.contains(.vet) {
            for record in horse.vetRecords ?? [] {
                result.append(TimelineEvent(
                    id: "vet-\(record.persistentModelID)",
                    date: record.date,
                    type: .vet,
                    title: record.descriptionText.isEmpty ? appLocalized("Vet Visit", comment: "Health timeline title for a vet record without a description") : record.descriptionText,
                    subtitle: record.vetName,
                    detail: record.nextDueDate.map { appLocalized("Next due: \($0.shortFormatted)", comment: "When the next visit is due") },
                    cost: record.cost > 0 ? record.cost : nil
                ))
            }
        }

        if activeFilters.contains(.farrier) {
            for visit in horse.farrierVisits ?? [] {
                result.append(TimelineEvent(
                    id: "farrier-\(visit.persistentModelID)",
                    date: visit.date,
                    type: .farrier,
                    title: visit.serviceDescription.isEmpty ? appLocalized("Farrier Visit", comment: "Health timeline title for a farrier visit without a description") : visit.serviceDescription,
                    subtitle: visit.farrierName,
                    detail: visit.nextDueDate.map { appLocalized("Next due: \($0.shortFormatted)", comment: "When the next visit is due") },
                    cost: visit.cost > 0 ? visit.cost : nil
                ))
            }
        }

        if activeFilters.contains(.dentist) {
            for visit in horse.dentistVisits ?? [] {
                result.append(TimelineEvent(
                    id: "dentist-\(visit.persistentModelID)",
                    date: visit.date,
                    type: .dentist,
                    title: visit.serviceDescription.isEmpty ? appLocalized("Dentist Visit", comment: "Health timeline title for a dentist visit without a description") : visit.serviceDescription,
                    subtitle: visit.dentistName,
                    detail: visit.nextDueDate.map { appLocalized("Next due: \($0.shortFormatted)", comment: "When the next visit is due") },
                    cost: visit.cost > 0 ? visit.cost : nil
                ))
            }
        }

        if activeFilters.contains(.weight) {
            for entry in horse.weightEntries ?? [] {
                result.append(TimelineEvent(
                    id: "weight-\(entry.persistentModelID)",
                    date: entry.date,
                    type: .weight,
                    title: appLocalized("\(Int(entry.weight)) lbs", comment: "Health timeline title for a weight entry: the weight in pounds"),
                    subtitle: appLocalized("Weight recorded", comment: "Health timeline subtitle for a weight entry"),
                    detail: nil,
                    cost: nil
                ))
            }
        }

        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        // Built once per render (it was built twice).
        let events = computeEvents()
        return List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if events.isEmpty {
                EmptyStateView(
                    icon: "heart.text.clipboard",
                    title: "No Health Events",
                    subtitle: "Add vet, farrier, or dentist visits, or weight logs to build a timeline."
                )
            } else {
                ForEach(events) { event in
                    timelineRow(event)
                }
            }
        }
        .navigationTitle("Health Timeline")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                NavigationLink(value: HorseRoute.weightChart(horseID)) {
                    Label("Weight Trend", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        router.navigate(to: HorseRoute.addVetRecord(horseID))
                    } label: {
                        Label("Add Vet Record", systemImage: TimelineEventType.vet.icon)
                    }
                    Button {
                        router.navigate(to: HorseRoute.addFarrierVisit(horseID))
                    } label: {
                        Label("Add Farrier Visit", systemImage: TimelineEventType.farrier.icon)
                    }
                    Button {
                        router.navigate(to: HorseRoute.addDentistVisit(horseID))
                    } label: {
                        Label("Add Dentist Visit", systemImage: TimelineEventType.dentist.icon)
                    }
                    Button {
                        showAddWeight = true
                    } label: {
                        Label("Log Weight", systemImage: TimelineEventType.weight.icon)
                    }
                } label: {
                    Label("Add Event", systemImage: "plus")
                }
            }
        }
        .alert("Log Weight", isPresented: $showAddWeight) {
            TextField("Weight (lbs)", text: $newWeight)
                .decimalKeyboard()
            Button("Save") { saveWeight() }
            Button("Cancel", role: .cancel) { newWeight = "" }
        } message: {
            Text("Enter the current weight in pounds.")
        }
        .toast(toast)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(TimelineEventType.allCases, id: \.self) { type in
                Button {
                    if activeFilters.contains(type) {
                        activeFilters.remove(type)
                    } else {
                        activeFilters.insert(type)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.caption2)
                        Text(type.label)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(activeFilters.contains(type) ? type.color.opacity(0.2) : Color.gray.opacity(0.1))
                    )
                    .foregroundStyle(activeFilters.contains(type) ? type.color : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func timelineRow(_ event: TimelineEvent) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.type.color)
                .frame(width: 10, height: 10)
                .frame(width: 24)

            Image(systemName: event.type.icon)
                .font(.caption)
                .foregroundStyle(event.type.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline.weight(.medium))
                Text(event.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.date.shortFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let cost = event.cost {
                    Text(cost.asCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func saveWeight() {
        guard let horse, let weightValue = Double(newWeight), weightValue > 0 else {
            newWeight = ""
            return
        }
        let entry = WeightEntry(date: .now, weight: weightValue)
        entry.horse = horse
        modelContext.insert(entry)
        horse.weight = weightValue
        BarnHubLogger.success("Weight logged weight=\(weightValue)")
        toast.show(appLocalized("Weight logged: \(Int(weightValue)) lbs", comment: "Weight logging confirmation"))
        newWeight = ""
    }
}
