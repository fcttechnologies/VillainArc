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
        let scopeText = isSetScoped ? "One target set." : "Whole exercise."

        switch self {
        case .performance:
            if changeTypes.contains(.increaseWeight) || changeTypes.contains(.decreaseWeight) {
                return "\(scopeText) Judge whether they actually used the suggested load and landed in the intended difficulty zone. Moving in the right direction is weaker evidence than reaching the target. For easier loads, prefer Insufficient when the problem still was not solved."
            }
            if changeTypes.contains(.increaseReps) || changeTypes.contains(.decreaseReps) {
                return "\(scopeText) Judge whether they worked near the new rep target instead of the old one, and whether the result looked appropriately challenging. For easier rep targets, prefer Insufficient when the reduction still did not solve the problem."
            }
            return "\(scopeText) Judge adherence to the new target and whether it landed in the right difficulty zone."
        case .recovery:
            return "\(scopeText) Judge whether they followed the new recovery target and whether the following set improved or at least stopped falling off. Matching rest alone is not enough. Prefer Insufficient when the change was followed but did not fix the problem."
        case .structure:
            if changeTypes.contains(.changeSetType), let targetSetType {
                return "\(scopeText) Judge whether they used the intended set structure. Target structure: \(targetSetType.displayName). Prefer Ignored when evidence is mixed instead of inferring structure from load alone."
            }
            return "\(scopeText) Judge whether they used the intended set structure."
        case .repRangeConfiguration:
            return "\(scopeText) Judge whether the working-set distribution now matches the suggested rep range or mode. Focus on representative working sets, not one outlier."
        case .warmupCalibration:
            return "\(scopeText) Judge whether they used the new warmup load and whether the set still behaved like a warmup relative to the main work. Too Aggressive means it became too close to working load or stopped behaving like a warmup."
        case .volume:
            return "\(scopeText) Judge whether they followed the suggested set count and whether the added or reduced volume looked productive. For added volume, look for a real extra set, not logged noise. For reduced volume, look for adherence and acceptable performance quality."
        }
    }
}
