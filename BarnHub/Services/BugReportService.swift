import Foundation
import SwiftData
import UserNotifications
#if os(iOS)
import UIKit
#endif

// MARK: - Storage mode

/// Which kind of store the app's ModelContainer ended up with. Set once at launch
/// by `BarnHubApp` so bug reports can tell support when data isn't syncing because
/// the app fell back to an in-memory store.
enum StorageMode: String {
    case cloudKit = "CloudKit (persistent)"
    case inMemorySeed = "In-memory (sample data)"
    case inMemoryFallback = "In-memory FALLBACK (persistent store failed to open)"

    static var current: StorageMode = .cloudKit
}

// MARK: - Redaction

/// Strips personal data from free-form diagnostic text (log messages) before it is
/// stored or sent: email addresses, phone-like numbers, URL query strings, and
/// user home directory names.
enum DiagnosticsRedactor {
    private static let rules: [(pattern: String, replacement: String)] = [
        (#"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}"#, "<email>"),
        (#"(https?://[^\s?]+)\?[^\s]*"#, "$1?<query>"),
        (#"/Users/[^/\s]+"#, "/Users/<user>"),
        (#"\+?\d[\d\s().\-]{6,}\d"#, "<number>"),
    ]

    static func scrub(_ text: String) -> String {
        rules.reduce(text) { result, rule in
            result.replacingOccurrences(
                of: rule.pattern,
                with: rule.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
    }
}

// MARK: - Diagnostics

/// A snapshot of non-personal app state attached to bug reports.
///
/// It deliberately contains no horse, client, contact, financial, or note content:
/// only app/device facts, settings, sync state, record *counts*, and scrubbed
/// recent warnings/errors. The text is written in English because it is read by
/// support, not shown as app UI.
struct AppDiagnostics: Equatable {
    struct RecordCount: Equatable {
        let name: String
        let count: Int
    }

    var generatedAt: Date
    var appVersion: String
    var buildNumber: String
    var distribution: String
    var platform: String
    var osVersion: String
    var deviceModel: String
    var appLanguage: String
    var deviceLocale: String
    var timeZone: String
    var currency: String
    var appearance: String
    var subscription: String
    var iCloudAccountAvailable: Bool
    var syncStatus: String
    var lastSuccessfulSync: Date?
    var storageMode: String
    var notifications: String
    var freeDiskSpace: String?
    var recordCounts: [RecordCount]
    var recentLogs: [RecentLogBuffer.Entry]

    var formatted: String {
        var lines: [String] = [
            "Generated: \(Self.timestamp(generatedAt))",
            "",
            "[App]",
            "Version: \(appVersion) (\(buildNumber))",
            "Distribution: \(distribution)",
            "Storage: \(storageMode)",
            "Subscription: \(subscription)",
            "",
            "[Device]",
            "Platform: \(platform) \(osVersion)",
            "Model: \(deviceModel)",
        ]
        if let freeDiskSpace { lines.append("Free space: \(freeDiskSpace)") }
        lines += [
            "",
            "[Settings]",
            "App language: \(appLanguage)",
            "Device locale: \(deviceLocale)",
            "Time zone: \(timeZone)",
            "Currency: \(currency)",
            "Appearance: \(appearance)",
            "Notifications: \(notifications)",
            "",
            "[iCloud Sync]",
            "iCloud account: \(iCloudAccountAvailable ? "available" : "NOT available")",
            "Status: \(syncStatus)",
            "Last successful sync: \(lastSuccessfulSync.map(Self.timestamp) ?? "never this session")",
            "",
            "[Record counts]",
        ]
        lines += recordCounts.map { "\($0.name): \($0.count)" }
        lines += ["", "[Recent warnings & errors (\(recentLogs.count))]"]
        if recentLogs.isEmpty {
            lines.append("none this session")
        } else {
            lines += recentLogs.map { "\(Self.timestamp($0.date)) \($0.level.rawValue) \($0.message)" }
        }
        return lines.joined(separator: "\n")
    }

    static func timestamp(_ date: Date) -> String {
        date.formatted(.iso8601)
    }
}

extension SyncStatus {
    /// English, support-facing description (the UI uses the localized `label`).
    var diagnosticDescription: String {
        switch self {
        case .idle: "idle (no sync events yet)"
        case .syncing: "syncing"
        case .succeeded(let date): "succeeded at \(AppDiagnostics.timestamp(date))"
        case .failed: "FAILED (last import or export errored)"
        case .notAvailable: "not available (no iCloud account)"
        }
    }
}

// MARK: - Collection

enum DiagnosticsCollector {
    @MainActor
    static func collect(
        context: ModelContext,
        isPro: Bool,
        hasLifetime: Bool,
        syncMonitor: SyncMonitor,
        appearance: AppearanceMode,
        logBuffer: RecentLogBuffer = .shared
    ) async -> AppDiagnostics {
        let info = Bundle.main.infoDictionary
        let defaults = UserDefaults.standard
        let appLocale = defaults.string(forKey: "net.shadowpuppet.BarnBook.appLocale") ?? ""
        let currency = defaults.string(forKey: "net.shadowpuppet.BarnBook.currencyCode") ?? ""

        return AppDiagnostics(
            generatedAt: Date(),
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "—",
            buildNumber: info?["CFBundleVersion"] as? String ?? "—",
            distribution: distribution,
            platform: platformName,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: deviceModelIdentifier,
            appLanguage: appLocale.isEmpty ? "System default" : appLocale,
            deviceLocale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            currency: currency.isEmpty ? "USD (default)" : currency,
            appearance: String(describing: appearance),
            subscription: hasLifetime ? "Pro (lifetime)" : (isPro ? "Pro (subscription)" : "Free"),
            iCloudAccountAvailable: FileManager.default.ubiquityIdentityToken != nil,
            syncStatus: syncMonitor.status.diagnosticDescription,
            lastSuccessfulSync: syncMonitor.lastSuccessfulSync,
            storageMode: StorageMode.current.rawValue,
            notifications: await notificationStatus(),
            freeDiskSpace: freeDiskSpace,
            recordCounts: recordCounts(in: context),
            recentLogs: logBuffer.snapshot
        )
    }

    @MainActor
    static func recordCounts(in context: ModelContext) -> [AppDiagnostics.RecordCount] {
        func count<T: PersistentModel>(_ type: T.Type, _ name: String) -> AppDiagnostics.RecordCount {
            AppDiagnostics.RecordCount(name: name, count: (try? context.fetchCount(FetchDescriptor<T>())) ?? -1)
        }
        return [
            count(Horse.self, "Horses"),
            count(Client.self, "Clients"),
            count(Transaction.self, "Transactions"),
            count(Invoice.self, "Invoices"),
            count(VetRecord.self, "Vet records"),
            count(FarrierVisit.self, "Farrier visits"),
            count(DentistVisit.self, "Dentist visits"),
            count(WeightEntry.self, "Weight entries"),
            count(Reminder.self, "Reminders"),
            count(Lesson.self, "Lessons"),
            count(SupplyItem.self, "Supplies"),
            count(FeedProduct.self, "Feed products"),
            count(FeedPlanEntry.self, "Feed plan entries"),
            count(BarnNote.self, "Barn notes"),
            count(HorseDocument.self, "Horse documents"),
            count(ClientDocument.self, "Client documents"),
        ]
    }

    private static func notificationStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .notDetermined: return "not determined"
        case .provisional: return "provisional"
        #if os(iOS)
        case .ephemeral: return "ephemeral"
        #endif
        @unknown default: return "unknown"
        }
    }

    private static var distribution: String {
        #if DEBUG
        return "Debug"
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return "TestFlight"
        }
        return "App Store"
        #endif
    }

    private static var platformName: String {
        #if targetEnvironment(macCatalyst)
        return "Mac Catalyst"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "unknown"
        #endif
    }

    /// Hardware identifier such as "iPhone16,2" or "Mac14,7" (never the user-set device name).
    private static var deviceModelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "\(simulated) (Simulator)"
        }
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
        #endif
    }

    private static var freeDiskSpace: String? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Report

enum BugReport {
    static let supportEmail = "support@barnhub.online"

    /// mailto: URLs get unreliable past a few thousand characters, so the fallback
    /// path trims diagnostics (oldest log lines go first) to stay under this.
    static let mailtoBodyLimit = 6000

    static func subject(diagnostics: AppDiagnostics?) -> String {
        guard let diagnostics else { return "BarnHub Bug Report" }
        return "BarnHub Bug Report (v\(diagnostics.appVersion) build \(diagnostics.buildNumber), \(diagnostics.platform))"
    }

    static func body(description: String, steps: String, diagnostics: AppDiagnostics?) -> String {
        var sections: [String] = [
            "What happened:",
            description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "(not provided)" : description.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        let trimmedSteps = steps.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSteps.isEmpty {
            sections += ["", "Steps to reproduce:", trimmedSteps]
        }
        if let diagnostics {
            sections += ["", "---", "Diagnostics (no personal data included):", diagnostics.formatted]
        }
        return sections.joined(separator: "\n")
    }

    /// Builds a mailto: URL, dropping the oldest log lines if the body is too long.
    static func mailtoURL(description: String, steps: String, diagnostics: AppDiagnostics?) -> URL? {
        var trimmed = diagnostics
        var body = Self.body(description: description, steps: steps, diagnostics: trimmed)
        while body.count > mailtoBodyLimit, var d = trimmed, !d.recentLogs.isEmpty {
            d.recentLogs.removeFirst(max(1, d.recentLogs.count / 4))
            trimmed = d
            body = Self.body(description: description, steps: steps, diagnostics: trimmed)
        }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject(diagnostics: diagnostics)),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
