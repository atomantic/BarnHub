import Foundation
import SwiftData

/// Reports how far a long-running CSV import or export has got, from 0 to 1.
typealias CSVProgressHandler = @Sendable (Double) -> Void

/// Reports which file an export is writing: step (1-based), step count, kind.
typealias CSVStepHandler = @Sendable (Int, Int, CSVExportKind) -> Void

/// Time zone and locale used to read and write CSV dates and amounts.
/// Captured once per import/export so every row is interpreted the same way,
/// and injectable so tests can run in a non-UTC zone and a European locale.
struct CSVOptions: Sendable {
    var timeZone: TimeZone = .current
    var locale: Locale = .current
    /// Inserted rows are saved in batches of this size.
    var batchSize: Int = 500
}

// MARK: - Dates

/// Reads and writes date-only CSV values.
///
/// Exports always use `yyyy-MM-dd` in the user's time zone, so a transaction
/// entered at 8 PM in California exports as that day rather than the next UTC day.
///
/// Imports accept, in order:
/// 1. ISO 8601 timestamps with a time (`2026-01-15T20:00:00Z`), kept as that instant.
/// 2. Year-first dates: `yyyy-MM-dd`, `yyyy/MM/dd`, `yyyy.MM.dd`.
/// 3. Year-last dates with `/`, `.` or `-` separators and 2- or 4-digit years.
///    Ambiguity rule: when only one of month/day or day/month is a valid date
///    (for example `25/03/2026`, where 25 cannot be a month), that reading wins.
///    When both are valid (`03/04/2026`), the user's region decides: day-first
///    regions (en_GB, de_DE, fr_FR, ...) read dd/MM, all others read MM/dd.
///
/// Date-only values import at 12:00 in the user's time zone, so moving to
/// another time zone later (up to ±11 hours) does not shift them to another day.
struct CSVDateCodec {
    let calendar: Calendar
    let prefersDayFirst: Bool
    private let dayFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let timestampFormatter: ISO8601DateFormatter
    private let fractionalTimestampFormatter: ISO8601DateFormatter

    init(options: CSVOptions = CSVOptions()) {
        let posix = Locale(identifier: "en_US_POSIX")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = options.timeZone
        calendar.locale = posix
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.locale = posix
        formatter.calendar = calendar
        formatter.timeZone = options.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        dayFormatter = formatter

        let time = DateFormatter()
        time.locale = posix
        time.calendar = calendar
        time.timeZone = options.timeZone
        time.dateFormat = "HH:mm"
        timeFormatter = time

        let timestamp = ISO8601DateFormatter()
        timestamp.formatOptions = [.withInternetDateTime]
        timestamp.timeZone = options.timeZone
        timestampFormatter = timestamp
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractional.timeZone = options.timeZone
        fractionalTimestampFormatter = fractional

        let pattern = DateFormatter.dateFormat(fromTemplate: "ddMMyyyy", options: 0, locale: options.locale) ?? "MM/dd/yyyy"
        let dayIndex = pattern.firstIndex(of: "d") ?? pattern.endIndex
        let monthIndex = pattern.firstIndex(of: "M") ?? pattern.endIndex
        prefersDayFirst = dayIndex < monthIndex
    }

    func string(from date: Date) -> String {
        dayFormatter.string(from: date)
    }

    /// 24-hour `HH:mm`, for the time column next to a date-only value.
    func timeString(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    func date(from raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }

        if s.contains("T") {
            return timestampFormatter.date(from: s) ?? fractionalTimestampFormatter.date(from: s)
        }

        let parts = s.split(whereSeparator: { $0 == "/" || $0 == "." || $0 == "-" }).map(String.init)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.count <= 4 && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let a = Int(parts[0]), let b = Int(parts[1]), let c = Int(parts[2]) else { return nil }

        if parts[0].count == 4 {
            return makeDate(year: a, month: b, day: c)
        }
        guard parts[2].count == 4 || parts[2].count == 2 else { return nil }
        let year = parts[2].count == 2 ? expandTwoDigitYear(c) : c

        let monthFirst = makeDate(year: year, month: a, day: b)
        let dayFirst = makeDate(year: year, month: b, day: a)
        return prefersDayFirst ? (dayFirst ?? monthFirst) : (monthFirst ?? dayFirst)
    }

