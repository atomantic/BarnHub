import Foundation
import SwiftData

/// Restores a "BarnHub Export" folder written by All Data: every CSV, plus the
/// photos, documents and invoice PDFs its `Photo` and `File` columns point at.
///
/// **Links.** The `ID`, `Horse ID`, `Client ID` and `Product ID` columns are
/// only meaningful inside one export, so the restore keeps a map from each
/// horse, client and feed product's export ID to the record it inserted (or
/// matched) and resolves links through it. Two same-named horses stay distinct.
/// Nothing is stored on the models, so this needs no schema change.
///
/// **Duplicates.** A row that matches a record already in the store is skipped
/// and the existing record is left unchanged (records that link to it are
/// attached to it). Horses and clients match as in the single-file import
/// (name, breed and birth date; full name and email), feed products on name
/// and brand; other records match on their owner's key plus the fields that
/// identify them (see `DataRestoreService.Restorer`). Each existing record can
/// be matched once, so restoring the same folder twice adds nothing, while an
/// export with two identical rows still restores both into an empty store.
///
/// **Cancel and errors.** Rows are saved in batches (500 rows, or about 32 MB
/// of files) through a fresh `ModelContext` per batch, so photos and PDFs
/// don't pile up in memory. Every record the restore inserts, and every
/// horse/client link it adds between existing records, is remembered; on
/// cancel or any error those are deleted (restored owners first, so their
/// history goes with them by cascade) and the links removed, so the store is
/// back to where it started.
enum DataRestoreService {
    struct Result: Sendable, Equatable {
        /// Records (and horse-client links) added.
        var imported = 0
        /// Rows that matched a record already in BarnHub.
        var duplicates = 0
        var skipReasons: [DataImportService.SkipReason: Int] = [:]
        /// Photos, documents and invoice PDFs read from the folder.
        var filesRestored = 0
        /// `Photo` / `File` paths that weren't in the folder (or were unsafe).
        var filesMissing = 0

        var skipped: Int { skipReasons.values.reduce(0, +) }
    }

    enum RestoreError: LocalizedError, Equatable {
        case notAnExport

        var errorDescription: String? {
            appLocalized("This folder isn't a BarnHub All Data export. Choose the BarnHub Export folder that All Data saved.",
                         comment: "Restore All Data error: the picked folder has no All Data files")
        }
    }

    /// Files in the order they're read: owners before the records linking to them.
    static let order: [CSVExportKind] = [
        .horses, .clients, .feedProducts, .horseClients, .transactions,
        .vetRecords, .farrierVisits, .dentistVisits, .weightEntries, .feedPlan,
        .reminders, .lessons, .barnNotes, .supplies, .invoices, .horseDocuments, .clientDocuments,
    ]

    /// The export folder itself, or its "BarnHub Export" subfolder when the user
    /// picked the folder around it. Throws `notAnExport` when neither holds an
    /// All Data `horses.csv` (one whose first column is "ID").
    static func exportRoot(for folder: URL) throws -> URL {
        let candidates = [folder, folder.appendingPathComponent(CSVDataActor.allDataFolderName, isDirectory: true)]
        for candidate in candidates {
            let url = candidate.appendingPathComponent("\(CSVExportKind.horses.rawValue).csv")
            guard let reader = try? CSVReader(url: coordinated(url)), let header = reader.nextRow() else { continue }
            if header.first?.trimmingCharacters(in: .whitespaces).lowercased() == "id" { return candidate }
        }
        throw RestoreError.notAnExport
    }

