#if DEBUG
import Foundation
import SwiftData

/// Seeds the real app store with curated, marketing-grade demo data for the Screenshot Studio.
/// Reuses the same unit conventions the app uses (completed-set weights in kg → display as clean lbs;
/// active-session weights in display units).
///
/// **Converging: it inserts what is missing, re-anchors what it wrote before to the present, and
/// deletes nothing.** The store is the signed-in account's own and every model here syncs, so a
/// clear-first seed would push tombstones for the user's real training to every one of their
/// devices.
@MainActor
enum ScreenshotStudioSeeder {
    /// Catalog IDs for the demo push plan.
    private static let planExerciseIDs = ["barbell_bench_press", "dumbbell_incline_bench_press", "cable_bench_chest_fly", "cable_bar_pushdown"]

    /// The fixed identities of the demo rows: what makes a re-seed converge, and what each scene
    /// fetches so it photographs the curated row rather than whatever else the account holds.
    enum DemoID {
        static let plan = VASyncIdentity.screenshotStudioID("plan")
        static let activeSession = VASyncIdentity.screenshotStudioID("active-session")
        static let summarySession = VASyncIdentity.screenshotStudioID("summary-session")
        static let cardioSession = VASyncIdentity.screenshotStudioID("cardio-session")
        static func historySession(_ index: Int) -> UUID { VASyncIdentity.screenshotStudioID("history-session-\(index)") }
    }

    static func seedAll(in context: ModelContext = SharedModelContainer.container.mainContext) throws {
        dedupeExercises(in: context)
        // Health caches (35 days of steps, energy, sleep, heart, hydration, weight + a goal).
        try DebugOperations.seedHealthSamples(scenario: .daily, replacingExisting: false, in: context)

        let plan = demoPlan(in: context)
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

    private static func demoPlan(in context: ModelContext) -> WorkoutPlan {
        if let existing = try? context.fetch(WorkoutPlan.byID(DemoID.plan)).first { return existing }

        let plan = WorkoutPlan(title: "Push Day", notes: "Chest, shoulders, triceps", favorite: true, completed: true, lastUsed: .now)
        plan.id = DemoID.plan
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
            if let existing = try? context.fetch(WorkoutSession.byID(DemoID.historySession(index))).first {
                reanchor(existing, startingAt: start)
                ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(existing, context: context)
                continue
            }

            let session = WorkoutSession(from: plan)
            session.id = DemoID.historySession(index)
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
        let start = Date.now.addingTimeInterval(-22 * 60)
        if let existing = try? context.fetch(WorkoutSession.byID(DemoID.activeSession)).first {
            reanchor(existing, startingAt: start)
            return
        }

        let session = WorkoutSession(from: plan)
        session.id = DemoID.activeSession
        session.title = "Push Day"
        session.startedAt = start
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
        let start = Date.now.addingTimeInterval(-65 * 60)
        if let existing = try? context.fetch(WorkoutSession.byID(DemoID.summarySession)).first {
            reanchor(existing, startingAt: start)
            return
        }

        let session = WorkoutSession(from: plan)
        session.id = DemoID.summarySession
        session.title = "Push Day"
        session.startedAt = start
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
        let start = Date.now.addingTimeInterval(-32 * 60)
        if let existing = try? context.fetch(CardioSession.byID(DemoID.cardioSession)).first {
            reanchor(existing, startingAt: start)
            return
        }

        let session = CardioSession(activity: .run, environment: .outdoor)
        session.id = DemoID.cardioSession
        session.startedAt = start
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

    // MARK: - Re-anchoring

    /// Slides an already-seeded demo session, and everything hanging off it, to a new start time.
    /// The scenes photograph elapsed time and recent history, so a re-seed has to leave the demo
    /// data reading as current — and it does that by moving the rows it wrote rather than
    /// replacing them.
    private static func reanchor(_ session: WorkoutSession, startingAt start: Date) {
        let delta = start.timeIntervalSince(session.startedAt)
        guard delta != 0 else { return }
        session.startedAt = start
        session.endedAt = session.endedAt?.addingTimeInterval(delta)
        for performance in session.sortedExercises {
            performance.date = performance.date.addingTimeInterval(delta)
            for set in performance.sortedSets {
                set.completedAt = set.completedAt?.addingTimeInterval(delta)
            }
        }
    }

    private static func reanchor(_ session: CardioSession, startingAt start: Date) {
        guard let current = session.startedAt else { return }
        let delta = start.timeIntervalSince(current)
        guard delta != 0 else { return }
        session.startedAt = start
        session.endedAt = session.endedAt?.addingTimeInterval(delta)
        for point in session.routePoints ?? [] {
            point.timestamp = point.timestamp.addingTimeInterval(delta)
        }
    }

    /// Duplicate `Exercise` rows for one catalogID crash `ExerciseHistoryUpdater`'s
    /// `Dictionary(uniqueKeysWithValues:)`, which the seed runs. Keep one per catalogID; the rows
    /// dropped here are local catalog copies (an exercise's synced part is its `ExercisePreference`)
    /// and nothing references them — a plan or a session carries its own copy of the catalogID.
    private static func dedupeExercises(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var seen = Set<String>()
        for ex in all {
            if seen.contains(ex.catalogID) { context.delete(ex) } else { seen.insert(ex.catalogID) }
        }
    }
}
#endif