    /// Two-digit years up to ten years ahead of now are this century; the rest are last century.
    private func expandTwoDigitYear(_ yy: Int) -> Int {
        let currentYear = calendar.component(.year, from: .now)
        let century = currentYear / 100 * 100
        return yy <= (currentYear % 100) + 10 ? century + yy : century - 100 + yy
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: components) else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        // Rejects dates that don't exist, such as 31/02, which Calendar would roll over.
        guard back.year == year, back.month == month, back.day == day else { return nil }
        return date
    }
}

// MARK: - Amounts

/// Parses money and other decimal values written by spreadsheets in any common
/// convention: "12.50", "12,50", "1,234.50", "1.234,56", "1'234.50", "€12",
/// "12 kr", "$1,234.50", "-50", "50-", "(50.00)".
///
/// A separator is the decimal mark when it's the last of two different marks,
/// or the only mark and not followed by exactly three digits. "1,234" and
/// "1.234" are genuinely ambiguous; they follow the user's locale (a comma is
/// the decimal mark in de_DE, a grouping mark in en_US). A `NumberFormatter`
/// alone can't do this: in en_US it rejects "€12" and reads "12,50" as 1250.
struct CSVAmountParser {
    let decimalSeparator: Character

    init(options: CSVOptions = CSVOptions()) {
        let formatter = NumberFormatter()
        formatter.locale = options.locale
        formatter.numberStyle = .decimal
        decimalSeparator = formatter.decimalSeparator.first ?? "."
    }

    func parse(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        var negative = false
        if s.hasPrefix("("), s.hasSuffix(")") {
            negative = true
            s = String(s.dropFirst().dropLast())
        }

        // Scientific notation as written by Swift/POSIX ("1e-05").
        if s.contains(where: { $0 == "e" || $0 == "E" }),
           s.allSatisfy({ "0123456789.+-eE".contains($0) }),
           let value = Double(s) {
            return negative ? -abs(value) : value
        }

        var body = ""
        var minusCount = 0
        for ch in s {
            if ch.isASCII, ch.isNumber || ch == "." || ch == "," {
                body.append(ch)
            } else if ch == "-" || ch == "\u{2212}" {
                minusCount += 1
            }
            // Everything else (currency symbols and codes, spaces, NBSP, apostrophes) is ignored.
        }
        guard minusCount <= 1, body.contains(where: \.isNumber) else { return nil }
        if minusCount == 1 { negative = true }

        guard let normalized = normalizeSeparators(body), let value = Double(normalized) else { return nil }
        return negative ? -value : value
    }

    private func normalizeSeparators(_ body: String) -> String? {
        let dots = body.filter { $0 == "." }.count
        let commas = body.filter { $0 == "," }.count

        let decimal: Character?
        if dots > 0, commas > 0 {
            decimal = body.lastIndex(of: ".")! > body.lastIndex(of: ",")! ? "." : ","
        } else if dots + commas == 0 {
            decimal = nil
        } else {
            let mark: Character = dots > 0 ? "." : ","
            if dots + commas > 1 {
                decimal = nil
            } else {
                let idx = body.firstIndex(of: mark)!
                let integerPart = body[..<idx]
                let fractionDigits = body.distance(from: body.index(after: idx), to: body.endIndex)
                let canBeGrouping = fractionDigits == 3
                    && !integerPart.isEmpty
                    && integerPart.count <= 3
                    && !integerPart.allSatisfy({ $0 == "0" })
                decimal = (!canBeGrouping || mark == decimalSeparator) ? mark : nil
            }
        }

        guard let decimal else {
            return body.filter(\.isNumber)
        }
        guard body.filter({ $0 == decimal }).count == 1 else { return nil }
        let grouping: Character = decimal == "." ? "," : "."
        let parts = body.split(separator: decimal, omittingEmptySubsequences: false)
        // A grouping mark after the decimal mark ("1.234,5.6") is not a number.
        guard parts.count == 2, !parts[1].contains(grouping) else { return nil }
        let integer = parts[0].filter(\.isNumber)
        return "\(integer.isEmpty ? "0" : integer).\(parts[1])"
    }
}

