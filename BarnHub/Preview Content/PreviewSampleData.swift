import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct PreviewSampleData {
    static var previewContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, BarnNote.self,
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

        // Link clients to horses
        if let jane = clients.first {
            jane.horses = [horses[0], horses[1]]  // Jane rides Arrow and Bella
        }
        if clients.count > 1 {
            clients[1].horses = [horses[2]]  // Mike boards Storm
        }
        if clients.count > 2 {
            clients[2].horses = [horses[0]]  // Sarah trains on Arrow
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

        let barnNotes = createBarnNotes(horses: horses)
        barnNotes.forEach { context.insert($0) }

        try? context.save()
    }

    private static func loadArrowPhoto() -> Data? {
        #if canImport(UIKit)
        guard let url = Bundle.main.url(forResource: "arrow", withExtension: "jpeg"),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        // Downsample for storage
        let maxDim: CGFloat = 800
        let scale = min(maxDim / max(image.size.width, image.size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
        #else
        return nil
        #endif
    }

    static func createHorses() -> [Horse] {
        let calendar = Calendar.current
        return [
            Horse(
                name: "Arrow",
                breed: "Thoroughbred",
                dateOfBirth: calendar.date(byAdding: .year, value: -8, to: .now) ?? .now,
                colorMarkings: "Bay with white blaze",
                weight: 1100,
                purchasePrice: 15000,
                medicalNotes: "Annual vaccines up to date. Slight sensitivity in left front hoof — monitor after farrier visits.",
                feedingSchedule: "2x daily: AM/PM grain + hay",
                stallNumber: "A1",
                isActive: true,
                photoData: loadArrowPhoto()
            ),
            Horse(
                name: "Bella",
                breed: "Quarter Horse",
                dateOfBirth: calendar.date(byAdding: .year, value: -12, to: .now) ?? .now,
                colorMarkings: "Sorrel, no markings",
                weight: 1050,
                purchasePrice: 8500,
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
                purchasePrice: 25000,
                medicalNotes: "Cleared for jumping. Excellent temperament.",
                feedingSchedule: "2x daily: performance feed + hay",
                stallNumber: "B2",
                isActive: true
            ),
            Horse(
                name: "Daisy",
                breed: "Paint Horse",
                dateOfBirth: calendar.date(byAdding: .year, value: -10, to: .now) ?? .now,
                colorMarkings: "Tobiano, black and white",
                weight: 1000,
                purchasePrice: 6000,
                medicalNotes: "Senior horse, joint supplements recommended",
                feedingSchedule: "2x daily: senior feed + hay",
                stallNumber: "B4",
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
                notes: "Prefers Saturday lessons. Working toward first show season.",
                isActive: true
            ),
            Client(
                firstName: "Mike",
                lastName: "Rivera",
                email: "mike.r@example.com",
                phone: "(555) 234-5678",
                emergencyContact: "Sarah Rivera",
                emergencyPhone: "(555) 876-5432",
                notes: "Boards Storm, full care. Competes in dressage.",
                isActive: true
            ),
            Client(
                firstName: "Sarah",
                lastName: "Chen",
                email: "sarah.c@example.com",
                phone: "(555) 345-6789",
                emergencyContact: "David Chen",
                emergencyPhone: "(555) 765-4321",
                notes: "Beginner rider, Tuesday/Thursday lessons",
                isActive: true
            )
        ]
    }

    static func createTransactions(clients: [Client]) -> [Transaction] {
        let calendar = Calendar.current
        let jane = clients.first
        let mike = clients.count > 1 ? clients[1] : nil
        let sarah = clients.count > 2 ? clients[2] : nil

        var transactions: [Transaction] = []

        // Current month — income
        let lesson1 = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -2, to: .now) ?? .now, memo: "Weekly lesson — Jane on Arrow", category: .lesson, type: .income, isPaid: true)
        lesson1.client = jane
        transactions.append(lesson1)

        let lesson2 = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -4, to: .now) ?? .now, memo: "Weekly lesson — Sarah on Arrow", category: .lesson, type: .income, isPaid: true)
        lesson2.client = sarah
        transactions.append(lesson2)

        let boarding1 = Transaction(amount: 850.00, date: calendar.date(byAdding: .day, value: -5, to: .now) ?? .now, memo: "Monthly boarding — Storm (full care)", category: .boarding, type: .income, isPaid: true)
        boarding1.client = mike
        transactions.append(boarding1)

        let training1 = Transaction(amount: 200.00, date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now, memo: "Dressage training session — Storm", category: .training, type: .income, isPaid: true)
        training1.client = mike
        transactions.append(training1)

        // Current month — expenses
        transactions.append(Transaction(amount: 320.00, date: calendar.date(byAdding: .day, value: -6, to: .now) ?? .now, memo: "Hay delivery — 20 bales", category: .feed, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 85.00, date: calendar.date(byAdding: .day, value: -7, to: .now) ?? .now, memo: "Grain restock — 5 bags", category: .feed, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 250.00, date: calendar.date(byAdding: .day, value: -10, to: .now) ?? .now, memo: "Annual vaccinations — Arrow", category: .vetBill, type: .expense, isPaid: false))
        transactions.append(Transaction(amount: 150.00, date: calendar.date(byAdding: .day, value: -8, to: .now) ?? .now, memo: "Trim and reset front shoes — Arrow", category: .farrier, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 45.00, date: calendar.date(byAdding: .day, value: -9, to: .now) ?? .now, memo: "Fly spray and wound care supplies", category: .supplies, type: .expense, isPaid: true))

        // Last month
        let lastLesson1 = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -35, to: .now) ?? .now, memo: "Weekly lesson — Jane", category: .lesson, type: .income, isPaid: true)
        lastLesson1.client = jane
        transactions.append(lastLesson1)

        let lastLesson2 = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -37, to: .now) ?? .now, memo: "Weekly lesson — Jane", category: .lesson, type: .income, isPaid: true)
        lastLesson2.client = jane
        transactions.append(lastLesson2)

        let lastLesson3 = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -33, to: .now) ?? .now, memo: "Weekly lesson — Sarah", category: .lesson, type: .income, isPaid: true)
        lastLesson3.client = sarah
        transactions.append(lastLesson3)

        let lastBoarding = Transaction(amount: 850.00, date: calendar.date(byAdding: .day, value: -36, to: .now) ?? .now, memo: "Monthly boarding — Storm", category: .boarding, type: .income, isPaid: true)
        lastBoarding.client = mike
        transactions.append(lastBoarding)

        transactions.append(Transaction(amount: 280.00, date: calendar.date(byAdding: .day, value: -38, to: .now) ?? .now, memo: "Hay delivery — 18 bales", category: .feed, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 180.00, date: calendar.date(byAdding: .day, value: -40, to: .now) ?? .now, memo: "Dental float — Bella", category: .vetBill, type: .expense, isPaid: true))

        // Two months ago
        let oldLesson = Transaction(amount: 75.00, date: calendar.date(byAdding: .day, value: -65, to: .now) ?? .now, memo: "Weekly lesson — Jane", category: .lesson, type: .income, isPaid: true)
        oldLesson.client = jane
        transactions.append(oldLesson)

        let oldBoarding = Transaction(amount: 850.00, date: calendar.date(byAdding: .day, value: -67, to: .now) ?? .now, memo: "Monthly boarding — Storm", category: .boarding, type: .income, isPaid: true)
        oldBoarding.client = mike
        transactions.append(oldBoarding)

        transactions.append(Transaction(amount: 300.00, date: calendar.date(byAdding: .day, value: -68, to: .now) ?? .now, memo: "Hay delivery", category: .feed, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 85.00, date: calendar.date(byAdding: .day, value: -70, to: .now) ?? .now, memo: "Barefoot trim — Bella", category: .farrier, type: .expense, isPaid: true))
        transactions.append(Transaction(amount: 120.00, date: calendar.date(byAdding: .day, value: -66, to: .now) ?? .now, memo: "New halters and lead ropes", category: .tack, type: .expense, isPaid: true))

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
            descriptionText: "Dental float — routine",
            cost: 180.00,
            nextDueDate: calendar.date(byAdding: .month, value: 9, to: .now),
            reminderFrequency: .annually
        )
        dental.horse = horses.count > 1 ? horses[1] : nil
        records.append(dental)

        let coggins = VetRecord(
            date: calendar.date(byAdding: .month, value: -2, to: .now) ?? .now,
            vetName: "Dr. Sarah Chen",
            descriptionText: "Coggins test — negative",
            cost: 45.00,
            nextDueDate: calendar.date(byAdding: .year, value: 1, to: .now),
            reminderFrequency: .annually
        )
        coggins.horse = horses.count > 2 ? horses[2] : nil
        records.append(coggins)

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
            title: "Deworming — Arrow",
            notes: "Ivermectin rotation",
            dueDate: calendar.date(byAdding: .weekOfYear, value: 2, to: .now) ?? .now,
            isCompleted: false,
            frequency: .quarterly
        )
        deworming.horse = horses.first
        reminders.append(deworming)

        let farrier = Reminder(
            title: "Farrier visit — all horses",
            notes: "Tom Bradley scheduled",
            dueDate: calendar.date(byAdding: .weekOfYear, value: 4, to: .now) ?? .now,
            isCompleted: false,
            frequency: .monthly
        )
        reminders.append(farrier)

        let dentist = Reminder(
            title: "Dental checkup — Bella",
            notes: "Dr. Chen, annual float",
            dueDate: calendar.date(byAdding: .month, value: 3, to: .now) ?? .now,
            isCompleted: false,
            frequency: .annually
        )
        dentist.horse = horses.count > 1 ? horses[1] : nil
        reminders.append(dentist)

        return reminders
    }

    static func createBarnNotes(horses: [Horse]) -> [BarnNote] {
        let calendar = Calendar.current
        var notes: [BarnNote] = []

        let note1 = BarnNote(
            content: "Arrow seemed a little stiff in his left front during turnout this morning. Will monitor over the next few days.",
            date: calendar.date(byAdding: .hour, value: -3, to: .now) ?? .now,
            category: .observation
        )
        note1.horse = horses.first
        notes.append(note1)

        notes.append(BarnNote(
            content: "Repaired the latch on stall B4 — was sticking and hard to open. Replaced hinge pin.",
            date: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
            category: .maintenance
        ))

        let note3 = BarnNote(
            content: "Bella refused grain at evening feed. Ate hay normally. No other signs of distress — keeping an eye on it given her colic history.",
            date: calendar.date(byAdding: .day, value: -1, to: .now) ?? .now,
            category: .health
        )
        note3.horse = horses.count > 1 ? horses[1] : nil
        notes.append(note3)

        notes.append(BarnNote(
            content: "Heavy rain overnight, paddocks are muddy. Shortened turnout to 2 hours for all horses.",
            date: calendar.date(byAdding: .day, value: -2, to: .now) ?? .now,
            category: .weather
        ))

        notes.append(BarnNote(
            content: "Hay delivery arrived — 40 bales of timothy. Stacked in the upper loft.",
            date: calendar.date(byAdding: .day, value: -3, to: .now) ?? .now,
            category: .general
        ))

        let note6 = BarnNote(
            content: "Storm spooked at a tarp near the arena and pulled back on cross-ties. No injury, but re-tied with quick-release knots.",
            date: calendar.date(byAdding: .day, value: -4, to: .now) ?? .now,
            category: .incident
        )
        note6.horse = horses.count > 2 ? horses[2] : nil
        notes.append(note6)

        return notes
    }
}
