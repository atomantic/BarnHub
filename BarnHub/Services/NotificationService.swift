import Foundation
import UserNotifications
import SwiftData
import CoreData

// MARK: - Notification center abstraction

/// The slice of `UNUserNotificationCenter` that `NotificationService` uses, so
/// tests can swap in an in-memory fake.
protocol NotificationCenterScheduling: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterScheduling {
    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

extension Notification.Name {
    /// Posted after `ModelContext.saveWithLogging()` / `deleteWithLogging(_:)`
    /// succeed, so derived state (pending notifications) follows every edit,
    /// including cascade deletes of a horse and Delete All.
    static let barnHubModelContextDidSave = Notification.Name("net.shadowpuppet.BarnBook.modelContextDidSave")
}

// MARK: - Planning

/// Something with a due date that may deserve a notification.
struct NotificationDueItem: Equatable {
    enum Kind: String { case reminder, vet, farrier, dentist }

    /// Stable per-record key, e.g. `reminder-<uuid>`.
    let key: String
    let kind: Kind
    let title: String
    let body: String
    let deepLink: String
    let dueDate: Date
}

/// One notification request the service wants pending.
struct PlannedNotification: Equatable {
    enum Trigger: Equatable {
        /// Fire at this local date and time.
        case at(Date)
        /// Already late today: fire shortly after scheduling.
        case soon
    }

    let identifier: String
    let title: String
    let body: String
    let deepLink: String
    /// When the notification is meant for (8:00 on the due day, or 7:00 for the
    /// summary). Used for ordering and change detection.
    let fireDate: Date
    let trigger: Trigger

    /// Stored in `userInfo` so a pending request can be compared with the plan
    /// without decoding its trigger.
    var fingerprint: String {
        "\(title)|\(body)|\(deepLink)|\(Int(fireDate.timeIntervalSince1970))"
    }
}

struct NotificationPlan: Equatable {
    var items: [PlannedNotification]
    var summary: PlannedNotification?

    var all: [PlannedNotification] { items + (summary.map { [$0] } ?? []) }
}

/// Pure scheduling rules, kept free of SwiftData and UserNotifications so they
/// can be tested directly.
enum NotificationPlanner {
    /// Local hour that per-item notifications fire on their due day.
    static let itemHour = 8
    /// Local hour of the morning summary.
    static let summaryHour = 7
    /// iOS keeps at most 64 pending requests per app; leave room for the summary.
    static let maxItemRequests = 60
    static let summaryIdentifier = "morning-summary"

