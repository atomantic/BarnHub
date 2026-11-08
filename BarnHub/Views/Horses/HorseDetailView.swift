import SwiftUI
import SwiftData

struct HorseDetailView: View {
    let horseID: PersistentIdentifier
    /// True when shown as the detail pane beside the horse list.
    var isEmbedded = false
    /// Called after the horse is deleted, so an embedded pane can clear its selection.
    var onDelete: (() -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreService.self) private var storeService
    @Environment(NotificationService.self) private var notificationService

    @State private var showDeleteConfirmation = false
    @State private var toast = ToastState()
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var horse: Horse? {
        modelContext.existingModel(for: horseID)
    }

    private var sortedVetRecords: [VetRecord] {
        (horse?.vetRecords ?? []).sorted { $0.date > $1.date }
    }

    private var sortedFarrierVisits: [FarrierVisit] {
        (horse?.farrierVisits ?? []).sorted { $0.date > $1.date }
    }

    private var sortedDentistVisits: [DentistVisit] {
        (horse?.dentistVisits ?? []).sorted { $0.date > $1.date }
    }

    private var sortedHorseClients: [Client] {
        (horse?.clients ?? []).sorted { $0.fullName < $1.fullName }
    }

    var body: some View {
        Group {
            if let horse {
                horseContent(horse)
            } else {
                EmptyStateView(
                    icon: "exclamationmark.triangle",
                    title: "Horse Not Found",
                    subtitle: "This horse may have been deleted."
                )
            }
        }
        .overlay {
            HorseRemovalDialog(
                isPresented: $showDeleteConfirmation,
                onMarkInactive: markHorseInactive,
                onDelete: deleteHorse
            )
        }
        .toast(toast)
    }

    // MARK: - Shared section builders

