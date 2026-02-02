import Intents

final class StartWorkoutSiriHandler: NSObject, INStartWorkoutIntentHandling {
    func handle(intent: INStartWorkoutIntent, completion: @escaping (INStartWorkoutIntentResponse) -> Void) {
        let activity = NSUserActivity(activityType: "com.villainarc.siri.startWorkout")
        let response = INStartWorkoutIntentResponse(code: .continueInApp, userActivity: activity)
        completion(response)
    }
}
