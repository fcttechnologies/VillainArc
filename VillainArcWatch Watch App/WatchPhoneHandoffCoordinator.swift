import Foundation

enum WatchPhoneHandoffActivityType {
    static let openApp = "com.villainarc.handoff.openApp"
    static let openActiveWorkout = "com.villainarc.handoff.openActiveWorkout"
}

enum WatchPhoneHandoffCoordinator {
    private static var currentActivity: NSUserActivity?

    static func openAppOnPhone() {
        beginHandoff(
            activityType: WatchPhoneHandoffActivityType.openApp,
            title: "Open Villain Arc on iPhone"
        )
    }

    static func openActiveWorkoutOnPhone() {
        beginHandoff(
            activityType: WatchPhoneHandoffActivityType.openActiveWorkout,
            title: "Continue Workout on iPhone"
        )
    }

    private static func beginHandoff(activityType: String, title: String) {
        currentActivity?.invalidate()

        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.becomeCurrent()

        currentActivity = activity
    }
}