    /// - Parameters:
    ///   - lateIdentifiersAlreadyScheduled: "fire soon" requests already handed
    ///     to the system today. Once delivered (no longer pending) they are not
    ///     planned again, or every app activation would repeat them.
    ///   - pendingIdentifiers: identifiers currently pending.
    static func plan(
        items: [NotificationDueItem],
        now: Date,
        calendar: Calendar = .current,
        lateIdentifiersAlreadyScheduled: Set<String> = [],
        pendingIdentifiers: Set<String> = []
    ) -> NotificationPlan {
        let today = calendar.startOfDay(for: now)
        var planned: [PlannedNotification] = []

        for item in items {
            let dueDay = calendar.startOfDay(for: item.dueDate)
            // Overdue items only appear in the morning summary.
            guard dueDay >= today,
                  let fireDate = calendar.date(bySettingHour: itemHour, minute: 0, second: 0, of: dueDay)
            else { continue }

            let stamp = dayStamp(dueDay, calendar: calendar)
            if fireDate > now {
                planned.append(PlannedNotification(
                    identifier: "\(item.key)-\(stamp)",
                    title: item.title, body: item.body, deepLink: item.deepLink,
                    fireDate: fireDate, trigger: .at(fireDate)
                ))
            } else {
                // Due today but 8:00 has passed (e.g. added this afternoon):
                // notify once, shortly, instead of dropping it.
                let identifier = "\(item.key)-\(stamp)-late"
                if lateIdentifiersAlreadyScheduled.contains(identifier),
                   !pendingIdentifiers.contains(identifier) {
                    continue
                }
                planned.append(PlannedNotification(
                    identifier: identifier,
                    title: item.title, body: item.body, deepLink: item.deepLink,
                    fireDate: fireDate, trigger: .soon
                ))
            }
        }

        planned.sort { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
        return NotificationPlan(
            items: Array(planned.prefix(maxItemRequests)),
            summary: summary(items: items, now: now, calendar: calendar)
        )
    }

    /// A single-shot summary at the next 7:00, counting what will be overdue or
    /// due that day. Recomputed on every sync, so it never goes stale.
    static func summary(items: [NotificationDueItem], now: Date, calendar: Calendar = .current) -> PlannedNotification? {
        guard let todayAtHour = calendar.date(bySettingHour: summaryHour, minute: 0, second: 0, of: now),
              let fireDate = todayAtHour > now ? todayAtHour : calendar.date(byAdding: .day, value: 1, to: todayAtHour)
        else { return nil }
        let summaryDay = calendar.startOfDay(for: fireDate)

        var overdue = 0
        var dueToday = 0
        for item in items {
            let dueDay = calendar.startOfDay(for: item.dueDate)
            if dueDay < summaryDay {
                overdue += 1
            } else if dueDay == summaryDay {
                dueToday += 1
            }
        }
        guard overdue > 0 || dueToday > 0 else { return nil }

        return PlannedNotification(
            identifier: summaryIdentifier,
            title: appLocalized("Good Morning from BarnHub", comment: "Morning summary notification title"),
            body: summaryBody(overdue: overdue, dueToday: dueToday),
            deepLink: "barnhub://home",
            fireDate: fireDate,
            trigger: .at(fireDate)
        )
    }

    static func summaryBody(overdue: Int, dueToday: Int) -> String {
        switch (overdue > 0, dueToday > 0) {
        case (true, true):
            return appLocalized("You have \(overdue) overdue tasks and \(dueToday) tasks due today.",
                                comment: "Morning summary body: overdue and due-today task counts")
        case (true, false):
            return appLocalized("You have \(overdue) overdue tasks.",
                                comment: "Morning summary body: overdue task count")
        default:
            return appLocalized("You have \(dueToday) tasks due today.",
                                comment: "Morning summary body: due-today task count")
        }
    }

    /// Locale-independent `yyyyMMdd`.
    static func dayStamp(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - Service

/// Keeps the app's pending local notifications in line with the store.
///
/// Every sync rebuilds the wanted set (incomplete reminders plus the latest
/// vet/farrier/dentist record per horse), caps it below iOS's 64-request limit,
/// and diffs it against what is pending: stale requests are removed and missing
/// or changed ones added. Syncs run on launch, on scene activation, after
/// `saveWithLogging()`, and after CloudKit imports (`NSPersistentStoreRemoteChange`).
@MainActor
@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    @ObservationIgnored private let center: NotificationCenterScheduling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: () -> Date

    @ObservationIgnored private weak var context: ModelContext?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pendingSync: Task<Void, Never>?
    @ObservationIgnored private var isSyncing = false
    @ObservationIgnored private var needsResync = false

    private static let lateIdentifiersKey = "net.shadowpuppet.BarnBook.notifications.lateIdentifiers"

    init(
        center: NotificationCenterScheduling = UNUserNotificationCenter.current(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now }
    ) {
        self.center = center
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    // MARK: Authorization

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            BarnHubLogger.info("Notification authorization granted=\(granted)")
            if granted { requestSync(delay: .zero) }
        } catch {
            BarnHubLogger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func refreshAuthorizationStatus() async {
        isAuthorized = Self.allowsScheduling(await center.currentAuthorizationStatus())
    }

    private static func allowsScheduling(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional
    }

    /// Removes every pending and delivered BarnHub notification, after Delete All
    /// Data. The save hook's sync would drop pending requests for deleted records
    /// too, but only when authorized and attached; this also clears delivered
    /// ones and the morning summary. Static so the Mac Settings window, which has
    /// no NotificationService in its environment, can call it.
    static func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        UserDefaults.standard.removeObject(forKey: lateIdentifiersKey)
        BarnHubLogger.info("Cancelled all notifications")
    }

    // MARK: Triggers

    /// Binds the service to the app's main context and starts following saves
    /// and CloudKit imports. Safe to call more than once.
    func attach(to context: ModelContext) {
        self.context = context
        guard observers.isEmpty else { return }
        let triggers: [(Notification.Name, Duration)] = [
            (.barnHubModelContextDidSave, .milliseconds(300)),
            // CloudKit imports arrive in bursts; let them settle first.
            (.NSPersistentStoreRemoteChange, .seconds(2)),
        ]
        // The service lives as long as the app; the observers hold it weakly.
        observers = triggers.map { name, delay in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.requestSync(delay: delay) }
            }
        }
    }

