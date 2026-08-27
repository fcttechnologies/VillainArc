import FCTAccount
import Foundation

/// Villain Arc's one `AccountController`.
///
/// **The account is required.** Villain Arc syncs everything it authors through the FCT platform,
/// and the fleet posture is mandatory auth: onboarding ends in the sign-in step, and the app runs
/// signed in. The controller is created once here and shared by the app shell, onboarding, and
/// the sync bootstrap.
@MainActor
enum VAAccount {
    static let controller = AccountController()
}