// MARK: - Streaming CSV reader

/// Reads RFC 4180 CSV from a file in 64 KB chunks, one row at a time, so large
/// imports never hold the whole file (or an `Array` of its characters) in memory.
/// Quoted fields may contain commas, doubled quotes and line breaks.
/// Fully blank lines are skipped. A leading UTF-8 BOM is ignored. Fields that
/// aren't valid UTF-8 are decoded as Windows-1252, which older Excel exports use.
final class CSVReader {
    private static let chunkSize = 64 * 1024
    private static let quote = UInt8(ascii: "\"")
    private static let comma = UInt8(ascii: ",")
    private static let cr = UInt8(ascii: "\r")
    private static let lf = UInt8(ascii: "\n")

    private let handle: FileHandle?
    private var buffer: [UInt8]
    private var index = 0
    private var consumed: Int64 = 0
    private var reachedEnd: Bool
    let totalBytes: Int64
    /// True when the row just returned ended inside an unterminated quoted field.
    private(set) var lastRowUnterminated = false

    init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        totalBytes = size ?? 0
        buffer = []
        reachedEnd = false
        skipBOM()
    }

    init(string: String) {
        handle = nil
        buffer = Array(string.utf8)
        totalBytes = Int64(buffer.count)
        reachedEnd = true
        skipBOM()
    }

    deinit {
        try? handle?.close()
    }

    var fractionRead: Double {
        guard totalBytes > 0 else { return 1 }
        return min(1, Double(consumed + Int64(index)) / Double(totalBytes))
    }

    private func skipBOM() {
        if peek() == 0xEF, buffer.count >= index + 3, buffer[index + 1] == 0xBB, buffer[index + 2] == 0xBF {
            index += 3
        }
    }

    private func refill() -> Bool {
        guard !reachedEnd, let handle else { return false }
        consumed += Int64(buffer.count)
        index = 0
        if let data = try? handle.read(upToCount: Self.chunkSize), !data.isEmpty {
            buffer = Array(data)
            return true
        }
        buffer = []
        reachedEnd = true
        return false
    }

    private func peek() -> UInt8? {
        if index >= buffer.count, !refill() { return nil }
        return buffer[index]
    }

    private func next() -> UInt8? {
        guard let byte = peek() else { return nil }
        index += 1
        return byte
    }

    private static func decode(_ bytes: [UInt8]) -> String {
        if bytes.allSatisfy({ $0 < 0x80 }) { return String(decoding: bytes, as: UTF8.self) }
        return String(bytes: bytes, encoding: .utf8)
            ?? String(bytes: bytes, encoding: .windowsCP1252)
            ?? String(decoding: bytes, as: UTF8.self)
    }

    /// The next non-blank row, or nil at end of file.
    func nextRow() -> [String]? {
        while true {
            guard peek() != nil else { return nil }
            var row: [String] = []
            var field: [UInt8] = []
            var inQuotes = false
            lastRowUnterminated = false

            rowLoop: while true {
                guard let byte = next() else {
                    lastRowUnterminated = inQuotes
                    row.append(Self.decode(field))
                    break rowLoop
                }
                if inQuotes {
                    if byte == Self.quote {
                        if peek() == Self.quote {
                            field.append(Self.quote)
                            index += 1
                        } else {
                            inQuotes = false
                        }
                    } else {
                        field.append(byte)
                    }
                } else if byte == Self.quote {
                    inQuotes = true
                } else if byte == Self.comma {
                    row.append(Self.decode(field))
                    field.removeAll(keepingCapacity: true)
                } else if byte == Self.lf || byte == Self.cr {
                    if byte == Self.cr, peek() == Self.lf { index += 1 }
                    row.append(Self.decode(field))
                    break rowLoop
                } else {
                    field.append(byte)
                }
            }

            if !row.allSatisfy({ $0.isEmpty }) { return row }
        }
    }
}

