import Foundation

// Storage: SharedModelContainer.sharedDefaults (App Group UserDefaults)
// Key: whats_new_last_shown_version — String, the last bundle short version the sheet was shown for.
// Logic: compare stored version to CFBundleShortVersionString at launch; show sheet once when they differ.
// Mark as seen by calling markCurrentVersionSeen() when the user dismisses.
nonisolated enum WhatsNewPreferences {
    private static let lastShownVersionKey = "whats_new_last_shown_version"
    nonisolated(unsafe) private static var defaults: UserDefaults { SharedModelContainer.sharedDefaults }

    static var lastShownVersion: String? {
        get { defaults.string(forKey: lastShownVersionKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: lastShownVersionKey)
            } else {
                defaults.removeObject(forKey: lastShownVersionKey)
            }
        }
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var shouldShowWhatsNew: Bool {
        lastShownVersion != currentVersion
    }

    static func markCurrentVersionSeen() {
        lastShownVersion = currentVersion
    }
}
