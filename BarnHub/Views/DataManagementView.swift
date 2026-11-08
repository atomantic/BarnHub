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
    /// The Delete All Data / Restore All Data dialog on screen, if any (#76).
    @State private var resetStep: DataResetStep?
    /// The picker is choosing an All Data folder to restore, not a CSV file.
    @State private var pickingFolder = false
    @State private var restoreResult: DataRestoreService.Result?
    @State private var showRestoreResult = false
    /// Why a restore that followed Delete All Data didn't finish.
    @State private var restoreNotice: String?
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
                Text("Export your records as CSV files for use in spreadsheets. All Data saves one file for each kind of record, with IDs that link related records, plus horse and feed photos, horse and client documents and invoice PDFs in folders next to the files. With many photos or documents it can be large.")
            }

            Section {
                HStack {
                    Button("Horses") { startImport(.horses) }
                    Button("Clients") { startImport(.clients) }
                    Button("Transactions") { startImport(.transactions) }
                    Spacer()
                    Button("Restore All Data") { startRestore() }
                        .buttonStyle(.borderedProminent)
                        .tint(.barnGreen)
                }
            } header: {
                Text("Import")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CSV files should include a header row. Column names are matched flexibly (e.g. \"First Name\" or \"Name\" for clients).")
                    Text(restoreFooter)
                }
            }

            Section {
                HStack {
                    Button(role: .destructive) {
                        resetStep = .chooseScope(.delete)
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                    Spacer()
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Permanently deletes all your BarnHub data from your iCloud account and from every device signed in to it.")
            }
        }
        .formStyle(.grouped)
    }
    #else
    private var dataContent: some View {
        List {
            Section {
                Text("Export your records as CSV files for use in spreadsheets. All Data saves one file for each kind of record, with IDs that link related records, plus horse and feed photos, horse and client documents and invoice PDFs in folders next to the files. With many photos or documents it can be large.")
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
                Button { startRestore() } label: {
                    importRow("Restore All Data", icon: "folder")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CSV files should include a header row. Column names are matched flexibly (e.g. \"First Name\" or \"Name\" for clients).")
                    Text(restoreFooter)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .listRowBackground(Color.clear)
            }

            Section {
                Button(role: .destructive) {
                    resetStep = .chooseScope(.delete)
                } label: {
                    Label("Delete All Data", systemImage: "trash")
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Permanently deletes all your BarnHub data from your iCloud account and from every device signed in to it.")
                    .font(.caption)
            }
        }
    }
    #endif

    private var restoreFooter: LocalizedStringKey {
        "Restore All Data reads a BarnHub Export folder saved by All Data and adds its records, photos, documents and invoices."
    }

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
        .sheet(isPresented: $showExportSheet, onDismiss: {
            ShareTempFiles.cleanUp(exportURL)
            exportURL = nil
        }) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: pickingFolder ? [.folder] : [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if pickingFolder {
                handleFolderSelection(result)
            } else {
                handleFileSelection(result)
            }
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
        .overlay { resetDialog }
        .alert(importResult?.cancelled == true ? Text("Import Cancelled") : Text("Import Complete"), isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            if let r = importResult {
                Text(importSummary(r))
            }
        }
        .alert("Restore Complete", isPresented: $showRestoreResult) {
            Button("OK") {}
        } message: {
            if let r = restoreResult {
                Text(restoreSummary(r))
            }
        }
        .alert("Restore Didn't Finish", isPresented: Binding(get: { restoreNotice != nil }, set: { if !$0 { restoreNotice = nil } })) {
            Button("OK") {}
        } message: {
            Text(restoreNotice ?? "")
        }
    }

    // MARK: - Delete / Restore Dialogs

    /// One custom dialog per step instead of chained system alerts: a system
    /// alert presented from another alert's button is dropped on iPad (#76).
    /// The binding is tied to the step it was made for, so closing that
    /// dialog after a button moved on to the next step doesn't clear it.
    @ViewBuilder
    private var resetDialog: some View {
        if let step = resetStep {
            ChoiceDialog(
                isPresented: Binding(get: { resetStep == step }, set: { if !$0, resetStep == step { resetStep = nil } }),
                title: step.title,
                message: step.message,
                choices: step.choices.map { choice in
                    .init(title: choice.title, role: choice.isDestructive ? .destructive : nil, isDefault: choice.isDefault) {
                        handle(step.action(for: choice))
                    }
                }
            )
            .id(step)
        }
    }

    private func handle(_ action: DataResetAction) {
        switch action {
        case .next(let step):
            resetStep = step
        case .restore(let url):
            resetStep = nil
            performRestore(url, afterDelete: false)
        case .delete(let keepDocuments):
            resetStep = nil
            deleteAllData(keepDocuments: keepDocuments)
        case .deleteThenRestore(let url, let keepDocuments):
            resetStep = nil
            // Check the folder first, so a wrong pick doesn't cost the user their data.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                _ = try DataRestoreService.exportRoot(for: url)
            } catch {
                toast.show(error.localizedDescription, isError: true)
                return
            }
            guard deleteAllData(keepDocuments: keepDocuments) else { return }
            performRestore(url, afterDelete: true)
        }
    }

    // MARK: - CSV Progress

    @ViewBuilder
    private var csvProgressOverlay: some View {
        if let title = csvJob.title {
            VStack(spacing: 12) {
                Text(csvJob.isCancelling ? appLocalized("Cancelling…", comment: "Progress title after tapping Cancel while an export, import or restore stops and undoes its work") : title)
                    .font(.headline)
                ProgressView(value: csvJob.progress)
                    .frame(width: 220)
                if let detail = csvJob.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("Cancel", role: .cancel) { csvJob.cancel() }
                    .disabled(csvJob.isCancelling)
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
        let title = appLocalized("Exporting…", comment: "CSV export progress title")
        if type == .all {
            // Writes into its own tmp/BarnHubShare/<UUID>/BarnHub Export/ folder,
            // which it deletes itself on failure or cancel.
            csvJob.run(title: title) { progress, step in
                let actor = CSVDataActor(modelContainer: container)
                return Optional(try await actor.exportAllData(options: options, progress: progress, step: step))
            } onSuccess: { showExport($0, type) } onFailure: { exportFailed($0, shareFolder: nil) }
            return
        }

        // Each single-file export gets its own tmp/BarnHubShare/<UUID>/ folder,
        // deleted when the share sheet closes (or at the next launch).
        let shareFolder: URL
        do {
            shareFolder = try ShareTempFiles.makeShareFolder()
        } catch {
            BarnHubLogger.error("Failed to create export directory error=\(error.localizedDescription)")
            toast.show(appLocalized("Export failed"), isError: true)
            return
        }
        csvJob.run(title: title) { progress, _ in
            let actor = CSVDataActor(modelContainer: container)
            let urls = try await actor.export(type.kinds, to: shareFolder, filePrefix: "barnhub_", options: options, progress: progress)
            return urls.first
        } onSuccess: { url in
            if url == nil { ShareTempFiles.discardShareFolder(shareFolder) }
            showExport(url, type)
        } onFailure: { exportFailed($0, shareFolder: shareFolder) }
    }

    private func showExport(_ url: URL?, _ type: ExportDataType) {
        guard let url else {
            toast.show(appLocalized("Export failed"), isError: true)
            return
        }
        ShareTempFiles.cleanUp(exportURL)
        exportURL = url
        showExportSheet = true
        BarnHubLogger.success("Exported \(type.label) files=\(type.kinds.count)")
    }

    private func exportFailed(_ error: Error, shareFolder: URL?) {
        if let shareFolder { ShareTempFiles.discardShareFolder(shareFolder) }
        if error is CancellationError {
            toast.show(appLocalized("Export cancelled", comment: "Toast after the user cancels a CSV export"))
        } else {
            BarnHubLogger.error("Export failed error=\(error.localizedDescription)")
            toast.show(appLocalized("Export failed"), isError: true)
        }
    }

    // MARK: - Import

    private func startImport(_ type: ImportDataType) {
        importType = type
        pickingFolder = false
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
        csvJob.run(title: appLocalized("Importing…", comment: "CSV import progress title")) { progress, _ in
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
                    lines.append(appLocalized("\(reason.label): \(count)", comment: "CSV import result: why rows were skipped, then how many"))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Restore All Data

    private func startRestore() {
        pickingFolder = true
        showImportPicker = true
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            resetStep = .restoreChoice(url)
        case .failure(let error):
            toast.show(appLocalized("Could not open file: \(error.localizedDescription)", comment: "File open error"), isError: true)
        }
    }

    /// Restores the folder at `url`. `afterDelete`: Delete All Data just ran,
    /// so a failure has to say the old data is gone.
    private func performRestore(_ url: URL, afterDelete: Bool) {
        // The restore reads through background contexts, so flush pending edits first.
        modelContext.saveWithLogging()
        let container = modelContext.container
        let options = CSVOptions()
        csvJob.run(title: appLocalized("Restoring…", comment: "Restore All Data progress title")) { progress, step in
            // A picked folder is security scoped on iOS and in the Mac sandbox;
            // otherwise reading still works or reports a real error.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let actor = CSVDataActor(modelContainer: container)
            return try await actor.restoreAllData(from: url, options: options, progress: progress, step: step)
        } onSuccess: { result in
            restoreResult = result
            showRestoreResult = true
            // Same hook as a save on the main context, so reminders get scheduled.
            NotificationCenter.default.post(name: .barnHubModelContextDidSave, object: modelContext)
        } onFailure: { error in
            if !(error is CancellationError) {
                BarnHubLogger.error("Restore failed afterDelete=\(afterDelete) error=\(error.localizedDescription)")
            }
            let failure = DataResetStep.restoreFailure(error, afterDelete: afterDelete)
            if afterDelete {
                restoreNotice = failure.message
            } else {
                toast.show(failure.message, isError: failure.isError)
            }
        }
    }

    private func restoreSummary(_ r: DataRestoreService.Result) -> String {
        var lines = [appLocalized("\(r.imported) records restored", comment: "Restore All Data result: records added")]
        if r.duplicates > 0 {
            lines.append(appLocalized("\(r.duplicates) records already in BarnHub skipped", comment: "Restore All Data result: rows that matched existing records"))
        }
        if r.filesRestored > 0 {
            lines.append(appLocalized("\(r.filesRestored) photos and files restored", comment: "Restore All Data result: photos, documents and invoice PDFs read from the folder"))
        }
        if r.filesMissing > 0 {
            lines.append(appLocalized("\(r.filesMissing) files not found in the folder", comment: "Restore All Data result: Photo or File paths missing from the folder"))
        }
        if r.skipped > 0 {
            lines.append(appLocalized("\(r.skipped) rows skipped", comment: "CSV import result: invalid rows, followed by one line per reason"))
            for reason in DataImportService.SkipReason.allCases {
                if let count = r.skipReasons[reason] {
                    lines.append(appLocalized("\(reason.label): \(count)", comment: "CSV import result: why rows were skipped, then how many"))
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Delete All

    /// Returns whether everything was deleted.
    @discardableResult
    private func deleteAllData(keepDocuments: Bool) -> Bool {
        do {
            try RecordRemoval.deleteAllData(in: modelContext, keepDocuments: keepDocuments)
            NotificationService.cancelAllNotifications()
            BarnHubLogger.success("Deleted all data keepDocuments=\(keepDocuments)")
            toast.show(appLocalized("All data deleted"))
            return true
        } catch {
            BarnHubLogger.error("Failed to delete all data error=\(error.localizedDescription)")
            toast.show(appLocalized("Failed to delete data"), isError: true)
            return false
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
    /// Which file an export is writing, shown below the bar.
    private(set) var detail: String?
    private(set) var progress: Double = 0
    /// Cancel was tapped; the job is stopping (a restore undoes what it added).
    private(set) var isCancelling = false
    private var task: Task<Void, Never>?

    func run<T: Sendable>(
        title: String,
        work: @escaping @Sendable (@escaping CSVProgressHandler, @escaping CSVStepHandler) async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onFailure: @escaping (Error) -> Void
    ) {
        guard task == nil else { return }
        self.title = title
        detail = nil
        progress = 0
        isCancelling = false
        let report: CSVProgressHandler = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }
        let step: CSVStepHandler = { [weak self] index, count, kind in
            Task { @MainActor in
                guard self?.title != nil else { return }
                // The file name is one value, so the key matches the catalog's "Step %lld of %lld: %@".
                self?.detail = appLocalized("Step \(index) of \(count): \(kind.rawValue + ".csv")",
                                            comment: "Export or restore progress: which file is being written or read, e.g. Step 3 of 17: transactions.csv")
            }
        }
        task = Task {
            // Detached so the @ModelActor is created, and runs, off the main thread.
            let worker = Task.detached(priority: .userInitiated) { try await work(report, step) }
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
            self.detail = nil
            self.isCancelling = false
            self.task = nil
        }
    }

    func cancel() {
        guard let task, !isCancelling else { return }
        isCancelling = true
        task.cancel()
    }
}

// MARK: - Delete / Restore Steps

/// What the Delete All Data dialogs are deleting for (#76).
enum DataResetIntent: Hashable {
    /// Delete All Data on its own.
    case delete
    /// Restore All Data's "Delete All Data, Then Restore": the folder to restore afterwards.
    case replace(URL)
}

/// The dialogs for Delete All Data and for Restore All Data's choice, one at a
/// time. A button either moves to the next step or ends with an action.
enum DataResetStep: Hashable {
    /// A folder was picked: restore into the current data, or delete first.
    case restoreChoice(URL)
    /// Where the data lives, and whether to keep documents.
    case chooseScope(DataResetIntent)
    case finalConfirmation(DataResetIntent, keepDocuments: Bool)

    enum Choice: Hashable {
        case restoreAndKeep, deleteThenRestore, deleteEverything, keepDocuments, confirm
    }

    /// The step's buttons, Cancel aside.
    var choices: [Choice] {
        switch self {
        case .restoreChoice: return [.restoreAndKeep, .deleteThenRestore]
        case .chooseScope: return [.deleteEverything, .keepDocuments]
        case .finalConfirmation(.delete, _): return [.confirm]
        case .finalConfirmation(.replace, _): return [.deleteThenRestore]
        }
    }

    /// What tapping `choice` does here.
    func action(for choice: Choice) -> DataResetAction {
        switch (self, choice) {
        case (.restoreChoice(let url), .deleteThenRestore): return .next(.chooseScope(.replace(url)))
        case (.restoreChoice(let url), _): return .restore(url)
        case (.chooseScope(let intent), .keepDocuments): return .next(.finalConfirmation(intent, keepDocuments: true))
        case (.chooseScope(let intent), _): return .next(.finalConfirmation(intent, keepDocuments: false))
        case (.finalConfirmation(.delete, let keep), _): return .delete(keepDocuments: keep)
        case (.finalConfirmation(.replace(let url), let keep), _): return .deleteThenRestore(url, keepDocuments: keep)
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .restoreChoice: return "Restore All Data"
        case .chooseScope(.delete): return "Delete All Data?"
        case .chooseScope(.replace): return "Delete All Data, Then Restore?"
        case .finalConfirmation: return "Final Confirmation"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .restoreChoice:
            return "Restore only adds what's missing. Records, photos, documents and invoices in this folder that aren't in BarnHub yet are added. Records you already have are kept unchanged, even where the folder's copy differs: for example, it won't add a photo to a horse you already have. Nothing is deleted.\n\nTo replace your data with this folder instead, choose Delete All Data, Then Restore."
        case .chooseScope(.delete):
            return "BarnHub doesn't keep your data on its own or any third-party servers. It lives on your devices and in your own iCloud account, so this deletes it from your iCloud and from every device signed in to it, not just this one.\n\nYou can also delete all horse and client documents and photos, or keep them. Keeping them also keeps the horses and clients they belong to."
        case .chooseScope(.replace):
            return "BarnHub doesn't keep your data on its own or any third-party servers. It lives on your devices and in your own iCloud account, so this deletes it from your iCloud and from every device signed in to it, not just this one. Then the folder is restored.\n\nYou can also delete all horse and client documents and photos, or keep them. Keeping them also keeps the horses and clients they belong to, and the restore skips the ones that are also in the folder."
        case .finalConfirmation(.delete, keepDocuments: false):
            return "This cannot be undone. Every horse, client, record, transaction, invoice, document and photo will be deleted from your iCloud and all your devices."
        case .finalConfirmation(.delete, keepDocuments: true):
            return "This cannot be undone. Everything except horse and client documents, and the horses and clients they belong to, will be deleted from your iCloud and all your devices."
        case .finalConfirmation(.replace, keepDocuments: false):
            return "This cannot be undone. Every horse, client, record, transaction, invoice, document and photo will be deleted from your iCloud and all your devices, then the folder is restored."
        case .finalConfirmation(.replace, keepDocuments: true):
            return "This cannot be undone. Everything except horse and client documents, and the horses and clients they belong to, will be deleted from your iCloud and all your devices, then the folder is restored."
        }
    }

    /// How a restore that ended with `error` is reported. After Delete All
    /// Data the message says the old data is already gone.
    static func restoreFailure(_ error: Error, afterDelete: Bool) -> (message: String, isError: Bool) {
        let cancelled = error is CancellationError
        switch (cancelled, afterDelete) {
        case (true, false):
            return (appLocalized("Restore cancelled. Nothing was added.", comment: "Toast after the user cancels Restore All Data"), false)
        case (true, true):
            return (appLocalized("Restore cancelled. Your data was already deleted, and nothing from the folder was added.",
                                 comment: "Alert after cancelling the restore that follows Delete All Data"), true)
        case (false, true):
            return (appLocalized("Restore failed. Your data was already deleted, and nothing from the folder was added.",
                                 comment: "Alert when the restore that follows Delete All Data fails"), true)
        case (false, false):
            if let error = error as? DataRestoreService.RestoreError { return (error.localizedDescription, true) }
            return (appLocalized("Restore failed. Nothing was added.", comment: "Toast when Restore All Data fails; everything it added was removed again"), true)
        }
    }
}

extension DataResetStep.Choice {
    var title: LocalizedStringKey {
        switch self {
        case .restoreAndKeep: return "Restore and Keep My Data"
        case .deleteThenRestore: return "Delete All Data, Then Restore"
        case .deleteEverything: return "Delete Everything"
        case .keepDocuments: return "Keep Documents"
        case .confirm: return "Delete All Data"
        }
    }

    var isDestructive: Bool { self != .restoreAndKeep && self != .keepDocuments }
    var isDefault: Bool { self == .restoreAndKeep }
}

enum DataResetAction: Equatable {
    case next(DataResetStep)
    /// Restore into the current data.
    case restore(URL)
    case delete(keepDocuments: Bool)
    case deleteThenRestore(URL, keepDocuments: Bool)
}