// MARK: - Import

struct DataImportService {

    enum SkipReason: String, CaseIterable, Sendable {
        case missingName, missingFirstName, missingAmount, invalidAmount, invalidDate, malformedRow

        var label: String {
            switch self {
            case .missingName: return appLocalized("Missing name", comment: "CSV import skip reason")
            case .missingFirstName: return appLocalized("Missing first name", comment: "CSV import skip reason")
            case .missingAmount: return appLocalized("Missing or zero amount", comment: "CSV import skip reason")
            case .invalidAmount: return appLocalized("Unrecognized amount", comment: "CSV import skip reason")
            case .invalidDate: return appLocalized("Unrecognized date", comment: "CSV import skip reason")
            case .malformedRow: return appLocalized("Malformed row", comment: "CSV import skip reason: unterminated quote or extra columns")
            }
        }
    }

    struct ImportResult: Sendable, Equatable {
        /// Rows saved to the store.
        var imported = 0
        /// Rows identical to a record that already existed before the import.
        var duplicates = 0
        var skipReasons: [SkipReason: Int] = [:]
        var errors: [String] = []
        /// The user cancelled; rows from batches saved before that are kept.
        var cancelled = false

        /// Rows skipped because they were invalid (duplicates are counted separately).
        var skipped: Int { skipReasons.values.reduce(0, +) }

        init(imported: Int = 0, duplicates: Int = 0, skipReasons: [SkipReason: Int] = [:], errors: [String] = [], cancelled: Bool = false) {
            self.imported = imported
            self.duplicates = duplicates
            self.skipReasons = skipReasons
            self.errors = errors
            self.cancelled = cancelled
        }
    }

    private enum RowOutcome {
        case inserted, duplicate, skipped(SkipReason)
    }

    private struct HeaderError: Error {
        let message: String
    }

    /// One CSV row with lookups by (lowercased) header name.
    private struct Row {
        let fields: [String]
        let columns: [String: Int]

        /// Trimmed, non-empty text for the first matching column. A leading
        /// apostrophe that our exporter adds to neutralize spreadsheet formulas
        /// ("'=SUM(A1)", "'+1 555 0100") is removed again.
        func text(_ names: String...) -> String? {
            for name in names {
                guard let idx = columns[name], idx < fields.count else { continue }
                var value = fields[idx].trimmingCharacters(in: .whitespaces)
                if value.count > 1, value.first == "'",
                   let second = value.dropFirst().first, CSVFormulaGuard.triggers.contains(second) {
                    value.removeFirst()
                }
                if !value.isEmpty { return value }
            }
            return nil
        }

        func bool(_ name: String) -> Bool? {
            guard let str = text(name)?.lowercased() else { return nil }
            return ["true", "yes", "1"].contains(str)
        }
    }

    // MARK: Engine

    /// Reads the header, then hands each row to `process`, saving every
    /// `options.batchSize` inserts and stopping early when the task is cancelled.
    private static func run(
        reader: CSVReader,
        context: ModelContext,
        options: CSVOptions,
        progress: CSVProgressHandler?,
        prepare: ([String: Int]) throws -> (Row) -> RowOutcome
    ) throws -> ImportResult {
        guard let header = reader.nextRow() else {
            return ImportResult(errors: [appLocalized("Empty file", comment: "Import error")])
        }
        var columns: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            let key = name.lowercased().trimmingCharacters(in: .whitespaces)
            if columns[key] == nil { columns[key] = i }
        }

