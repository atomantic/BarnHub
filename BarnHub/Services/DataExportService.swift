import Foundation
import SwiftData

/// One CSV file per kind; the raw value is the file name ("vet_records.csv").
/// "All Data" writes every case, so a new model with user data needs a case here.
enum CSVExportKind: String, CaseIterable, Sendable {
    case horses, clients, transactions
    case horseClients = "horse_clients"
    case vetRecords = "vet_records"
    case farrierVisits = "farrier_visits"
    case dentistVisits = "dentist_visits"
    case weightEntries = "weight_entries"
    case feedProducts = "feed_products"
    case feedPlan = "feed_plan"
    case reminders, lessons
    case barnNotes = "barn_notes"
    case supplies, invoices
    case horseDocuments = "horse_documents"
    case clientDocuments = "client_documents"
}

/// Neutralizes cells a spreadsheet would run as a formula ("=HYPERLINK(...)",
/// "+1 555 0100", "-2+3", "@SUM(...)", or a leading tab/CR) by prefixing a
/// single quote, per OWASP's CSV injection guidance. The importer strips the
/// quote again so BarnHub exports round-trip unchanged.
enum CSVFormulaGuard {
    static let triggers: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

    static func escape(_ value: String) -> String {
        guard let first = value.first, triggers.contains(first) else { return value }
        return "'" + value
    }
}

/// Buffered CSV writer that streams rows to a file (or, for tests, to memory)
/// instead of building one large `String`.
final class CSVWriter {
    private static let flushThreshold = 64 * 1024
    private let handle: FileHandle?
    private var buffer = Data()
    private var collected = Data()

    /// Creates (or truncates) the file at `url`.
    init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try FileHandle(forWritingTo: url)
        try handle?.truncate(atOffset: 0)
    }

    /// Collects output in memory; read it with `string` after `finish()`.
    init() {
        handle = nil
    }

    deinit {
        try? handle?.close()
    }

    /// Quotes a field containing a comma, quote, CR or LF (doubling inner quotes)
    /// after formula-escaping it.
    static func field(_ value: String) -> String {
        let escaped = CSVFormulaGuard.escape(value)
        let needsQuoting = escaped.contains { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }
        guard needsQuoting else { return escaped }
        return "\"\(escaped.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// A locale-independent number ("." decimal mark, no grouping). Values like
    /// 123.456 get a trailing zero so a comma-decimal locale can't mistake the
    /// "." for a thousands separator when the file is re-imported.
    static func number(_ value: Double) -> String {
        let s = "\(value)"
        guard let dot = s.firstIndex(of: "."), !s.contains("e") else { return s }
        let integerDigits = s[..<dot].filter(\.isNumber).count
        let fractionDigits = s.distance(from: s.index(after: dot), to: s.endIndex)
        return integerDigits <= 3 && fractionDigits == 3 ? s + "0" : s
    }

    func writeRow(_ fields: [String]) throws {
        buffer.append(contentsOf: fields.map(Self.field).joined(separator: ",").utf8)
        buffer.append(UInt8(ascii: "\n"))
        if buffer.count >= Self.flushThreshold { try flush() }
    }

    private func flush() throws {
        guard !buffer.isEmpty else { return }
        if let handle {
            try handle.write(contentsOf: buffer)
        } else {
            collected.append(buffer)
        }
        buffer.removeAll(keepingCapacity: true)
    }

    func finish() throws {
        try flush()
        try handle?.close()
    }

    var string: String { String(decoding: collected, as: UTF8.self) }
}

struct DataExportService {
    private static let fetchBatchSize = 500

