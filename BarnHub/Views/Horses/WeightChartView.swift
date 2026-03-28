import Charts
import SwiftUI
import SwiftData

struct WeightChartView: View {
    let horseID: PersistentIdentifier
    @Environment(\.modelContext) private var modelContext

    @State private var selectedEntry: WeightEntry?

    private var horse: Horse? {
        modelContext.model(for: horseID) as? Horse
    }

    private var entries: [WeightEntry] {
        (horse?.weightEntries ?? []).sorted { $0.date < $1.date }
    }

    var body: some View {
        let sortedEntries = entries
        let minWeight = sortedEntries.map(\.weight).min() ?? 0
        let maxWeight = sortedEntries.map(\.weight).max() ?? 0
        return Group {
            if sortedEntries.isEmpty {
                EmptyStateView(
                    icon: "scalemass",
                    title: "No Weight Records",
                    subtitle: "Log weights from the Health Timeline to see trends."
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCards(sortedEntries: sortedEntries, minWeight: minWeight, maxWeight: maxWeight)
                        chartSection(sortedEntries: sortedEntries, minWeight: minWeight, maxWeight: maxWeight)
                        historySection(sortedEntries: sortedEntries)
                    }
                    .padding()
                }
                .background(Color.barnOffWhite)
            }
        }
        .navigationTitle("Weight Trend")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary Cards

    private func summaryCards(sortedEntries: [WeightEntry], minWeight: Double, maxWeight: Double) -> some View {
        let weightChange: Double? = {
            guard sortedEntries.count >= 2,
                  let first = sortedEntries.first,
                  let last = sortedEntries.last else { return nil }
            return last.weight - first.weight
        }()
        return HStack(spacing: 12) {
            weightCard(
                title: "Current",
                value: "\(Int(sortedEntries.last?.weight ?? 0))",
                unit: "lbs",
                color: .barnGreen
            )
            weightCard(
                title: "Range",
                value: "\(Int(minWeight))–\(Int(maxWeight))",
                unit: "lbs",
                color: .barnBrown
            )
            if let change = weightChange {
                weightCard(
                    title: "Change",
                    value: "\(change >= 0 ? "+" : "")\(Int(change))",
                    unit: "lbs",
                    color: change >= 0 ? .barnGreen : .red
                )
            }
        }
    }

    private func weightCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    // MARK: - Chart

    private func chartSection(sortedEntries: [WeightEntry], minWeight: Double, maxWeight: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Over Time")
                .font(.headline)

            let yMin = max(0, minWeight - 50)
            let yMax = maxWeight + 50

            Chart(sortedEntries, id: \.persistentModelID) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color.barnGreen)
                .symbol(Circle())
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weight)
                )
                .foregroundStyle(Color.barnGreen.opacity(0.1))
                .interpolationMethod(.catmullRom)

                if let selected = selectedEntry,
                   selected.persistentModelID == entry.persistentModelID {
                    PointMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Weight", entry.weight)
                    )
                    .foregroundStyle(Color.barnGreen)
                    .symbolSize(100)
                    .annotation(position: .top, spacing: 8) {
                        VStack(spacing: 2) {
                            Text("\(Int(entry.weight)) lbs")
                                .font(.caption.weight(.bold))
                            Text(entry.date.shortFormatted)
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.barnCardBackground)
                                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        )
                    }
                }
            }
            .chartYScale(domain: yMin...yMax)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let weight = value.as(Double.self) {
                            Text("\(Int(weight))")
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    AxisGridLine()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectEntry(at: value.location, proxy: proxy, geometry: geometry, entries: sortedEntries)
                                }
                                .onEnded { _ in
                                    selectedEntry = nil
                                }
                        )
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func selectEntry(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, entries: [WeightEntry]) {
        guard let frame = proxy.plotFrame else { return }
        let plotFrame = geometry[frame]
        let xPosition = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xPosition) else { return }

        selectedEntry = entries.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: - History

    private func historySection(sortedEntries: [WeightEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            ForEach(sortedEntries.reversed(), id: \.persistentModelID) { entry in
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.caption)
                        .foregroundStyle(.barnGreen)
                        .frame(width: 24)
                    Text("\(Int(entry.weight)) lbs")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(entry.date.shortFormatted)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let change = changeFrom(entry, in: sortedEntries) {
                        Text("\(change >= 0 ? "+" : "")\(Int(change))")
                            .font(.caption)
                            .foregroundStyle(change >= 0 ? .barnGreen : .red)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.barnCardBackground)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }

    private func changeFrom(_ entry: WeightEntry, in entries: [WeightEntry]) -> Double? {
        guard let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
              index > 0 else { return nil }
        return entry.weight - entries[index - 1].weight
    }
}