        let process: (Row) -> RowOutcome
        do {
            process = try prepare(columns)
        } catch let error as HeaderError {
            return ImportResult(errors: [error.message])
        }

        var result = ImportResult()
        var pending = 0
        var rowNumber = 0
        let batchSize = max(1, options.batchSize)

        while let fields = reader.nextRow() {
            if Task.isCancelled {
                context.rollback()
                result.cancelled = true
                break
            }
            rowNumber += 1

            let extra = fields.count > header.count && fields[header.count...].contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let outcome: RowOutcome = (reader.lastRowUnterminated || extra)
                ? .skipped(.malformedRow)
                : process(Row(fields: fields, columns: columns))

            switch outcome {
            case .inserted:
                pending += 1
                if pending >= batchSize {
                    try context.save()
                    result.imported += pending
                    pending = 0
                }
            case .duplicate:
                result.duplicates += 1
            case .skipped(let reason):
                result.skipReasons[reason, default: 0] += 1
            }

            if rowNumber % 100 == 0 { progress?(reader.fractionRead) }
        }

        if !result.cancelled, pending > 0 {
            try context.save()
            result.imported += pending
        }
        progress?(1)
        return result
    }

    // MARK: Duplicate keys

    /// Horses match on name, breed and birth date (day in the user's time zone).
    static func horseKey(name: String, breed: String, day: String) -> String {
        [name, breed, day].map { $0.lowercased() }.joined(separator: "\u{1F}")
    }

    /// Clients match on full name and email.
    static func clientKey(firstName: String, lastName: String, email: String) -> String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return [fullName, email].map { $0.lowercased() }.joined(separator: "\u{1F}")
    }

    /// Transactions match on day, type, category, amount (to the cent), memo and client name.
    static func transactionKey(day: String, type: TransactionType, category: TransactionCategory, amount: Double, memo: String, clientName: String) -> String {
        let cents = Int((amount * 100).rounded())
        return [day, type.rawValue, category.rawValue, String(cents), memo.lowercased(), clientName.lowercased()]
            .joined(separator: "\u{1F}")
    }

    // MARK: Horses

    /// Lowercased gender text to gender: the stored raw value ("gelding") plus the
    /// display name in the app language and in every bundled translation, so a
    /// file edited by hand ("Wallach", "Hongre") still imports. Older files have
    /// no Gender column, and blank or unknown values keep the model default (mare).
    static func horseGenderLookup() -> [String: HorseGender] {
        let bundles = Bundle.main.localizations.compactMap { language in
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        var lookup: [String: HorseGender] = [:]
        for gender in HorseGender.allCases {
            // The string catalog key is the English display name ("Mare").
            let english = gender.rawValue.capitalized
            var names = [gender.rawValue, gender.displayName, english]
            names += bundles.map { $0.localizedString(forKey: english, value: nil, table: nil) }
            for name in names {
                let key = name.lowercased().trimmingCharacters(in: .whitespaces)
                if !key.isEmpty, lookup[key] == nil { lookup[key] = gender }
            }
        }
        return lookup
    }

    static func importHorses(reader: CSVReader, context: ModelContext, options: CSVOptions = CSVOptions(), progress: CSVProgressHandler? = nil) throws -> ImportResult {
        let dates = CSVDateCodec(options: options)
        let numbers = CSVAmountParser(options: options)
        let result = try run(reader: reader, context: context, options: options, progress: progress) { columns in
            guard columns["name"] != nil else {
                throw HeaderError(message: appLocalized("Missing required column: Name", comment: "Import error"))
            }
            let existing = try context.fetch(FetchDescriptor<Horse>())
            var fullKeys = Set<String>()
            var nameBreedKeys = Set<String>()
            for horse in existing {
                fullKeys.insert(horseKey(name: horse.name, breed: horse.breed, day: dates.string(from: horse.dateOfBirth)))
                nameBreedKeys.insert(horseKey(name: horse.name, breed: horse.breed, day: ""))
            }
            let genders = horseGenderLookup()

            return { row in
                guard let name = row.text("name") else { return .skipped(.missingName) }
                let breed = row.text("breed") ?? ""

                var dob: Date?
                if let raw = row.text("date of birth", "dob") {
                    guard let parsed = dates.date(from: raw) else { return .skipped(.invalidDate) }
                    dob = parsed
                }
                // Without a birth date in the file, name + breed is the best key we have.
                let key = horseKey(name: name, breed: breed, day: dob.map(dates.string(from:)) ?? "")
                if dob == nil ? nameBreedKeys.contains(key) : fullKeys.contains(key) { return .duplicate }

                var weight: Double?
                if let raw = row.text("weight", "weight (lbs)") {
                    guard let parsed = numbers.parse(raw) else { return .skipped(.invalidAmount) }
                    weight = parsed
                }
                var price: Double?
                if let raw = row.text("purchase price") {
                    guard let parsed = numbers.parse(raw) else { return .skipped(.invalidAmount) }
                    price = parsed
                }

                let horse = Horse(name: name, breed: breed)
                horse.colorMarkings = row.text("color/markings", "color") ?? ""
                horse.stallNumber = row.text("stall", "stall number") ?? ""
                horse.medicalNotes = row.text("medical notes") ?? ""
                horse.feedingSchedule = row.text("feeding schedule") ?? ""
                if let weight { horse.weight = weight }
                if let price { horse.purchasePrice = price }
                if let dob { horse.dateOfBirth = dob }
                if let active = row.bool("active") { horse.isActive = active }
                if let raw = row.text("gender", "sex"), let gender = genders[raw.lowercased()] { horse.gender = gender }
                context.insert(horse)
                return .inserted
            }
        }
        BarnHubLogger.success("Imported \(result.imported) horses, skipped \(result.skipped), duplicates \(result.duplicates)")
        return result
    }

    // MARK: Clients

    static func importClients(reader: CSVReader, context: ModelContext, options: CSVOptions = CSVOptions(), progress: CSVProgressHandler? = nil) throws -> ImportResult {
        let result = try run(reader: reader, context: context, options: options, progress: progress) { columns in
            let hasFirst = columns["first name"] != nil
            guard hasFirst || columns["name"] != nil else {
                throw HeaderError(message: appLocalized("Missing required column: First Name or Name", comment: "Import error"))
            }
            let existing = try context.fetch(FetchDescriptor<Client>())
            let existingKeys = Set(existing.map { clientKey(firstName: $0.firstName, lastName: $0.lastName, email: $0.email) })

            return { row in
                var firstName = ""
                var lastName = ""
                if hasFirst {
                    firstName = row.text("first name") ?? ""
                    lastName = row.text("last name") ?? ""
                } else if let full = row.text("name") {
                    let parts = full.split(separator: " ", maxSplits: 1)
                    firstName = String(parts.first ?? "")
                    lastName = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
                }
                guard !firstName.isEmpty else { return .skipped(hasFirst ? .missingFirstName : .missingName) }

                let email = row.text("email") ?? ""
                if existingKeys.contains(clientKey(firstName: firstName, lastName: lastName, email: email)) {
                    return .duplicate
                }

                let client = Client(firstName: firstName, lastName: lastName)
                client.email = email
                client.phone = row.text("phone") ?? ""
                client.emergencyContact = row.text("emergency contact") ?? ""
                client.emergencyPhone = row.text("emergency phone") ?? ""
                client.notes = row.text("notes") ?? ""
                if let active = row.bool("active") { client.isActive = active }
                context.insert(client)
                return .inserted
            }
        }
        BarnHubLogger.success("Imported \(result.imported) clients, skipped \(result.skipped), duplicates \(result.duplicates)")
        return result
    }

    // MARK: Transactions

    /// Amounts are stored positive with a type. A negative amount flips the
    /// row's type (a negative "income" is money out, a negative "expense" is a
    /// refund); a negative amount with no type is an expense. Rows with a zero
    /// or missing amount are skipped.
    static func importTransactions(reader: CSVReader, context: ModelContext, options: CSVOptions = CSVOptions(), progress: CSVProgressHandler? = nil) throws -> ImportResult {
        let dates = CSVDateCodec(options: options)
        let numbers = CSVAmountParser(options: options)
        let result = try run(reader: reader, context: context, options: options, progress: progress) { columns in
            guard columns["amount"] != nil else {
                throw HeaderError(message: appLocalized("Missing required column: Amount", comment: "Import error"))
            }

            var clientsByName: [String: Client] = [:]
            for client in try context.fetch(FetchDescriptor<Client>()) {
                let key = client.fullName.lowercased()
                if clientsByName[key] == nil { clientsByName[key] = client }
            }

            var descriptor = FetchDescriptor<Transaction>()
            descriptor.relationshipKeyPathsForPrefetching = [\.client]
            var existingKeys = Set<String>()
            for txn in try context.fetch(descriptor) {
                existingKeys.insert(transactionKey(
                    day: dates.string(from: txn.date), type: txn.type, category: txn.category,
                    amount: txn.amount, memo: txn.memo, clientName: txn.client?.fullName ?? ""))
            }

            return { row in
                guard let rawAmount = row.text("amount") else { return .skipped(.missingAmount) }
                guard let signed = numbers.parse(rawAmount) else { return .skipped(.invalidAmount) }
                guard signed != 0 else { return .skipped(.missingAmount) }

                var date = Date.now
                if let raw = row.text("date") {
                    guard let parsed = dates.date(from: raw) else { return .skipped(.invalidDate) }
                    date = parsed
                }

                let explicitType = row.text("type").flatMap { raw in TransactionType.allCases.first { $0.rawValue.lowercased() == raw.lowercased() } }
                var type = explicitType ?? .expense
                if signed < 0, explicitType != nil {
                    type = type == .income ? .expense : .income
                }
                let amount = abs(signed)
                // Case-insensitive, so the exported camelCase "vetBill" reads back as Vet Bill, not Other.
                let category = row.text("category").flatMap { raw in TransactionCategory.allCases.first { $0.rawValue.lowercased() == raw.lowercased() } } ?? .other
                let memo = row.text("memo", "description") ?? ""
                let clientName = row.text("client") ?? ""
                let client = clientName.isEmpty ? nil : clientsByName[clientName.lowercased()]

                let key = transactionKey(day: dates.string(from: date), type: type, category: category,
                                         amount: amount, memo: memo, clientName: client?.fullName ?? "")
                if existingKeys.contains(key) { return .duplicate }

                let txn = Transaction(amount: amount, date: date, memo: memo, category: category, type: type,
                                      isPaid: row.bool("paid") ?? false)
                context.insert(txn)
                txn.client = client
                return .inserted
            }
        }
        BarnHubLogger.success("Imported \(result.imported) transactions, skipped \(result.skipped), duplicates \(result.duplicates)")
        return result
    }

    // MARK: String conveniences (tests and small inputs)

    static func importHorses(from csvString: String, context: ModelContext, options: CSVOptions = CSVOptions()) -> ImportResult {
        do {
            return try importHorses(reader: CSVReader(string: csvString), context: context, options: options)
        } catch {
            return ImportResult(errors: [error.localizedDescription])
        }
    }

    static func importClients(from csvString: String, context: ModelContext, options: CSVOptions = CSVOptions()) -> ImportResult {
        do {
            return try importClients(reader: CSVReader(string: csvString), context: context, options: options)
        } catch {
            return ImportResult(errors: [error.localizedDescription])
        }
    }

    static func importTransactions(from csvString: String, context: ModelContext, options: CSVOptions = CSVOptions()) throws -> ImportResult {
        try importTransactions(reader: CSVReader(string: csvString), context: context, options: options)
    }
}

