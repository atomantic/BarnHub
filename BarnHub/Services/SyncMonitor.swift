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

    init() {
        if FileManager.default.ubiquityIdentityToken == nil {
            status = .notAvailable
            BarnHubLogger.warning("iCloud account not available")
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil
        )
        BarnHubLogger.info("SyncMonitor started, listening for CloudKit events")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        let newStatus = computeStatus()
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
