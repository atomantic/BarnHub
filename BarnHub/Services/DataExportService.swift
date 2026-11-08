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

    static let horsesHeader = ["Name", "Breed", "Date of Birth", "Color/Markings", "Weight (lbs)", "Purchase Price", "Stall", "Medical Notes", "Feeding Schedule", "Active"]
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

    /// Writes one model type to `writer`, fetching in batches of 500 so memory
    /// stays flat, and throwing `CancellationError` if the task is cancelled.
    /// Dates are `yyyy-MM-dd` (plus a 24-hour `HH:mm` column for lessons and
    /// reminders) in `options.timeZone`; numbers use "." as the decimal mark
    /// regardless of locale, so files re-import anywhere. Enum columns hold the
    /// stored raw value, not the localized label.
    ///
    /// Related records name their horse ("Horse") or client ("Client", first and
    /// last name), and `horse_clients` lists each horse/client pair. Photos,
    /// document files and invoice PDFs are not written: the document and invoice
    /// files list their details only, so the external-storage blobs are never
    /// faulted in.
    static func export(_ kind: CSVExportKind, from context: ModelContext, to writer: CSVWriter,
                       options: CSVOptions = CSVOptions(), progress: CSVProgressHandler? = nil) throws {
        let dates = CSVDateCodec(options: options)
        let num = CSVWriter.number
        func day(_ date: Date?) -> String { date.map(dates.string(from:)) ?? "" }
        try writer.writeRow(header(for: kind))
        switch kind {
        case .horses:
            try paged(FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)]), context, progress) { h in
                try writer.writeRow([h.name, h.breed, day(h.dateOfBirth), h.colorMarkings, num(h.weight),
                                     num(h.purchasePrice), h.stallNumber, h.medicalNotes, h.feedingSchedule, "\(h.isActive)"])
            }
        case .clients:
            try paged(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.lastName)]), context, progress) { c in
                try writer.writeRow([c.firstName, c.lastName, c.email, c.phone, c.emergencyContact,
                                     c.emergencyPhone, c.notes, "\(c.isActive)"])
            }
        case .transactions:
            try paged(prefetching(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.client),
                      context, progress) { t in
                try writer.writeRow([day(t.date), t.type.rawValue, t.category.rawValue, num(t.amount),
                                     t.memo, t.client?.fullName ?? "", "\(t.isPaid)"])
            }
        case .horseClients:
            try paged(prefetching(FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)]), \.clients), context, progress) { h in
                for name in (h.clients ?? []).map(\.fullName).sorted() {
                    try writer.writeRow([h.name, name])
                }
            }
        case .vetRecords:
            try paged(prefetching(FetchDescriptor<VetRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { r in
                try writer.writeRow([day(r.date), r.horse?.name ?? "", r.vetName, r.descriptionText, num(r.cost),
                                     day(r.nextDueDate), r.reminderFrequencyRaw])
            }
        case .farrierVisits:
            try paged(prefetching(FetchDescriptor<FarrierVisit>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { v in
                try writer.writeRow([day(v.date), v.horse?.name ?? "", v.farrierName, v.serviceDescription,
                                     num(v.cost), day(v.nextDueDate)])
            }
        case .dentistVisits:
            try paged(prefetching(FetchDescriptor<DentistVisit>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { v in
                try writer.writeRow([day(v.date), v.horse?.name ?? "", v.dentistName, v.serviceDescription,
                                     num(v.cost), day(v.nextDueDate)])
            }
        case .weightEntries:
            try paged(prefetching(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { w in
                try writer.writeRow([day(w.date), w.horse?.name ?? "", num(w.weight)])
            }
        case .feedProducts:
            try paged(FetchDescriptor<FeedProduct>(sortBy: [SortDescriptor(\.name)]), context, progress) { p in
                try writer.writeRow([p.name, p.brand, p.defaultUnitRaw, p.notes])
            }
        case .feedPlan:
            var descriptor = FetchDescriptor<FeedPlanEntry>()
            descriptor.relationshipKeyPathsForPrefetching = [\.horse, \.product]
            try paged(descriptor, context, progress) { e in
                try writer.writeRow([e.horse?.name ?? "", e.feedTimeRaw, e.product?.name ?? "", e.product?.brand ?? "",
                                     num(e.amount), e.unitRaw, e.assignedPerson, e.notes])
            }
        case .reminders:
            try paged(prefetching(FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.dueDate)]), \.horse), context, progress) { r in
                try writer.writeRow([day(r.dueDate), dates.timeString(from: r.dueDate), r.title, r.horse?.name ?? "",
                                     r.frequencyRaw, "\(r.isCompleted)", r.notes])
            }
        case .lessons:
            var descriptor = FetchDescriptor<Lesson>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.relationshipKeyPathsForPrefetching = [\.horse, \.client]
            try paged(descriptor, context, progress) { l in
                try writer.writeRow([day(l.date), dates.timeString(from: l.date), "\(l.duration)", l.lessonTypeRaw,
                                     l.client?.fullName ?? "", l.horse?.name ?? "", num(l.cost), "\(l.isPaid)",
                                     l.frequencyRaw, day(l.nextDate), l.notes])
            }
        case .barnNotes:
            try paged(prefetching(FetchDescriptor<BarnNote>(sortBy: [SortDescriptor(\.date, order: .reverse)]), \.horse),
                      context, progress) { n in
                try writer.writeRow([day(n.date), n.categoryRaw, n.horse?.name ?? "", n.content])
            }
        case .supplies:
            try paged(FetchDescriptor<SupplyItem>(sortBy: [SortDescriptor(\.name)]), context, progress) { s in
                try writer.writeRow([s.name, s.categoryRaw, num(s.quantity), s.unit, num(s.reorderThreshold),
                                     day(s.lastOrderedDate)])
            }
        case .invoices:
            try paged(prefetching(FetchDescriptor<Invoice>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.client),
                      context, progress) { i in
                try writer.writeRow([day(i.createdAt), i.client?.fullName ?? "", day(i.startDate), day(i.endDate),
                                     num(i.totalAmount)])
            }
        case .horseDocuments:
            try paged(prefetching(FetchDescriptor<HorseDocument>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.horse),
                      context, progress) { d in
                try writer.writeRow([day(d.createdAt), d.horse?.name ?? "", d.title, d.typeRaw])
            }
        case .clientDocuments:
            try paged(prefetching(FetchDescriptor<ClientDocument>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]), \.client),
                      context, progress) { d in
                try writer.writeRow([day(d.createdAt), d.client?.fullName ?? "", d.title, d.typeRaw])
            }
        }
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
        let items = try context.fetch(descriptor, batchSize: fetchBatchSize)
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
