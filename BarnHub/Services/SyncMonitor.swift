import CoreData
import Foundation
import SwiftUI

enum SyncStatus: Equatable {
    case idle
    case syncing
    case succeeded(Date)
    case failed
    case notAvailable

    var label: String {
        switch self {
        case .idle:         return appLocalized("Waiting",            comment: "Sync status")
        case .syncing:      return appLocalized("Syncing…",           comment: "Sync status")
        case .succeeded:    return appLocalized("Up to date",         comment: "Sync status")
        case .failed:       return appLocalized("Sync paused",        comment: "Sync status shown when CloudKit sync can't complete")
        case .notAvailable: return appLocalized("iCloud unavailable", comment: "Sync status")
        }
    }

    var icon: String {
        switch self {
        case .idle: "cloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .succeeded: "checkmark.icloud"
        case .failed: "cloud"
        case .notAvailable: "icloud.slash"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .syncing: .barnGreen
        case .succeeded: .barnGreen
        case .failed: .secondary
        case .notAvailable: .secondary
        }
    }
}

@Observable
final class SyncMonitor {
    private(set) var status: SyncStatus = .idle
    private(set) var lastSuccessfulSync: Date?

    private var importStatus: SyncStatus = .idle
    private var exportStatus: SyncStatus = .idle

    /// Whether an iCloud account is signed in; injectable for tests.
    private let hasAccount: () -> Bool
    private let notificationCenter: NotificationCenter

    /// Observes CloudKit events and iCloud account changes even when no account
    /// is signed in at launch, so signing in later (or switching accounts)
    /// recovers from "iCloud unavailable" without relaunching.
    init(
        notificationCenter: NotificationCenter = .default,
        hasAccount: @escaping () -> Bool = { FileManager.default.ubiquityIdentityToken != nil }
    ) {
        self.hasAccount = hasAccount
        self.notificationCenter = notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSyncEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleIdentityChange(_:)),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
        updateAccountAvailability()
        BarnHubLogger.info("SyncMonitor started, listening for CloudKit events and account changes")
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    @objc private func handleIdentityChange(_ notification: Notification) {
        Task { @MainActor in
            self.updateAccountAvailability()
        }
    }

    /// Shows "iCloud unavailable" while signed out; on sign-in, goes back to
    /// waiting for the first sync event.
    func updateAccountAvailability() {
        if !hasAccount() {
            if status != .notAvailable {
                status = .notAvailable
                BarnHubLogger.warning("iCloud account not available")
            }
        } else if status == .notAvailable {
            importStatus = .idle
            exportStatus = .idle
            resolveStatus()
            BarnHubLogger.info("iCloud account available")
        }
    }

    @objc private func handleSyncEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return }

        let type = event.type
        let ended = event.endDate != nil
        let error = event.error

        Task { @MainActor in
            if type == .setup {
                if ended {
                    if let error {
                        BarnHubLogger.error("CloudKit setup failed: \(error.localizedDescription)")
                    } else {
                        BarnHubLogger.success("CloudKit setup complete")
                    }
                }
                return
            }

            let eventStatus: SyncStatus
            if !ended {
                eventStatus = .syncing
            } else if let error {
                eventStatus = .failed
                BarnHubLogger.error("CloudKit \(type == .import ? "import" : "export") failed: \(error.localizedDescription)")
            } else {
                eventStatus = .succeeded(Date())
                BarnHubLogger.success("CloudKit \(type == .import ? "import" : "export") completed")
            }

            if type == .import {
                importStatus = eventStatus
            } else {
                exportStatus = eventStatus
            }

            resolveStatus()
        }
    }

    private func resolveStatus() {
        // Without an account, sync events (failed setups) don't change what we show.
        let newStatus = !hasAccount() ? .notAvailable : computeStatus()
        if let date = latestSucceededDate(), lastSuccessfulSync != date {
            lastSuccessfulSync = date
        }
        if status != newStatus { status = newStatus }
    }

    private func computeStatus() -> SyncStatus {
        if case .syncing = importStatus { return .syncing }
        if case .syncing = exportStatus { return .syncing }

        // Surface failures only after a prior successful sync — fresh installs
        // commonly hit transient errors (CloudKit setup, account reconciliation)
        // that aren't meaningful to the user.
        if lastSuccessfulSync != nil, importStatus == .failed || exportStatus == .failed {
            return .failed
        }

        if let latest = latestSucceededDate() {
            return .succeeded(latest)
        }
        return .idle
    }

    private func latestSucceededDate() -> Date? {
        var latest: Date?
        if case .succeeded(let d) = importStatus { latest = d }
        if case .succeeded(let d) = exportStatus {
            latest = latest.map { max($0, d) } ?? d
        }
        return latest
    }
}
