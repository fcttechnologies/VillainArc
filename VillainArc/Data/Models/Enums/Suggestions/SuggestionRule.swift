import Foundation

enum SuggestionRule: String, Codable {
    case immediateProgressionRange
    case immediateProgressionTarget
    case confirmedProgressionRange
    case confirmedProgressionTarget
    case steadyRepIncreaseWithinRange
    case largeOvershootProgression
    case belowRangeWeightDecrease
    case matchActualWeight
    case reducedWeightToHitReps
    case shortRestPerformanceDrop
    case stagnationIncreaseRest
    case dropSetWithoutBase
    case calibrateWarmupWeights
    case warmupActingLikeWorkingSet
    case regularActingLikeWarmup
    case setTypeMismatch
    case suggestInitialRange
    case suggestTargetToRange
    case suggestShiftedRangeUp
    case suggestShiftedRangeDown
}