    @ViewBuilder
    private func photoSection(_ horse: Horse) -> some View {
        if let photoData = horse.photoData, let image = Image(photoData: photoData) {
            Section {
                HStack {
                    Spacer()
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(Circle())
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var sortedFeedEntries: [FeedPlanEntry] {
        (horse?.feedPlanEntries ?? []).sorted { $0.feedTime < $1.feedTime }
    }

    private func quickLinksSection() -> some View {
        Section {
            NavigationLink(value: HorseRoute.healthTimeline(horseID)) {
                Label("Health Timeline", systemImage: "heart.text.clipboard")
                    .foregroundStyle(.barnGreen)
            }
            NavigationLink(value: HorseRoute.weightChart(horseID)) {
                Label("Weight Trend", systemImage: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.barnGreen)
            }
            NavigationLink(value: HorseRoute.feedPlan(horseID)) {
                HStack {
                    Label("Feed Plan", systemImage: "fork.knife")
                        .foregroundStyle(.barnGreen)
                    Spacer()
                    let count = horse?.feedPlanEntries?.count ?? 0
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func infoSection(_ horse: Horse) -> some View {
        Section("Info") {
            LabeledContent("Breed", value: horse.breed.isEmpty ? "--" : horse.breed)
            LabeledContent("Gender", value: horse.gender.displayName)
            LabeledContent("Date of Birth", value: horse.dateOfBirth.shortFormatted)
            LabeledContent("Color/Markings", value: horse.colorMarkings.isEmpty ? "--" : horse.colorMarkings)
            LabeledContent("Weight", value: horse.weight > 0 ? "\(Int(horse.weight)) lbs" : "--")
            if horse.purchasePrice > 0 {
                LabeledContent("Purchase Price", value: horse.purchasePrice.asCurrency)
            }
            LabeledContent("Stall", value: horse.stallNumber.isEmpty ? "--" : horse.stallNumber)
            LabeledContent("Status", value: horse.isActive ? "Active" : "Inactive")
        }
    }

    @ViewBuilder
    private func notesSection(_ horse: Horse) -> some View {
        if !horse.medicalNotes.isEmpty {
            Section("Medical Notes") {
                Text(horse.medicalNotes)
            }
        }
        if !sortedFeedEntries.isEmpty {
            Section("Feeding Schedule") {
                ForEach(sortedFeedEntries, id: \.persistentModelID) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: entry.feedTime.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(entry.summary)
                            .font(.subheadline)
                        Spacer()
                        if !entry.assignedPerson.isEmpty {
                            Text(entry.assignedPerson)
                                .font(.caption)
                                .foregroundStyle(.barnGreen)
                        }
                    }
                }
            }
        } else if !horse.feedingSchedule.isEmpty {
            Section("Feeding Schedule") {
                Text(horse.feedingSchedule)
            }
        }
    }

    private func vetSection() -> some View {
        Section {
            if sortedVetRecords.isEmpty {
                Text("No vet records")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedVetRecords, id: \.persistentModelID) { record in
                    Button {
                        router.navigate(to: HorseRoute.editVetRecord(record.persistentModelID))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.date.shortFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(record.cost.asCurrency)
                                    .font(.subheadline)
                            }
                            Text(record.vetName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !record.descriptionText.isEmpty {
                                Text(record.descriptionText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let nextDue = record.nextDueDate {
                                Text("Next due: \(nextDue.shortFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Vet Records")
                Spacer()
                Button {
                    router.navigate(to: HorseRoute.addVetRecord(horseID))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Add Vet Record")
            }
        }
    }

    private func farrierSection() -> some View {
        Section {
            if sortedFarrierVisits.isEmpty {
                Text("No farrier visits")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedFarrierVisits, id: \.persistentModelID) { visit in
                    Button {
                        router.navigate(to: HorseRoute.editFarrierVisit(visit.persistentModelID))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(visit.date.shortFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(visit.cost.asCurrency)
                                    .font(.subheadline)
                            }
                            Text(visit.farrierName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !visit.serviceDescription.isEmpty {
                                Text(visit.serviceDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let nextDue = visit.nextDueDate {
                                Text("Next due: \(nextDue.shortFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Farrier Visits")
                Spacer()
                Button {
                    router.navigate(to: HorseRoute.addFarrierVisit(horseID))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Add Farrier Visit")
            }
        }
    }

    private func dentistSection() -> some View {
        Section {
            if sortedDentistVisits.isEmpty {
                Text("No dentist visits")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedDentistVisits, id: \.persistentModelID) { visit in
                    Button {
                        router.navigate(to: HorseRoute.editDentistVisit(visit.persistentModelID))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(visit.date.shortFormatted)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(visit.cost.asCurrency)
                                    .font(.subheadline)
                            }
                            Text(visit.dentistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !visit.serviceDescription.isEmpty {
                                Text(visit.serviceDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let nextDue = visit.nextDueDate {
                                Text("Next due: \(nextDue.shortFormatted)")
                                    .font(.caption2)
                                    .foregroundStyle(nextDue.isOverdue ? .red : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack {
                Text("Dentist Visits")
                Spacer()
                Button {
                    router.navigate(to: HorseRoute.addDentistVisit(horseID))
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Add Dentist Visit")
            }
        }
    }

    @ViewBuilder
    private func documentsSection() -> some View {
        if FeatureGate.canStoreDocuments(storeService.isPro) {
            Section("Documents") {
                NavigationLink(value: HorseRoute.documents(horseID)) {
                    HStack {
                        Label("Documents", systemImage: "folder.fill")
                        Spacer()
                        let count = horse?.documents?.count ?? 0
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func clientsSection() -> some View {
        Section("Clients") {
            if sortedHorseClients.isEmpty {
                Text("No assigned clients")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sortedHorseClients, id: \.persistentModelID) { client in
                    NavigationLink(value: ClientRoute.detail(client.persistentModelID)) {
                        Text(client.fullName)
                    }
                }
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private func horseContent(_ horse: Horse) -> some View {
        #if os(macOS)
        if isEmbedded {
            macOSPaneLayout(horse)
        } else {
            macOSLayout(horse)
        }
        #else
        iOSLayout(horse)
        #endif
    }

    #if os(iOS)
    private func iOSLayout(_ horse: Horse) -> some View {
        Group {
            // The embedded pane beside the list is too narrow for two columns.
            if sizeClass == .regular && !isEmbedded {
                // Same split as macOS: profile on the left, records on the right.
                WideColumns {
                    photoSection(horse)
                    quickLinksSection()
                    infoSection(horse)
                } trailing: {
                    // Notes and feeding go right so the two columns are similar lengths.
                    notesSection(horse)
                    vetSection()
                    farrierSection()
                    dentistSection()
                    documentsSection()
                    clientsSection()
                }
            } else {
                List {
                    if isEmbedded { paneHeader(horse) }
                    photoSection(horse)
                    quickLinksSection()
                    infoSection(horse)
                    notesSection(horse)
                    vetSection()
                    farrierSection()
                    dentistSection()
                    documentsSection()
                    clientsSection()
                }
            }
        }
        .detailNavigationTitle(horse.name, isEmbedded: isEmbedded)
        .toolbar { if !isEmbedded { horseToolbar } }
    }
    #endif

    #if os(macOS)
    /// One column for the detail pane beside the horse list, which is too narrow
    /// for the two-column window layout.
    private func macOSPaneLayout(_ horse: Horse) -> some View {
        Form {
            paneHeader(horse)
            photoSection(horse)
            quickLinksSection()
            infoSection(horse)
            notesSection(horse)
            vetSection()
            farrierSection()
            dentistSection()
            documentsSection()
            clientsSection()
        }
        .formStyle(.grouped)
    }

    private func macOSLayout(_ horse: Horse) -> some View {
        ScrollView {
            HStack(alignment: .top, spacing: 24) {
                // Left column: photo + info + notes
                VStack(spacing: 0) {
                    Form {
                        if let photoData = horse.photoData, let image = Image(photoData: photoData) {
                            Section {
                                HStack {
                                    Spacer()
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Spacer()
                                }
                            }
                        }
                        quickLinksSection()
                        infoSection(horse)
                        notesSection(horse)
                    }
                    .formStyle(.grouped)
                }
                .frame(maxWidth: .infinity)

                // Right column: records + clients
                VStack(spacing: 0) {
                    Form {
                        vetSection()
                        farrierSection()
                        dentistSection()
                        documentsSection()
                        clientsSection()
                    }
                    .formStyle(.grouped)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .detailNavigationTitle(horse.name, isEmbedded: isEmbedded)
        .toolbar { horseToolbar }
    }
    #endif

    private func paneHeader(_ horse: Horse) -> some View {
        DetailPaneHeader(
            title: horse.name,
            subtitle: [horse.breed, horse.gender.displayName].filter { !$0.isEmpty }.joined(separator: " · "),
            onEdit: { router.navigate(to: HorseRoute.edit(horseID)) },
            onDelete: { showDeleteConfirmation = true }
        )
    }

    @ToolbarContentBuilder
    private var horseToolbar: some ToolbarContent {
        // Standalone items (instead of a custom "…" menu) so iPhone Duo can lay
        // them out vertically and fold them into the system overflow menu.
        ToolbarItemGroup(placement: .trailingBar) {
            Button {
                router.navigate(to: HorseRoute.edit(horseID))
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .help(Text("Edit"))
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .help(Text("Delete"))
        }
    }

    private func markHorseInactive() {
        guard let horse else { return }
        BarnHubLogger.info("Marking horse inactive name=\(horse.name)")
        RecordRemoval.markInactive(horse, in: modelContext)
        toast.show(appLocalized("Horse marked inactive", comment: "Toast after marking a horse inactive"))
    }

    private func deleteHorse() {
        guard let horse else { return }
        BarnHubLogger.info("Deleting horse name=\(horse.name)")
        notificationService.cancelNotifications(for: horse)
        RecordRemoval.delete(horse, in: modelContext)
        if let onDelete {
            onDelete()
        } else {
            dismiss()
        }
    }
}
