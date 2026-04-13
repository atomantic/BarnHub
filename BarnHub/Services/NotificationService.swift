import Foundation
import UserNotifications
import SwiftData

@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private var lastScheduledDate: Date?

    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isAuthorized = granted }
            BarnHubLogger.info("Notification authorization granted=\(granted)")
        } catch {
            BarnHubLogger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
        await MainActor.run { isAuthorized = authorized }
    }

    // MARK: - Reminder Notifications

    func scheduleReminder(_ reminder: Reminder) {
        guard !reminder.isCompleted else {
            cancelNotification(identifier: reminderID(reminder))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = appLocalized("Reminder", comment: "Notification title for a reminder")
        content.body = reminder.title
        if let horse = reminder.horse {
            content.body += " — \(horse.name)"
        }
        content.sound = .default
        content.userInfo = ["type": "reminder", "deepLink": "barnhub://schedule/reminders"]

        scheduleAtDate(
            reminder.dueDate,
            identifier: reminderID(reminder),
            content: content
        )
    }

    func cancelReminder(_ reminder: Reminder) {
        cancelNotification(identifier: reminderID(reminder))
    }

    // MARK: - Vet Record Notifications

    func scheduleVetRecord(_ record: VetRecord) {
        guard let nextDue = record.nextDueDate else {
            cancelNotification(identifier: vetRecordID(record))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = appLocalized("Vet Appointment Due", comment: "Notification title for vet appointment")
        content.body = "\(record.horse?.name ?? appLocalized("Horse", comment: "Fallback name for horse in notification")) — \(record.vetName)"
        content.sound = .default
        content.userInfo = ["type": "vetRecord", "deepLink": "barnhub://schedule"]

        scheduleAtDate(nextDue, identifier: vetRecordID(record), content: content)
    }

    // MARK: - Farrier Visit Notifications

    func scheduleFarrierVisit(_ visit: FarrierVisit) {
        guard let nextDue = visit.nextDueDate else {
            cancelNotification(identifier: farrierVisitID(visit))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = appLocalized("Farrier Visit Due", comment: "Notification title for farrier visit")
        content.body = "\(visit.horse?.name ?? appLocalized("Horse", comment: "Fallback name for horse in notification")) — \(visit.farrierName)"
        content.sound = .default
        content.userInfo = ["type": "farrierVisit", "deepLink": "barnhub://schedule"]

        scheduleAtDate(nextDue, identifier: farrierVisitID(visit), content: content)
    }

    // MARK: - Dentist Visit Notifications

    func scheduleDentistVisit(_ visit: DentistVisit) {
        guard let nextDue = visit.nextDueDate else {
            cancelNotification(identifier: dentistVisitID(visit))
            return
        }

        let content = UNMutableNotificationContent()
        content.title = appLocalized("Dentist Visit Due", comment: "Notification title for dentist visit")
        content.body = "\(visit.horse?.name ?? appLocalized("Horse", comment: "Fallback name for horse in notification")) — \(visit.dentistName)"
        content.sound = .default
        content.userInfo = ["type": "dentistVisit", "deepLink": "barnhub://schedule"]

        scheduleAtDate(nextDue, identifier: dentistVisitID(visit), content: content)
    }

    // MARK: - Bulk Scheduling

    func scheduleAllPending(context: ModelContext) {
        if let last = lastScheduledDate, Calendar.current.isDateInToday(last) { return }

        do {
            let reminders = try context.fetch(FetchDescriptor<Reminder>())
            let vetRecords = try context.fetch(FetchDescriptor<VetRecord>())
            let farrierVisits = try context.fetch(FetchDescriptor<FarrierVisit>())
            let dentistVisits = try context.fetch(FetchDescriptor<DentistVisit>())

            for reminder in reminders where !reminder.isCompleted {
                scheduleReminder(reminder)
            }
            for record in vetRecords where record.nextDueDate != nil {
                scheduleVetRecord(record)
            }
            for visit in farrierVisits where visit.nextDueDate != nil {
                scheduleFarrierVisit(visit)
            }
            for visit in dentistVisits where visit.nextDueDate != nil {
                scheduleDentistVisit(visit)
            }

            lastScheduledDate = .now
            BarnHubLogger.info("Scheduled notifications reminders=\(reminders.filter { !$0.isCompleted }.count) vet=\(vetRecords.filter { $0.nextDueDate != nil }.count) farrier=\(farrierVisits.filter { $0.nextDueDate != nil }.count) dentist=\(dentistVisits.filter { $0.nextDueDate != nil }.count)")
        } catch {
            BarnHubLogger.error("scheduleAllPending fetch failed: \(error.localizedDescription) — will retry next launch")
        }
    }

    // MARK: - Morning Summary

    func scheduleMorningSummary(overdueCount: Int, todayCount: Int) {
        cancelNotification(identifier: "morning-summary")
        guard overdueCount > 0 || todayCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = appLocalized("Good Morning from BarnHub", comment: "Morning summary notification title")

        var parts: [String] = []
        if overdueCount > 0 {
            parts.append("\(overdueCount) \(appLocalized("overdue", comment: "Morning summary: overdue task count"))")
        }
        if todayCount > 0 {
            parts.append("\(todayCount) \(appLocalized("due today", comment: "Morning summary: tasks due today count"))")
        }
        let taskWord = overdueCount + todayCount == 1
            ? appLocalized("task", comment: "Singular task in morning summary")
            : appLocalized("tasks", comment: "Plural tasks in morning summary")
        content.body = "\(appLocalized("You have", comment: "Morning summary prefix")) \(parts.joined(separator: " \(appLocalized("and", comment: "Conjunction in morning summary")) ")) \(taskWord)."
        content.sound = .default
        content.userInfo = ["type": "morning", "deepLink": "barnhub://home"]

        var dateComponents = DateComponents()
        dateComponents.hour = 7
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning-summary", content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                BarnHubLogger.error("Failed to schedule morning summary: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private Helpers

    private func scheduleAtDate(_ date: Date, identifier: String, content: UNMutableNotificationContent) {
        guard date > .now else { return }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                BarnHubLogger.error("Failed to schedule notification id=\(identifier): \(error.localizedDescription)")
            }
        }
    }

    private func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func reminderID(_ reminder: Reminder) -> String {
        "reminder-\(reminder.persistentModelID)"
    }

    private func vetRecordID(_ record: VetRecord) -> String {
        "vet-\(record.persistentModelID)"
    }

    private func farrierVisitID(_ visit: FarrierVisit) -> String {
        "farrier-\(visit.persistentModelID)"
    }

    private func dentistVisitID(_ visit: DentistVisit) -> String {
        "dentist-\(visit.persistentModelID)"
    }
}
