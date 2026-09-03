import Foundation

// Storage: SharedModelContainer.sharedDefaults (App Group UserDefaults)
// Keys:
//   review_completed_session_count — Int, total finalized sessions ever
//   review_has_requested           — Bool, true once the prompt has been shown
// Trigger rule: show once after the 3rd completed session, never again.
nonisolated enum AppReviewPreferences {
    private static let completedSessionCountKey = "review_completed_session_count"
    private static let hasRequestedReviewKey = "review_has_requested"
    private static var defaults: UserDefaults { unsafe SharedModelContainer.sharedDefaults }

    static var completedSessionCount: Int {
        get { defaults.integer(forKey: completedSessionCountKey) }
        set { defaults.set(newValue, forKey: completedSessionCountKey) }
    }

    static var hasRequestedReview: Bool {
        get { defaults.bool(forKey: hasRequestedReviewKey) }
        set { defaults.set(newValue, forKey: hasRequestedReviewKey) }
    }

    static func incrementCompletedSessionCount() {
        completedSessionCount += 1
    }

    static var shouldRequestReview: Bool {
        !hasRequestedReview && completedSessionCount >= 3
    }
}
