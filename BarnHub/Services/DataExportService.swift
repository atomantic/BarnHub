import Foundation
import SwiftData

enum CSVExportKind: String, CaseIterable, Sendable {
    case horses, clients, transactions
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

    /// Writes one model type to `writer`, fetching in batches of 500 so memory
    /// stays flat, and throwing `CancellationError` if the task is cancelled.
    /// Dates are `yyyy-MM-dd` in `options.timeZone`; numbers use "." as the
    /// decimal mark regardless of locale, so files re-import anywhere.
    static func export(_ kind: CSVExportKind, from context: ModelContext, to writer: CSVWriter,
                       options: CSVOptions = CSVOptions(), progress: CSVProgressHandler? = nil) throws {
        let dates = CSVDateCodec(options: options)
        switch kind {
        case .horses:
            try writer.writeRow(horsesHeader)
            try paged(FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)]), context, progress) { h in
                try writer.writeRow([h.name, h.breed, dates.string(from: h.dateOfBirth), h.colorMarkings, CSVWriter.number(h.weight),
                                     CSVWriter.number(h.purchasePrice), h.stallNumber, h.medicalNotes, h.feedingSchedule, "\(h.isActive)"])
            }
        case .clients:
            try writer.writeRow(clientsHeader)
            try paged(FetchDescriptor<Client>(sortBy: [SortDescriptor(\.lastName)]), context, progress) { c in
                try writer.writeRow([c.firstName, c.lastName, c.email, c.phone, c.emergencyContact,
                                     c.emergencyPhone, c.notes, "\(c.isActive)"])
            }
        case .transactions:
            try writer.writeRow(transactionsHeader)
            var descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.relationshipKeyPathsForPrefetching = [\.client]
            try paged(descriptor, context, progress) { t in
                try writer.writeRow([dates.string(from: t.date), t.type.rawValue, t.category.rawValue, CSVWriter.number(t.amount),
                                     t.memo, t.client?.fullName ?? "", "\(t.isPaid)"])
            }
        }
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
