#if DEBUG
import Foundation
import SwiftData

/// Seeds the real app store with curated, marketing-grade demo data for the Screenshot Studio.
/// Reuses the same unit conventions the app uses (completed-set weights in kg → display as clean lbs;
/// active-session weights in display units). Idempotent: clears its own seeded data first.
@MainActor
enum ScreenshotStudioSeeder {
    /// Catalog IDs for the demo push plan.
    private static let planExerciseIDs = ["barbell_bench_press", "dumbbell_incline_bench_press", "cable_bench_chest_fly", "cable_bar_pushdown"]

    static func seedAll() throws {
        let context = SharedModelContainer.container.mainContext

        clearWorkoutsAndCardio(in: context)
        // Health caches (35 days of steps, energy, sleep, heart, hydration, weight + a goal).
        try DebugOperations.seedHealthSamples(scenario: .daily)

        let plan = makeDemoPlan(in: context)
        seedCompletedHistory(plan: plan, in: context)
        seedActiveSession(plan: plan, in: context)
        seedSummarySession(plan: plan, in: context)
        seedCardioSession(in: context)

        try context.save()
        AppLog.info("Screenshot Studio demo data seeded.")
    }

    // MARK: - Plan

    /// Reuse the exercise the app already seeded at onboarding; only insert if the catalog is empty.
    /// Inserting a duplicate catalogID crashes `ExerciseHistoryUpdater`'s `Dictionary(uniqueKeysWithValues:)`.
    private static func exercise(_ id: String, in context: ModelContext) -> Exercise {
        if let existing = try? context.fetch(Exercise.withCatalogID(id)).first {
            return existing
        }
        let ex = Exercise(from: ExerciseCatalog.byID[id]!)
        context.insert(ex)
        return ex
    }

