import Foundation
import SwiftData

struct PreviewSampleData {
    static var previewContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            configurations: config
        )
        populate(container: container)
        return container
    }()

    static func populate(container: ModelContainer) {
        let context = ModelContext(container)

        let horses = createHorses()
        horses.forEach { context.insert($0) }

        let clients = createClients()
        clients.forEach { context.insert($0) }

        // Link first client to first two horses
        if let firstClient = clients.first {
            firstClient.horses = Array(horses.prefix(2))
        }
        if clients.count > 1 {
            clients[1].horses = [horses.last].compactMap { $0 }
        }

        let transactions = createTransactions(clients: clients)
        transactions.forEach { context.insert($0) }

        let vetRecords = createVetRecords(horses: horses)
        vetRecords.forEach { context.insert($0) }

        let farrierVisits = createFarrierVisits(horses: horses)
        farrierVisits.forEach { context.insert($0) }

        let supplies = createSupplyItems()
        supplies.forEach { context.insert($0) }

        let reminders = createReminders(horses: horses)
        reminders.forEach { context.insert($0) }

        try? context.save()
    }

    static func createHorses() -> [Horse] {
        let calendar = Calendar.current
        return [
            Horse(
                name: "Thunder",
                breed: "Thoroughbred",
                dateOfBirth: calendar.date(byAdding: .year, value: -8, to: .now) ?? .now,
                colorMarkings: "Bay with white blaze",
                weight: 1100,
                medicalNotes: "Annual vaccines up to date",
                feedingSchedule: "2x daily: AM/PM grain + hay",
                stallNumber: "A1",
                isActive: true
            ),
            Horse(
                name: "Bella",
                breed: "Quarter Horse",
                dateOfBirth: calendar.date(byAdding: .year, value: -12, to: .now) ?? .now,
                colorMarkings: "Sorrel, no markings",
                weight: 1050,
                medicalNotes: "History of mild colic, monitor feed changes",
                feedingSchedule: "3x daily: small portions",
                stallNumber: "A3",
                isActive: true
            ),
            Horse(
                name: "Storm",
                breed: "Warmblood",
                dateOfBirth: calendar.date(byAdding: .year, value: -5, to: .now) ?? .now,
                colorMarkings: "Dark bay, four white socks",
                weight: 1250,
                medicalNotes: "Cleared for jumping",
                feedingSchedule: "2x daily: performance feed + hay",
                stallNumber: "B2",
                isActive: true
            )
        ]
    }

    static func createClients() -> [Client] {
        [
            Client(
                firstName: "Jane",
                lastName: "Doe",
                email: "jane@example.com",
                phone: "(555) 123-4567",
                emergencyContact: "John Doe",
                emergencyPhone: "(555) 987-6543",
                notes: "Prefers Saturday lessons",
                isActive: true
            ),
            Client(
                firstName: "Mike",
                lastName: "Rivera",
                email: "mike.r@example.com",
                phone: "(555) 234-5678",
                emergencyContact: "Sarah Rivera",
                emergencyPhone: "(555) 876-5432",
                notes: "Boards Storm, full care",
                isActive: true
            )
        ]
    }

    static func createTransactions(clients: [Client]) -> [Transaction] {
        let calendar = Calendar.current
        let firstClient = clients.first
        let secondClient = clients.count > 1 ? clients[1] : nil

        var transactions: [Transaction] = []

        let lesson = Transaction(
            amount: 75.00,
            date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now,
            memo: "Weekly riding lesson",
            category: .lesson,
            type: .income,
            isPaid: true
        )
        lesson.client = firstClient
        transactions.append(lesson)

        let boarding = Transaction(
            amount: 850.00,
            date: calendar.date(byAdding: .day, value: -7, to: .now) ?? .now,
            memo: "Monthly boarding - Storm",
            category: .boarding,
            type: .income,
            isPaid: true
        )
        boarding.client = secondClient
        transactions.append(boarding)

        let feed = Transaction(
            amount: 320.00,
            date: calendar.date(byAdding: .day, value: -5, to: .now) ?? .now,
            memo: "Hay delivery - 20 bales",
            category: .feed,
            type: .expense,
            isPaid: true
        )
        transactions.append(feed)

        let vet = Transaction(
            amount: 250.00,
            date: calendar.date(byAdding: .day, value: -14, to: .now) ?? .now,
            memo: "Annual vaccinations - Thunder",
            category: .vetBill,
            type: .expense,
            isPaid: false
        )
        transactions.append(vet)

        return transactions
    }

    static func createVetRecords(horses: [Horse]) -> [VetRecord] {
        let calendar = Calendar.current
        var records: [VetRecord] = []

        let vaccines = VetRecord(
            date: calendar.date(byAdding: .month, value: -1, to: .now) ?? .now,
            vetName: "Dr. Sarah Chen",
            descriptionText: "Annual vaccinations: EWT, Rabies, Influenza",
            cost: 250.00,
            nextDueDate: calendar.date(byAdding: .year, value: 1, to: .now),
            reminderFrequency: .annually
        )
        vaccines.horse = horses.first
        records.append(vaccines)

        let dental = VetRecord(
            date: calendar.date(byAdding: .month, value: -3, to: .now) ?? .now,
            vetName: "Dr. Sarah Chen",
            descriptionText: "Dental float - routine",
            cost: 180.00,
            nextDueDate: calendar.date(byAdding: .month, value: 9, to: .now),
            reminderFrequency: .annually
        )
        dental.horse = horses.count > 1 ? horses[1] : nil
        records.append(dental)

        return records
    }

    static func createFarrierVisits(horses: [Horse]) -> [FarrierVisit] {
        let calendar = Calendar.current
        var visits: [FarrierVisit] = []

        let trim = FarrierVisit(
            date: calendar.date(byAdding: .weekOfYear, value: -2, to: .now) ?? .now,
            farrierName: "Tom Bradley",
            serviceDescription: "Trim and reset front shoes",
            cost: 150.00,
            nextDueDate: calendar.date(byAdding: .weekOfYear, value: 6, to: .now)
        )
        trim.horse = horses.first
        visits.append(trim)

        let barefoot = FarrierVisit(
            date: calendar.date(byAdding: .weekOfYear, value: -4, to: .now) ?? .now,
            farrierName: "Tom Bradley",
            serviceDescription: "Barefoot trim",
            cost: 85.00,
            nextDueDate: calendar.date(byAdding: .weekOfYear, value: 4, to: .now)
        )
        barefoot.horse = horses.count > 1 ? horses[1] : nil
        visits.append(barefoot)

        return visits
    }

    static func createSupplyItems() -> [SupplyItem] {
        [
            SupplyItem(
                name: "Timothy Hay",
                categoryRaw: "feed",
                quantity: 45,
                unit: "bales",
                reorderThreshold: 20,
                lastOrderedDate: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now)
            ),
            SupplyItem(
                name: "Sweet Feed",
                categoryRaw: "feed",
                quantity: 3,
                unit: "bags",
                reorderThreshold: 5,
                lastOrderedDate: Calendar.current.date(byAdding: .weekOfYear, value: -3, to: .now)
            ),
            SupplyItem(
                name: "Pine Shavings",
                categoryRaw: "bedding",
                quantity: 12,
                unit: "bags",
                reorderThreshold: 10,
                lastOrderedDate: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: .now)
            ),
            SupplyItem(
                name: "Fly Spray",
                categoryRaw: "health",
                quantity: 2,
                unit: "bottles",
                reorderThreshold: 3,
                lastOrderedDate: nil
            )
        ]
    }

    static func createReminders(horses: [Horse]) -> [Reminder] {
        let calendar = Calendar.current
        var reminders: [Reminder] = []

        let deworming = Reminder(
            title: "Deworming - Thunder",
            notes: "Ivermectin rotation",
            dueDate: calendar.date(byAdding: .weekOfYear, value: 2, to: .now) ?? .now,
            isCompleted: false,
            frequency: .quarterly
        )
        deworming.horse = horses.first
        reminders.append(deworming)

        let farrier = Reminder(
            title: "Farrier visit - all horses",
            notes: "Tom Bradley scheduled",
            dueDate: calendar.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now,
            isCompleted: false,
            frequency: .monthly
        )
        reminders.append(farrier)

        let dentist = Reminder(
            title: "Dental checkup - Bella",
            notes: "Dr. Chen, annual float",
            dueDate: calendar.date(byAdding: .month, value: 3, to: .now) ?? .now,
            isCompleted: false,
            frequency: .annually
        )
        dentist.horse = horses.count > 1 ? horses[1] : nil
        reminders.append(dentist)

        return reminders
    }
}
