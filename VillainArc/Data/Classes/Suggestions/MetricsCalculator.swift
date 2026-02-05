import Foundation

enum SetEligibility {
    case workingSet
    case supportSet
    case warmupSet
}

enum TrainingStyle {
    case heaviestFirst
    case pyramidUp
    case straightSets
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
    static func selectProgressionSets(from performance: ExercisePerformance) -> [SetPerformance] {
        // Picks the best 1–2 working sets to drive progression rules.
        let completeSets = performance.sortedSets.filter { $0.complete }
        guard !completeSets.isEmpty else { return [] }

        let regularSets = completeSets.filter { $0.type == .regular }
        if regularSets.count >= 2 {
            // If user labels sets properly, take the heaviest regular sets.
            return Array(regularSets.sorted { $0.weight > $1.weight }.prefix(2))
        }

        if regularSets.isEmpty {
            // If set types are unreliable, infer training style by weight pattern.
            let style = detectTrainingStyle(completeSets)
            switch style {
            case .heaviestFirst:
                return Array(completeSets.prefix(2))
            case .pyramidUp:
                let maxWeight = completeSets.map { $0.weight }.max() ?? 0
                let topSets = completeSets.filter { $0.weight >= maxWeight * 0.95 }
                return Array(topSets.sorted { $0.index < $1.index }.prefix(2))
            case .straightSets:
                return Array(completeSets.prefix(2))
            case .unknown:
                return Array(completeSets.sorted { $0.weight > $1.weight }.prefix(2))
            }
        }

        // If there are some regular sets but fewer than 2, backfill with heaviest non-warmups.
        var selected = regularSets
        if selected.count < 2 {
            let nonWarmup = completeSets.filter { $0.type != .warmup }
            let additional = nonWarmup
                .filter { candidate in
                    !selected.contains { $0.id == candidate.id }
                }
                .sorted { $0.weight > $1.weight }
            selected.append(contentsOf: Array(additional.prefix(2 - selected.count)))
        }

        return selected
    }

    static func detectTrainingStyle(_ sets: [SetPerformance]) -> TrainingStyle {
        // Infers training style by weight patterns when set types aren't reliable.
        guard sets.count >= 3 else { return .unknown }

        let weights = sets.map { $0.weight }
        // Heaviest-first: mostly descending.
        let descendingCount = zip(weights, weights.dropFirst()).filter { $0 > $1 }.count
        if descendingCount >= sets.count - 2 {
            return .heaviestFirst
        }

        // Pyramid: max in the middle.
        let maxWeight = weights.max() ?? 0
        let maxIndex = weights.firstIndex(of: maxWeight) ?? 0
        if maxIndex > 0 && maxIndex < weights.count - 1 {
            return .pyramidUp
        }

        // Straight sets: all weights within 10% of average.
        let avgWeight = weights.reduce(0, +) / Double(weights.count)
        if avgWeight > 0 {
            let allSimilar = weights.allSatisfy { abs($0 - avgWeight) < avgWeight * 0.1 }
            if allSimilar {
                return .straightSets
            }
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
