import Foundation
import os

struct BarnIOLogger {
    private static let logger = os.Logger(subsystem: "net.shadowpuppet.BarnBook", category: "general")

    static func info(_ message: String) {
        logger.info("ℹ️ \(message)")
    }

    static func success(_ message: String) {
        logger.info("✅ \(message)")
    }

    static func warning(_ message: String) {
        logger.warning("⚠️ \(message)")
    }

    static func error(_ message: String) {
        logger.error("❌ \(message)")
    }
}
