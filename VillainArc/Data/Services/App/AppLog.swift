import Foundation
import OSLog

nonisolated enum AppLog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.fcttechnologies.VillainArc", category: "App")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String, error: Error? = nil) {
        if let error {
            logger.error("\(message, privacy: .public): \(error)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }
}
