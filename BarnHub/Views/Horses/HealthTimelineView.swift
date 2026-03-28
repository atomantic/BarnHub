import SwiftUI
import SwiftData

enum TimelineEventType: String, CaseIterable {
    case vet, farrier, weight

    var label: String {
        switch self {
        case .vet: return "Vet"
        case .farrier: return "Farrier"
        case .weight: return "Weight"
        }
    }

    var icon: String {
        switch self {
        case .vet: return "cross.case.fill"
        case .farrier: return "hammer.fill"
        case .weight: return "scalemass.fill"
        }
    }

    var color: Color {
        switch self {
        case .vet: return .blue
        case .farrier: return .orange
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
    @State private var events: [TimelineEvent] = []

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
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
                    title: record.descriptionText.isEmpty ? "Vet Visit" : record.descriptionText,
                    subtitle: record.vetName,
                    detail: record.nextDueDate.map { "Next due: \($0.shortFormatted)" },
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
                    title: visit.serviceDescription.isEmpty ? "Farrier Visit" : visit.serviceDescription,
                    subtitle: visit.farrierName,
                    detail: visit.nextDueDate.map { "Next due: \($0.shortFormatted)" },
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
                    title: "\(Int(entry.weight)) lbs",
                    subtitle: "Weight recorded",
                    detail: nil,
                    cost: nil
                ))
            }
        }

        return result.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                filterBar
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if events.isEmpty {
                EmptyStateView(
                    icon: "heart.text.clipboard",
                    title: "No Health Events",
                    subtitle: "Add vet visits, farrier visits, or weight logs to build a timeline."
                )
            } else {
                ForEach(events) { event in
                    timelineRow(event)
                }
            }
        }
        .navigationTitle("Health Timeline")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HorseRoute.weightChart(horseID)) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
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
                        showAddWeight = true
                    } label: {
                        Label("Log Weight", systemImage: TimelineEventType.weight.icon)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Log Weight", isPresented: $showAddWeight) {
            TextField("Weight (lbs)", text: $newWeight)
                .keyboardType(.decimalPad)
            Button("Save") { saveWeight() }
            Button("Cancel", role: .cancel) { newWeight = "" }
        } message: {
            Text("Enter the current weight in pounds.")
        }
        .toast(toast)
        .onAppear { events = computeEvents() }
        .onChange(of: activeFilters) { events = computeEvents() }
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
        BarnHubLogger.success("Weight logged for horse=\(horse.name) weight=\(weightValue)")
        toast.show("Weight logged: \(Int(weightValue)) lbs")
        newWeight = ""
        events = computeEvents()
    }
}
