import Intents

final class EndWorkoutSiriHandler: NSObject, INEndWorkoutIntentHandling {
    func handle(intent: INEndWorkoutIntent, completion: @escaping (INEndWorkoutIntentResponse) -> Void) {
        let activity = NSUserActivity(activityType: "com.villainarc.siri.endWorkout")
        let response = INEndWorkoutIntentResponse(code: .continueInApp, userActivity: activity)
        completion(response)
    }
}
