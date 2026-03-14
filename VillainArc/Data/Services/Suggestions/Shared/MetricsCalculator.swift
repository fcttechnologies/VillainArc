import Foundation

struct MetricsCalculator {
    static func selectProgressionSets(from performance: ExercisePerformance, overrideStyle: TrainingStyle? = nil) -> [SetPerformance] {
        let sets = performance.sortedSets.filter(\.complete)
        guard !sets.isEmpty else { return [] }

        let workingSets = sets.filter { $0.type == .working }
        let candidates = workingSets.isEmpty ? sets : workingSets
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
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.95)
        case .descendingPyramid:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.95)
        case .ascending:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.95)
        case .topSetBackoffs:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.92)
        case .unknown:
            return heavyClusterSets(from: orderedSets, maxWeight: maxWeight, thresholdRatio: 0.95)
        }
    }

    static func detectTrainingStyle(_ sets: [SetPerformance]) -> TrainingStyle {
        let completeSets = sets.filter(\.complete)
        let workingSets = completeSets.filter { $0.type == .working }
        let analysisSets = workingSets.isEmpty ? completeSets : workingSets

        guard analysisSets.count >= 3 else { return .unknown }

        let weights = analysisSets.map(\.weight)
        let maxWeight = weights.max() ?? 0
        guard maxWeight > 0 else { return .unknown }
        let avgWeight = weights.reduce(0, +) / Double(weights.count)

        // Straight sets: all weights within 10% of average.
        if avgWeight > 0 {
            let allSimilar = weights.allSatisfy { abs($0 - avgWeight) < avgWeight * 0.1 }
            if allSimilar {
                return .straightSets
            }
        }

        // Top set + backoffs: a cluster of heavy sets at top, the rest significantly lighter.
        let heavyCluster = weights.filter { $0 >= maxWeight * 0.9 }
        let lightSets = weights.filter { $0 < maxWeight * 0.8 }
        if heavyCluster.count >= 1 && heavyCluster.count <= 3 && lightSets.count >= 1 {
            return .topSetBackoffs
        }

        // Ascending: weights monotonically increase (with small tolerance), heaviest is last.
        let ascendingCount = zip(weights, weights.dropFirst()).filter { $0 <= $1 }.count
        if ascendingCount >= analysisSets.count - 2 && weights.last == maxWeight {
            return .ascending
        }

        // Descending pyramid: mostly descending, heaviest is first.
        let descendingCount = zip(weights, weights.dropFirst()).filter { $0 > $1 }.count
        if descendingCount >= analysisSets.count - 2 && weights.first == maxWeight {
            return .descendingPyramid
        }

        // Ascending pyramid: max weight is in the middle (not first or last).
        let maxIndex = weights.firstIndex(of: maxWeight) ?? 0
        if maxIndex > 0 && maxIndex < weights.count - 1 {
            return .ascendingPyramid
        }

        return .unknown
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

    // All weight values are stored in kg. Increments are calibrated for kg plate sizes.
    static func weightIncrement(for currentWeight: Double, primaryMuscle: Muscle, equipmentType: EquipmentType) -> Double {
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

        return muscleBasedIncrement(for: currentWeight, primaryMuscle: primaryMuscle)
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
