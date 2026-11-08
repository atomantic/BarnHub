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
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            if let r = importResult {
                if r.errors.isEmpty {
                    Text("Imported \(r.imported) records.\(r.skipped > 0 ? " Skipped \(r.skipped) rows." : "")")
                } else {
                    Text("Imported \(r.imported) records. Errors: \(r.errors.joined(separator: ", "))")
                }
            }
        }
    }

    // MARK: - Export

    private func exportData(_ type: ExportDataType) {
        let tempDir = FileManager.default.temporaryDirectory

        do {
            switch type {
            case .horses:
                let csv = try DataExportService.exportHorsesCSV(from: modelContext)
                exportURL = writeTemp(csv, name: "barnhub_horses.csv", dir: tempDir)
            case .clients:
                let csv = try DataExportService.exportClientsCSV(from: modelContext)
                exportURL = writeTemp(csv, name: "barnhub_clients.csv", dir: tempDir)
            case .transactions:
                let csv = try DataExportService.exportTransactionsCSV(from: modelContext)
                exportURL = writeTemp(csv, name: "barnhub_transactions.csv", dir: tempDir)
            case .all:
                let folder = tempDir.appendingPathComponent("BarnHub Export", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                } catch {
                    BarnHubLogger.error("Failed to create export directory error=\(error.localizedDescription)")
                    toast.show(appLocalized("Export failed"), isError: true)
                    return
                }
                _ = writeTemp(try DataExportService.exportHorsesCSV(from: modelContext), name: "horses.csv", dir: folder)
                _ = writeTemp(try DataExportService.exportClientsCSV(from: modelContext), name: "clients.csv", dir: folder)
                _ = writeTemp(try DataExportService.exportTransactionsCSV(from: modelContext), name: "transactions.csv", dir: folder)
                exportURL = folder
            }
        } catch {
            BarnHubLogger.error("Export fetch failed error=\(error.localizedDescription)")
            toast.show(appLocalized("Export failed"), isError: true)
            return
        }

        if exportURL != nil {
            showExportSheet = true
            BarnHubLogger.success("Exported \(type.label)")
        } else {
            toast.show(appLocalized("Export failed"), isError: true)
        }
    }

    private func writeTemp(_ content: String, name: String, dir: URL) -> URL? {
        let url = dir.appendingPathComponent(name)
        guard let data = content.data(using: .utf8) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            BarnHubLogger.error("Failed to write export file: \(error.localizedDescription)")
            return nil
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

        guard url.startAccessingSecurityScopedResource() else {
            toast.show(appLocalized("Cannot access file"), isError: true)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let csvString = String(data: data, encoding: .utf8) else {
            toast.show(appLocalized("Could not read file"), isError: true)
            return
        }

        let result: DataImportService.ImportResult
        do {
            switch type {
            case .horses:
                result = DataImportService.importHorses(from: csvString, context: modelContext)
            case .clients:
                result = DataImportService.importClients(from: csvString, context: modelContext)
            case .transactions:
                result = try DataImportService.importTransactions(from: csvString, context: modelContext)
            }
        } catch {
            toast.show(appLocalized("Import failed: \(error.localizedDescription)", comment: "Import error"), isError: true)
            return
        }

        importResult = result
        showImportResult = true
        pendingImportURL = nil
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

