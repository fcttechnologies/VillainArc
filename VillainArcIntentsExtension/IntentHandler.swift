import Intents

class IntentHandler: INExtension {
    override func handler(for intent: INIntent) -> Any {
        if intent is INStartWorkoutIntent {
            return StartWorkoutSiriHandler()
        }
        if intent is INCancelWorkoutIntent {
            return CancelWorkoutSiriHandler()
        }
        if intent is INEndWorkoutIntent {
            return EndWorkoutSiriHandler()
        }
        return self
    }
}