// MARK: - Background actor

/// Runs CSV import and export on its own `ModelContext`, off the main actor.
///
/// Create it from a detached task, not on the main thread: on iOS 17 a
/// `@ModelActor` initialized on the main thread can end up executing there.
@ModelActor
actor CSVDataActor {
    func importCSV(_ type: ImportDataType, from url: URL, options: CSVOptions, progress: CSVProgressHandler?) throws -> DataImportService.ImportResult {
        let reader = try CSVReader(url: url)
        switch type {
        case .horses:
            return try DataImportService.importHorses(reader: reader, context: modelContext, options: options, progress: progress)
        case .clients:
            return try DataImportService.importClients(reader: reader, context: modelContext, options: options, progress: progress)
        case .transactions:
            return try DataImportService.importTransactions(reader: reader, context: modelContext, options: options, progress: progress)
        }
    }

    /// Writes each kind to `<directory>/<filePrefix><kind>.csv` and returns the file URLs.
    /// With a `bundle`, the files get ID columns and the records' files are
    /// copied into the bundle's subfolders. `step` is told which file is being
    /// written (1-based). Throws `CancellationError` (after removing partial
    /// files) when cancelled.
    func export(_ kinds: [CSVExportKind], to directory: URL, filePrefix: String = "", options: CSVOptions,
                bundle: CSVExportBundle? = nil, progress: CSVProgressHandler?, step: CSVStepHandler? = nil) throws -> [URL] {
        var urls: [URL] = []
        // Kinds that copy files take longer, so they get a bigger share of the bar.
        let weights = kinds.map { bundle != nil && Self.copiesFiles($0) ? 4.0 : 1.0 }
        let totalWeight = weights.reduce(0, +)
        var done = 0.0
        do {
            for (i, kind) in kinds.enumerated() {
                try Task.checkCancellation()
                step?(i + 1, kinds.count, kind)
                let url = directory.appendingPathComponent("\(filePrefix)\(kind.rawValue).csv")
                urls.append(url)
                let writer = try CSVWriter(url: url)
                let base = done
                let weight = weights[i]
                try DataExportService.export(kind, from: modelContext, to: writer, options: options, bundle: bundle) { fraction in
                    progress?((base + fraction * weight) / totalWeight)
                }
                try writer.finish()
                done += weight
            }
        } catch {
            for url in urls { try? FileManager.default.removeItem(at: url) }
            throw error
        }
        progress?(1)
        return urls
    }

    /// Name of the folder an "All Data" export shares.
    static let allDataFolderName = "BarnHub Export"

    /// Writes every kind, with IDs and the records' photos, documents and
    /// invoice PDFs, to a new `tmp/BarnHubShare/<UUID>/BarnHub Export/` folder
    /// and returns it. On any error, cancellation included, the whole share
    /// folder is deleted before rethrowing.
    func exportAllData(options: CSVOptions, progress: CSVProgressHandler?, step: CSVStepHandler? = nil) throws -> URL {
        let shareFolder = try ShareTempFiles.makeShareFolder()
        do {
            let directory = shareFolder.appendingPathComponent(Self.allDataFolderName, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let bundle = CSVExportBundle(root: directory, container: modelContainer)
            _ = try export(CSVExportKind.allCases, to: directory, options: options, bundle: bundle, progress: progress, step: step)
            BarnHubLogger.info("All Data export wrote files=\(bundle.filesWritten)")
            return directory
        } catch {
            ShareTempFiles.discardShareFolder(shareFolder)
            throw error
        }
    }

    private static func copiesFiles(_ kind: CSVExportKind) -> Bool {
        !DataExportService.bundleExtras(for: kind).filter { $0 == "Photo" || $0 == "File" }.isEmpty
    }
}
