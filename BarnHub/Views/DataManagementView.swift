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

    var body: some View {
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
        }
        .navigationTitle("Import / Export")
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
                title: "Import \(importType?.label ?? "Data")",
                message: "This will add new records from the CSV file. Existing data will not be modified or removed.",
                confirmTitle: "Import",
                onConfirm: performImport
            )
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

        switch type {
        case .horses:
            let csv = DataExportService.exportHorsesCSV(from: modelContext)
            exportURL = writeTemp(csv, name: "barnhub_horses.csv", dir: tempDir)
        case .clients:
            let csv = DataExportService.exportClientsCSV(from: modelContext)
            exportURL = writeTemp(csv, name: "barnhub_clients.csv", dir: tempDir)
        case .transactions:
            let csv = DataExportService.exportTransactionsCSV(from: modelContext)
            exportURL = writeTemp(csv, name: "barnhub_transactions.csv", dir: tempDir)
        case .all:
            let folder = tempDir.appendingPathComponent("BarnHub Export", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            _ = writeTemp(DataExportService.exportHorsesCSV(from: modelContext), name: "horses.csv", dir: folder)
            _ = writeTemp(DataExportService.exportClientsCSV(from: modelContext), name: "clients.csv", dir: folder)
            _ = writeTemp(DataExportService.exportTransactionsCSV(from: modelContext), name: "transactions.csv", dir: folder)
            exportURL = folder
        }

        if exportURL != nil {
            showExportSheet = true
            BarnHubLogger.success("Exported \(type.label)")
        } else {
            toast.show("Export failed", isError: true)
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
            toast.show("Could not open file: \(error.localizedDescription)", isError: true)
        }
    }

    private func performImport() {
        guard let url = pendingImportURL, let type = importType else { return }

        guard url.startAccessingSecurityScopedResource() else {
            toast.show("Cannot access file", isError: true)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let csvString = String(data: data, encoding: .utf8) else {
            toast.show("Could not read file", isError: true)
            return
        }

        let result: DataImportService.ImportResult
        switch type {
        case .horses:
            result = DataImportService.importHorses(from: csvString, context: modelContext)
        case .clients:
            result = DataImportService.importClients(from: csvString, context: modelContext)
        case .transactions:
            result = DataImportService.importTransactions(from: csvString, context: modelContext)
        }

        importResult = result
        showImportResult = true
        pendingImportURL = nil
    }

    // MARK: - Row Views

    private func exportRow(_ label: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Image(systemName: "square.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func importRow(_ label: String, icon: String) -> some View {
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
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
