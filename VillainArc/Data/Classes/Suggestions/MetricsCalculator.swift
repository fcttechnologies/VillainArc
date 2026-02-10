import Foundation
import FoundationModels

@Generable
enum TrainingStyle: String {
    case straightSets = "Straight Sets"        // all weights within ~10% of average
    case ascendingPyramid = "Ascending Pyramid" // weight peaks in middle, not first or last
    case descendingPyramid = "Descending Pyramid" // heaviest first, weight drops each set
    case ascending = "Ascending"               // weights ramp up monotonically, heaviest is last
    case topSetBackoffs = "Top Set Then Backoffs" // 1-3 heavy sets at top, remaining are clearly lighter
    case unknown = "Unknown"
}

struct MetricsCalculator {
    static func selectProgressionSets(from performance: ExercisePerformance, overrideStyle: TrainingStyle? = nil) -> [SetPerformance] {
        // Picks the working sets that drive progression rules.
        let sets = performance.sortedSets
        guard !sets.isEmpty else { return [] }

        let regularSets = sets.filter { $0.type == .working }
        if !regularSets.isEmpty {
            // If user labels sets properly, use all regular sets.
            return regularSets
        }

        // If set types are unreliable, infer training style by weight pattern.
        let style = overrideStyle ?? detectTrainingStyle(sets)
        return setsForStyle(style, from: sets)
    }

    private static func setsForStyle(_ style: TrainingStyle, from sets: [SetPerformance]) -> [SetPerformance] {
        switch style {
        case .straightSets:
            return sets
        case .ascendingPyramid:
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            return sets.filter { $0.weight >= maxWeight * 0.95 }
                .sorted { $0.index < $1.index }
        case .descendingPyramid:
            // Heaviest sets are at the front; include all sets near top weight.
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            return sets.filter { $0.weight >= maxWeight * 0.9 }
                .sorted { $0.index < $1.index }
        case .ascending:
            // Heaviest sets are at the end; include all sets near top weight.
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            return sets.filter { $0.weight >= maxWeight * 0.9 }
                .sorted { $0.index < $1.index }
        case .topSetBackoffs:
            // Pick the heavy cluster: sets within 10% of max weight.
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            guard maxWeight > 0 else { return sets }
            return sets.filter { $0.weight >= maxWeight * 0.9 }
                .sorted { $0.weight > $1.weight }
        case .unknown:
            return sets.sorted { $0.weight > $1.weight }
        }
    }

    static func detectTrainingStyle(_ sets: [SetPerformance]) -> TrainingStyle {
        // Infers training style by weight patterns when set types aren't reliable.
        guard sets.count >= 3 else { return .unknown }

        let weights = sets.map { $0.weight }
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
        if ascendingCount >= sets.count - 2 && weights.last == maxWeight {
            return .ascending
        }

        // Descending pyramid: mostly descending, heaviest is first.
        let descendingCount = zip(weights, weights.dropFirst()).filter { $0 > $1 }.count
        if descendingCount >= sets.count - 2 && weights.first == maxWeight {
            return .descendingPyramid
        }

        // Ascending pyramid: max weight is in the middle (not first or last).
        let maxIndex = weights.firstIndex(of: maxWeight) ?? 0
        if maxIndex > 0 && maxIndex < weights.count - 1 {
            return .ascendingPyramid
        }

        return .unknown
    }

    static func weightIncrement(for currentWeight: Double, primaryMuscle: Muscle, equipmentType: EquipmentType) -> Double {
        switch equipmentType {
        case .dumbbellSingle:
            return currentWeight < 15 ? 2.5 : 5.0
        case .dumbbells:
            let perHand = max(0, currentWeight / 2)
            return perHand < 15 ? 5.0 : 10.0
        case .cableSingle:
            return currentWeight < 30 ? 2.5 : 5.0
        case .cables:
            return currentWeight < 60 ? 5.0 : 10.0
        case .machine, .smithMachine:
            return currentWeight < 100 ? 5.0 : 10.0
        case .barbell:
            break
        case .bodyweight:
            if currentWeight <= 0 { return 0 }
            return currentWeight < 25 ? 2.5 : 5.0
        }

        return muscleBasedIncrement(for: currentWeight, primaryMuscle: primaryMuscle)
    }

    private static func muscleBasedIncrement(for currentWeight: Double, primaryMuscle: Muscle) -> Double {
        // Muscle-group based increments (larger jumps for bigger movers).
        switch primaryMuscle {
        case .chest, .shoulders, .back:
            return 5.0
        case .biceps, .triceps:
            return 5.0
        case .frontDelt, .sideDelt, .rearDelt, .lats, .lowerBack,
             .upperTraps, .lowerTraps, .midTraps, .rhomboids:
            return 5.0
        case .longHeadBiceps, .shortHeadBiceps, .brachialis,
             .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps:
            return 5.0
        case .quads, .hamstrings, .glutes:
            return 10.0
        case .calves:
            return 10.0
        case .adductors, .abductors:
            return 5.0
        case .abs, .obliques, .upperAbs, .lowerAbs:
            return 5.0
        case .forearms, .wrists, .rotatorCuff:
            return 2.5
        case .upperChest, .lowerChest, .midChest:
            return 5.0
        }
    }

    static func roundToNearestPlate(_ value: Double, plate: Double = 2.5) -> Double {
        // Keeps weight changes on realistic plate increments.
        guard plate > 0 else { return value }
        return (value / plate).rounded() * plate
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
