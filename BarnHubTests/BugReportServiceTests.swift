import XCTest
@testable import BarnHub

final class BugReportServiceTests: XCTestCase {

    private func makeDiagnostics(logs: [RecentLogBuffer.Entry] = []) -> AppDiagnostics {
        AppDiagnostics(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            appVersion: "1.4.0",
            buildNumber: "36",
            distribution: "TestFlight",
            platform: "iOS",
            osVersion: "Version 18.1",
            deviceModel: "iPhone16,2",
            appLanguage: "System default",
            deviceLocale: "en_US",
            timeZone: "America/Denver",
            currency: "USD (default)",
            appearance: "system",
            subscription: "Pro (subscription)",
            iCloudAccountAvailable: true,
            syncStatus: SyncStatus.failed.diagnosticDescription,
            lastSuccessfulSync: nil,
            storageMode: StorageMode.cloudKit.rawValue,
            notifications: "authorized",
            freeDiskSpace: "12 GB",
            recordCounts: [.init(name: "Horses", count: 7), .init(name: "Vet records", count: 21)],
            recentLogs: logs
        )
    }

    // MARK: - Redaction

    func test_scrub_removesEmail() {
        XCTAssertEqual(DiagnosticsRedactor.scrub("Failed for vet@example.com today"), "Failed for <email> today")
    }

    func test_scrub_removesPhoneNumbers() {
        XCTAssertEqual(DiagnosticsRedactor.scrub("call +1 (555) 123-4567 now"), "call <number> now")
    }

    func test_scrub_removesURLQuery() {
        XCTAssertEqual(
            DiagnosticsRedactor.scrub("Unhandled https://barnhub.online/x?client=Jane"),
            "Unhandled https://barnhub.online/x?<query>"
        )
    }

    func test_scrub_removesMacUserName() {
        XCTAssertEqual(
            DiagnosticsRedactor.scrub("write failed at /Users/jane/Library/x.pdf"),
            "write failed at /Users/<user>/Library/x.pdf"
        )
    }

    func test_scrub_keepsOrdinaryErrorText() {
        let message = "CloudKit export failed: The operation couldn't be completed. (CKErrorDomain error 2.)"
        XCTAssertEqual(DiagnosticsRedactor.scrub(message), message)
    }

    // MARK: - Log buffer

    func test_logBuffer_dropsOldestPastCapacity() {
        let buffer = RecentLogBuffer(capacity: 3)
        for i in 1...5 { buffer.append(level: .error, message: "e\(i)") }
        XCTAssertEqual(buffer.snapshot.map(\.message), ["e3", "e4", "e5"])
    }

    func test_logBuffer_scrubsOnAppend() {
        let buffer = RecentLogBuffer()
        buffer.append(level: .warning, message: "bad address a@b.co")
        XCTAssertEqual(buffer.snapshot.first?.message, "bad address <email>")
        XCTAssertEqual(buffer.snapshot.first?.level, .warning)
    }

    // MARK: - Formatting

    func test_formatted_includesKeyFacts() {
        let text = makeDiagnostics().formatted
        XCTAssertTrue(text.contains("Version: 1.4.0 (36)"))
        XCTAssertTrue(text.contains("Model: iPhone16,2"))
        XCTAssertTrue(text.contains("Subscription: Pro (subscription)"))
        XCTAssertTrue(text.contains("Status: FAILED"))
        XCTAssertTrue(text.contains("Last successful sync: never this session"))
        XCTAssertTrue(text.contains("Vet records: 21"))
        XCTAssertTrue(text.contains("none this session"))
    }

    func test_formatted_listsRecentLogs() {
        let entry = RecentLogBuffer.Entry(date: Date(timeIntervalSince1970: 0), level: .error, message: "boom")
        let text = makeDiagnostics(logs: [entry]).formatted
        XCTAssertTrue(text.contains("[Recent warnings & errors (1)]"))
        XCTAssertTrue(text.contains("ERROR boom"))
    }

    // MARK: - Report

    func test_subject_includesVersionAndPlatform() {
        XCTAssertEqual(BugReport.subject(diagnostics: makeDiagnostics()), "BarnHub Bug Report (v1.4.0 build 36, iOS)")
        XCTAssertEqual(BugReport.subject(diagnostics: nil), "BarnHub Bug Report")
    }

    func test_body_omitsDiagnosticsWhenExcluded() {
        let body = BugReport.body(description: "  Crash on save  ", steps: "", diagnostics: nil)
        XCTAssertEqual(body, "What happened:\nCrash on save")
    }

    func test_body_includesStepsAndDiagnostics() {
        let body = BugReport.body(description: "Crash", steps: "1. Open vet record", diagnostics: makeDiagnostics())
        XCTAssertTrue(body.contains("Steps to reproduce:\n1. Open vet record"))
        XCTAssertTrue(body.contains("Diagnostics (no personal data included):"))
    }

    func test_mailtoURL_trimsLongLogs() throws {
        let longLogs = (0..<200).map {
            RecentLogBuffer.Entry(date: Date(), level: .error, message: "error \($0) " + String(repeating: "x", count: 80))
        }
        let url = try XCTUnwrap(BugReport.mailtoURL(description: "Crash", steps: "", diagnostics: makeDiagnostics(logs: longLogs)))
        XCTAssertEqual(url.scheme, "mailto")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, BugReport.supportEmail)
        let body = try XCTUnwrap(components.queryItems?.first { $0.name == "body" }?.value)
        XCTAssertLessThanOrEqual(url.absoluteString.count, BugReport.mailtoURLLimit)
        XCTAssertTrue(body.contains("error 199"), "newest log lines should be kept")
        XCTAssertFalse(body.contains("error 0 "), "oldest log lines should be dropped")
    }

    func test_mailtoURL_returnsNilForLongDescriptionWithoutDiagnostics() {
        let description = String(repeating: "a", count: BugReport.mailtoURLLimit)
        XCTAssertNil(BugReport.mailtoURL(description: description, steps: "", diagnostics: nil))
    }

    func test_mailtoURL_returnsNilForLongSteps() {
        let steps = String(repeating: "step ", count: BugReport.mailtoURLLimit / 4)
        XCTAssertNil(BugReport.mailtoURL(description: "Crash", steps: steps, diagnostics: makeDiagnostics()))
    }

    func test_mailtoURL_accountsForMultibyteEncoding() {
        // 2,000 characters fits decoded, but each "é" percent-encodes to 6 characters.
        let description = String(repeating: "é", count: 2000)
        XCTAssertNil(BugReport.mailtoURL(description: description, steps: "", diagnostics: nil))
    }

    func test_mailtoURL_keepsShortReportIntact() throws {
        let url = try XCTUnwrap(BugReport.mailtoURL(description: "Crash", steps: "", diagnostics: makeDiagnostics()))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let body = try XCTUnwrap(components.queryItems?.first { $0.name == "body" }?.value)
        XCTAssertEqual(body, BugReport.body(description: "Crash", steps: "", diagnostics: makeDiagnostics()))
    }
}
