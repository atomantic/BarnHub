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
    }

    static func error(_ message: String) {
        logger.error("❌ \(message, privacy: .private)")
    }
}
