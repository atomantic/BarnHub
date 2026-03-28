import Foundation
import SwiftData

struct DataImportService {
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    struct ImportResult {
        let imported: Int
        let skipped: Int
        let errors: [String]
    }

    // MARK: - Horses

    static func importHorses(from csvString: String, context: ModelContext) -> ImportResult {
        let rows = parseCSV(csvString)
        guard let header = rows.first else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Empty file"])
        }

        let columns = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let nameIdx = columns.firstIndex(of: "name")
        guard let nameIdx else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Missing required column: Name"])
        }

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for (rowNum, row) in rows.dropFirst().enumerated() {
            guard row.count > nameIdx else {
                skipped += 1
                continue
            }

            let name = row[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else {
                skipped += 1
                continue
            }

            let horse = Horse(name: name)
            horse.breed = value(row, columns, "breed") ?? ""
            horse.colorMarkings = value(row, columns, "color/markings") ?? value(row, columns, "color") ?? ""
            horse.stallNumber = value(row, columns, "stall") ?? value(row, columns, "stall number") ?? ""
            horse.medicalNotes = value(row, columns, "medical notes") ?? ""
            horse.feedingSchedule = value(row, columns, "feeding schedule") ?? ""

            if let w = doubleValue(row, columns, "weight") ?? doubleValue(row, columns, "weight (lbs)") {
                horse.weight = w
            }
            if let p = doubleValue(row, columns, "purchase price") {
                horse.purchasePrice = p
            }
            if let dob = dateValue(row, columns, "date of birth") ?? dateValue(row, columns, "dob") {
                horse.dateOfBirth = dob
            }
            if let active = boolValue(row, columns, "active") {
                horse.isActive = active
            }

            context.insert(horse)
            imported += 1
        }

        context.saveWithLogging()
        BarnHubLogger.success("Imported \(imported) horses, skipped \(skipped)")
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    // MARK: - Clients

    static func importClients(from csvString: String, context: ModelContext) -> ImportResult {
        let rows = parseCSV(csvString)
        guard let header = rows.first else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Empty file"])
        }

        let columns = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let firstIdx = columns.firstIndex(of: "first name")
        let lastIdx = columns.firstIndex(of: "last name")
        let nameIdx = columns.firstIndex(of: "name")

        guard firstIdx != nil || nameIdx != nil else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Missing required column: First Name or Name"])
        }

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for row in rows.dropFirst() {
            var firstName = ""
            var lastName = ""

            if let fi = firstIdx, row.count > fi {
                firstName = row[fi].trimmingCharacters(in: .whitespaces)
                if let li = lastIdx, row.count > li {
                    lastName = row[li].trimmingCharacters(in: .whitespaces)
                }
            } else if let ni = nameIdx, row.count > ni {
                let parts = row[ni].trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                firstName = String(parts.first ?? "")
                lastName = parts.count > 1 ? String(parts[1]) : ""
            }

            guard !firstName.isEmpty else {
                skipped += 1
                continue
            }

            let client = Client(firstName: firstName, lastName: lastName)
            client.email = value(row, columns, "email") ?? ""
            client.phone = value(row, columns, "phone") ?? ""
            client.emergencyContact = value(row, columns, "emergency contact") ?? ""
            client.emergencyPhone = value(row, columns, "emergency phone") ?? ""
            client.notes = value(row, columns, "notes") ?? ""
            if let active = boolValue(row, columns, "active") {
                client.isActive = active
            }

            context.insert(client)
            imported += 1
        }

        context.saveWithLogging()
        BarnHubLogger.success("Imported \(imported) clients, skipped \(skipped)")
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    // MARK: - Transactions

    static func importTransactions(from csvString: String, context: ModelContext) throws -> ImportResult {
        let rows = parseCSV(csvString)
        guard let header = rows.first else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Empty file"])
        }

        let columns = header.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        guard columns.contains("amount") else {
            return ImportResult(imported: 0, skipped: 0, errors: ["Missing required column: Amount"])
        }

        // Pre-fetch clients for matching
        let clientDescriptor = FetchDescriptor<Client>()
        let allClients = try context.fetch(clientDescriptor)

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        for row in rows.dropFirst() {
            guard let amount = doubleValue(row, columns, "amount"), amount > 0 else {
                skipped += 1
                continue
            }

            let typeStr = value(row, columns, "type")?.lowercased() ?? "expense"
            let type = TransactionType(rawValue: typeStr) ?? .expense

            let catStr = value(row, columns, "category")?.lowercased() ?? "other"
            let category = TransactionCategory(rawValue: catStr) ?? .other

            let txn = Transaction(
                amount: amount,
                date: dateValue(row, columns, "date") ?? .now,
                memo: value(row, columns, "memo") ?? value(row, columns, "description") ?? "",
                category: category,
                type: type,
                isPaid: boolValue(row, columns, "paid") ?? false
            )

            // Match client by name if provided
            if let clientName = value(row, columns, "client"), !clientName.isEmpty {
                txn.client = allClients.first { $0.fullName.lowercased() == clientName.lowercased() }
            }

            context.insert(txn)
            imported += 1
        }

        context.saveWithLogging()
        BarnHubLogger.success("Imported \(imported) transactions, skipped \(skipped)")
        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    // MARK: - CSV Parsing

    private static func parseCSV(_ string: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(string)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if c == "\n" || c == "\r" {
                    if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                } else {
                    currentField.append(c)
                }
            }
            i += 1
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    // MARK: - Helpers

    private static func value(_ row: [String], _ columns: [String], _ name: String) -> String? {
        guard let idx = columns.firstIndex(of: name), row.count > idx else { return nil }
        let val = row[idx].trimmingCharacters(in: .whitespaces)
        return val.isEmpty ? nil : val
    }

    private static func doubleValue(_ row: [String], _ columns: [String], _ name: String) -> Double? {
        guard let str = value(row, columns, name) else { return nil }
        let cleaned = str.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private static func dateValue(_ row: [String], _ columns: [String], _ name: String) -> Date? {
        guard let str = value(row, columns, name) else { return nil }
        if let d = dateFormatter.date(from: str) { return d }
        // Try common formats
        let fallback = DateFormatter()
        for fmt in ["MM/dd/yyyy", "yyyy-MM-dd", "M/d/yyyy", "dd/MM/yyyy"] {
            fallback.dateFormat = fmt
            if let d = fallback.date(from: str) { return d }
        }
        return nil
    }

    private static func boolValue(_ row: [String], _ columns: [String], _ name: String) -> Bool? {
        guard let str = value(row, columns, name)?.lowercased() else { return nil }
        return ["true", "yes", "1"].contains(str)
    }
}
