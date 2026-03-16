import Foundation

struct ProgressionProfile {
    enum Kind {
        case `default`
        case heavyCompound
        case controlledAccessory
        case largeJumpLoad
        case bodyweightAssisted
    }

    let kind: Kind
    let allowsImmediateLoadProgression: Bool
    let confirmedRangeMargin: Int
    let confirmedTargetMargin: Int
    let overshootRangeExtraReps: Int
    let overshootTargetExtraReps: Int
    let overshootIncrementMultiplier: Double
    let belowRangeWindowSize: Int
    let belowRangeRequiredCount: Int
    let matchActualWeightSessionsRequired: Int
    let reducedWeightSessionsRequired: Int
    let attemptedWeightToleranceIncrementMultiplier: Double
    let meaningfulDeviationIncrementMultiplier: Double
    let reducedLoadIncrementMultiplier: Double

    static let `default` = ProgressionProfile(
        kind: .default,
        allowsImmediateLoadProgression: true,
        confirmedRangeMargin: 1,
        confirmedTargetMargin: 1,
        overshootRangeExtraReps: 3,
        overshootTargetExtraReps: 4,
        overshootIncrementMultiplier: 1.5,
        belowRangeWindowSize: 3,
        belowRangeRequiredCount: 2,
        matchActualWeightSessionsRequired: 3,
        reducedWeightSessionsRequired: 2,
        attemptedWeightToleranceIncrementMultiplier: 0.5,
        meaningfulDeviationIncrementMultiplier: 1.0,
        reducedLoadIncrementMultiplier: 0.5
    )

    static let heavyCompound = ProgressionProfile(
        kind: .heavyCompound,
        allowsImmediateLoadProgression: false,
        confirmedRangeMargin: 0,
        confirmedTargetMargin: 0,
        overshootRangeExtraReps: 3,
        overshootTargetExtraReps: 4,
        overshootIncrementMultiplier: 1.25,
        belowRangeWindowSize: 4,
        belowRangeRequiredCount: 3,
        matchActualWeightSessionsRequired: 4,
        reducedWeightSessionsRequired: 3,
        attemptedWeightToleranceIncrementMultiplier: 0.5,
        meaningfulDeviationIncrementMultiplier: 1.0,
        reducedLoadIncrementMultiplier: 0.5
    )

    static let controlledAccessory = ProgressionProfile(
        kind: .controlledAccessory,
        allowsImmediateLoadProgression: true,
        confirmedRangeMargin: 1,
        confirmedTargetMargin: 1,
        overshootRangeExtraReps: 3,
        overshootTargetExtraReps: 4,
        overshootIncrementMultiplier: 1.5,
        belowRangeWindowSize: 3,
        belowRangeRequiredCount: 2,
        matchActualWeightSessionsRequired: 3,
        reducedWeightSessionsRequired: 2,
        attemptedWeightToleranceIncrementMultiplier: 0.5,
        meaningfulDeviationIncrementMultiplier: 1.0,
        reducedLoadIncrementMultiplier: 0.5
    )

    static let largeJumpLoad = ProgressionProfile(
        kind: .largeJumpLoad,
        allowsImmediateLoadProgression: false,
        confirmedRangeMargin: 0,
        confirmedTargetMargin: 0,
        overshootRangeExtraReps: 4,
        overshootTargetExtraReps: 5,
        overshootIncrementMultiplier: 1.0,
        belowRangeWindowSize: 3,
        belowRangeRequiredCount: 2,
        matchActualWeightSessionsRequired: 3,
        reducedWeightSessionsRequired: 2,
        attemptedWeightToleranceIncrementMultiplier: 0.5,
        meaningfulDeviationIncrementMultiplier: 1.0,
        reducedLoadIncrementMultiplier: 0.5
    )

    static let bodyweightAssisted = ProgressionProfile(
        kind: .bodyweightAssisted,
        allowsImmediateLoadProgression: false,
        confirmedRangeMargin: 0,
        confirmedTargetMargin: 0,
        overshootRangeExtraReps: 4,
        overshootTargetExtraReps: 5,
        overshootIncrementMultiplier: 1.0,
        belowRangeWindowSize: 4,
        belowRangeRequiredCount: 3,
        matchActualWeightSessionsRequired: 4,
        reducedWeightSessionsRequired: 3,
        attemptedWeightToleranceIncrementMultiplier: 0.5,
        meaningfulDeviationIncrementMultiplier: 1.0,
        reducedLoadIncrementMultiplier: 0.5
    )
}

struct MetricsCalculator {
    static func isPlanAnchored(_ set: SetPerformance) -> Bool {
        set.prescription != nil || set.originalTargetSetID != nil
    }

