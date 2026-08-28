import FCTOnboarding
import SwiftUI

/// The pages of the first-launch carousel: Villain Arc's pillars, one each, over the App Store
/// artwork in `Assets.xcassets/Onboarding`.
///
/// `AccountOnboardingFlow` pages these and then hands off to the FCT account sign-in step, which is
/// what completes the flow — the carousel introduces the app, it never finishes onboarding.
enum VAOnboardingCarousel {
    /// The carousel's button labels. Passed explicitly because `FCTOnboarding` ships no String
    /// Catalog of its own and would otherwise render its English defaults inside a localized app.
    static let continueTitle = String(localized: "Continue", comment: "Advance to the next onboarding page")

    static var items: [OnboardingItem] {
        [
            OnboardingItem(
                id: 0,
                title: String(localized: "Log Every Set in Seconds", comment: "Onboarding page: workout logging"),
                subtitle: String(
                    localized: "Weight, reps, and rest, with your last session right there.",
                    comment: "Onboarding page subtitle: workout logging"
                ),
                screenshot: UIImage(named: "onboarding-train")
            ),
            OnboardingItem(
                id: 1,
                title: String(localized: "Smart Suggestions", comment: "Onboarding page: set suggestions"),
                subtitle: String(
                    localized: "Your next weight and reps, worked out from your own history. (Pro)",
                    comment: "Onboarding page subtitle: set suggestions"
                ),
                screenshot: UIImage(named: "onboarding-suggestions")
            ),
            OnboardingItem(
                id: 2,
                title: String(localized: "AI Plan Generation", comment: "Onboarding page: AI plans"),
                subtitle: String(
                    localized: "Build a full program from a sentence. (Pro)",
                    comment: "Onboarding page subtitle: AI plans"
                ),
                screenshot: UIImage(named: "onboarding-plans"),
                // Pushed into the prompt itself: the story of this page is the sentence you type,
                // and the shot's lower half is the keyboard that came up to type it.
                zoomScale: 1.3,
                zoomAnchor: .top
            ),
            OnboardingItem(
                id: 3,
                title: String(localized: "Every Lift's History", comment: "Onboarding page: exercise history"),
                subtitle: String(
                    localized: "Muscles worked, PRs, and totals for every exercise.",
                    comment: "Onboarding page subtitle: exercise history"
                ),
                screenshot: UIImage(named: "onboarding-history")
            ),
            OnboardingItem(
                id: 4,
                title: String(localized: "Health Insights", comment: "Onboarding page: health insights"),
                subtitle: String(
                    localized: "Trends, sleep timing, and correlations. (Pro)",
                    comment: "Onboarding page subtitle: health insights"
                ),
                screenshot: UIImage(named: "onboarding-trends")
            ),
        ]
    }
}
