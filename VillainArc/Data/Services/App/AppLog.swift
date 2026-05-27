import Foundation
import OSLog

nonisolated enum AppLog {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.fcttechnologies.VillainArc", category: "App")

    /// Logs a fully formatted message. Treats the whole string as `.public`.
    /// Prefer the `(StaticString, String)` overload when the message contains any user data or runtime values.
    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Logs a static template plus one dynamic value redacted under `.private`. Use this when the
    /// interpolated value could contain identifiers, paths, or anything not safe to publish in os_log.
    static func info(_ template: StaticString, _ value: String) {
        logger.info("\(template, privacy: .public): \(value, privacy: .private)")
    }

    /// Logs a fully formatted error message. Treats the whole string as `.public`.
    /// Prefer the `(StaticString, String, error:)` overload when the message contains any user data or runtime values.
    static func error(_ message: String, error: Error? = nil) {
        if let error {
            logger.error("\(message, privacy: .public): \(error)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }

    /// Logs a static template plus one dynamic value redacted under `.private`, and an optional error.
    static func error(_ template: StaticString, _ value: String, error: Error? = nil) {
        if let error {
            logger.error("\(template, privacy: .public): \(value, privacy: .private): \(error)")
        } else {
            logger.error("\(template, privacy: .public): \(value, privacy: .private)")
        }
    }
}
