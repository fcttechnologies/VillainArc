import Foundation

// Storage: SharedModelContainer.sharedDefaults (App Group UserDefaults)
// Key: whats_new_last_shown_version — String, the last bundle short version the What's New sheet was shown for.
// Logic: on launch, compare the stored version to CFBundleShortVersionString and decide what to present (see presentationOnLaunch).
// Mark as seen by calling markCurrentVersionSeen() when the user dismisses, or immediately when nothing is presented.
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

    // Decides what (if anything) to show after onboarding reaches `.ready`:
    // - no stored version → nothing. This device has not run the app before under this App
    //   Group, so there is no earlier release to catch up on and the front door's carousel is
    //   what introduced the app.
    // - a stored version behind the current one → the aggregated What's New for every release
    //   between them (nil when those releases carry no highlights)
    // - already on the current version → nil
    static func presentationOnLaunch() -> WhatsNewPresentation? {
        let current = currentVersion
        guard let stored = lastShownVersion, stored != current else { return nil }

        let features = WhatsNewCatalog.featuresIntroduced(after: stored, throughIncluding: current)
        guard !features.isEmpty else { return nil }
        return WhatsNewPresentation(version: current, features: features)
    }

    static func markCurrentVersionSeen() {
        lastShownVersion = currentVersion
    }
}
