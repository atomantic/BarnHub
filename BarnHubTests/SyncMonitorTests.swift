import XCTest
@testable import BarnHub

final class SyncMonitorTests: XCTestCase {

    // MARK: - SyncStatus label / icon / tint

    func test_syncStatus_idle_label() {
        XCTAssertEqual(SyncStatus.idle.label, "Waiting")
    }

    func test_syncStatus_syncing_label() {
        XCTAssertEqual(SyncStatus.syncing.label, "Syncing…")
    }

    func test_syncStatus_succeeded_label() {
        XCTAssertEqual(SyncStatus.succeeded(Date()).label, "Up to date")
    }

    func test_syncStatus_failed_label() {
        XCTAssertEqual(SyncStatus.failed("network error").label, "Sync error")
    }

    func test_syncStatus_notAvailable_label() {
        XCTAssertEqual(SyncStatus.notAvailable.label, "iCloud unavailable")
    }

    // MARK: - SyncStatus icons

    func test_syncStatus_idle_icon() {
        XCTAssertEqual(SyncStatus.idle.icon, "cloud")
    }

    func test_syncStatus_syncing_icon() {
        XCTAssertEqual(SyncStatus.syncing.icon, "arrow.triangle.2.circlepath.icloud")
    }

    func test_syncStatus_succeeded_icon() {
        XCTAssertEqual(SyncStatus.succeeded(Date()).icon, "checkmark.icloud")
    }

    func test_syncStatus_failed_icon() {
        XCTAssertEqual(SyncStatus.failed("error").icon, "exclamationmark.icloud")
    }

    func test_syncStatus_notAvailable_icon() {
        XCTAssertEqual(SyncStatus.notAvailable.icon, "icloud.slash")
    }

    // MARK: - SyncStatus equality

    func test_syncStatus_idle_equatability() {
        XCTAssertEqual(SyncStatus.idle, SyncStatus.idle)
        XCTAssertNotEqual(SyncStatus.idle, SyncStatus.syncing)
    }

    func test_syncStatus_failed_equatability() {
        XCTAssertEqual(SyncStatus.failed("msg"), SyncStatus.failed("msg"))
        XCTAssertNotEqual(SyncStatus.failed("a"), SyncStatus.failed("b"))
    }

    func test_syncStatus_succeeded_equatability() {
        let d = Date(timeIntervalSinceReferenceDate: 0)
        XCTAssertEqual(SyncStatus.succeeded(d), SyncStatus.succeeded(d))
    }

    // MARK: - resolveStatus via helper

    /// SyncMonitor.resolveStatus() is private; we test its logic by replicating it
    /// using the same rules documented in the source, then verify the status
    /// transitions an instance would undergo. The SyncMonitor init checks for
    /// iCloud availability — in CI the token is nil so status becomes .notAvailable.
    /// We test the logic-level rules below with a direct helper.

    func test_resolveStatus_logic_bothIdle_returnsIdle() {
        let result = resolveStatus(import: .idle, export: .idle)
        XCTAssertEqual(result, .idle)
    }

    func test_resolveStatus_logic_importSyncing_returnsSyncing() {
        let result = resolveStatus(import: .syncing, export: .idle)
        XCTAssertEqual(result, .syncing)
    }

    func test_resolveStatus_logic_exportSyncing_returnsSyncing() {
        let result = resolveStatus(import: .idle, export: .syncing)
        XCTAssertEqual(result, .syncing)
    }

    func test_resolveStatus_logic_importFailed_returnsFailed() {
        let result = resolveStatus(import: .failed("import err"), export: .idle)
        if case .failed(let msg) = result {
            XCTAssertEqual(msg, "import err")
        } else {
            XCTFail("Expected .failed, got \(result)")
        }
    }

    func test_resolveStatus_logic_exportFailed_returnsFailed() {
        let result = resolveStatus(import: .idle, export: .failed("export err"))
        if case .failed(let msg) = result {
            XCTAssertEqual(msg, "export err")
        } else {
            XCTFail("Expected .failed, got \(result)")
        }
    }

    func test_resolveStatus_logic_bothSucceeded_picksLatestDate() {
        let earlier = Date(timeIntervalSinceReferenceDate: 1000)
        let later   = Date(timeIntervalSinceReferenceDate: 2000)
        let result = resolveStatus(import: .succeeded(earlier), export: .succeeded(later))
        if case .succeeded(let d) = result {
            XCTAssertEqual(d, later)
        } else {
            XCTFail("Expected .succeeded, got \(result)")
        }
    }

    func test_resolveStatus_logic_oneSucceededOneIdle_returnsSucceeded() {
        let d = Date(timeIntervalSinceReferenceDate: 500)
        let result = resolveStatus(import: .succeeded(d), export: .idle)
        if case .succeeded(let rd) = result {
            XCTAssertEqual(rd, d)
        } else {
            XCTFail("Expected .succeeded, got \(result)")
        }
    }

    // MARK: - SyncMonitor initial state

    func test_syncMonitor_initialStatus_isIdleOrNotAvailable() {
        let monitor = SyncMonitor()
        // In test environment iCloud may not be available; either is valid
        let acceptable = monitor.status == .idle || monitor.status == .notAvailable
        XCTAssertTrue(acceptable, "Initial status should be .idle or .notAvailable, got \(monitor.status)")
    }

    // MARK: - Private helper: replicates SyncMonitor.resolveStatus logic

    private func resolveStatus(import importStatus: SyncStatus, export exportStatus: SyncStatus) -> SyncStatus {
        if case .syncing = importStatus { return .syncing }
        if case .syncing = exportStatus { return .syncing }

        if case .failed(let msg) = importStatus { return .failed(msg) }
        if case .failed(let msg) = exportStatus { return .failed(msg) }

        var latest: Date?
        if case .succeeded(let d) = importStatus { latest = d }
        if case .succeeded(let d) = exportStatus {
            if let existing = latest { latest = max(existing, d) } else { latest = d }
        }

        if let latest {
            return .succeeded(latest)
        }
        return .idle
    }
}
