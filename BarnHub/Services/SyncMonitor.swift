import CoreData
import Foundation
import SwiftUI

enum SyncStatus: Equatable {
    case idle
    case syncing
    case succeeded(Date)
    case failed(String)
    case notAvailable

    var label: String {
        switch self {
        case .idle: String(localized: "Waiting", comment: "Sync status")
        case .syncing: String(localized: "Syncing…", comment: "Sync status")
        case .succeeded: String(localized: "Up to date", comment: "Sync status")
        case .failed: String(localized: "Sync error", comment: "Sync status")
        case .notAvailable: String(localized: "iCloud unavailable", comment: "Sync status")
        }
    }

    var icon: String {
        switch self {
        case .idle: "cloud"
        case .syncing: "arrow.triangle.2.circlepath.icloud"
        case .succeeded: "checkmark.icloud"
        case .failed: "exclamationmark.icloud"
        case .notAvailable: "icloud.slash"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .syncing: .barnGreen
        case .succeeded: .barnGreen
        case .failed: .red
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
    private var setupComplete = false

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
                    setupComplete = error == nil
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
                eventStatus = .failed(error.localizedDescription)
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
        // If either direction is actively syncing, show syncing
        if case .syncing = importStatus { status = .syncing; return }
        if case .syncing = exportStatus { status = .syncing; return }

        // If either failed, show failed
        if case .failed(let msg) = importStatus { status = .failed(msg); return }
        if case .failed(let msg) = exportStatus { status = .failed(msg); return }

        // Both idle or succeeded — pick latest success
        var latest: Date?
        if case .succeeded(let d) = importStatus { latest = d }
        if case .succeeded(let d) = exportStatus {
            if let existing = latest { latest = max(existing, d) } else { latest = d }
        }

        if let latest {
            lastSuccessfulSync = latest
            status = .succeeded(latest)
        } else {
            status = .idle
        }
    }
}