    /// Debounced sync: bursts of saves or remote changes collapse into one pass.
    func requestSync(delay: Duration = .milliseconds(300)) {
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Brings pending requests in line with the store. Overlapping calls are
    /// coalesced into one extra pass rather than interleaving.
    func sync(context explicitContext: ModelContext? = nil) async {
        guard let context = explicitContext ?? context else { return }
        if isSyncing {
            needsResync = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsResync = false
            await performSync(context: context)
        } while needsResync
    }

    private func performSync(context: ModelContext) async {
        isAuthorized = Self.allowsScheduling(await center.currentAuthorizationStatus())
        guard isAuthorized else { return }

        let items: [NotificationDueItem]
        do {
            items = try Self.dueItems(in: context)
        } catch {
            BarnHubLogger.error("Notification sync fetch failed: \(error.localizedDescription)")
            return
        }

        let currentDate = now()
        let pending = await center.pendingNotificationRequests()
        let pendingFingerprints = Dictionary(
            pending.map { ($0.identifier, $0.content.userInfo["fingerprint"] as? String) },
            uniquingKeysWith: { first, _ in first }
        )
        var lateIdentifiers = storedLateIdentifiers(today: currentDate)
        let plan = NotificationPlanner.plan(
            items: items,
            now: currentDate,
            calendar: calendar,
            lateIdentifiersAlreadyScheduled: lateIdentifiers,
            pendingIdentifiers: Set(pendingFingerprints.keys)
        )
        let wanted = Dictionary(plan.all.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })

        let stale = pendingFingerprints.compactMap { identifier, fingerprint in
            wanted[identifier]?.fingerprint == fingerprint ? nil : identifier
        }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        var added = 0
        for planned in plan.all where pendingFingerprints[planned.identifier] != planned.fingerprint {
            do {
                try await center.add(makeRequest(planned))
                added += 1
                if planned.trigger == .soon { lateIdentifiers.insert(planned.identifier) }
            } catch {
                BarnHubLogger.error("Failed to schedule notification id=\(planned.identifier): \(error.localizedDescription)")
            }
        }
        defaults.set(Array(lateIdentifiers), forKey: Self.lateIdentifiersKey)

        BarnHubLogger.info("Notification sync candidates=\(items.count) wanted=\(wanted.count) removed=\(stale.count) added=\(added)")
    }

    /// Late identifiers scheduled today (older days are dropped).
    private func storedLateIdentifiers(today: Date) -> Set<String> {
        let suffix = "-\(NotificationPlanner.dayStamp(today, calendar: calendar))-late"
        let stored = defaults.stringArray(forKey: Self.lateIdentifiersKey) ?? []
        return Set(stored.filter { $0.hasSuffix(suffix) })
    }

    private func makeRequest(_ planned: PlannedNotification) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default
        content.userInfo = ["deepLink": planned.deepLink, "fingerprint": planned.fingerprint]

        let trigger: UNNotificationTrigger
        switch planned.trigger {
        case .at(let date):
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .soon:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        }
        return UNNotificationRequest(identifier: planned.identifier, content: content, trigger: trigger)
    }

    // MARK: Candidates