    static func selectProgressionSets(from performance: ExercisePerformance, overrideStyle: TrainingStyle? = nil) -> [SetPerformance] {
        let sets = performance.sortedSets.filter(\.complete)
        guard !sets.isEmpty else { return [] }

        let anchoredSets = sets.filter(isPlanAnchored(_:))
        let anchoredWorkingSets = anchoredSets.filter { $0.type == .working }
        let workingSets = sets.filter { $0.type == .working }
        let candidates: [SetPerformance]

        if !anchoredWorkingSets.isEmpty {
            candidates = anchoredWorkingSets
        } else if !anchoredSets.isEmpty {
            candidates = anchoredSets
        } else {
            candidates = workingSets.isEmpty ? sets : workingSets
        }

        guard !candidates.isEmpty else { return [] }
        guard candidates.contains(where: { $0.type == .working || $0.type == .dropSet }) else { return [] }
        guard !candidates.allSatisfy({ $0.type == .warmup }) else { return [] }

        let style = overrideStyle ?? detectTrainingStyle(candidates)
        return setsForStyle(style, from: candidates)
    }

    private static func setsForStyle(_ style: TrainingStyle, from sets: [SetPerformance]) -> [SetPerformance] {
        let orderedSets = sets.sorted { $0.index < $1.index }
        let maxWeight = orderedSets.map(\.weight).max() ?? 0

        switch style {
        case .straightSets:
            return orderedSets
        case .ascendingPyramid:
            return topWeightedSets(from: orderedSets, limit: 3)
        case .descendingPyramid:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.95)
        case .ascending:
            return topWeightedSets(from: orderedSets, limit: 3)
        case .feederRamp:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.97)
        case .reversePyramid:
            return topWeightedSets(from: orderedSets, limit: 2)
        case .topSetBackoffs:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.92)
        case .restPauseCluster:
            return orderedSets.isEmpty ? [] : [orderedSets[0]]
        case .dropSetCluster:
            return []
        case .unknown:
            return topWeightedSets(from: orderedSets, limit: 2)
        }
    }

    static func detectTrainingStyle(_ sets: [SetPerformance]) -> TrainingStyle {
        let completeSets = sets.filter(\.complete)
        guard !completeSets.isEmpty else { return .unknown }

        let workingSets = completeSets.filter { $0.type == .working }
        let dropSets = completeSets.filter { $0.type == .dropSet }

        if workingSets.isEmpty {
            if isDropSetCluster(completeSets, explicitDropSets: dropSets) {
                return .dropSetCluster
            }
            return .unknown
        }

        let analysisSets = workingSets

        guard analysisSets.count >= 3 else { return .unknown }

        let weights = analysisSets.map(\.weight)
        let maxWeight = weights.max() ?? 0
        guard maxWeight > 0 else { return .unknown }
        let avgWeight = weights.reduce(0, +) / Double(weights.count)

        if isRestPauseCluster(analysisSets) {
            return .restPauseCluster
        }

        // Top set + backoffs: a cluster of heavy sets at top, the rest significantly lighter.
        if isTopSetBackoffs(weights: weights, maxWeight: maxWeight) {
            return .topSetBackoffs
        }

        if isFeederRamp(weights: weights, maxWeight: maxWeight) {
            return .feederRamp
        }

        if isReversePyramid(weights: weights, maxWeight: maxWeight) {
            return .reversePyramid
        }

        // Ascending: weights monotonically increase (with small tolerance), heaviest is last.
        let ascendingCount = zip(weights, weights.dropFirst()).filter { $0 <= $1 }.count
        let hasStrictIncrease = zip(weights, weights.dropFirst()).contains { $0 < $1 }
        if hasStrictIncrease && ascendingCount >= analysisSets.count - 2 && weights.last == maxWeight {
            return .ascending
        }

        // Descending pyramid: mostly descending, heaviest is first.
        let descendingCount = zip(weights, weights.dropFirst()).filter { $0 > $1 }.count
        if descendingCount >= analysisSets.count - 2 && weights.first == maxWeight {
            return .descendingPyramid
        }

        // Ascending pyramid: weights rise into a middle peak, then fall away.
        if isAscendingPyramid(weights: weights, maxWeight: maxWeight) {
            return .ascendingPyramid
        }

        if hasInteriorPeakOrPlateau(weights: weights, maxWeight: maxWeight) {
            return .unknown
        }

        // Straight sets are a fallback, not a primary structural pattern. Keep the window
        // fairly tight so modest ramps/backoffs do not get over-classified as straight sets.
        if avgWeight > 0 {
            let allSimilar = weights.allSatisfy { abs($0 - avgWeight) <= avgWeight * 0.08 }
            if allSimilar {
                return .straightSets
            }
        }

        return .unknown
    }

    private static func isDropSetCluster(_ sets: [SetPerformance], explicitDropSets: [SetPerformance]) -> Bool {
        guard !sets.isEmpty else { return false }
        guard explicitDropSets.count == sets.count else { return false }

        let weights = explicitDropSets.map(\.weight)
        guard let firstWeight = weights.first, firstWeight > 0 else { return false }

        let mostlyDescending = zip(weights, weights.dropFirst()).allSatisfy { lhs, rhs in
            rhs <= lhs
        }
        let meaningfulDrop = (weights.min() ?? firstWeight) <= firstWeight * 0.85
        return mostlyDescending && meaningfulDrop
    }

    private static func isTopSetBackoffs(weights: [Double], maxWeight: Double) -> Bool {
        guard weights.count >= 3 else { return false }

        let heavyIndices = weights.enumerated().compactMap { index, weight in
            weight >= maxWeight * 0.9 ? index : nil
        }
        let lightIndices = weights.enumerated().compactMap { index, weight in
            weight < maxWeight * 0.8 ? index : nil
        }

        guard heavyIndices.count >= 1, heavyIndices.count <= 3, !lightIndices.isEmpty else { return false }
        guard let lastHeavyIndex = heavyIndices.last, let firstLightIndex = lightIndices.first else { return false }
        guard lastHeavyIndex < firstLightIndex else { return false }

        let backoffWeights = Array(weights[(lastHeavyIndex + 1)...])
        guard !backoffWeights.isEmpty else { return false }

        let backoffSpread = (backoffWeights.max() ?? 0) - (backoffWeights.min() ?? 0)
        return backoffSpread <= maxWeight * 0.08
    }

    private static func isFeederRamp(weights: [Double], maxWeight: Double) -> Bool {
        guard weights.count >= 3 else { return false }

        let plateauThreshold = maxWeight * 0.97
        let trailingClusterCount = weights.reversed().prefix(while: { $0 >= plateauThreshold }).count
        guard trailingClusterCount >= 2 else { return false }

        let leadIn = Array(weights.dropLast(trailingClusterCount))
        guard !leadIn.isEmpty else { return false }

        let leadInRises = zip(leadIn, leadIn.dropFirst()).allSatisfy { lhs, rhs in
            lhs <= rhs
        }
        let leadInMeaningfullyLighter = (leadIn.max() ?? 0) <= maxWeight * 0.92
        return leadInRises && leadInMeaningfullyLighter
    }

    private static func isReversePyramid(weights: [Double], maxWeight: Double) -> Bool {
        guard weights.count >= 3 else { return false }
        guard weights.first == maxWeight else { return false }

        let backoffs = Array(weights.dropFirst())
        guard backoffs.count >= 2 else { return false }
        guard backoffs.allSatisfy({ $0 < maxWeight }) else { return false }

        let backoffMax = backoffs.max() ?? 0
        let backoffMin = backoffs.min() ?? 0
        let clusteredBackoffs = (backoffMax - backoffMin) <= maxWeight * 0.06
        let meaningfullyLighter = backoffMax <= maxWeight * 0.95 && backoffMin >= maxWeight * 0.82
        return clusteredBackoffs && meaningfullyLighter
    }

    private static func isAscendingPyramid(weights: [Double], maxWeight: Double) -> Bool {
        guard let maxIndex = weights.firstIndex(of: maxWeight), maxIndex > 0, maxIndex < weights.count - 1 else {
            return false
        }

        let climb = Array(weights[...maxIndex])
        let descent = Array(weights[maxIndex...])

        let climbsCleanly = zip(climb, climb.dropFirst()).allSatisfy { $0 < $1 }
        let descendsCleanly = zip(descent, descent.dropFirst()).allSatisfy { $0 > $1 }
        let peakProminence = maxWeight * 0.1
        let risesMeaningfully = maxWeight - (climb.min() ?? maxWeight) >= peakProminence
        let fallsMeaningfully = maxWeight - (descent.min() ?? maxWeight) >= peakProminence

        return climbsCleanly && descendsCleanly && risesMeaningfully && fallsMeaningfully
    }

    private static func hasInteriorPeakOrPlateau(weights: [Double], maxWeight: Double) -> Bool {
        guard weights.count >= 4 else { return false }
        let plateauThreshold = maxWeight * 0.98
        let heavyIndices = weights.enumerated().compactMap { index, weight in
            weight >= plateauThreshold ? index : nil
        }

        guard heavyIndices.count >= 2 else { return false }

        guard let firstHeavy = heavyIndices.first,
              let lastHeavy = heavyIndices.last,
              firstHeavy > 0,
              lastHeavy < weights.count - 1 else {
            return false
        }

        let heavyClusterIsContiguous = zip(heavyIndices, heavyIndices.dropFirst()).allSatisfy { next, following in
            following == next + 1
        }
        guard heavyClusterIsContiguous else { return false }

        let beforeCluster = Array(weights[..<firstHeavy])
        let afterCluster = Array(weights[(lastHeavy + 1)...])
        guard !beforeCluster.isEmpty, !afterCluster.isEmpty else { return false }

        let climbsIntoPeak = zip(beforeCluster, beforeCluster.dropFirst()).allSatisfy { $0 <= $1 } && (beforeCluster.last ?? 0) <= maxWeight
        let fallsAwayFromPeak = zip(afterCluster, afterCluster.dropFirst()).allSatisfy { $0 >= $1 } && (afterCluster.first ?? maxWeight) <= maxWeight

        return climbsIntoPeak && fallsAwayFromPeak
    }

    private static func isRestPauseCluster(_ sets: [SetPerformance]) -> Bool {
        guard sets.count >= 3 else { return false }

        let weights = sets.map(\.weight)
        guard let maxWeight = weights.max(), let minWeight = weights.min(), maxWeight > 0 else { return false }

        let tightLoadBand = (maxWeight - minWeight) <= max(2.5, maxWeight * 0.03)
        guard tightLoadBand else { return false }

        let reps = sets.map(\.reps)
        let nonIncreasingReps = zip(reps, reps.dropFirst()).allSatisfy { lhs, rhs in
            lhs >= rhs
        }
        let repDrops = zip(reps, reps.dropFirst()).map(-)
        let everyTransitionDrops = repDrops.allSatisfy { $0 >= 1 }
        let totalRepDrop = (reps.first ?? 0) - (reps.last ?? 0)
        let firstSetReps = reps.first ?? 0
        let collapsedMiniSetThreshold = max(1, Int(floor(Double(firstSetReps) * 0.7)))
        let hasCollapsedMiniSet = reps.dropFirst().contains { $0 <= collapsedMiniSetThreshold }
        guard nonIncreasingReps,
              everyTransitionDrops,
              totalRepDrop >= 4,
              hasCollapsedMiniSet else { return false }

        let shortRestTransitions = sets.dropLast().filter { set in
            let effectiveRest = set.effectiveRestSeconds
            return effectiveRest > 0 && effectiveRest <= 30
        }.count

        return shortRestTransitions == sets.count - 1
    }

    private static func heavyClusterSets(from sets: [SetPerformance], maxWeight: Double, thresholdRatio: Double) -> [SetPerformance] {
        guard !sets.isEmpty else { return [] }
        guard maxWeight > 0 else { return sets }

        let cluster = sets.filter { $0.weight >= maxWeight * thresholdRatio }
        if !cluster.isEmpty {
            return cluster.sorted { $0.index < $1.index }
        }

        return sets.filter { $0.weight == maxWeight }.sorted { $0.index < $1.index }
    }

    private static func topWeightedSets(from sets: [SetPerformance], limit: Int) -> [SetPerformance] {
        guard limit > 0 else { return [] }

        let selected = sets
            .sorted {
                if $0.weight != $1.weight {
                    return $0.weight > $1.weight
                }
                return $0.index < $1.index
            }
            .prefix(limit)

        return selected.sorted { $0.index < $1.index }
    }

    // All weight values are stored in kg. Increments are calibrated for kg plate sizes.
    static func weightIncrement(for currentWeight: Double, primaryMuscle: Muscle, equipmentType: EquipmentType, catalogID: String? = nil) -> Double {
        switch equipmentType {
        case .dumbbellSingle, .kettlebellSingle:
            return currentWeight < 7 ? 1.25 : 2.5
        case .dumbbells, .kettlebell:
            let perHand = max(0, currentWeight / 2)
            return perHand < 7 ? 2.5 : 5.0
        case .cableSingle:
            return currentWeight < 14 ? 1.25 : 2.5
        case .cables, .rope:
            return currentWeight < 27 ? 2.5 : 5.0
        case .machine, .smithMachine, .machineAssisted:
            return currentWeight < 45 ? 2.5 : 5.0
        case .barbell, .ezBar, .landmine:
            break
        case .bodyweight, .band, .plate, .weightedBall:
            if currentWeight <= 0 { return 0 }
            return currentWeight < 11 ? 1.25 : 2.5
        case .other:
            break
        }

        if let catalogID, shouldUseLargeBarbellPullIncrement(catalogID: catalogID, equipmentType: equipmentType) {
            return 5.0
        }

        return muscleBasedIncrement(for: currentWeight, primaryMuscle: primaryMuscle)
    }

    static func progressionProfile(primaryMuscle: Muscle, equipmentType: EquipmentType, catalogID: String? = nil) -> ProgressionProfile {
        // First-pass heavy-compound tuning is intentionally limited to reviewed catalog
        // exercises so we do not over-apply conservative thresholds to unrelated barbell work.
        if let catalogID, isHeavyCompound(catalogID: catalogID, equipmentType: equipmentType) {
            return .heavyCompound
        }

        switch equipmentType {
        case .machine, .cableSingle, .cables, .rope:
            return .controlledAccessory
        case .dumbbells, .dumbbellSingle, .kettlebell, .kettlebellSingle:
            return .largeJumpLoad
        case .bodyweight, .machineAssisted:
            return .bodyweightAssisted
        case .band:
            return primaryMuscle.isMajor ? .bodyweightAssisted : .controlledAccessory
        case .barbell, .smithMachine, .landmine, .ezBar, .plate, .weightedBall, .other:
            return .default
        }
    }

    private static func isHeavyCompound(catalogID: String, equipmentType: EquipmentType) -> Bool {
        switch equipmentType {
        case .barbell, .smithMachine, .landmine:
            break
        default:
            return false
        }

        let heavyCompoundCatalogIDs: Set<String> = [
            "barbell_bench_press",
            "barbell_incline_bench_press",
            "barbell_decline_bench_press",
            "barbell_floor_press",
            "barbell_close_grip_bench_press",
            "smith_machine_bench_press",
            "smith_machine_incline_bench_press",
            "barbell_shoulder_press",
            "barbell_seated_shoulder_press",
            "smith_machine_shoulder_press",
            "barbell_squat",
            "barbell_box_squat",
            "barbell_front_squat",
            "smith_machine_squat",
            "barbell_deadlift",
            "barbell_sumo_deadlift",
            "deficit_deadlift",
            "trap_bar_deadlift",
            "barbell_romanian_deadlift",
            "smith_machine_romanian_deadlift",
            "good_mornings",
            "barbell_bent_over_row",
            "barbell_reverse_grip_bent_over_row",
            "barbell_pendlay_row",
            "t_bar_rows",
            "machine_t_bar_row",
            "barbell_hip_thrust",
            "smith_machine_hip_thrust",
            "machine_hip_thrust"
        ]

        return heavyCompoundCatalogIDs.contains(catalogID)
    }

    private static func shouldUseLargeBarbellPullIncrement(catalogID: String, equipmentType: EquipmentType) -> Bool {
        switch equipmentType {
        case .barbell, .landmine:
            break
        default:
            return false
        }

        let largePullAndHingeOverrides: Set<String> = [
            "barbell_bent_over_row",
            "barbell_reverse_grip_bent_over_row",
            "barbell_pendlay_row",
            "barbell_deadlift",
            "barbell_sumo_deadlift",
            "deficit_deadlift",
            "trap_bar_deadlift",
            "barbell_romanian_deadlift",
            "good_mornings",
            "rack_pulls",
            "t_bar_rows"
        ]

        return largePullAndHingeOverrides.contains(catalogID)
    }

    private static func muscleBasedIncrement(for currentWeight: Double, primaryMuscle: Muscle) -> Double {
        // Muscle-group based increments (larger jumps for bigger movers).
        switch primaryMuscle {
        case .chest, .shoulders, .back:
            return 2.5
        case .biceps, .triceps:
            return 2.5
        case .frontDelt, .sideDelt, .rearDelt, .lats, .lowerBack,
             .upperTraps, .lowerTraps, .midTraps, .rhomboids:
            return 2.5
        case .longHeadBiceps, .shortHeadBiceps, .brachialis,
             .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps:
            return 2.5
        case .quads, .hamstrings, .glutes:
            return 5.0
        case .calves:
            return 5.0
        case .adductors, .abductors:
            return 2.5
        case .abs, .obliques, .upperAbs, .lowerAbs:
            return 2.5
        case .forearms, .wrists, .rotatorCuff:
            return 1.25
        case .upperChest, .lowerChest, .midChest:
            return 2.5
        }
    }

    // Default plate is 1.25 kg (smallest standard bumper/change plate).
    static func roundToNearestPlate(_ value: Double, plate: Double = 1.25) -> Double {
        guard plate > 0 else { return value }
        return (value / plate).rounded() * plate
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
