import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var toast = ToastState()
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var exportURL: URL?
    @State private var importType: ImportDataType?
    @State private var showImportConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var importResult: DataImportService.ImportResult?
    @State private var showImportResult = false
    @State private var deleteStep: DeleteStep?
    @State private var csvJob = CSVJob()

    #if os(macOS)
    /// The Settings window's Data tab: a native grouped form with compact
    /// button rows instead of a stack of full-width iOS rows.
    private var dataContent: some View {
        Form {
            Section {
                HStack {
                    Button("Horses") { exportData(.horses) }
                    Button("Clients") { exportData(.clients) }
                    Button("Transactions") { exportData(.transactions) }
                    Spacer()
                    Button("All Data") { exportData(.all) }
                        .buttonStyle(.borderedProminent)
                        .tint(.barnGreen)
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Export your barn data as CSV files for backup or use in spreadsheets.")
            }

            Section {
                HStack {
                    Button("Horses") { startImport(.horses) }
                    Button("Clients") { startImport(.clients) }
                    Button("Transactions") { startImport(.transactions) }
                    Spacer()
                }
            } header: {
                Text("Import")
            } footer: {
                Text("CSV files should include a header row. Column names are matched flexibly (e.g. \"First Name\" or \"Name\" for clients).")
            }

            Section {
                HStack {
                    Button(role: .destructive) {
                        deleteStep = .warning
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                    Spacer()
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Permanently removes all horses, clients, transactions, vet records, farrier visits, supplies, and reminders from this device.")
            }
        }
        .formStyle(.grouped)
    }
    #else
    private var dataContent: some View {
        List {
            Section {
                Text("Export your barn data as CSV files for backup or use in spreadsheets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            Section("Export") {
                Button { exportData(.horses) } label: {
                    exportRow("Horses", icon: "figure.equestrian.sports")
                }
                Button { exportData(.clients) } label: {
                    exportRow("Clients", icon: "person.2")
                }
                Button { exportData(.transactions) } label: {
                    exportRow("Transactions", icon: "dollarsign.circle")
                }
                Button { exportData(.all) } label: {
                    exportRow("All Data", icon: "square.and.arrow.up")
                }
            }

            Section("Import") {
                Button { startImport(.horses) } label: {
                    importRow("Horses", icon: "figure.equestrian.sports")
                }
                Button { startImport(.clients) } label: {
                    importRow("Clients", icon: "person.2")
                }
                Button { startImport(.transactions) } label: {
                    importRow("Transactions", icon: "dollarsign.circle")
                }
            }

            Section {
                Text("CSV files should include a header row. Column names are matched flexibly (e.g. \"First Name\" or \"Name\" for clients).")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .listRowBackground(Color.clear)
            }

            Section {
                Button(role: .destructive) {
                    deleteStep = .warning
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Permanently removes all horses, clients, transactions, vet records, farrier visits, supplies, and reminders from this device.")
                    .font(.caption)
            }
        }
    }
    #endif

    var body: some View {
        dataContent
        .disabled(csvJob.title != nil)
        .overlay { csvProgressOverlay }
        #if os(macOS)
        .navigationTitle("Data")  // matches its Settings tab
        #else
        .navigationTitle("Import / Export")
        #endif
        .inlineNavTitle()
        .toast(toast)
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .overlay {
            ConfirmationDialog(
                isPresented: $showImportConfirmation,
                title: importType?.importTitle ?? "Import",
                message: "This will add new records from the CSV file. Existing data will not be modified or removed.",
                confirmTitle: "Import",
                onConfirm: performImport
            )
        }
        .alert(
            deleteStep?.title ?? "",
            isPresented: Binding(get: { deleteStep != nil }, set: { if !$0 { deleteStep = nil } })
        ) {
            switch deleteStep {
            case .warning:
                Button("Export Data First") {
                    deleteStep = nil
                    exportData(.all)
                }
                Button("Delete Everything", role: .destructive) {
                    deleteStep = .finalConfirmation
                }
                Button("Cancel", role: .cancel) { deleteStep = nil }
            case .finalConfirmation:
                Button("Delete All Data", role: .destructive) {
                    deleteStep = nil
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) { deleteStep = nil }
            case nil:
                EmptyView()
            }
        } message: {
            Text(deleteStep?.message ?? "")
        }
        .alert(importResult?.cancelled == true ? Text("Import Cancelled") : Text("Import Complete"), isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            if let r = importResult {
                Text(importSummary(r))
            }
        }
    }

    // MARK: - CSV Progress

    @ViewBuilder
    private var csvProgressOverlay: some View {
        if let title = csvJob.title {
            VStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                ProgressView(value: csvJob.progress)
                    .frame(width: 220)
                Button("Cancel", role: .cancel) { csvJob.cancel() }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 8)
        }
    }

    // MARK: - Export

    private func exportData(_ type: ExportDataType) {
        // The export reads the store from a background context, so flush pending edits first.
        modelContext.saveWithLogging()
        let container = modelContext.container
        let options = CSVOptions()
        let tempDir = FileManager.default.temporaryDirectory
        let isFolder = type == .all
        let directory = isFolder ? tempDir.appendingPathComponent("BarnHub Export", isDirectory: true) : tempDir

        if isFolder {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                BarnHubLogger.error("Failed to create export directory error=\(error.localizedDescription)")
                toast.show(appLocalized("Export failed"), isError: true)
                return
            }
        }

        csvJob.run(title: appLocalized("Exporting…", comment: "CSV export progress title")) { progress in
            let actor = CSVDataActor(modelContainer: container)
            let urls = try await actor.export(type.kinds, to: directory, filePrefix: isFolder ? "" : "barnhub_",
                                              options: options, progress: progress)
            return isFolder ? directory : urls.first
        } onSuccess: { url in
            guard let url else {
                toast.show(appLocalized("Export failed"), isError: true)
                return
            }
            exportURL = url
            showExportSheet = true
            BarnHubLogger.success("Exported \(type.label)")
        } onFailure: { error in
            if error is CancellationError {
                toast.show(appLocalized("Export cancelled", comment: "Toast after the user cancels a CSV export"))
            } else {
                BarnHubLogger.error("Export failed error=\(error.localizedDescription)")
                toast.show(appLocalized("Export failed"), isError: true)
            }
        }
    }

    // MARK: - Import

    private func startImport(_ type: ImportDataType) {
        importType = type
        showImportPicker = true
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            pendingImportURL = url
            showImportConfirmation = true
        case .failure(let error):
            toast.show(appLocalized("Could not open file: \(error.localizedDescription)", comment: "File open error"), isError: true)
        }
    }

    private func performImport() {
        guard let url = pendingImportURL, let type = importType else { return }
        pendingImportURL = nil

        guard url.startAccessingSecurityScopedResource() else {
            toast.show(appLocalized("Cannot access file"), isError: true)
            return
        }

        let container = modelContext.container
        let options = CSVOptions()
        csvJob.run(title: appLocalized("Importing…", comment: "CSV import progress title")) { progress in
            defer { url.stopAccessingSecurityScopedResource() }
            let actor = CSVDataActor(modelContainer: container)
            return try await actor.importCSV(type, from: url, options: options, progress: progress)
        } onSuccess: { result in
            importResult = result
            showImportResult = true
        } onFailure: { error in
            if error is CocoaError {
                toast.show(appLocalized("Could not read file"), isError: true)
            } else {
                toast.show(appLocalized("Import failed: \(error.localizedDescription)", comment: "Import error"), isError: true)
            }
        }
    }

    private func importSummary(_ r: DataImportService.ImportResult) -> String {
        var lines: [String] = []
        if r.cancelled {
            lines.append(appLocalized("Import cancelled. Rows saved before you cancelled were kept.", comment: "CSV import result after cancelling"))
        }
        lines.append(contentsOf: r.errors)
        lines.append(appLocalized("\(r.imported) rows imported", comment: "CSV import result: number of rows added"))
        if r.duplicates > 0 {
            lines.append(appLocalized("\(r.duplicates) duplicate rows skipped", comment: "CSV import result: rows that matched existing records"))
        }
        if r.skipped > 0 {
            lines.append(appLocalized("\(r.skipped) rows skipped", comment: "CSV import result: invalid rows, followed by one line per reason"))
            for reason in DataImportService.SkipReason.allCases {
                if let count = r.skipReasons[reason] {
                    lines.append("\(reason.label): \(count)")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Delete All

    private func deleteAllData() {
        do {
            try modelContext.delete(model: VetRecord.self)
            try modelContext.delete(model: FarrierVisit.self)
            try modelContext.delete(model: Reminder.self)
            try modelContext.delete(model: SupplyItem.self)
            try modelContext.delete(model: Transaction.self)
            try modelContext.delete(model: Client.self)
            try modelContext.delete(model: Horse.self)
            modelContext.saveWithLogging()
            BarnHubLogger.success("Deleted all data")
            toast.show(appLocalized("All data deleted"))
        } catch {
            BarnHubLogger.error("Failed to delete all data error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to delete data"), isError: true)
        }
    }

    // MARK: - Row Views

    private func exportRow(_ label: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func importRow(_ label: LocalizedStringKey, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Image(systemName: "square.and.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Types

private enum DeleteStep {
    case warning, finalConfirmation

    var title: String {
        switch self {
        case .warning: return appLocalized("Are You Sure?", comment: "Delete confirmation alert title")
        case .finalConfirmation: return appLocalized("Final Confirmation", comment: "Final delete confirmation alert title")
        }
    }

    var message: String {
        switch self {
        case .warning:
            return appLocalized("This will permanently delete ALL data from BarnHub on this device. Consider exporting your data first so you have a backup.", comment: "Delete warning message")
        case .finalConfirmation:
            return appLocalized("This cannot be undone. All horses, clients, transactions, and records will be permanently deleted.", comment: "Final delete confirmation message")
        }
    }
}

private enum ExportDataType {
    case horses, clients, transactions, all
    var kinds: [CSVExportKind] {
        switch self {
        case .horses: return [.horses]
        case .clients: return [.clients]
        case .transactions: return [.transactions]
        case .all: return CSVExportKind.allCases
        }
    }
    var label: String {
        switch self {
        case .horses: return "horses"
        case .clients: return "clients"
        case .transactions: return "transactions"
        case .all: return "all data"
        }
    }
}

enum ImportDataType {
    case horses, clients, transactions
    var label: String {
        switch self {
        case .horses: return "Horses"
        case .clients: return "Clients"
        case .transactions: return "Transactions"
        }
    }
    var importTitle: LocalizedStringKey {
        switch self {
        case .horses: return "Import Horses"
        case .clients: return "Import Clients"
        case .transactions: return "Import Transactions"
        }
    }
}


/// A CSV import or export running off the main actor, with progress and cancel.
@MainActor
@Observable
private final class CSVJob {
    /// Non-nil while a job runs; shown above the progress bar.
    private(set) var title: String?
    private(set) var progress: Double = 0
    private var task: Task<Void, Never>?

    func run<T: Sendable>(
        title: String,
        work: @escaping @Sendable (@escaping CSVProgressHandler) async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        guard task == nil else { return }
        self.title = title
        progress = 0
        let report: CSVProgressHandler = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }
        task = Task {
            // Detached so the @ModelActor is created, and runs, off the main thread.
            let worker = Task.detached(priority: .userInitiated) { try await work(report) }
            do {
                let value = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                onSuccess(value)
            } catch {
                onFailure(error)
            }
            self.title = nil
            self.task = nil
        }
    }

    func cancel() {
        task?.cancel()
    }
}
