import SwiftUI

// A single highlighted feature shown in the What's New sheet.
nonisolated struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource
}

// A release's user-facing highlights, keyed by its marketing version ("2.1").
nonisolated struct WhatsNewRelease {
    let version: String
    let features: [WhatsNewFeature]
}

// The unseen releases a launch should announce, and their aggregated highlights.
// A brand-new install has no releases to announce: the first-launch carousel
// (`VAOnboardingCarousel`) is where a new user meets the app.
nonisolated struct WhatsNewPresentation: Identifiable {
    let version: String
    let features: [WhatsNewFeature]

    var id: String { version }
}

// The single source of truth for the per-version What's New changelog. To
// announce a new release's features, append a `WhatsNewRelease` with its
// marketing version — the launch logic (`WhatsNewPreferences.presentationOnLaunch`)
// aggregates every release a user hasn't seen, so a user who skips versions still
// sees all missed highlights in one sheet. A version with no entry (e.g. a minor
// bug-fix build) contributes nothing and no sheet is shown.
nonisolated enum WhatsNewCatalog {
    // Per-version highlights, ascending, and every entry is a release that shipped.
    //
    // 2.0 is the baseline: it is the first release to run in this App Group, so no device can
    // hold a stored version below it and the launch sheet never presents 2.0's own entry — the
    // front door's carousel is what introduces the app to whoever arrives at it. The entry is
    // here because this list is the record of what each shipped version changed, which is what
    // the aggregation reads from 2.1 onward.
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "2.0", features: [
            WhatsNewFeature(icon: "hammer", iconColor: .orange, title: "Rebuilt From the Ground Up", description: "A faster launch, a cleaner store, and the foundation for what comes next."),
            WhatsNewFeature(icon: "person.crop.circle.badge.checkmark", iconColor: .blue, title: "Your Free FCT Account", description: "Sign in once and your workouts, plans, splits, and cardio reach every device you use."),
            WhatsNewFeature(icon: "applewatch", iconColor: .green, title: "Apple Watch Companion", description: "Rest timer, live session, and heart-rate stats on your wrist."),
            WhatsNewFeature(icon: "globe", iconColor: .indigo, title: "Ten Languages", description: "Villain Arc now speaks ten languages, including yours."),
            WhatsNewFeature(icon: "arrow.triangle.2.circlepath", iconColor: .gray, title: "A Fresh Start", description: "The store underneath the app changed, so workouts saved in Villain Arc 1.x do not carry over.")
        ])
    ]

    // Aggregated highlights of every release after `baseline`, up to and
    // including `current`. Powers the version-skip case: a 2.0 → 2.2 jump pulls
    // both 2.1 and 2.2 into one sheet.
    static func featuresIntroduced(after baseline: String, throughIncluding current: String) -> [WhatsNewFeature] {
        releases
            .filter {
                compareVersions($0.version, baseline) == .orderedDescending &&
                compareVersions($0.version, current) != .orderedDescending
            }
            .flatMap(\.features)
    }

    // Semantic, component-wise version compare so "1.10" > "1.9" and "1.4.1" > "1.4".
    static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let aComponents = a.split(separator: ".").map { Int($0) ?? 0 }
        let bComponents = b.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(aComponents.count, bComponents.count) {
            let aValue = index < aComponents.count ? aComponents[index] : 0
            let bValue = index < bComponents.count ? bComponents[index] : 0
            if aValue != bValue {
                return aValue < bValue ? .orderedAscending : .orderedDescending
            }
        }
        return .orderedSame
    }
}
