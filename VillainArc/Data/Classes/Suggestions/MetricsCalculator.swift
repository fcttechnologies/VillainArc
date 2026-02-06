import Foundation

enum SetEligibility {
    case workingSet
    case supportSet
    case warmupSet
}

enum TrainingStyle {
    case straightSets        // all weights within ~10% of average
    case ascendingPyramid    // weight peaks in middle, not first or last
    case descendingPyramid   // heaviest first, weight drops each set
    case ascending           // weights ramp up monotonically, heaviest is last
    case topSetBackoffs      // 1-3 heavy sets at top, remaining are clearly lighter
    case unknown
}

extension ExerciseSetType {
    var eligibility: SetEligibility {
        switch self {
        case .regular:
            return .workingSet
        case .failure, .dropSet, .superSet:
            return .supportSet
        case .warmup:
            return .warmupSet
        }
    }

    var shouldDriveProgression: Bool {
        eligibility == .workingSet
    }
}

struct MetricsCalculator {
    static func selectProgressionSets(from performance: ExercisePerformance, overrideStyle: TrainingStyle? = nil) -> [SetPerformance] {
        // Picks the best 1–2 working sets to drive progression rules.
        let sets = performance.sortedSets
        guard !sets.isEmpty else { return [] }

        let regularSets = sets.filter { $0.type == .regular }
        if regularSets.count >= 2 {
            // If user labels sets properly, take the heaviest regular sets.
            return Array(regularSets.sorted { $0.weight > $1.weight }.prefix(2))
        }

        if regularSets.isEmpty {
            // If set types are unreliable, infer training style by weight pattern.
            let style = overrideStyle ?? detectTrainingStyle(sets)
            return setsForStyle(style, from: sets)
        }

        // If there are some regular sets but fewer than 2, backfill with heaviest non-warmups.
        var selected = regularSets
        if selected.count < 2 {
            let nonWarmup = sets.filter { $0.type != .warmup }
            let additional = nonWarmup
                .filter { candidate in
                    !selected.contains { $0.id == candidate.id }
                }
                .sorted { $0.weight > $1.weight }
            selected.append(contentsOf: Array(additional.prefix(2 - selected.count)))
        }

        return selected
    }

    private static func setsForStyle(_ style: TrainingStyle, from sets: [SetPerformance]) -> [SetPerformance] {
        switch style {
        case .straightSets:
            return Array(sets.prefix(2))
        case .ascendingPyramid:
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            let topSets = sets.filter { $0.weight >= maxWeight * 0.95 }
            return Array(topSets.sorted { $0.index < $1.index }.prefix(2))
        case .descendingPyramid:
            return Array(sets.prefix(2))
        case .ascending:
            // Heaviest sets are at the end.
            return Array(sets.suffix(2).reversed())
        case .topSetBackoffs:
            // Pick the heavy cluster: sets within 10% of max weight.
            let maxWeight = sets.map { $0.weight }.max() ?? 0
            guard maxWeight > 0 else { return Array(sets.prefix(2)) }
            let heavyCluster = sets.filter { $0.weight >= maxWeight * 0.9 }
            return Array(heavyCluster.sorted { $0.weight > $1.weight }.prefix(3))
        case .unknown:
            return Array(sets.sorted { $0.weight > $1.weight }.prefix(2))
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

    static func weightIncrement(for currentWeight: Double, primaryMuscle: Muscle?) -> Double {
        // Heuristic weight jump based on muscle group or load.
        if let muscle = primaryMuscle {
            // Muscle-group based increments (larger jumps for bigger movers).
            switch muscle {
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

        // Fallback based on absolute load.
        if currentWeight < 50 {
            return 2.5
        } else if currentWeight < 150 {
            return 5.0
        } else {
            return 10.0
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
