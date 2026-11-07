import Foundation
import os

struct BarnHubLogger {
    private static let logger = os.Logger(subsystem: "net.shadowpuppet.BarnBook", category: "general")

    static func info(_ message: String) {
        logger.info("ℹ️ \(message, privacy: .private)")
    }

    static func success(_ message: String) {
        logger.info("✅ \(message, privacy: .private)")
    }

    static func warning(_ message: String) {
        logger.warning("⚠️ \(message, privacy: .private)")
        RecentLogBuffer.shared.append(level: .warning, message: message)
    }

    static func error(_ message: String) {
        logger.error("❌ \(message, privacy: .private)")
        RecentLogBuffer.shared.append(level: .error, message: message)
    }
}

/// In-memory ring buffer of recent warnings and errors for this app session,
/// attached to bug reports so users don't have to describe what went wrong.
/// Messages are scrubbed by `DiagnosticsRedactor` before they are stored, and
/// nothing is written to disk.
final class RecentLogBuffer: @unchecked Sendable {
    enum Level: String {
        case warning = "WARN"
        case error = "ERROR"
    }

    struct Entry: Equatable {
        let date: Date
        let level: Level
        let message: String
    }

    static let shared = RecentLogBuffer()

    let capacity: Int
    private var entries: [Entry] = []
    private let lock = NSLock()

    init(capacity: Int = 50) {
        self.capacity = capacity
    }

    func append(level: Level, message: String, date: Date = Date()) {
        let entry = Entry(date: date, level: level, message: DiagnosticsRedactor.scrub(message))
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
        if entries.count > capacity {
            entries.removeFirst(entries.count - capacity)
        }
    }

    /// Oldest first.
    var snapshot: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
