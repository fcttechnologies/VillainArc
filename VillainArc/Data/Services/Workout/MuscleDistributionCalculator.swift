import FCTCore
import Foundation

struct MuscleDistributionSlice: Identifiable {
    let muscle: Muscle
    let score: Double
    let percentage: Double

    var id: Muscle { muscle }
}

enum MuscleDistributionCalculator {
    static func slices(for workout: WorkoutSession) -> [MuscleDistributionSlice] {
        buildSlices(for: workout.sortedExercises)
    }

    static func slices(for plan: WorkoutPlan) -> [MuscleDistributionSlice] {
        buildSlices(for: plan.sortedExercises)
    }

    /// The distribution across several sessions: every session's exercises folded into one set of
    /// totals, then shared out as percentages of that whole. Summing the per-session *percentages*
    /// would weight a three-exercise session as heavily as a ten-exercise one, which is why the
    /// fold is over raw exercises rather than over `slices(for:)` results.
    static func slices(for sessions: [WorkoutSession]) -> [MuscleDistributionSlice] {
        buildSlices(for: sessions.flatMap(\.sortedExercises))
    }

    /// The window a range asks for, as the date a fetch starts at. `nil` is all of history.
    ///
    /// Anchored to the start of the day rather than to the instant, so a range means the same
    /// thing however far into the day it is read and a session logged this morning never drops out
    /// of "past week" during the afternoon.
    static func windowStart(
        for range: ChartSeriesRange,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .month, value: -1, to: today)
        case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: today)
        case .year: return calendar.date(byAdding: .year, value: -1, to: today)
        case .all: return nil
        }
    }

    private static func buildSlices<ExerciseType: MuscleDistributionExerciseProviding>(for exercises: [ExerciseType]) -> [MuscleDistributionSlice] {
        var totalsByMuscle: [Muscle: Double] = [:]

        for exercise in exercises {
            let majorMuscles = uniqueMajorMuscles(from: exercise.musclesForDistribution)
            guard !majorMuscles.isEmpty else { continue }

            for set in exercise.setsForDistribution {
                let score = distributionScore(volume: set.distributionVolume, reps: set.distributionReps)
                guard score > 0 else { continue }

                let scorePerMuscle = score / Double(majorMuscles.count)
                for muscle in majorMuscles {
                    totalsByMuscle[muscle, default: 0] += scorePerMuscle
                }
            }
        }

        let totalScore = totalsByMuscle.values.reduce(0, +)
        guard totalScore > 0 else { return [] }

        return totalsByMuscle
            .map { muscle, score in
                MuscleDistributionSlice(muscle: muscle, score: score, percentage: (score / totalScore) * 100)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.muscle.displayName < $1.muscle.displayName
                }
                return $0.score > $1.score
            }
    }

    private static func distributionScore(volume: Double, reps: Int) -> Double {
        if volume > 0 {
            return volume
        }

        if reps > 0 {
            return Double(reps)
        }

        return 0
    }

    private static func uniqueMajorMuscles(from muscles: [Muscle]) -> [Muscle] {
        var seen = Set<Muscle>()
        var result: [Muscle] = []

        for muscle in muscles {
            let majorMuscle = majorMuscle(for: muscle)
            if !seen.contains(majorMuscle) {
                seen.insert(majorMuscle)
                result.append(majorMuscle)
            }
        }

        return result
    }

    private static func majorMuscle(for muscle: Muscle) -> Muscle {
        switch muscle {
        case .chest, .back, .shoulders, .biceps, .triceps, .abs, .glutes, .quads, .hamstrings, .calves:
            return muscle
        case .upperChest, .midChest, .lowerChest:
            return .chest
        case .lats, .lowerBack, .upperTraps, .midTraps, .lowerTraps, .rhomboids:
            return .back
        case .frontDelt, .sideDelt, .rearDelt, .rotatorCuff:
            return .shoulders
        case .longHeadBiceps, .shortHeadBiceps, .brachialis, .forearms, .wrists:
            return .biceps
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps:
            return .triceps
        case .upperAbs, .lowerAbs, .obliques:
            return .abs
        case .adductors:
            return .quads
        case .abductors:
            return .glutes
        }
    }
}

private protocol MuscleDistributionSetProviding {
    var distributionVolume: Double { get }
    var distributionReps: Int { get }
}

private protocol MuscleDistributionExerciseProviding {
    associatedtype DistributionSet: MuscleDistributionSetProviding

    var musclesForDistribution: [Muscle] { get }
    var setsForDistribution: [DistributionSet] { get }
}

extension SetPerformance: MuscleDistributionSetProviding {
    var distributionVolume: Double { volume }
    var distributionReps: Int { reps }
}

extension SetPrescription: MuscleDistributionSetProviding {
    var distributionVolume: Double { volume }
    var distributionReps: Int { targetReps }
}

extension ExercisePerformance: MuscleDistributionExerciseProviding {
    var musclesForDistribution: [Muscle] { musclesTargeted }
    var setsForDistribution: [SetPerformance] { sortedSets }
}

extension ExercisePrescription: MuscleDistributionExerciseProviding {
    var musclesForDistribution: [Muscle] { musclesTargeted }
    var setsForDistribution: [SetPrescription] { sortedSets }
}
