import Intents

final class CancelWorkoutSiriHandler: NSObject, INCancelWorkoutIntentHandling {
    func handle(intent: INCancelWorkoutIntent, completion: @escaping (INCancelWorkoutIntentResponse) -> Void) {
        let activity = NSUserActivity(activityType: "com.villainarc.siri.cancelWorkout")
        let response = INCancelWorkoutIntentResponse(code: .continueInApp, userActivity: activity)
        completion(response)
    }
}
