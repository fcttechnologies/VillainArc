import Foundation

// Storage: SharedModelContainer.sharedDefaults (App Group UserDefaults)
// Key: whats_new_last_shown_version — String, the last bundle short version the What's New sheet was shown for.
// Logic: on launch, compare the stored version to CFBundleShortVersionString and decide what to present (see presentationOnLaunch).
// Mark as seen by calling markCurrentVersionSeen() when the user dismisses, or immediately when nothing is presented.
nonisolated enum WhatsNewPreferences {
    private static let lastShownVersionKey = "whats_new_last_shown_version"
    // Legacy marker from the removed onboarding slideshow (1.3 and earlier). Read-only:
    // anyone who saw the old slideshow is by definition a pre-1.4 user, so when no version
    // is stored we still treat them as returning (What's New) rather than brand-new.
    private static let legacySlideshowSeenKey = "has_seen_onboarding_slideshow"
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

    private static var isReturningPreV14User: Bool {
        defaults.bool(forKey: legacySlideshowSeenKey)
    }

    // Decides what (if anything) to show after onboarding reaches `.ready`:
    // - brand-new install (no stored version, no legacy marker) → nothing; the first-launch
    //   carousel already introduced the app, and there is no earlier release to catch up on
    // - returning/updated user → aggregated What's New for every unseen release (nil if none)
    // - already on the current version → nil
    static func presentationOnLaunch() -> WhatsNewPresentation? {
        let current = currentVersion
        let stored = lastShownVersion

        if stored == current { return nil }
        if stored == nil && !isReturningPreV14User { return nil }

        let features = WhatsNewCatalog.featuresIntroduced(after: stored ?? "0", throughIncluding: current)
        guard !features.isEmpty else { return nil }
        return WhatsNewPresentation(version: current, features: features)
    }

    static func markCurrentVersionSeen() {
        lastShownVersion = currentVersion
    }
}
