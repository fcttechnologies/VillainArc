import Foundation
import UIKit

/// Builds `mailto:` URLs and gathers device + app context for the in-app Support flow.
/// Pure namespace — nothing here mutates state; views call these statics from `@MainActor` rows
/// and pass the result to `UIApplication.shared.open(_:)`. UIKit accessors keep the enum on the
/// main actor (project default isolation).
enum SupportContact {

    static let supportEmail: String = "fernando@fct-technologies.com"

    static let supportPageURL: URL = URL(string: "https://fct-technologies.com/projects/villainarc/support/")!

    /// Diagnostic JSON above this length is truncated before being placed in the mailto body to keep
    /// the URL within iOS's practical handler limit.
    static let diagnosticBodyMaxCharacters: Int = 6000

    // MARK: - Device + app context

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    static var iosVersion: String {
        UIDevice.current.systemVersion
    }

    static var localeIdentifier: String {
        Locale.current.identifier
    }

    /// Hardware identifier like `iPhone17,1`. Falls back to `UIDevice.model` on simulators (where
    /// utsname reports the host architecture) or if sysctl is unavailable.
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineSize = MemoryLayout.size(ofValue: systemInfo.machine)
        let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer -> String in
            pointer.withMemoryRebound(to: CChar.self, capacity: machineSize) {
                String(cString: $0)
            }
        }
        if identifier.isEmpty || identifier == "x86_64" || identifier == "arm64" {
            return UIDevice.current.model
        }
        return identifier
    }

    // MARK: - Mailto URLs

    static func mailtoForBugReport() -> URL? {
        let subject = "Villain Arc Issue — v\(appVersion)"
        let body = """
        Hi Fernando,

        [Describe the issue here]

        ---
        Device: \(deviceModel)
        iOS: \(iosVersion)
        App version: \(appVersion) (build \(buildNumber))
        Locale: \(localeIdentifier)
        """
        return mailtoURL(subject: subject, body: body)
    }

    static func mailtoForFeatureRequest() -> URL? {
        let subject = "Villain Arc Feature Request — v\(appVersion)"
        let body = """
        Hi Fernando,

        [Describe your feature request here]

        ---
        App version: \(appVersion) (build \(buildNumber))
        """
        return mailtoURL(subject: subject, body: body)
    }

    static func mailtoForDiagnostic(json: String, receivedAt: Date) -> URL? {
        let subject = "Villain Arc Crash Report — v\(appVersion) (build \(buildNumber))"
        let truncated = truncateForMailto(json)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let capturedAt = formatter.string(from: receivedAt)

        let body = """
        Hi Fernando,

        My Villain Arc app crashed. Here's the diagnostic data:

        Device: \(deviceModel)
        iOS: \(iosVersion)
        App version: \(appVersion) (build \(buildNumber))
        Captured: \(capturedAt)

        --- Diagnostic Payload ---
        \(truncated)
        """
        return mailtoURL(subject: subject, body: body)
    }

    // MARK: - Internals

    private static let mailtoAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return allowed
    }()

    private static func mailtoURL(subject: String, body: String) -> URL? {
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: mailtoAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: mailtoAllowed) else {
            return nil
        }
        return URL(string: "mailto:\(supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    private static func truncateForMailto(_ value: String) -> String {
        guard value.count > diagnosticBodyMaxCharacters else { return value }
        let endIndex = value.index(value.startIndex, offsetBy: diagnosticBodyMaxCharacters)
        return String(value[..<endIndex]) + "\n\n[truncated]"
    }
}
