import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PreviewSampleData {
    static var previewContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Horse.self, Client.self, Transaction.self,
            VetRecord.self, FarrierVisit.self, DentistVisit.self, SupplyItem.self, Reminder.self,
            Invoice.self, WeightEntry.self, ClientDocument.self, HorseDocument.self, FeedProduct.self, FeedPlanEntry.self, BarnNote.self, Lesson.self,
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
            jane.horses = [horses[0], horses[1], horses[3]]  // Jane rides Arrow, Bella, Daisy
        }
        if clients.count > 1 {
            clients[1].horses = [horses[2], horses[4]]  // Mike boards Storm and Cleo
        }
        if clients.count > 2 {
            clients[2].horses = [horses[0], horses[4]]  // Sarah trains on Arrow and Cleo
        }

        let transactions = createTransactions(clients: clients)
        transactions.forEach { context.insert($0) }

        let vetRecords = createVetRecords(horses: horses)
        vetRecords.forEach { context.insert($0) }

        let farrierVisits = createFarrierVisits(horses: horses)
        farrierVisits.forEach { context.insert($0) }

        let dentistVisits = createDentistVisits(horses: horses)
        dentistVisits.forEach { context.insert($0) }

        let supplies = createSupplyItems()
        supplies.forEach { context.insert($0) }

        let reminders = createReminders(horses: horses)
        reminders.forEach { context.insert($0) }

        let barnNotes = createBarnNotes(horses: horses)
        barnNotes.forEach { context.insert($0) }

        let lessons = createLessons(horses: horses, clients: clients)
        lessons.forEach { context.insert($0) }

        let feedProducts = createFeedProducts()
        feedProducts.forEach { context.insert($0) }

        let feedPlanEntries = createFeedPlanEntries(horses: horses, products: feedProducts)
        feedPlanEntries.forEach { context.insert($0) }

        try? context.save()
    }

    static func createFeedProducts() -> [FeedProduct] {
        [
            FeedProduct(name: "Sweet Feed", brand: "Purina", notes: "10% protein pellets", defaultUnit: .scoops),
            FeedProduct(name: "Performance Feed", brand: "Triple Crown", notes: "14% protein for working horses", defaultUnit: .scoops),
            FeedProduct(name: "Senior Feed", brand: "Nutrena", notes: "For older horses with soft texture", defaultUnit: .scoops),
            FeedProduct(name: "Timothy Hay", brand: "", notes: "Local cut", defaultUnit: .flakes),
            FeedProduct(name: "Alfalfa Cubes", brand: "Standlee", notes: "Soak before feeding", defaultUnit: .cups),
            FeedProduct(name: "Joint Supplement", brand: "SmartPak", notes: "Glucosamine & MSM", defaultUnit: .scoops),
        ]
    }

    static func createFeedPlanEntries(horses: [Horse], products: [FeedProduct]) -> [FeedPlanEntry] {
        guard products.count >= 6, horses.count >= 2 else { return [] }
        let sweetFeed = products[0]
        let performance = products[1]
        let senior = products[2]
        let timothy = products[3]
        let alfalfa = products[4]
        let joint = products[5]

        var entries: [FeedPlanEntry] = []

        func add(_ amount: Double, _ unit: FeedUnit, _ time: FeedTime,
                 person: String = "", notes: String = "",
                 horse: Horse, product: FeedProduct) {
            let e = FeedPlanEntry(amount: amount, unit: unit, feedTime: time,
                                  assignedPerson: person, notes: notes)
            e.horse = horse
            e.product = product
            entries.append(e)
        }

        // Arrow (horse 0) — morning + evening
        add(2, .scoops, .morning, person: "Morning staff", horse: horses[0], product: sweetFeed)
        add(3, .flakes, .morning, horse: horses[0], product: timothy)
        add(1, .scoops, .evening, notes: "With water", horse: horses[0], product: joint)
        add(2, .scoops, .evening, horse: horses[0], product: sweetFeed)
        add(3, .flakes, .evening, horse: horses[0], product: timothy)

        // Bella (horse 1) — 3x daily, small portions
        add(1, .scoops, .morning, person: "Morning staff", horse: horses[1], product: sweetFeed)
        add(2, .flakes, .morning, horse: horses[1], product: timothy)
        add(1, .cups, .midday, notes: "Soaked 20 min", horse: horses[1], product: alfalfa)
        add(1, .scoops, .evening, horse: horses[1], product: sweetFeed)
        add(2, .flakes, .evening, horse: horses[1], product: timothy)

        // Storm (horse 2) — performance feed
        if horses.count > 2 {
            add(3, .scoops, .morning, person: "Morning staff", horse: horses[2], product: performance)
            add(4, .flakes, .morning, horse: horses[2], product: timothy)
            add(3, .scoops, .evening, horse: horses[2], product: performance)
            add(4, .flakes, .evening, horse: horses[2], product: timothy)
        }

        // Daisy (horse 3) — senior feed
        if horses.count > 3 {
            add(2, .scoops, .morning, person: "Morning staff", horse: horses[3], product: senior)
            add(1, .scoops, .morning, notes: "Mixed in feed", horse: horses[3], product: joint)
            add(3, .flakes, .morning, horse: horses[3], product: timothy)
            add(2, .scoops, .evening, horse: horses[3], product: senior)
            add(3, .flakes, .evening, horse: horses[3], product: timothy)
        }

        return entries
    }

    private static func loadPhoto(_ name: String, ext: String = "jpeg") -> Data? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else { return nil }
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let maxDim: CGFloat = 800
        let scale = min(maxDim / max(image.size.width, image.size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        let maxDim: CGFloat = 800
        let scale = min(maxDim / max(image.size.width, image.size.height), 1.0)
        guard scale < 1.0 else { return data }
        let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return data }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #else
        return data
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
                photoData: loadPhoto("arrow")
            ),
            Horse(
                name: "Bella",
                breed: "Quarter Horse",
                dateOfBirth: calendar.date(byAdding: .year, value: -12, to: .now) ?? .now,
                colorMarkings: "Sorrel with wide blaze",
                weight: 1050,
                purchasePrice: 8500,
                medicalNotes: "History of mild colic, monitor feed changes",
                feedingSchedule: "3x daily: small portions",
                stallNumber: "A3",
                isActive: true,
                photoData: loadPhoto("bella")
            ),
            Horse(
                name: "Storm",
                breed: "Warmblood",
                dateOfBirth: calendar.date(byAdding: .year, value: -5, to: .now) ?? .now,
                colorMarkings: "Flea-bitten grey",
                weight: 1250,
                purchasePrice: 25000,
                medicalNotes: "Cleared for jumping. Excellent temperament.",
                feedingSchedule: "2x daily: performance feed + hay",
                stallNumber: "B2",
                isActive: true,
                photoData: loadPhoto("storm", ext: "png")
            ),
            Horse(
                name: "Daisy",
                breed: "Morgan",
                dateOfBirth: calendar.date(byAdding: .year, value: -10, to: .now) ?? .now,
                colorMarkings: "Dark bay",
                weight: 1000,
                purchasePrice: 6000,
                medicalNotes: "Senior horse, joint supplements recommended",
                feedingSchedule: "2x daily: senior feed + hay",
                stallNumber: "B4",
                isActive: true,
                photoData: loadPhoto("daisy", ext: "png")
            ),
            Horse(
                name: "Cleo",
                breed: "Paint Horse",
                dateOfBirth: calendar.date(byAdding: .year, value: -6, to: .now) ?? .now,
                colorMarkings: "Tobiano, black and white, blue eye",
                weight: 1100,
                purchasePrice: 12000,
                medicalNotes: "UV-sensitive around pink skin. Apply sunscreen on muzzle during turnout.",
                feedingSchedule: "2x daily: grain + hay",
                stallNumber: "C1",
                isActive: true,
                photoData: loadPhoto("cleo", ext: "png")
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

    /// Helper: date on given day of the current month (clamped to today)
    private static func thisMonth(day: Int) -> Date {
        let cal = Calendar.current
        let now = Date.now
        let comps = cal.dateComponents([.year, .month], from: now)
        let maxDay = min(day, cal.component(.day, from: now))
        return cal.date(from: DateComponents(year: comps.year, month: comps.month, day: maxDay)) ?? now
    }

    /// Helper: date N days before the 1st of the current month
    private static func lastMonth(daysBeforeFirst: Int) -> Date {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        return cal.date(byAdding: .day, value: -daysBeforeFirst, to: first) ?? .now
    }

    static func createTransactions(clients: [Client]) -> [Transaction] {
        let jane = clients.first
        let mike = clients.count > 1 ? clients[1] : nil
        let sarah = clients.count > 2 ? clients[2] : nil

        var txns: [Transaction] = []

        func add(_ amount: Double, _ date: Date, _ memo: String,
                 _ cat: TransactionCategory, _ type: TransactionType,
                 paid: Bool = true, client: Client? = nil) {
            let t = Transaction(amount: amount, date: date, memo: memo,
                                category: cat, type: type, isPaid: paid)
            t.client = client
            txns.append(t)
        }

        // ── Current month — income ──────────────────────
        add(850, thisMonth(day: 1), "Monthly boarding — Storm (full care)", .boarding, .income, client: mike)
        add(850, thisMonth(day: 1), "Monthly boarding — Daisy", .boarding, .income, client: jane)
        add(75,  thisMonth(day: 2), "Weekly lesson — Jane on Arrow", .lesson, .income, client: jane)
        add(200, thisMonth(day: 2), "Dressage training session — Storm", .training, .income, client: mike)
        add(75,  thisMonth(day: 3), "Weekly lesson — Sarah on Arrow", .lesson, .income, client: sarah)
        add(50,  thisMonth(day: 3), "Group trail ride — Saturday", .lesson, .income, client: jane)

        // ── Current month — expenses ────────────────────
        add(420, thisMonth(day: 1), "Hay delivery — 25 bales timothy", .feed, .expense)
        add(95,  thisMonth(day: 1), "Grain restock — 6 bags performance feed", .feed, .expense)
        add(250, thisMonth(day: 2), "Annual vaccinations — Arrow", .vetBill, .expense, paid: false)
        add(175, thisMonth(day: 2), "Trim and reset front shoes — Arrow", .farrier, .expense)
        add(85,  thisMonth(day: 2), "Barefoot trim — Bella", .farrier, .expense)
        add(65,  thisMonth(day: 1), "Fly spray, wound care, leg wraps", .supplies, .expense)
        add(140, thisMonth(day: 3), "Arena footing maintenance", .other, .expense)

        // ── Last month — income ─────────────────────────
        add(850, lastMonth(daysBeforeFirst: 28), "Monthly boarding — Storm", .boarding, .income, client: mike)
        add(850, lastMonth(daysBeforeFirst: 28), "Monthly boarding — Daisy", .boarding, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 21), "Weekly lesson — Jane", .lesson, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 14), "Weekly lesson — Jane", .lesson, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 7),  "Weekly lesson — Jane", .lesson, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 22), "Weekly lesson — Sarah", .lesson, .income, client: sarah)
        add(75,  lastMonth(daysBeforeFirst: 15), "Weekly lesson — Sarah", .lesson, .income, client: sarah)
        add(200, lastMonth(daysBeforeFirst: 18), "Dressage training — Storm", .training, .income, client: mike)
        add(200, lastMonth(daysBeforeFirst: 11), "Dressage training — Storm", .training, .income, client: mike)

        // ── Last month — expenses ───────────────────────
        add(380, lastMonth(daysBeforeFirst: 25), "Hay delivery — 22 bales", .feed, .expense)
        add(85,  lastMonth(daysBeforeFirst: 20), "Grain — 5 bags", .feed, .expense)
        add(180, lastMonth(daysBeforeFirst: 16), "Dental float — Bella", .vetBill, .expense)
        add(150, lastMonth(daysBeforeFirst: 12), "Trim and shoes — Arrow", .farrier, .expense)
        add(85,  lastMonth(daysBeforeFirst: 12), "Barefoot trim — Bella", .farrier, .expense)
        add(45,  lastMonth(daysBeforeFirst: 8),  "Dewormer paste x4", .supplies, .expense)

        // ── Two months ago ──────────────────────────────
        add(850, lastMonth(daysBeforeFirst: 58), "Monthly boarding — Storm", .boarding, .income, client: mike)
        add(850, lastMonth(daysBeforeFirst: 58), "Monthly boarding — Daisy", .boarding, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 50), "Weekly lesson — Jane", .lesson, .income, client: jane)
        add(75,  lastMonth(daysBeforeFirst: 43), "Weekly lesson — Jane", .lesson, .income, client: jane)
        add(200, lastMonth(daysBeforeFirst: 45), "Dressage training — Storm", .training, .income, client: mike)
        add(300, lastMonth(daysBeforeFirst: 55), "Hay delivery", .feed, .expense)
        add(85,  lastMonth(daysBeforeFirst: 52), "Barefoot trim — Bella", .farrier, .expense)
        add(120, lastMonth(daysBeforeFirst: 48), "New halters and lead ropes", .tack, .expense)
        add(350, lastMonth(daysBeforeFirst: 46), "Pasture fence repair", .other, .expense)

        return txns
    }

    static func createVetRecords(horses: [Horse]) -> [VetRecord] {
        let calendar = Calendar.current
        var records: [VetRecord] = []

        let vaccines = VetRecord(
            date: calendar.date(byAdding: .month, value: -1, to: .now) ?? .now,
            vetName: "Dr. Sarah Chen",
            descriptionText: "Annual vaccinations: EWT, Rabies, Influenza",
            cost: 250.00,
            nextDueDate: dayOffset(-1, hour: 14),  // This week — vet checkup
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
            date: calendar.date(byAdding: .weekOfYear, value: -6, to: .now) ?? .now,
            farrierName: "Tom Bradley",
            serviceDescription: "Trim and reset front shoes",
            cost: 150.00,
            nextDueDate: dayOffset(-2, hour: 10)  // This week — farrier
        )
        trim.horse = horses.first
        visits.append(trim)

        let barefoot = FarrierVisit(
            date: calendar.date(byAdding: .weekOfYear, value: -4, to: .now) ?? .now,
            farrierName: "Tom Bradley",
            serviceDescription: "Barefoot trim",
            cost: 85.00,
            nextDueDate: dayOffset(-2, hour: 11)  // Same day as trim
        )
        barefoot.horse = horses.count > 1 ? horses[1] : nil
        visits.append(barefoot)

        return visits
    }

    static func createDentistVisits(horses: [Horse]) -> [DentistVisit] {
        let calendar = Calendar.current
        var visits: [DentistVisit] = []

        let floatVisit = DentistVisit(
            date: calendar.date(byAdding: .month, value: -3, to: .now) ?? .now,
            dentistName: "Dr. Lisa Morgan",
            serviceDescription: "Routine dental float",
            cost: 200.00,
            nextDueDate: dayOffset(5, hour: 10)
        )
        floatVisit.horse = horses.first
        visits.append(floatVisit)

        let wolfTeeth = DentistVisit(
            date: calendar.date(byAdding: .month, value: -6, to: .now) ?? .now,
            dentistName: "Dr. Lisa Morgan",
            serviceDescription: "Wolf teeth extraction",
            cost: 350.00,
            nextDueDate: dayOffset(30, hour: 9)
        )
        wolfTeeth.horse = horses.count > 2 ? horses[2] : nil
        visits.append(wolfTeeth)

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

    /// Helper: today at a specific hour
    private static func todayAt(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }

    /// Helper: a day offset from today at a specific hour
    private static func dayOffset(_ days: Int, hour: Int) -> Date {
        let day = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    static func createLessons(horses: [Horse], clients: [Client]) -> [Lesson] {
        let jane = clients.first
        let mike = clients.count > 1 ? clients[1] : nil
        let sarah = clients.count > 2 ? clients[2] : nil
        var lessons: [Lesson] = []

        func add(_ date: Date, _ dur: Int, _ type: LessonType, _ notes: String,
                 _ cost: Double, paid: Bool, horse: Horse?, client: Client?,
                 nextDate: Date?) {
            let l = Lesson(date: date, duration: dur, lessonType: type, notes: notes,
                           cost: cost, isPaid: paid, frequency: .weekly, nextDate: nextDate)
            l.horse = horse
            l.client = client
            lessons.append(l)
        }

        // Lessons with nextDate spread across the current week
        // Mon/Tue lessons (past this week — still shows on calendar)
        add(dayOffset(-10, hour: 10), 60, .privateLesson, "Flatwork and jumping basics",
            75, paid: true, horse: horses[0], client: jane,
            nextDate: dayOffset(-3, hour: 10))

        add(dayOffset(-9, hour: 14), 45, .privateLesson, "Walk/trot fundamentals",
            75, paid: true, horse: horses[0], client: sarah,
            nextDate: dayOffset(-2, hour: 14))

        // Wed lesson
        add(dayOffset(-8, hour: 11), 60, .privateLesson, "Dressage fundamentals",
            75, paid: true, horse: horses[2], client: mike,
            nextDate: dayOffset(-1, hour: 11))

        // Today — two lessons
        add(dayOffset(-7, hour: 10), 60, .privateLesson, "Canter work and lead changes",
            75, paid: false, horse: horses[0], client: jane,
            nextDate: todayAt(hour: 10))

        add(dayOffset(-7, hour: 16), 90, .group, "Group trail ride and horsemanship",
            50, paid: true, horse: horses.count > 3 ? horses[3] : nil, client: jane,
            nextDate: todayAt(hour: 16))

        // Tomorrow + weekend
        add(dayOffset(-6, hour: 9), 60, .training, "Jump course practice — Cleo",
            100, paid: true, horse: horses.count > 4 ? horses[4] : nil, client: mike,
            nextDate: dayOffset(1, hour: 9))

        add(dayOffset(-5, hour: 15), 45, .privateLesson, "Posting trot and diagonals",
            75, paid: false, horse: horses.count > 3 ? horses[3] : nil, client: sarah,
            nextDate: dayOffset(2, hour: 15))

        return lessons
    }

    static func createReminders(horses: [Horse]) -> [Reminder] {
        var reminders: [Reminder] = []

        func add(_ title: String, _ notes: String, _ dueDate: Date,
                 _ freq: ReminderFrequency, horse: Horse? = nil) {
            let r = Reminder(title: title, notes: notes, dueDate: dueDate,
                             isCompleted: false, frequency: freq)
            r.horse = horse
            reminders.append(r)
        }

        // This week — spread across days for a compelling week view
        add("Stall bedding refresh", "Replace shavings in A1 and B2",
            dayOffset(-3, hour: 8), .once)
        add("Order grain refill", "Sweet feed running low — 3 bags left",
            dayOffset(-2, hour: 9), .once)
        add("Hay delivery", "40 bales timothy — confirm with supplier",
            dayOffset(-1, hour: 8), .monthly)
        add("Deworming — Arrow", "Ivermectin rotation",
            dayOffset(0, hour: 9), .quarterly, horse: horses.first)
        add("Check pasture fencing", "North paddock gate was loose yesterday",
            dayOffset(1, hour: 7), .once)
        add("Barn inspection", "County inspector visiting at 2 PM",
            dayOffset(2, hour: 14), .once)

        // Future
        add("Farrier visit — all horses", "Tom Bradley scheduled",
            dayOffset(10, hour: 9), .monthly)
        add("Dental checkup — Bella", "Dr. Chen, annual float",
            dayOffset(60, hour: 10), .annually, horse: horses.count > 1 ? horses[1] : nil)

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
