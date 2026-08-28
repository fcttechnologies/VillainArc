import SwiftUI

// A single highlighted feature shown in the What's New sheet.
nonisolated struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: LocalizedStringResource
    let description: LocalizedStringResource
}

// A release's user-facing highlights, keyed by its marketing version ("1.4").
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
    // Per-version highlights, ascending. Start at 1.4 — the 1.3 pillars are the
    // app's introduction and live in the onboarding carousel, so a user updating
    // from 1.3 sees only what's new in 1.4.
    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(version: "1.4", features: [
            WhatsNewFeature(icon: "text.magnifyingglass", iconColor: .indigo, title: "Ask Villain Arc", description: "Ask about your training and get answers from your own history. (Pro)"),
            WhatsNewFeature(icon: "square.and.arrow.up", iconColor: .green, title: "Share Your Progress", description: "Share workout summaries and your muscle map."),
            WhatsNewFeature(icon: "figure.run", iconColor: .orange, title: "Cardio Live Activity", description: "Choose the stats shown on your Lock Screen."),
            WhatsNewFeature(icon: "pencil.and.list.clipboard", iconColor: .blue, title: "Edit Past Workouts", description: "Update notes on completed workouts.")
        ])
    ]

    // Aggregated highlights of every release after `baseline`, up to and
    // including `current`. Powers the version-skip case: a 1.3 → 1.5 jump pulls
    // both 1.4 and 1.5 into one sheet.
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
