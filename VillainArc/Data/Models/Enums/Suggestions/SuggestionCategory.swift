import Foundation
import FoundationModels

@Generable
enum SuggestionCategory: String, Codable {
    case performance
    case recovery
    case structure
    case repRangeConfiguration
    case warmupCalibration
    case volume

    func guidance(isSetScoped: Bool, targetSetType: ExerciseSetType?, changeTypes: [ChangeType]) -> String {
        let scopeText = isSetScoped ? "This suggestion targets one specific set." : "This suggestion targets the exercise as a whole."

        switch self {
        case .performance:
            if changeTypes.contains(.increaseWeight) || changeTypes.contains(.decreaseWeight) {
                return "\(scopeText) Judge whether the athlete actually used the suggested load and whether the resulting reps landed in the intended difficulty zone. Treat simply moving in the right direction as weaker evidence than actually reaching the target. For easing changes like load reductions, use Insufficient when the athlete followed the easier target but performance still did not improve enough."
            }
            if changeTypes.contains(.increaseReps) || changeTypes.contains(.decreaseReps) {
                return "\(scopeText) Judge whether the athlete actually performed near the new rep target rather than staying at the old one, and whether the result looked appropriately challenging. For easier rep targets, use Insufficient when the athlete followed the reduction but it still did not solve the performance problem."
            }
            return "\(scopeText) Judge whether the athlete followed the new performance target and whether it landed in the right difficulty zone."
        case .recovery:
            return "\(scopeText) Judge whether the athlete followed the new recovery target and whether downstream performance on the following set improved, stabilized, or at least stopped falling off. Matching the rest target alone is not enough if the following set does not improve. Use Insufficient when the change was followed but did not meaningfully fix the problem."
        case .structure:
            if changeTypes.contains(.changeSetType), let targetSetType {
                return "\(scopeText) Judge whether the athlete actually used the intended set structure. The suggested target structure is \(targetSetType.displayName). Prefer Ignored if the evidence is mixed rather than inferring a structural change from load alone."
            }
            return "\(scopeText) Judge whether the athlete actually used the intended set structure."
        case .repRangeConfiguration:
            return "\(scopeText) Judge whether the working-set distribution now matches the suggested rep range or mode. Focus on the representative working sets for the exercise rather than one unusual outlier set."
        case .warmupCalibration:
            return "\(scopeText) Judge whether the athlete followed the new warmup load while the set still behaved like a warmup relative to the main working or top sets. Good means they used the heavier warmup and it still clearly sat below the main work; Too Aggressive means the warmup became too close to working-set load or no longer behaved like a warmup."
        case .volume:
            return "\(scopeText) Judge whether the athlete followed the suggested set count and whether the extra or reduced volume looked productive. For added volume, look for a genuinely performed extra set that was not just logged noise. For reduced volume, look for adherence to the leaner structure and acceptable performance quality."
        }
    }
}