    static let horsesHeader = ["Name", "Breed", "Date of Birth", "Color/Markings", "Weight (lbs)", "Purchase Price", "Stall", "Medical Notes", "Feeding Schedule", "Active", "Gender"]
    static let clientsHeader = ["First Name", "Last Name", "Email", "Phone", "Emergency Contact", "Emergency Phone", "Notes", "Active"]
    static let transactionsHeader = ["Date", "Type", "Category", "Amount", "Memo", "Client", "Paid"]
    static let horseClientsHeader = ["Horse", "Client"]
    static let vetRecordsHeader = ["Date", "Horse", "Vet", "Description", "Cost", "Next Due", "Repeats"]
    static let farrierVisitsHeader = ["Date", "Horse", "Farrier", "Service", "Cost", "Next Due"]
    static let dentistVisitsHeader = ["Date", "Horse", "Dentist", "Service", "Cost", "Next Due"]
    static let weightEntriesHeader = ["Date", "Horse", "Weight (lbs)"]
    static let feedProductsHeader = ["Name", "Brand", "Default Unit", "Notes"]
    static let feedPlanHeader = ["Horse", "Feed Time", "Product", "Brand", "Amount", "Unit", "Assigned To", "Notes"]
    static let remindersHeader = ["Due Date", "Time", "Title", "Horse", "Repeats", "Completed", "Notes"]
    static let lessonsHeader = ["Date", "Time", "Duration (min)", "Type", "Client", "Horse", "Cost", "Paid", "Repeats", "Next Date", "Notes"]
    static let barnNotesHeader = ["Date", "Category", "Horse", "Content"]
    static let suppliesHeader = ["Name", "Category", "Quantity", "Unit", "Reorder At", "Last Ordered"]
    static let invoicesHeader = ["Created", "Client", "Start Date", "End Date", "Total"]
    static let horseDocumentsHeader = ["Created", "Horse", "Title", "Type"]
    static let clientDocumentsHeader = ["Created", "Client", "Title", "Type"]

    static func header(for kind: CSVExportKind) -> [String] {
        switch kind {
        case .horses: return horsesHeader
        case .clients: return clientsHeader
        case .transactions: return transactionsHeader
        case .horseClients: return horseClientsHeader
        case .vetRecords: return vetRecordsHeader
        case .farrierVisits: return farrierVisitsHeader
        case .dentistVisits: return dentistVisitsHeader
        case .weightEntries: return weightEntriesHeader
        case .feedProducts: return feedProductsHeader
        case .feedPlan: return feedPlanHeader
        case .reminders: return remindersHeader
        case .lessons: return lessonsHeader
        case .barnNotes: return barnNotesHeader
        case .supplies: return suppliesHeader
        case .invoices: return invoicesHeader
        case .horseDocuments: return horseDocumentsHeader
        case .clientDocuments: return clientDocumentsHeader
        }
    }

    /// Columns an "All Data" bundle adds after the standalone columns: link IDs
    /// pointing at rows of other files, then the relative path of the record's
    /// file. Every bundle file also starts with an "ID" column.
    static func bundleExtras(for kind: CSVExportKind) -> [String] {
        switch kind {
        case .horses: return ["Photo"]
        case .clients, .supplies: return []
        case .transactions: return ["Client ID"]
        case .horseClients: return []
        case .vetRecords, .farrierVisits, .dentistVisits, .weightEntries, .reminders, .barnNotes: return ["Horse ID"]
        case .feedProducts: return ["Photo"]
        case .feedPlan: return ["Horse ID", "Product ID"]
        case .lessons: return ["Client ID", "Horse ID"]
        case .invoices: return ["Client ID", "File"]
        case .horseDocuments: return ["Horse ID", "File"]
        case .clientDocuments: return ["Client ID", "File"]
        }
    }

    /// The header of `kind`'s file in an "All Data" bundle. `horse_clients` is a
    /// pure join table there: it lists ID pairs, not names.
    static func bundleHeader(for kind: CSVExportKind) -> [String] {
        if kind == .horseClients { return ["ID", "Horse ID", "Client ID"] }
        return ["ID"] + header(for: kind) + bundleExtras(for: kind)
    }

    /// Prefix of the export-scoped IDs in `kind`'s "ID" column ("horse-1").
    static func idPrefix(for kind: CSVExportKind) -> String {
        switch kind {
        case .horses: return "horse"
        case .clients: return "client"
        case .transactions: return "transaction"
        case .horseClients: return "link"
        case .vetRecords: return "vet"
        case .farrierVisits: return "farrier"
        case .dentistVisits: return "dentist"
        case .weightEntries: return "weight"
        case .feedProducts: return "feed"
        case .feedPlan: return "plan"
        case .reminders: return "reminder"
        case .lessons: return "lesson"
        case .barnNotes: return "note"
        case .supplies: return "supply"
        case .invoices: return "invoice"
        case .horseDocuments: return "horse-document"
        case .clientDocuments: return "client-document"
        }
    }