    /// Asks the file system to make `url` available locally (an iCloud Drive
    /// file that isn't downloaded yet) before it's read.
    static func coordinated(_ url: URL) -> URL {
        var resolved = url
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &error) { resolved = $0 }
        return resolved
    }

    // MARK: - Restorer

    /// One restore run. Not thread-safe: create and use it on one actor.
    final class Restorer {
        private static let bytesPerSave = 32 * 1024 * 1024

        /// Rows per save (`CSVOptions.batchSize`, 500 by default).
        private let rowsPerSave: Int

        private let root: URL
        private let container: ModelContainer
        private let dates: CSVDateCodec
        private let numbers: CSVAmountParser
        private var context: ModelContext
        private(set) var result = Result()

        /// A saved record this restore inserted, with how to delete it again.
        private struct Inserted {
            let id: PersistentIdentifier
            let isOwner: Bool
            /// Deletes the record if it still exists (a cascade may have removed it).
            let delete: (ModelContext) -> Void
        }

        /// Inserted into `context` but not saved yet: the model, and how to
        /// make its `Inserted` entry once its ID is permanent.
        private var unsaved: [(model: any PersistentModel, saved: () -> Inserted)] = []
        /// Unsaved horses, clients and products with their export IDs; their
        /// permanent IDs are recorded once saved.
        private var unsavedOwners: [(exportID: String, model: any PersistentModel)] = []
        private var pendingBytes = 0
        /// Saved records this restore inserted, in insert order.
        private var inserted: [Inserted] = []
        private var insertedSet: Set<PersistentIdentifier> = []
        /// Horse/client links added between records that existed before.
        private var addedLinks: [(horse: PersistentIdentifier, client: PersistentIdentifier)] = []
        /// Export ID ("horse-3") to the record it was restored as or matched to.
        private var owners: [String: PersistentIdentifier] = [:]
        /// Export ID to the owner's duplicate key, from the export's own row.
        private var ownerKeys: [String: String] = [:]

        init(root: URL, container: ModelContainer, options: CSVOptions) {
            self.root = root
            self.container = container
            dates = CSVDateCodec(options: options)
            numbers = CSVAmountParser(options: options)
            rowsPerSave = max(1, options.batchSize)
            context = Self.makeContext(container)
        }

        private static func makeContext(_ container: ModelContainer) -> ModelContext {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            return context
        }

        /// Restores every file in `order`. On cancel or error, removes what it
        /// added and rethrows.
        func run(progress: CSVProgressHandler?, step: CSVStepHandler?) throws -> Result {
            let kinds = DataRestoreService.order
            // Files with photos or documents take longer, as in the export.
            let weights = kinds.map { kind in DataExportService.bundleExtras(for: kind).contains { $0 == "Photo" || $0 == "File" } ? 4.0 : 1.0 }
            let total = weights.reduce(0, +)
            var done = 0.0
            do {
                for (i, kind) in kinds.enumerated() {
                    try Task.checkCancellation()
                    step?(i + 1, kinds.count, kind)
                    let base = done
                    try restore(kind) { fraction in progress?((base + fraction * weights[i]) / total) }
                    done += weights[i]
                }
                try save()
            } catch {
                undo()
                throw error
            }
            progress?(1)
            BarnHubLogger.success("Restored All Data imported=\(result.imported) duplicates=\(result.duplicates) skipped=\(result.skipped) files=\(result.filesRestored) missingFiles=\(result.filesMissing)")
            return result
        }

        // MARK: Rows

        private enum Outcome {
            case inserted, duplicate, skipped(DataImportService.SkipReason)
        }

        /// Reads `kind`'s file row by row (a missing file restores nothing),
        /// then saves, so the next file can link to these records.
        private func each(_ kind: CSVExportKind, progress: (Double) -> Void,
                          _ body: (DataImportService.Row) throws -> Outcome) throws {
            let url = root.appendingPathComponent("\(kind.rawValue).csv")
            guard FileManager.default.fileExists(atPath: url.path) else {
                BarnHubLogger.warning("Restore: no \(kind.rawValue).csv in folder")
                return
            }
            let reader = try CSVReader(url: DataRestoreService.coordinated(url))
            guard let header = reader.nextRow() else { return }
            let columns = DataImportService.columnIndex(header)
            var rowNumber = 0
            while let fields = reader.nextRow() {
                try Task.checkCancellation()
                rowNumber += 1
                let outcome: Outcome = try autoreleasepool {
                    if DataImportService.isMalformed(fields, header: header, reader: reader) { return .skipped(.malformedRow) }
                    return try body(DataImportService.Row(fields: fields, columns: columns))
                }
                switch outcome {
                case .inserted: result.imported += 1
                case .duplicate: result.duplicates += 1
                case .skipped(let reason): result.skipReasons[reason, default: 0] += 1
                }
                if unsaved.count >= rowsPerSave || pendingBytes >= Self.bytesPerSave { try save() }
                if rowNumber % 50 == 0 { progress(reader.fractionRead) }
            }
            try save()
            progress(1)
        }

        private func insert<T: PersistentModel>(_ model: T, exportID: String? = nil, bytes: Int = 0) {
            context.insert(model)
            let isOwner = exportID != nil
            unsaved.append((model, {
                let id = model.persistentModelID
                return Inserted(id: id, isOwner: isOwner) { context in
                    if let existing: T = context.existingModel(for: id) { context.delete(existing) }
                }
            }))
            if let exportID { unsavedOwners.append((exportID, model)) }
            pendingBytes += bytes
        }

        /// Saves the batch, records the inserted records' permanent IDs, and
        /// starts a fresh context so saved photos and PDFs can be released.
        private func save() throws {
            guard context.hasChanges else { return }
            try context.save()
            for (_, saved) in unsaved {
                let record = saved()
                inserted.append(record)
                insertedSet.insert(record.id)
            }
            for (exportID, model) in unsavedOwners { owners[exportID] = model.persistentModelID }
            unsaved.removeAll()
            unsavedOwners.removeAll()
            pendingBytes = 0
            context = Self.makeContext(container)
        }

        /// Deletes what this restore saved and removes the links it added.
        /// The restored horses, clients and feed products go first, so their
        /// history goes with them by cascade instead of one record at a time
        /// (deleting a child while its owner lives rewrites the owner's list,
        /// which gets slow with thousands of rows). Records that hang off
        /// existing owners, or none, are deleted after that.
        private func undo() {
            context.rollback()
            var cleanup = Self.makeContext(container)
            do {
                for link in addedLinks {
                    guard let horse: Horse = cleanup.existingModel(for: link.horse) else { continue }
                    horse.clients?.removeAll { $0.persistentModelID == link.client }
                }
                for record in inserted where record.isOwner { record.delete(cleanup) }
                try cleanup.save()
                for (i, record) in inserted.reversed().filter({ !$0.isOwner }).enumerated() {
                    record.delete(cleanup)
                    if i % rowsPerSave == rowsPerSave - 1 {
                        try cleanup.save()
                        cleanup = Self.makeContext(container)
                    }
                }
                try cleanup.save()
                BarnHubLogger.info("Restore rolled back records=\(inserted.count) links=\(addedLinks.count)")
            } catch {
                BarnHubLogger.error("Restore rollback failed error=\(error.localizedDescription)")
            }
            inserted.removeAll()
            addedLinks.removeAll()
        }

        // MARK: Lookups

        private func owner<T: PersistentModel>(_ exportID: String?, as _: T.Type) -> T? {
            guard let exportID, let id = owners[exportID] else { return nil }
            return context.model(for: id) as? T
        }

        private func ownerKey(_ exportID: String?) -> String {
            exportID.flatMap { ownerKeys[$0] } ?? ""
        }

        private func key(_ parts: String...) -> String {
            parts.map { $0.lowercased() }.joined(separator: "\u{1F}")
        }

        private func day(_ date: Date?) -> String { date.map(dates.string(from:)) ?? "" }
        private func number(_ value: Double) -> String { CSVWriter.number(value) }

        private func horseKey(_ horse: Horse?) -> String {
            guard let horse else { return "" }
            return DataImportService.horseKey(name: horse.name, breed: horse.breed, day: day(horse.dateOfBirth))
        }

        private func clientKey(_ client: Client?) -> String {
            guard let client else { return "" }
            return DataImportService.clientKey(firstName: client.firstName, lastName: client.lastName, email: client.email)
        }

        private func productKey(name: String, brand: String) -> String { key(name, brand) }

        /// Every exported field, to tell apart existing records that share a
        /// duplicate key (two Jane Does with one email but different phones).
        private func signature(_ horse: Horse) -> String {
            key(horse.name, horse.breed, day(horse.dateOfBirth), horse.colorMarkings, number(horse.weight),
                number(horse.purchasePrice), horse.stallNumber, horse.medicalNotes, horse.feedingSchedule,
                "\(horse.isActive)", horse.genderRaw)
        }

        private func signature(_ client: Client) -> String {
            key(client.firstName, client.lastName, client.email, client.phone, client.emergencyContact,
                client.emergencyPhone, client.notes, "\(client.isActive)")
        }

        private func signature(_ product: FeedProduct) -> String {
            key(product.name, product.brand, product.defaultUnitRaw, product.notes)
        }

        /// Unclaimed existing records by duplicate key, each with its signature.
        private typealias Candidates = [String: [(id: PersistentIdentifier, signature: String)]]

        /// Existing records of `T` grouped by duplicate key, read through a
        /// throwaway context (unbatched: batched fetches lose relationships
        /// before iOS 27, #69).
        private func existingRecords<T: PersistentModel>(_: T.Type, signature: (T) -> String = { _ in "" },
                                                         _ keyOf: (T) -> String) throws -> Candidates {
            let scratch = ModelContext(container)
            var map: Candidates = [:]
            for model in try scratch.fetch(FetchDescriptor<T>()) {
                map[keyOf(model), default: []].append((model.persistentModelID, signature(model)))
            }
            return map
        }

        /// Takes one unclaimed existing record with `key`, preferring one whose
        /// signature matches too. Each existing record is matched at most once.
        private func claim(_ key: String, signature: String = "", in map: inout Candidates) -> PersistentIdentifier? {
            guard var candidates = map[key], !candidates.isEmpty else { return nil }
            let index = candidates.firstIndex { $0.signature == signature } ?? candidates.startIndex
            let id = candidates.remove(at: index).id
            map[key] = candidates
            return id
        }

        // MARK: Values

        private struct Skip: Error { let reason: DataImportService.SkipReason }

        private func parseDate(_ row: DataImportService.Row, _ names: String...) throws -> Date? {
            for name in names {
                guard let raw = row.text(name) else { continue }
                guard let parsed = dates.date(from: raw) else { throw Skip(reason: .invalidDate) }
                return parsed
            }
            return nil
        }

        /// A day column plus its "HH:mm" time column, in the export's time zone.
        private func dateTime(_ row: DataImportService.Row, day dayColumn: String, time timeColumn: String) throws -> Date? {
            guard let day = try parseDate(row, dayColumn) else { return nil }
            let parts = (row.text(timeColumn) ?? "").split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return day }
            return dates.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) ?? day
        }

        private func double(_ row: DataImportService.Row, _ name: String) throws -> Double? {
            guard let raw = row.text(name) else { return nil }
            guard let value = numbers.parse(raw) else { throw Skip(reason: .invalidAmount) }
            return value
        }

        /// Reads a `Photo` / `File` path relative to the folder. Blank paths are
        /// "no file"; missing files and paths leaving the folder are counted.
        private func file(_ row: DataImportService.Row, _ column: String) -> Data? {
            guard let path = row.text(column) else { return nil }
            let components = path.split(separator: "/")
            guard !path.hasPrefix("/"), !components.contains(where: { $0 == ".." || $0 == "." }) else {
                result.filesMissing += 1
                return nil
            }
            let url = root.appendingPathComponent(path)
            guard let data = try? Data(contentsOf: DataRestoreService.coordinated(url)) else {
                result.filesMissing += 1
                return nil
            }
            result.filesRestored += 1
            return data
        }

        /// Runs `body`, turning a thrown `Skip` into a skipped row.
        private func parsing(_ body: () throws -> Outcome) throws -> Outcome {
            do {
                return try body()
            } catch let skip as Skip {
                return .skipped(skip.reason)
            }
        }

        // MARK: Kinds

        private func restore(_ kind: CSVExportKind, progress: (Double) -> Void) throws {
            switch kind {
            case .horses: try restoreHorses(progress)
            case .clients: try restoreClients(progress)
            case .feedProducts: try restoreFeedProducts(progress)
            case .horseClients: try restoreHorseClients(progress)
            case .transactions: try restoreTransactions(progress)
            case .vetRecords: try restoreVetRecords(progress)
            case .farrierVisits: try restoreFarrierVisits(progress)
            case .dentistVisits: try restoreDentistVisits(progress)
            case .weightEntries: try restoreWeightEntries(progress)
            case .feedPlan: try restoreFeedPlan(progress)
            case .reminders: try restoreReminders(progress)
            case .lessons: try restoreLessons(progress)
            case .barnNotes: try restoreBarnNotes(progress)
            case .supplies: try restoreSupplies(progress)
            case .invoices: try restoreInvoices(progress)
            case .horseDocuments: try restoreHorseDocuments(progress)
            case .clientDocuments: try restoreClientDocuments(progress)
            }
        }

        /// The photo as exported, plus the inline thumbnail made from it the
        /// way the app does when a photo is set (`ImageProcessing.processPhoto`).
        private func photo(_ row: DataImportService.Row) -> (photo: Data, thumbnail: Data?)? {
            guard let data = file(row, "photo") else { return nil }
            return (data, ImageProcessing.thumbnailJPEG(from: data))
        }

        private func restoreHorses(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(Horse.self, signature: signature, horseKey)
            let genders = DataImportService.horseGenderLookup()
            try each(.horses, progress: progress) { row in
                let fields: DataImportService.HorseFields
                switch DataImportService.parseHorse(row, dates: dates, numbers: numbers, genders: genders) {
                case .success(let parsed): fields = parsed
                case .failure(let reason): return .skipped(reason)
                }
                let id = row.text("id")
                let horse = fields.makeHorse()
                let key = horseKey(horse)
                if let id { ownerKeys[id] = key }
                if let match = claim(key, signature: signature(horse), in: &existing) {
                    if let id { owners[id] = match }
                    return .duplicate
                }
                let picture = photo(row)
                horse.photoData = picture?.photo
                horse.thumbnailData = picture?.thumbnail
                insert(horse, exportID: id, bytes: picture?.photo.count ?? 0)
                return .inserted
            }
        }

        private func restoreClients(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(Client.self, signature: signature, clientKey)
            try each(.clients, progress: progress) { row in
                let fields: DataImportService.ClientFields
                switch DataImportService.parseClient(row, hasFirstNameColumn: true) {
                case .success(let parsed): fields = parsed
                case .failure(let reason): return .skipped(reason)
                }
                let id = row.text("id")
                let client = fields.makeClient()
                if let id { ownerKeys[id] = fields.key }
                if let match = claim(fields.key, signature: signature(client), in: &existing) {
                    if let id { owners[id] = match }
                    return .duplicate
                }
                insert(client, exportID: id)
                return .inserted
            }
        }

        private func restoreFeedProducts(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(FeedProduct.self, signature: signature) { productKey(name: $0.name, brand: $0.brand) }
            try each(.feedProducts, progress: progress) { row in
                guard let name = row.text("name") else { return .skipped(.missingName) }
                let brand = row.text("brand") ?? ""
                let id = row.text("id")
                let key = productKey(name: name, brand: brand)
                let product = FeedProduct(name: name, brand: brand, notes: row.text("notes") ?? "")
                if let unit = row.text("default unit") { product.defaultUnitRaw = unit }
                if let id { ownerKeys[id] = key }
                if let match = claim(key, signature: signature(product), in: &existing) {
                    if let id { owners[id] = match }
                    return .duplicate
                }
                let picture = photo(row)
                product.photoData = picture?.photo
                product.thumbnailData = picture?.thumbnail
                insert(product, exportID: id, bytes: picture?.photo.count ?? 0)
                return .inserted
            }
        }

        private func restoreHorseClients(_ progress: (Double) -> Void) throws {
            // Links match on the horse's and client's duplicate keys like other
            // records, so a restore that matched twin horses the other way round
            // still finds the link already there.
            var existing: [String: Int] = [:]
            let scratch = ModelContext(container)
            for horse in try scratch.fetch(FetchDescriptor<Horse>()) {
                for client in horse.clients ?? [] { existing[key(horseKey(horse), clientKey(client)), default: 0] += 1 }
            }
            try each(.horseClients, progress: progress) { row in
                let horseExportID = row.text("horse id")
                let clientExportID = row.text("client id")
                guard let horse = owner(horseExportID, as: Horse.self),
                      let client = owner(clientExportID, as: Client.self) else { return .skipped(.unknownLink) }
                let linkKey = key(ownerKey(horseExportID), ownerKey(clientExportID))
                if let count = existing[linkKey], count > 0 {
                    existing[linkKey] = count - 1
                    return .duplicate
                }
                let clients = horse.clients ?? []
                guard !clients.contains(where: { $0.persistentModelID == client.persistentModelID }) else { return .duplicate }
                horse.clients = clients + [client]
                if !insertedSet.contains(horse.persistentModelID), !insertedSet.contains(client.persistentModelID) {
                    addedLinks.append((horse.persistentModelID, client.persistentModelID))
                }
                return .inserted
            }
        }

        private func restoreTransactions(_ progress: (Double) -> Void) throws {
            func txnKey(day: String, type: TransactionType, category: TransactionCategory, amount: Double, memo: String, client: String) -> String {
                key(day, type.rawValue, category.rawValue, String(Int((amount * 100).rounded())), memo, client)
            }
            var existing = try existingRecords(Transaction.self) {
                txnKey(day: day($0.date), type: $0.type, category: $0.category, amount: $0.amount, memo: $0.memo, client: clientKey($0.client))
            }
            try each(.transactions, progress: progress) { row in
                let fields: DataImportService.TransactionFields
                switch DataImportService.parseTransaction(row, dates: dates, numbers: numbers) {
                case .success(let parsed): fields = parsed
                case .failure(let reason): return .skipped(reason)
                }
                let clientID = row.text("client id")
                let key = txnKey(day: day(fields.date), type: fields.type, category: fields.category,
                                 amount: fields.amount, memo: fields.memo, client: ownerKey(clientID))
                if claim(key, in: &existing) != nil { return .duplicate }
                let txn = fields.makeTransaction()
                insert(txn)
                txn.client = owner(clientID, as: Client.self)
                return .inserted
            }
        }

        private func restoreVetRecords(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(VetRecord.self) { key(day($0.date), horseKey($0.horse), $0.vetName, $0.descriptionText) }
            try each(.vetRecords, progress: progress) { row in
                try parsing {
                    let date = try parseDate(row, "date") ?? .now
                    let horseID = row.text("horse id")
                    let vet = row.text("vet") ?? ""
                    let description = row.text("description") ?? ""
                    if claim(key(day(date), ownerKey(horseID), vet, description), in: &existing) != nil { return .duplicate }
                    let record = VetRecord(date: date, vetName: vet, descriptionText: description,
                                           cost: try double(row, "cost") ?? 0, nextDueDate: try parseDate(row, "next due"))
                    if let repeats = row.text("repeats") { record.reminderFrequencyRaw = repeats }
                    insert(record)
                    record.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreFarrierVisits(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(FarrierVisit.self) { key(day($0.date), horseKey($0.horse), $0.farrierName, $0.serviceDescription) }
            try each(.farrierVisits, progress: progress) { row in
                try parsing {
                    let date = try parseDate(row, "date") ?? .now
                    let horseID = row.text("horse id")
                    let farrier = row.text("farrier") ?? ""
                    let service = row.text("service") ?? ""
                    if claim(key(day(date), ownerKey(horseID), farrier, service), in: &existing) != nil { return .duplicate }
                    let visit = FarrierVisit(date: date, farrierName: farrier, serviceDescription: service,
                                             cost: try double(row, "cost") ?? 0, nextDueDate: try parseDate(row, "next due"))
                    insert(visit)
                    visit.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreDentistVisits(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(DentistVisit.self) { key(day($0.date), horseKey($0.horse), $0.dentistName, $0.serviceDescription) }
            try each(.dentistVisits, progress: progress) { row in
                try parsing {
                    let date = try parseDate(row, "date") ?? .now
                    let horseID = row.text("horse id")
                    let dentist = row.text("dentist") ?? ""
                    let service = row.text("service") ?? ""
                    if claim(key(day(date), ownerKey(horseID), dentist, service), in: &existing) != nil { return .duplicate }
                    let visit = DentistVisit(date: date, dentistName: dentist, serviceDescription: service,
                                             cost: try double(row, "cost") ?? 0, nextDueDate: try parseDate(row, "next due"))
                    insert(visit)
                    visit.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreWeightEntries(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(WeightEntry.self) { key(day($0.date), horseKey($0.horse), number($0.weight)) }
            try each(.weightEntries, progress: progress) { row in
                try parsing {
                    let date = try parseDate(row, "date") ?? .now
                    let horseID = row.text("horse id")
                    let weight = try double(row, "weight (lbs)") ?? 0
                    if claim(key(day(date), ownerKey(horseID), number(weight)), in: &existing) != nil { return .duplicate }
                    let entry = WeightEntry(date: date, weight: weight)
                    insert(entry)
                    entry.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreFeedPlan(_ progress: (Double) -> Void) throws {
            // A horse gets one entry per product and feed time.
            var existing = try existingRecords(FeedPlanEntry.self) {
                key(horseKey($0.horse), $0.product.map { productKey(name: $0.name, brand: $0.brand) } ?? "", $0.feedTimeRaw)
            }
            try each(.feedPlan, progress: progress) { row in
                try parsing {
                    let horseID = row.text("horse id")
                    let productID = row.text("product id")
                    let feedTime = row.text("feed time") ?? FeedTime.morning.rawValue
                    if claim(key(ownerKey(horseID), ownerKey(productID), feedTime), in: &existing) != nil { return .duplicate }
                    let entry = FeedPlanEntry(amount: try double(row, "amount") ?? 1, assignedPerson: row.text("assigned to") ?? "",
                                              notes: row.text("notes") ?? "")
                    entry.feedTimeRaw = feedTime
                    if let unit = row.text("unit") { entry.unitRaw = unit }
                    insert(entry)
                    entry.horse = owner(horseID, as: Horse.self)
                    entry.product = owner(productID, as: FeedProduct.self)
                    return .inserted
                }
            }
        }

        private func restoreReminders(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(Reminder.self) {
                key(day($0.dueDate), dates.timeString(from: $0.dueDate), $0.title, horseKey($0.horse))
            }
            try each(.reminders, progress: progress) { row in
                try parsing {
                    let due = try dateTime(row, day: "due date", time: "time") ?? .now
                    let horseID = row.text("horse id")
                    let title = row.text("title") ?? ""
                    if claim(key(day(due), dates.timeString(from: due), title, ownerKey(horseID)), in: &existing) != nil { return .duplicate }
                    let reminder = Reminder(title: title, notes: row.text("notes") ?? "", dueDate: due,
                                            isCompleted: row.bool("completed") ?? false)
                    if let repeats = row.text("repeats") { reminder.frequencyRaw = repeats }
                    insert(reminder)
                    reminder.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreLessons(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(Lesson.self) {
                key(day($0.date), dates.timeString(from: $0.date), $0.lessonTypeRaw, clientKey($0.client), horseKey($0.horse))
            }
            try each(.lessons, progress: progress) { row in
                try parsing {
                    let date = try dateTime(row, day: "date", time: "time") ?? .now
                    let clientID = row.text("client id")
                    let horseID = row.text("horse id")
                    let type = row.text("type") ?? LessonType.privateLesson.rawValue
                    if claim(key(day(date), dates.timeString(from: date), type, ownerKey(clientID), ownerKey(horseID)),
                             in: &existing) != nil { return .duplicate }
                    let lesson = Lesson(date: date, duration: row.text("duration (min)").flatMap { Int($0) } ?? 60,
                                        notes: row.text("notes") ?? "", cost: try double(row, "cost") ?? 0,
                                        isPaid: row.bool("paid") ?? false, nextDate: try parseDate(row, "next date"))
                    lesson.lessonTypeRaw = type
                    if let repeats = row.text("repeats") { lesson.frequencyRaw = repeats }
                    insert(lesson)
                    lesson.client = owner(clientID, as: Client.self)
                    lesson.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreBarnNotes(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(BarnNote.self) { key(day($0.date), $0.categoryRaw, horseKey($0.horse), $0.content) }
            try each(.barnNotes, progress: progress) { row in
                try parsing {
                    let date = try parseDate(row, "date") ?? .now
                    let horseID = row.text("horse id")
                    let category = row.text("category") ?? BarnNoteCategory.general.rawValue
                    let content = row.text("content") ?? ""
                    if claim(key(day(date), category, ownerKey(horseID), content), in: &existing) != nil { return .duplicate }
                    let note = BarnNote(content: content, date: date)
                    note.categoryRaw = category
                    insert(note)
                    note.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreSupplies(_ progress: (Double) -> Void) throws {
            // Quantities change as supplies are used, so they don't make a supply distinct.
            var existing = try existingRecords(SupplyItem.self) { key($0.name, $0.categoryRaw, $0.unit) }
            try each(.supplies, progress: progress) { row in
                try parsing {
                    guard let name = row.text("name") else { return .skipped(.missingName) }
                    let category = row.text("category") ?? ""
                    let unit = row.text("unit") ?? ""
                    if claim(key(name, category, unit), in: &existing) != nil { return .duplicate }
                    insert(SupplyItem(name: name, categoryRaw: category, quantity: try double(row, "quantity") ?? 0, unit: unit,
                                      reorderThreshold: try double(row, "reorder at") ?? 0,
                                      lastOrderedDate: try parseDate(row, "last ordered")))
                    return .inserted
                }
            }
        }

        private func restoreInvoices(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(Invoice.self) {
                key(clientKey($0.client), day($0.startDate), day($0.endDate), day($0.createdAt))
            }
            try each(.invoices, progress: progress) { row in
                try parsing {
                    let created = try parseDate(row, "created") ?? .now
                    let start = try parseDate(row, "start date") ?? created
                    let end = try parseDate(row, "end date") ?? created
                    let clientID = row.text("client id")
                    if claim(key(ownerKey(clientID), day(start), day(end), day(created)), in: &existing) != nil { return .duplicate }
                    let pdf = file(row, "file")
                    let invoice = Invoice(startDate: start, endDate: end, totalAmount: try double(row, "total") ?? 0,
                                          createdAt: created, pdfData: pdf)
                    insert(invoice, bytes: pdf?.count ?? 0)
                    invoice.client = owner(clientID, as: Client.self)
                    return .inserted
                }
            }
        }

        private func restoreHorseDocuments(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(HorseDocument.self) { key(horseKey($0.horse), $0.title, $0.typeRaw, day($0.createdAt)) }
            try each(.horseDocuments, progress: progress) { row in
                try parsing {
                    let created = try parseDate(row, "created") ?? .now
                    let horseID = row.text("horse id")
                    let title = row.text("title") ?? ""
                    let type = row.text("type") ?? DocumentType.pdf.rawValue
                    if claim(key(ownerKey(horseID), title, type, day(created)), in: &existing) != nil { return .duplicate }
                    let data = file(row, "file")
                    let document = HorseDocument(title: title, fileData: data)
                    document.typeRaw = type
                    document.createdAt = created
                    insert(document, bytes: data?.count ?? 0)
                    document.horse = owner(horseID, as: Horse.self)
                    return .inserted
                }
            }
        }

        private func restoreClientDocuments(_ progress: (Double) -> Void) throws {
            var existing = try existingRecords(ClientDocument.self) { key(clientKey($0.client), $0.title, $0.typeRaw, day($0.createdAt)) }
            try each(.clientDocuments, progress: progress) { row in
                try parsing {
                    let created = try parseDate(row, "created") ?? .now
                    let clientID = row.text("client id")
                    let title = row.text("title") ?? ""
                    let type = row.text("type") ?? DocumentType.pdf.rawValue
                    if claim(key(ownerKey(clientID), title, type, day(created)), in: &existing) != nil { return .duplicate }
                    let data = file(row, "file")
                    let document = ClientDocument(title: title, fileData: data)
                    document.typeRaw = type
                    document.createdAt = created
                    insert(document, bytes: data?.count ?? 0)
                    document.client = owner(clientID, as: Client.self)
                    return .inserted
                }
            }
        }
    }
}

extension CSVDataActor {
    /// Restores an All Data folder (see `DataRestoreService`). The folder is the
    /// "BarnHub Export" folder or the one around it. Throws `CancellationError`
    /// or the underlying error after undoing everything it added.
    func restoreAllData(from folder: URL, options: CSVOptions, progress: CSVProgressHandler?,
                        step: CSVStepHandler? = nil) throws -> DataRestoreService.Result {
        let root = try DataRestoreService.exportRoot(for: folder)
        let restorer = DataRestoreService.Restorer(root: root, container: modelContainer, options: options)
        return try restorer.run(progress: progress, step: step)
    }
}