    /// Incomplete reminders plus, per horse, the latest vet, farrier and dentist
    /// record. An older record's `nextDueDate` is superseded by the newer visit,
    /// so it is never scheduled. Assigns missing notification keys (rows created
    /// before the key existed) and saves them.
    static func dueItems(in context: ModelContext) throws -> [NotificationDueItem] {
        var items: [NotificationDueItem] = []
        var assignedKeys = false
        func key(_ prefix: String, _ stored: inout UUID?) -> String {
            let value = stored ?? UUID()
            if stored == nil {
                stored = value
                assignedKeys = true
            }
            return "\(prefix)-\(value.uuidString)"
        }
        let fallbackHorse = appLocalized("Horse", comment: "Fallback name for horse in notification")
        func body(_ horse: Horse?, _ detail: String) -> String {
            let name = horse?.name ?? fallbackHorse
            return detail.isEmpty ? name : "\(name) — \(detail)"
        }

        let reminderTitle = appLocalized("Reminder", comment: "Notification title for a reminder")
        let reminders = try context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { !$0.isCompleted }))
        for reminder in reminders {
            let text = reminder.horse.map { "\(reminder.title) — \($0.name)" } ?? reminder.title
            items.append(NotificationDueItem(
                key: key("reminder", &reminder.notificationKey), kind: .reminder, title: reminderTitle,
                body: text, deepLink: "barnhub://schedule/reminders", dueDate: reminder.dueDate
            ))
        }

        let vetTitle = appLocalized("Vet Appointment Due", comment: "Notification title for vet appointment")
        let vetRecords = try context.fetch(FetchDescriptor<VetRecord>())
        for record in latestPerHorse(vetRecords, horse: { $0.horse }, date: { $0.date }, due: { $0.nextDueDate }) {
            guard let due = record.nextDueDate else { continue }
            items.append(NotificationDueItem(
                key: key("vet", &record.notificationKey), kind: .vet, title: vetTitle,
                body: body(record.horse, record.vetName), deepLink: "barnhub://schedule/vet", dueDate: due
            ))
        }

        let farrierTitle = appLocalized("Farrier Visit Due", comment: "Notification title for farrier visit")
        let farrierVisits = try context.fetch(FetchDescriptor<FarrierVisit>())
        for visit in latestPerHorse(farrierVisits, horse: { $0.horse }, date: { $0.date }, due: { $0.nextDueDate }) {
            guard let due = visit.nextDueDate else { continue }
            items.append(NotificationDueItem(
                key: key("farrier", &visit.notificationKey), kind: .farrier, title: farrierTitle,
                body: body(visit.horse, visit.farrierName), deepLink: "barnhub://schedule/farrier", dueDate: due
            ))
        }

        let dentistTitle = appLocalized("Dentist Visit Due", comment: "Notification title for dentist visit")
        let dentistVisits = try context.fetch(FetchDescriptor<DentistVisit>())
        for visit in latestPerHorse(dentistVisits, horse: { $0.horse }, date: { $0.date }, due: { $0.nextDueDate }) {
            guard let due = visit.nextDueDate else { continue }
            items.append(NotificationDueItem(
                key: key("dentist", &visit.notificationKey), kind: .dentist, title: dentistTitle,
                body: body(visit.horse, visit.dentistName), deepLink: "barnhub://schedule/dentist", dueDate: due
            ))
        }

        if assignedKeys {
            try context.save()
        }
        return items
    }

    /// The most recent record (by visit date, then next due date) for each horse.
    /// Records without a horse each stand alone.
    static func latestPerHorse<T: PersistentModel>(
        _ records: [T],
        horse: (T) -> Horse?,
        date: (T) -> Date,
        due: (T) -> Date?
    ) -> [T] {
        var latest: [PersistentIdentifier: T] = [:]
        for record in records {
            let groupKey = horse(record)?.persistentModelID ?? record.persistentModelID
            if let current = latest[groupKey] {
                let isNewer = (date(record), due(record) ?? .distantPast) > (date(current), due(current) ?? .distantPast)
                if isNewer { latest[groupKey] = record }
            } else {
                latest[groupKey] = record
            }
        }
        return Array(latest.values)
    }
}

// MARK: - Delegate

/// Shows notifications while the app is in front and turns taps into deep
/// links. Installed as the notification center's delegate in `BarnHubApp.init`
/// so a tap that cold-launches the app is not lost; the link waits in
/// `pendingDeepLink` until the root view routes it.
@MainActor
@Observable
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private(set) var pendingDeepLink: URL?

    /// Returns and clears the pending link.
    func consumeDeepLink() -> URL? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    func receive(deepLink: String?) {
        guard let deepLink, let url = URL(string: deepLink) else { return }
        pendingDeepLink = url
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let link = response.notification.request.content.userInfo["deepLink"] as? String
        Task { @MainActor in
            NotificationDelegate.shared.receive(deepLink: link)
            completionHandler()
        }
    }
}