    private static func makeDemoPlan(in context: ModelContext) -> WorkoutPlan {
        let plan = WorkoutPlan(title: "Push Day", notes: "Chest, shoulders, triceps", favorite: true, completed: true, lastUsed: .now)
        context.insert(plan)

        // Targets are stored in KG (the app converts display→kg on save); author via toKg so they show clean lbs.
        let lbs = WeightUnit.lbs
        let targets: [(id: String, sets: [(type: ExerciseSetType, lbs: Double, reps: Int, rest: Int, rpe: Int)])] = [
            ("barbell_bench_press", [(.warmup, 95, 10, 60, 0), (.working, 135, 8, 120, 8), (.working, 155, 6, 120, 9), (.working, 155, 6, 120, 9)]),
            ("dumbbell_incline_bench_press", [(.warmup, 50, 12, 60, 0), (.working, 65, 10, 90, 8), (.working, 70, 8, 90, 9)]),
            ("cable_bench_chest_fly", [(.working, 35, 12, 75, 8), (.working, 40, 10, 75, 9), (.working, 40, 10, 75, 9)]),
            ("cable_bar_pushdown", [(.working, 60, 12, 60, 8), (.working, 70, 10, 60, 9), (.working, 70, 10, 60, 9)]),
        ]

        for entry in targets {
            let prescription = ExercisePrescription(exercise: exercise(entry.id, in: context), workoutPlan: plan)
            prescription.sets?.removeAll()
            for s in entry.sets {
                let set = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: lbs.toKg(s.lbs), targetReps: s.reps, targetRest: s.rest, targetRPE: s.rpe)
                prescription.sets?.append(set)
            }
            plan.exercises?.append(prescription)
        }
        return plan
    }

    // MARK: - Completed history (heatmap + trends volume + correlation)

    /// Per-exercise working-set ramp in DISPLAY lbs across sessions; converted to kg for storage.
    private static let workingRampLbs: [String: (start: Double, perSession: Double)] = [
        "barbell_bench_press": (130, 2.5),
        "dumbbell_incline_bench_press": (60, 1.25),
        "cable_bench_chest_fly": (32.5, 1.0),
        "cable_bar_pushdown": (55, 1.5),
    ]

    private static func seedCompletedHistory(plan: WorkoutPlan, in context: ModelContext) {
        let lbs = WeightUnit.lbs
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        // 14 sessions over the last ~33 days (overlaps the 35-day health/sleep window for correlation).
        let dayOffsets = Array(stride(from: -33, through: -2, by: 2)).suffix(14)
        let efforts = [7, 8, 6, 9, 7, 8, 7, 9, 6, 8, 7, 8, 9, 7]

        for (index, dayOffset) in dayOffsets.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let start = day.addingTimeInterval(18 * 3600)
            let session = WorkoutSession(from: plan)
            session.startedAt = start
            session.endedAt = start.addingTimeInterval(4200)
            session.status = SessionStatus.done.rawValue
            session.postEffort = efforts[index % efforts.count]
            context.insert(session)

            for performance in session.sortedExercises {
                performance.sets?.removeAll()
                let ramp = workingRampLbs[performance.catalogID] ?? (60, 1.5)
                let workingLbs = ramp.start + Double(index) * ramp.perSession
                var setIndex = 0
                // one warmup
                if let warmup = warmupLbs(for: performance.catalogID) {
                    performance.sets?.append(SetPerformance(exercise: performance, setType: .warmup, weight: lbs.toKg(warmup), reps: 12, restSeconds: 60, index: setIndex, complete: true, completedAt: start.addingTimeInterval(Double(setIndex) * 150)))
                    setIndex += 1
                }
                // three working sets
                for s in 0..<3 {
                    let reps = 10 - s
                    let set = SetPerformance(exercise: performance, setType: .working, weight: lbs.toKg(workingLbs + Double(s) * 2.5), reps: reps, restSeconds: 100, index: setIndex, complete: true, completedAt: start.addingTimeInterval(Double(setIndex) * 150))
                    set.rpe = 8 + (s == 2 ? 1 : 0)
                    performance.sets?.append(set)
                    setIndex += 1
                }
                performance.syncDateToLatestCompletedSet()
            }
            ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(session, context: context)
        }
    }

    private static func warmupLbs(for catalogID: String) -> Double? {
        switch catalogID {
        case "barbell_bench_press": return 95
        case "dumbbell_incline_bench_press": return 45
        default: return nil
        }
    }

    // MARK: - Active session (poster: live logging)

    private static func seedActiveSession(plan: WorkoutPlan, in context: ModelContext) {
        let session = WorkoutSession(from: plan)
        session.title = "Push Day"
        session.startedAt = .now.addingTimeInterval(-22 * 60)
        session.status = SessionStatus.active.rawValue
        context.insert(session)

        let lbs = WeightUnit.lbs
        // The plan copied kg targets into each set; live-logging weights are DISPLAY units, so convert
        // every set (including the still-pending ones) back to clean lbs.
        for performance in session.sortedExercises {
            for set in performance.sortedSets {
                set.weight = lbs.fromKg(set.weight).rounded()
            }
        }
        // Complete warmup + first two working sets on bench (mid-workout poster).
        if let bench = session.sortedExercises.first(where: { $0.catalogID == "barbell_bench_press" }) {
            for (i, set) in bench.sortedSets.prefix(3).enumerated() {
                set.complete = true
                set.completedAt = .now.addingTimeInterval(Double(i - 3) * 180)
            }
        }
    }

    // MARK: - Summary session (PRs)

    private static func seedSummarySession(plan: WorkoutPlan, in context: ModelContext) {
        let lbs = WeightUnit.lbs
        let session = WorkoutSession(from: plan)
        session.title = "Push Day"
        session.startedAt = .now.addingTimeInterval(-65 * 60)
        session.endedAt = .now
        session.status = SessionStatus.summary.rawValue
        session.postEffort = 9
        context.insert(session)

        // Top weights — above all seeded history → clean PR badges.
        let topWorkingLbs: [String: Double] = [
            "barbell_bench_press": 185,
            "dumbbell_incline_bench_press": 80,
            "cable_bench_chest_fly": 50,
            "cable_bar_pushdown": 80,
        ]
        for performance in session.sortedExercises {
            performance.sets?.removeAll()
            let top = topWorkingLbs[performance.catalogID] ?? 100
            var idx = 0
            if let warm = warmupLbs(for: performance.catalogID) {
                performance.sets?.append(SetPerformance(exercise: performance, setType: .warmup, weight: lbs.toKg(warm), reps: 12, restSeconds: 60, index: idx, complete: true, completedAt: session.startedAt.addingTimeInterval(Double(idx) * 150)))
                idx += 1
            }
            for s in 0..<3 {
                let set = SetPerformance(exercise: performance, setType: .working, weight: lbs.toKg(top - Double(2 - s) * 5), reps: 10 - s, restSeconds: 100, index: idx, complete: true, completedAt: session.startedAt.addingTimeInterval(Double(idx) * 150))
                set.rpe = 9
                performance.sets?.append(set)
                idx += 1
            }
            performance.syncDateToLatestCompletedSet()
        }
    }

    // MARK: - Cardio (outdoor run with route)

    private static func seedCardioSession(in context: ModelContext) {
        let session = CardioSession(kind: .outdoorRun)
        session.startedAt = .now.addingTimeInterval(-32 * 60)
        session.endedAt = .now.addingTimeInterval(-2 * 60)
        context.insert(session)

        // A looping route through a park (~3 km). Lat/lon trace; distance recalculated from points.
        let baseLat = 41.8781, baseLon = -87.6298
        var points: [CardioRoutePoint] = []
        let steps = 80
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = t * 2 * Double.pi
            let lat = baseLat + 0.010 * sin(angle) + 0.0008 * sin(angle * 5)
            let lon = baseLon + 0.013 * (1 - cos(angle)) * 0.5 + 0.0008 * cos(angle * 4)
            let point = CardioRoutePoint(index: i, latitude: lat, longitude: lon, timestamp: session.startedAt!.addingTimeInterval(t * 30 * 60), horizontalAccuracy: 5, speedMetersPerSecond: 3.1, session: session)
            points.append(point)
            context.insert(point)
        }
        session.routePoints = points
        session.statusValue = .done
        session.recalculateRouteDistance()
    }

    // MARK: - AI exercise replacement suggestions (composed scene)

    static func sampleReplacementSuggestions() -> [AIResolvedReplacementSuggestion] {
        [
            AIResolvedReplacementSuggestion(catalogID: "dumbbell_lateral_raise", exerciseName: "Dumbbell Lateral Raise", equipment: .dumbbells, reasoning: "Same side-delt focus with a longer, more controlled range of motion."),
            AIResolvedReplacementSuggestion(catalogID: "cable_lateral_raise", exerciseName: "Cable Lateral Raise", equipment: .cableSingle, reasoning: "Constant cable tension keeps the medial delt loaded through the whole rep."),
            AIResolvedReplacementSuggestion(catalogID: "machine_lateral_raise", exerciseName: "Machine Lateral Raise", equipment: .machine, reasoning: "Fixed path lets you push closer to failure safely as a finisher."),
        ]
    }

    // MARK: - Clearing

    private static func clearWorkoutsAndCardio(in context: ModelContext) {
        deleteAll(SetPerformance.self, in: context)
        deleteAll(ExercisePerformance.self, in: context)
        deleteAll(WorkoutSession.self, in: context)
        deleteAll(SetPrescription.self, in: context)
        deleteAll(ExercisePrescription.self, in: context)
        deleteAll(WorkoutPlan.self, in: context)
        deleteAll(ExerciseHistory.self, in: context)
        deleteAll(CardioRoutePoint.self, in: context)
        deleteAll(CardioTreadmillInterval.self, in: context)
        deleteAll(CardioSession.self, in: context)
        dedupeExercises(in: context)
    }

    /// A prior crashed seed could leave duplicate `Exercise` rows for the same catalogID, which
    /// crashes `ExerciseHistoryUpdater`'s `Dictionary(uniqueKeysWithValues:)`. Keep one per catalogID.
    private static func dedupeExercises(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var seen = Set<String>()
        for ex in all {
            if seen.contains(ex.catalogID) { context.delete(ex) } else { seen.insert(ex.catalogID) }
        }
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let models = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for model in models { context.delete(model) }
    }
}
#endif