    /// Writes one model type to `writer`, fetching in batches of 500 so memory
    /// stays flat, and throwing `CancellationError` if the task is cancelled.
    /// Dates are `yyyy-MM-dd` (plus a 24-hour `HH:mm` column for lessons and
    /// reminders) in `options.timeZone`; numbers use "." as the decimal mark
    /// regardless of locale, so files re-import anywhere. Enum columns hold the
    /// stored raw value, not the localized label.
    ///
    /// Related records name their horse ("Horse") or client ("Client", first and
    /// last name), and `horse_clients` lists each horse/client pair.
    ///
    /// With a `bundle` ("All Data"), each row also gets an export-scoped "ID",
    /// related records carry the ID of their horse, client or product, and
    /// photos, document files and invoice PDFs are copied into the bundle's
    /// subfolders one at a time, with the row holding the file's relative path.
    /// Without one, no blob is ever faulted in.
    static func export(_ kind: CSVExportKind, from context: ModelContext, to writer: CSVWriter,
                       options: CSVOptions = CSVOptions(), bundle: CSVExportBundle? = nil,
                       progress: CSVProgressHandler? = nil) throws {
        let dates = CSVDateCodec(options: options)
        let num = CSVWriter.number
        func day(_ date: Date?) -> String { date.map(dates.string(from:)) ?? "" }
        let prefix = idPrefix(for: kind)
        /// Writes the standalone columns, or in a bundle the row's ID, those
        /// columns and the extras (which may copy a file, so they're lazy).
        func row(id: @autoclosure () -> String, _ fields: [String], extras: () throws -> [String] = { [] }) throws {
            if bundle != nil {
                try writer.writeRow([id()] + fields + extras())
            } else {
                try writer.writeRow(fields)
            }
        }
        func nextID() -> String { bundle?.nextID(prefix) ?? "" }
        func horseID(_ horse: Horse?) -> String { bundle?.id(for: horse, prefix: idPrefix(for: .horses)) ?? "" }
        func clientID(_ client: Client?) -> String { bundle?.id(for: client, prefix: idPrefix(for: .clients)) ?? "" }
        func productID(_ product: FeedProduct?) -> String { bundle?.id(for: product, prefix: idPrefix(for: .feedProducts)) ?? "" }

        try writer.writeRow(bundle == nil ? header(for: kind) : bundleHeader(for: kind))
        switch kind {
        case .horses:
            try paged(FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)]), context, progress) { h in
                try row(id: horseID(h), [h.name, h.breed, day(h.dateOfBirth), h.colorMarkings, num(h.weight),
                                         num(h.purchasePrice), h.stallNumber, h.medicalNotes, h.feedingSchedule, "\(h.isActive)", h.gender.rawValue]) {
                    [try bundle!.copyImage(of: h, \.photoData, to: CSVExportBundle.horsePhotosFolder, named: h.name)]
                }
            }
        case .clients:
            try paged(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.lastName)]), context, progress) { c in
                try row(id: clientID(c), [c.firstName, c.lastName, c.email, c.phone, c.emergencyContact,
                                          c.emergencyPhone, c.notes, "\(c.isActive)"])
            }
        case .transactions:
            try paged(prefetching(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.client),
                      context, progress) { t in
                try row(id: nextID(), [day(t.date), t.type.rawValue, t.category.rawValue, num(t.amount),
                                       t.memo, t.client?.fullName ?? "", "\(t.isPaid)"]) { [clientID(t.client)] }
            }
        case .horseClients:
            try paged(prefetching(FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)]), \.clients), context, progress) { h in
                let clients = (h.clients ?? []).sorted { $0.fullName < $1.fullName }
                for client in clients {
                    if bundle != nil {
                        try writer.writeRow([nextID(), horseID(h), clientID(client)])
                    } else {
                        try writer.writeRow([h.name, client.fullName])
                    }
                }
            }
        case .vetRecords:
            try paged(prefetching(FetchDescriptor<VetRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { r in
                try row(id: nextID(), [day(r.date), r.horse?.name ?? "", r.vetName, r.descriptionText, num(r.cost),
                                       day(r.nextDueDate), r.reminderFrequencyRaw]) { [horseID(r.horse)] }
            }
        case .farrierVisits:
            try paged(prefetching(FetchDescriptor<FarrierVisit>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { v in
                try row(id: nextID(), [day(v.date), v.horse?.name ?? "", v.farrierName, v.serviceDescription,
                                       num(v.cost), day(v.nextDueDate)]) { [horseID(v.horse)] }
            }
        case .dentistVisits:
            try paged(prefetching(FetchDescriptor<DentistVisit>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { v in
                try row(id: nextID(), [day(v.date), v.horse?.name ?? "", v.dentistName, v.serviceDescription,
                                       num(v.cost), day(v.nextDueDate)]) { [horseID(v.horse)] }
            }
        case .weightEntries:
            try paged(prefetching(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { w in
                try row(id: nextID(), [day(w.date), w.horse?.name ?? "", num(w.weight)]) { [horseID(w.horse)] }
            }
        case .feedProducts:
            try paged(FetchDescriptor<FeedProduct>(sortBy: [SortDescriptor(\.name)]), context, progress) { p in
                try row(id: productID(p), [p.name, p.brand, p.defaultUnitRaw, p.notes]) {
                    [try bundle!.copyImage(of: p, \.photoData, to: CSVExportBundle.feedPhotosFolder, named: p.name)]
                }
            }
        case .feedPlan:
            var descriptor = FetchDescriptor<FeedPlanEntry>()
            descriptor.relationshipKeyPathsForPrefetching = [\.horse, \.product]
            try paged(descriptor, context, progress) { e in
                try row(id: nextID(), [e.horse?.name ?? "", e.feedTimeRaw, e.product?.name ?? "", e.product?.brand ?? "",
                                       num(e.amount), e.unitRaw, e.assignedPerson, e.notes]) {
                    [horseID(e.horse), productID(e.product)]
                }
            }
        case .reminders:
            try paged(prefetching(FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.dueDate)]), \.horse), context, progress) { r in
                try row(id: nextID(), [day(r.dueDate), dates.timeString(from: r.dueDate), r.title, r.horse?.name ?? "",
                                       r.frequencyRaw, "\(r.isCompleted)", r.notes]) { [horseID(r.horse)] }
            }
        case .lessons:
            var descriptor = FetchDescriptor<Lesson>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.relationshipKeyPathsForPrefetching = [\.horse, \.client]
            try paged(descriptor, context, progress) { l in
                try row(id: nextID(), [day(l.date), dates.timeString(from: l.date), "\(l.duration)", l.lessonTypeRaw,
                                       l.client?.fullName ?? "", l.horse?.name ?? "", num(l.cost), "\(l.isPaid)",
                                       l.frequencyRaw, day(l.nextDate), l.notes]) { [clientID(l.client), horseID(l.horse)] }
            }
        case .barnNotes:
            try paged(prefetching(FetchDescriptor<BarnNote>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { n in
                try row(id: nextID(), [day(n.date), n.categoryRaw, n.horse?.name ?? "", n.content]) { [horseID(n.horse)] }
            }
        case .supplies:
            try paged(FetchDescriptor<SupplyItem>(sortBy: [SortDescriptor(\.name)]), context, progress) { s in
                try row(id: nextID(), [s.name, s.categoryRaw, num(s.quantity), s.unit, num(s.reorderThreshold),
                                       day(s.lastOrderedDate)])
            }
        case .invoices:
            try paged(prefetching(FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.client),
                      context, progress) { i in
                let clientName = i.client?.fullName ?? ""
                try row(id: nextID(), [day(i.createdAt), clientName, day(i.startDate), day(i.endDate),
                                       num(i.totalAmount)]) {
                    let name = ["Invoice", clientName, day(i.startDate), day(i.endDate)].filter { !$0.isEmpty }.joined(separator: " ")
                    return [clientID(i.client), try bundle!.copyFile(of: i, \.pdfData, to: CSVExportBundle.invoicesFolder,
                                                                     named: name, fileExtension: { _ in "pdf" })]
                }
            }
        case .horseDocuments:
            try paged(prefetching(FetchDescriptor<HorseDocument>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.horse),
                      context, progress) { d in
                try row(id: nextID(), [day(d.createdAt), d.horse?.name ?? "", d.title, d.typeRaw]) {
                    let folder = bundle!.ownerFolder(for: d.horse, named: d.horse?.name ?? "", in: CSVExportBundle.horseDocumentsFolder)
                    return [horseID(d.horse), try bundle!.copyFile(of: d, \.fileData, to: folder, named: d.title,
                                                                   fileExtension: documentExtension(d.documentType))]
                }
            }
        case .clientDocuments:
            try paged(prefetching(FetchDescriptor<ClientDocument>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.client),
                      context, progress) { d in
                try row(id: nextID(), [day(d.createdAt), d.client?.fullName ?? "", d.title, d.typeRaw]) {
                    let folder = bundle!.ownerFolder(for: d.client, named: d.client?.fullName ?? "", in: CSVExportBundle.clientDocumentsFolder)
                    return [clientID(d.client), try bundle!.copyFile(of: d, \.fileData, to: folder, named: d.title,
                                                                     fileExtension: documentExtension(d.documentType))]
                }
            }
        }
    }

    /// Same rule as `HorseDocument.fileExtension`, applied to bytes already read,
    /// so the model's own blob is never faulted in.
    private static func documentExtension(_ type: DocumentType) -> (Data) -> String {
        { data in type == .photo ? ImageProcessing.fileExtension(forImageData: data) : "pdf" }
    }

    private static func prefetching<T: PersistentModel, R>(_ descriptor: FetchDescriptor<T>,
                                                          _ keyPath: KeyPath<T, R>) -> FetchDescriptor<T> {
        var descriptor = descriptor
        descriptor.relationshipKeyPathsForPrefetching = [keyPath]
        return descriptor
    }

    /// Iterates a batched fetch (SwiftData faults in 500 objects at a time).
    /// Batched fetches can't include unsaved changes, so callers save first.
    private static func paged<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, _ context: ModelContext,
                                                  _ progress: CSVProgressHandler?, _ body: (T) throws -> Void) throws {
        var descriptor = descriptor
        descriptor.includePendingChanges = false
        // Before iOS 27, a batched fetch returns objects whose relationships read
        // as empty, and a to-many one (Horse.clients) traps in SwiftData, so
        // older systems fetch everything at once.
        if #available(iOS 27, macOS 27, macCatalyst 27, *) {
            try iterate(try context.fetch(descriptor, batchSize: fetchBatchSize), progress, body)
        } else {
            try iterate(try context.fetch(descriptor), progress, body)
        }
    }

    private static func iterate<C: Collection>(_ items: C, _ progress: CSVProgressHandler?,
                                               _ body: (C.Element) throws -> Void) throws {
        let total = items.count
        for (i, item) in items.enumerated() {
            if i % fetchBatchSize == 0 {
                try Task.checkCancellation()
                if i > 0 { progress?(Double(i) / Double(total)) }
            }
            try body(item)
        }
        progress?(1)
    }

    // MARK: String conveniences (tests)

    static func exportCSV(_ kind: CSVExportKind, from context: ModelContext, options: CSVOptions = CSVOptions()) throws -> String {
        let writer = CSVWriter()
        try export(kind, from: context, to: writer, options: options)
        try writer.finish()
        return writer.string
    }

    static func exportHorsesCSV(from context: ModelContext, options: CSVOptions = CSVOptions()) throws -> String {
        try exportCSV(.horses, from: context, options: options)
    }

    static func exportClientsCSV(from context: ModelContext, options: CSVOptions = CSVOptions()) throws -> String {
        try exportCSV(.clients, from: context, options: options)
    }

    static func exportTransactionsCSV(from context: ModelContext, options: CSVOptions = CSVOptions()) throws -> String {
        try exportCSV(.transactions, from: context, options: options)
    }
}

// MARK: - All Data bundle

/// State shared by every file of one "All Data" export: the export-scoped row
/// IDs and the files copied next to the CSVs.
///
/// IDs ("horse-1", "client-3") are assigned the first time a record is seen,
/// keyed by `persistentModelID`, so they're unique and consistent across the
/// files of one export (the link columns use them) but not across exports.
/// Nothing is stored on the models, so this needs no schema change.
///
/// Blobs are read through a short-lived scratch context that's replaced every
/// few files, and written straight to disk, so a large library is copied with
/// flat memory: no array of `Data`, and the main export context never faults
/// in a photo or PDF.
final class CSVExportBundle {
    static let horsePhotosFolder = "Photos/Horses"
    static let feedPhotosFolder = "Photos/Feed"
    static let horseDocumentsFolder = "Documents/Horses"
    static let clientDocumentsFolder = "Documents/Clients"
    static let invoicesFolder = "Invoices"
    private static let readsPerScratchContext = 10

    let root: URL
    private let container: ModelContainer
    private var scratch: ModelContext?
    private var scratchReads = 0
    private var ids: [PersistentIdentifier: String] = [:]
    private var counters: [String: Int] = [:]
    /// Lowercased names already used in each relative folder (APFS and most
    /// share targets are case-insensitive).
    private var usedNames: [String: Set<String>] = [:]
    private var ownerFolders: [PersistentIdentifier: String] = [:]
    private(set) var filesWritten = 0

    init(root: URL, container: ModelContainer) {
        self.root = root
        self.container = container
    }

    /// The next ID for a record nothing links to.
    func nextID(_ prefix: String) -> String {
        let n = (counters[prefix] ?? 0) + 1
        counters[prefix] = n
        return "\(prefix)-\(n)"
    }

    /// The record's ID, assigned on first use; "" for no record.
    func id<T: PersistentModel>(for model: T?, prefix: String) -> String {
        guard let model else { return "" }
        let key = model.persistentModelID
        if let existing = ids[key] { return existing }
        let id = nextID(prefix)
        ids[key] = id
        return id
    }

    /// A per-owner subfolder of `parent` ("Documents/Horses/Storm"), unique
    /// even when two horses share a name ("Storm-2"). Records without an owner
    /// go straight into `parent`.
    func ownerFolder<T: PersistentModel>(for owner: T?, named name: String, in parent: String) -> String {
        guard let owner else { return parent }
        let key = owner.persistentModelID
        if let folder = ownerFolders[key] { return folder }
        let folder = parent + "/" + uniqueName(ShareTempFiles.sanitizedFileName(name, fileExtension: ""), extension: "", in: parent)
        ownerFolders[key] = folder
        return folder
    }

    /// Copies a photo, named after `name` with the extension its bytes call for.
    func copyImage<T: PersistentModel>(of model: T, _ keyPath: KeyPath<T, Data?>, to folder: String, named name: String) throws -> String {
        try copyFile(of: model, keyPath, to: folder, named: name, fileExtension: ImageProcessing.fileExtension(forImageData:))
    }

    /// Writes the blob at `keyPath` to `<folder>/<sanitized name>.<ext>` and
    /// returns that path relative to `root`, or "" when the record has no file.
    func copyFile<T: PersistentModel>(of model: T, _ keyPath: KeyPath<T, Data?>, to folder: String, named name: String,
                                      fileExtension: (Data) -> String) throws -> String {
        try Task.checkCancellation()
        return try autoreleasepool {
            guard let data = blob(of: model, keyPath), !data.isEmpty else { return "" }
            let ext = fileExtension(data)
            // Sanitize with the extension so a title ending in ".pdf" isn't doubled.
            let base = String(ShareTempFiles.sanitizedFileName(name, fileExtension: ext).dropLast(ext.count + 1))
            let fileName = uniqueName(base, extension: ext, in: folder)
            let directory = root.appendingPathComponent(folder, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent(fileName))
            filesWritten += 1
            return folder + "/" + fileName
        }
    }

    private func blob<T: PersistentModel>(of model: T, _ keyPath: KeyPath<T, Data?>) -> Data? {
        if scratch == nil || scratchReads >= Self.readsPerScratchContext {
            scratch = ModelContext(container)
            scratchReads = 0
        }
        scratchReads += 1
        guard let copy = scratch?.model(for: model.persistentModelID) as? T else { return nil }
        return copy[keyPath: keyPath]
    }

    /// `base.ext`, or `base-2.ext`, `base-3.ext`… when that name is taken in `folder`.
    private func uniqueName(_ base: String, extension ext: String, in folder: String) -> String {
        func name(_ n: Int) -> String {
            let stem = n == 1 ? base : "\(base)-\(n)"
            return ext.isEmpty ? stem : "\(stem).\(ext)"
        }
        var used = usedNames[folder] ?? []
        var n = 1
        while used.contains(name(n).lowercased()) { n += 1 }
        let result = name(n)
        used.insert(result.lowercased())
        usedNames[folder] = used
        return result
    }
}
