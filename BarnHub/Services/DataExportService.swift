import Foundation
import SwiftData

struct DataExportService {
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    static func exportHorsesCSV(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Horse>(sortBy: [SortDescriptor(\.name)])
        let horses = (try? context.fetch(descriptor)) ?? []

        var csv = "Name,Breed,Date of Birth,Color/Markings,Weight (lbs),Purchase Price,Stall,Medical Notes,Feeding Schedule,Active\n"
        for h in horses {
            csv += "\(esc(h.name)),\(esc(h.breed)),\(dateFormatter.string(from: h.dateOfBirth)),\(esc(h.colorMarkings)),\(h.weight),\(h.purchasePrice),\(esc(h.stallNumber)),\(esc(h.medicalNotes)),\(esc(h.feedingSchedule)),\(h.isActive)\n"
        }
        return csv
    }

    static func exportClientsCSV(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Client>(sortBy: [SortDescriptor(\.lastName)])
        let clients = (try? context.fetch(descriptor)) ?? []

        var csv = "First Name,Last Name,Email,Phone,Emergency Contact,Emergency Phone,Notes,Active\n"
        for c in clients {
            csv += "\(esc(c.firstName)),\(esc(c.lastName)),\(esc(c.email)),\(esc(c.phone)),\(esc(c.emergencyContact)),\(esc(c.emergencyPhone)),\(esc(c.notes)),\(c.isActive)\n"
        }
        return csv
    }

    static func exportTransactionsCSV(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let transactions = (try? context.fetch(descriptor)) ?? []

        var csv = "Date,Type,Category,Amount,Memo,Client,Paid\n"
        for t in transactions {
            let clientName = t.client?.fullName ?? ""
            csv += "\(dateFormatter.string(from: t.date)),\(t.type.rawValue),\(t.category.rawValue),\(t.amount),\(esc(t.memo)),\(esc(clientName)),\(t.isPaid)\n"
        }
        return csv
    }

    private static func esc(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        guard needsQuoting else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
