import SwiftUI
import SwiftData

@MainActor
class PreviewDataContainer {
    var modelContainer: ModelContainer

    var context: ModelContext {
        modelContainer.mainContext
    }

    init(includeIncompleteData: Bool = false) {
        let schema = Schema([
            WorkoutSession.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            UserProfile.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [.init(schema: schema, isStoredInMemoryOnly: true)])

            context.insert(AppSettings())
            syncExercises()
            loadCompletedPlan()
            loadCompletedSession()
            loadSampleSplits()
            if includeIncompleteData {
                loadIncompleteSession()
                loadIncompletePlan()
            }

            rebuildExerciseHistories()

            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func syncExercises() {
        for catalogItem in ExerciseCatalog.all {
            context.insert(Exercise(from: catalogItem))
        }
    }

    @discardableResult
    private func insertSuggestionEvent(for exercise: ExercisePrescription, changes: [PrescriptionChange], session: WorkoutSession? = nil, targetSet: SetPrescription? = nil, category: SuggestionCategory = .performance, reasoning: String? = nil) -> SuggestionEvent {
        let event = SuggestionEvent(category: category, catalogID: exercise.catalogID, sessionFrom: session, targetExercisePrescription: exercise, targetSetPrescription: targetSet, triggerTargetSetID: targetSet?.id, trainingStyle: .straightSets, changeReasoning: reasoning, changes: changes)
        context.insert(event)
        for change in changes {
            change.event = event
        }
        return event
    }

    // MARK: - Completed Plan (Push Day)

    private func loadCompletedPlan() {
        let plan = WorkoutPlan(title: "Push Day", notes: "Chest and triceps focus", favorite: true, completed: true, lastUsed: date(2026, 1, 5, 8, 15))
        context.insert(plan)

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int, rest: Int, targetRPE: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12, 60, 0),
                (.working, 135, 10, 90, 7),
                (.working, 155, 8, 90, 8)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12, 60, 0),
                (.working, 55, 10, 90, 8),
                (.working, 60, 8, 90, 10)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.working, 30, 12, 90, 8),
                (.working, 35, 10, 90, 8),
                (.working, 35, 10, 90, 9)
            ]),
            ("cable_bar_pushdown", "triceps finisher", [
                (.working, 50, 12, 60, 8),
                (.working, 55, 10, 60, 9),
                (.working, 60, 8, 60, 9)
            ])
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            clearSeededSets(from: prescription)
            prescription.notes = ex.notes

            if ex.id == "dumbbell_incline_bench_press" {
                prescription.repRange?.activeMode = .range
                prescription.repRange?.lowerRange = 8
                prescription.repRange?.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                prescription.repRange?.activeMode = .range
                prescription.repRange?.lowerRange = 12
                prescription.repRange?.upperRange = 15
            } else if ex.id == "cable_bar_pushdown" {
                prescription.repRange?.activeMode = .range
                prescription.repRange?.lowerRange = 10
                prescription.repRange?.upperRange = 12
            }

            for s in ex.sets {
                let setPrescription = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: s.weight, targetReps: s.reps, targetRest: s.rest, targetRPE: s.targetRPE)
                prescription.sets?.append(setPrescription)
            }

            plan.exercises?.append(prescription)
        }
    }

    // MARK: - Completed Session (Chest Day)

    private func loadCompletedSession() {
        let session = WorkoutSession(title: "Chest Day", notes: "Testing sample", status: .done, startedAt: date(2026, 1, 5, 8, 15), endedAt: date(2026, 1, 5, 9, 5))
        context.insert(session)

        session.preWorkoutContext?.feeling = .okay
        session.preWorkoutContext?.tookPreWorkout = true
        session.preWorkoutContext?.notes = "Slept fine, but appetite was low before training."
        session.postEffort = 7

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12),
                (.working, 135, 10),
                (.working, 155, 8)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12),
                (.working, 55, 10),
                (.working, 60, 8)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.working, 30, 12),
                (.working, 35, 10),
                (.working, 35, 10)
            ]),
            ("push_ups", "2xAMRAP", [
                (.working, 0, 25),
                (.working, 0, 18)
            ])
        ]

        for (i, ex) in exercises.enumerated() {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let performance = ExercisePerformance(exercise: exercise, workoutSession: session, notes: ex.notes)
            clearSeededSets(from: performance)

            if ex.id == "dumbbell_incline_bench_press" {
                performance.repRange?.activeMode = .range
                performance.repRange?.lowerRange = 8
                performance.repRange?.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                performance.repRange?.activeMode = .range
                performance.repRange?.lowerRange = 12
                performance.repRange?.upperRange = 15
            }

            for (j, s) in ex.sets.enumerated() {
                let completedAt = session.startedAt.addingTimeInterval(Double((i * 3 + j + 1) * 120))
                let setPerf = SetPerformance(exercise: performance, setType: s.type, weight: s.weight, reps: s.reps, restSeconds: s.type == .warmup ? 60 : 90, index: j, complete: true, completedAt: completedAt)
                performance.sets?.append(setPerf)
            }

            session.exercises?.append(performance)
        }
    }

    // MARK: - Incomplete Session

    private func loadIncompleteSession() {
        let plan = WorkoutPlan(title: "Sample Workout Template")
        context.insert(plan)

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int, rest: Int, targetRPE: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12, 60, 0),
                (.working, 0, 10, 90, 7),
                (.working, 165, 8, 90, 10)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12, 60, 0),
                (.working, 60, 10, 90, 8),
                (.working, 65, 8, 90, 9)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.warmup, 20, 12, 60, 0),
                (.working, 35, 10, 90, 8),
                (.working, 40, 8, 90, 9)
            ]),
            ("barbell_bent_over_row", "Back focus", [
                (.warmup, 45, 12, 60, 0),
                (.working, 95, 10, 90, 8),
                (.working, 115, 8, 90, 9)
            ])
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            clearSeededSets(from: prescription)
            prescription.notes = ex.notes

            for s in ex.sets {
                let setPrescription = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: s.weight, targetReps: s.reps, targetRest: s.rest, targetRPE: s.targetRPE)
                prescription.sets?.append(setPrescription)
            }

            plan.exercises?.append(prescription)
        }

        let session = WorkoutSession(from: plan)
        session.title = "Sample Workout"
        context.insert(session)
    }

    // MARK: - Incomplete Plan

    private func loadIncompletePlan() {
        let plan = WorkoutPlan(title: "Back Day")
        context.insert(plan)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bent_over_row"]!)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
        clearSeededSets(from: prescription)

        let set1 = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetRest: 60)
        prescription.sets?.append(set1)

        let set2 = SetPrescription(exercisePrescription: prescription, targetRest: 90)
        prescription.sets?.append(set2)

        plan.exercises?.append(prescription)
    }

    // MARK: - Splits

    private func loadSampleSplits() {
        let weeklySplit = WorkoutSplit(title: "PPL Split", mode: .weekly, isActive: true)
        weeklySplit.days = (1...7).map { weekday in
            WorkoutSplitDay(weekday: weekday, split: weeklySplit, isRestDay: weekday == 1 || weekday == 4)
        }
        context.insert(weeklySplit)

        let rotationSplit = WorkoutSplit(title: "Upper/Lower", mode: .rotation)
        rotationSplit.days = [
            WorkoutSplitDay(index: 0, split: rotationSplit, name: "Upper Body"),
            WorkoutSplitDay(index: 1, split: rotationSplit, name: "Lower Body"),
            WorkoutSplitDay(index: 2, split: rotationSplit, name: "Rest", isRestDay: true)
        ]
        context.insert(rotationSplit)
    }

    fileprivate func rebuildExerciseHistories() {
        let performances = (try? context.fetch(ExercisePerformance.completedAll)) ?? []
        let catalogIDs = Set(performances.map(\.catalogID))
        let existingHistories = (try? context.fetch(FetchDescriptor<ExerciseHistory>())) ?? []
        let historyMap = Dictionary(uniqueKeysWithValues: existingHistories.map { ($0.catalogID, $0) })

        for history in existingHistories where !catalogIDs.contains(history.catalogID) {
            context.delete(history)
        }

        for catalogID in catalogIDs {
            let history = historyMap[catalogID] ?? {
                let history = ExerciseHistory(catalogID: catalogID)
                context.insert(history)
                return history
            }()

            let matchingPerformances = performances
                .filter { $0.catalogID == catalogID }
                .sorted { $0.date > $1.date }
            history.recalculate(using: matchingPerformances)
        }
    }

    // MARK: - Session with Suggestions
    
    func loadSessionWithSuggestions() {
        let session = WorkoutSession(title: "Suggestions Test", status: .pending)
        context.insert(session)
        
        let plan = WorkoutPlan(title: "Chest Growth")
        context.insert(plan)
        session.workoutPlan = plan
        
        // Exercise 1: Bench Press (Groups: Set 1, Set 2)
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let benchPrescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        clearSeededSets(from: benchPrescription)
        plan.exercises?.append(benchPrescription)
        
        // Set 1 changes
        let s1 = SetPrescription(exercisePrescription: benchPrescription, setType: .warmup, targetWeight: 1135, targetReps: 10, index: 0)
        benchPrescription.sets?.append(s1)
        
        // Set 2 changes
        let s2 = SetPrescription(exercisePrescription: benchPrescription, setType: .working, targetWeight: 155, targetReps: 8, index: 1)
        benchPrescription.sets?.append(s2)
        
        let change1 = PrescriptionChange(changeType: .increaseWeight, previousValue: 135, newValue: 145)
        context.insert(change1)

        let change2 = PrescriptionChange(changeType: .decreaseReps, previousValue: 10, newValue: 8)
        context.insert(change2)

        let change3 = PrescriptionChange(changeType: .increaseWeight, previousValue: 155, newValue: 160)
        context.insert(change3)
        insertSuggestionEvent(for: benchPrescription, changes: [change1, change2], session: session, targetSet: s1, reasoning: "Hit all reps last 3 sessions")
        insertSuggestionEvent(for: benchPrescription, changes: [change3], session: session, targetSet: s2)
        
        // Exercise 2: Incline DB (Group: Rep Range)
        let incline = Exercise(from: ExerciseCatalog.byID["dumbbell_incline_bench_press"]!)
        let inclinePrescription = ExercisePrescription(exercise: incline, workoutPlan: plan)
        inclinePrescription.repRange?.activeMode = .target
        inclinePrescription.repRange?.targetReps = 8
        plan.exercises?.append(inclinePrescription)
        
        let change4 = PrescriptionChange(changeType: .changeRepRangeMode, previousValue: Double(RepRangeMode.target.rawValue), newValue: Double(RepRangeMode.range.rawValue))
        context.insert(change4)

        let change5 = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 8, newValue: 10)
        context.insert(change5)

        let change6 = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 10, newValue: 12)
        context.insert(change6)
        insertSuggestionEvent(for: inclinePrescription, changes: [change4, change5, change6], session: session, category: .repRangeConfiguration, reasoning: "Switching to range for hypertrophy phase")
        
        // Exercise 3: Flys (Group: Rest Time)
        let flys = Exercise(from: ExerciseCatalog.byID["cable_bench_chest_fly"]!)
        let flysPrescription = ExercisePrescription(exercise: flys, workoutPlan: plan)
        clearSeededSets(from: flysPrescription)
        let flysSet1 = SetPrescription(exercisePrescription: flysPrescription, setType: .working, targetWeight: 30, targetReps: 12, targetRest: 60, index: 0)
        flysPrescription.sets?.append(flysSet1)
        plan.exercises?.append(flysPrescription)
        
        let change7 = PrescriptionChange(changeType: .increaseRest, previousValue: 60, newValue: 90)
        context.insert(change7)
        insertSuggestionEvent(for: flysPrescription, changes: [change7], session: session, targetSet: flysSet1, category: .recovery, reasoning: "Recovery needs increased")
    }

    // MARK: - Suggestion Generation Scenario

    func loadSuggestionGenerationScenario() {
        let plan = WorkoutPlan(title: "Progression Test Plan", completed: true)
        context.insert(plan)

        let planExercises: [(id: String, repRange: RepRangeMode, lower: Int, upper: Int, target: Int, sets: [(type: ExerciseSetType, weight: Double, reps: Int, rest: Int)])] = [
            ("dumbbell_incline_bench_press", .range, 8, 10, 0, [
                (.working, 60, 8, 90),
                (.working, 60, 8, 90)
            ]),
            ("barbell_bent_over_row", .range, 8, 10, 0, [
                (.working, 135, 8, 120),
                (.working, 135, 8, 120)
            ]),
            ("cable_bench_chest_fly", .notSet, 0, 0, 0, [
                (.working, 30, 12, 90),
                (.working, 30, 12, 90)
            ]),
            ("cable_bar_pushdown", .range, 10, 12, 0, [
                (.working, 55, 10, 60),
                (.working, 55, 10, 60)
            ])
        ]

        for (index, ex) in planExercises.enumerated() {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            clearSeededSets(from: prescription)
            prescription.index = index
            prescription.repRange?.activeMode = ex.repRange
            if ex.repRange == .range {
                prescription.repRange?.lowerRange = ex.lower
                prescription.repRange?.upperRange = ex.upper
            } else if ex.repRange == .target {
                prescription.repRange?.targetReps = ex.target
            }

            for (setIndex, s) in ex.sets.enumerated() {
                let setPrescription = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: s.weight, targetReps: s.reps, targetRest: s.rest, index: setIndex)
                prescription.sets?.append(setPrescription)
            }

            plan.exercises?.append(prescription)
        }

        let historySessions: [(date: Date, exercises: [(id: String, repRange: RepRangeMode, lower: Int, upper: Int, target: Int, sets: [(type: ExerciseSetType, weight: Double, reps: Int)])])] = [
            (
                date(2026, 2, 1, 8, 0),
                [
                    ("dumbbell_incline_bench_press", .range, 8, 10, 0, [
                        (.working, 60, 10),
                        (.working, 60, 10)
                    ]),
                    ("barbell_bent_over_row", .range, 8, 10, 0, [
                        (.working, 135, 6),
                        (.working, 135, 6)
                    ]),
                    ("cable_bench_chest_fly", .range, 12, 15, 0, [
                        (.working, 30, 12),
                        (.working, 30, 12)
                    ]),
                    ("cable_bar_pushdown", .range, 10, 12, 0, [
                        (.working, 55, 12),
                        (.working, 55, 11)
                    ])
                ]
            ),
            (
                date(2026, 2, 3, 8, 0),
                [
                    ("dumbbell_incline_bench_press", .range, 8, 10, 0, [
                        (.working, 60, 10),
                        (.working, 60, 10)
                    ]),
                    ("barbell_bent_over_row", .range, 8, 10, 0, [
                        (.working, 135, 7),
                        (.working, 135, 7)
                    ]),
                    ("cable_bench_chest_fly", .range, 12, 15, 0, [
                        (.working, 30, 13),
                        (.working, 30, 12)
                    ]),
                    ("cable_bar_pushdown", .range, 10, 12, 0, [
                        (.working, 55, 12),
                        (.working, 55, 10)
                    ])
                ]
            ),
            (
                date(2026, 2, 5, 8, 0),
                [
                    ("dumbbell_incline_bench_press", .range, 8, 10, 0, [
                        (.working, 60, 10),
                        (.working, 60, 10)
                    ]),
                    ("barbell_bent_over_row", .range, 8, 10, 0, [
                        (.working, 135, 9),
                        (.working, 135, 8)
                    ]),
                    ("cable_bench_chest_fly", .range, 12, 15, 0, [
                        (.working, 30, 12),
                        (.working, 30, 12)
                    ]),
                    ("cable_bar_pushdown", .range, 10, 12, 0, [
                        (.working, 55, 12),
                        (.working, 55, 12)
                    ])
                ]
            )
        ]

        for (sessionIndex, history) in historySessions.enumerated() {
            let session = WorkoutSession(title: "History Session \(sessionIndex + 1)", status: .done, startedAt: history.date, endedAt: history.date.addingTimeInterval(45 * 60))
            context.insert(session)

            for (exerciseIndex, ex) in history.exercises.enumerated() {
                let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
                let performance = ExercisePerformance(exercise: exercise, workoutSession: session, index: exerciseIndex, repRangeMode: ex.repRange, lowerRange: ex.lower, upperRange: ex.upper, targetReps: ex.target)
                clearSeededSets(from: performance)

                for (setIndex, s) in ex.sets.enumerated() {
                    let completedAt = history.date.addingTimeInterval(Double((exerciseIndex * 3 + setIndex + 1) * 120))
                    let setPerf = SetPerformance(exercise: performance, setType: s.type, weight: s.weight, reps: s.reps, restSeconds: s.type == .warmup ? 60 : 90, index: setIndex, complete: true, completedAt: completedAt)
                    performance.sets?.append(setPerf)
                }

                session.exercises?.append(performance)
            }
        }

        let session = WorkoutSession(from: plan)
        session.title = "Summary Test Session"
        session.status = SessionStatus.summary.rawValue
        session.startedAt = date(2026, 2, 7, 8, 0)
        session.endedAt = date(2026, 2, 7, 9, 0)
        context.insert(session)

        for (exerciseIndex, performance) in session.sortedExercises.enumerated() {
            for (setIndex, set) in performance.sortedSets.enumerated() {
                set.complete = true
                set.completedAt = session.startedAt.addingTimeInterval(Double((exerciseIndex * 3 + setIndex + 1) * 120))
            }
        }

        if let incline = session.sortedExercises.first(where: { $0.catalogID == "dumbbell_incline_bench_press" }) {
            for set in incline.sortedSets where set.type == .working {
                set.weight = 60
                set.reps = 10
            }
        }

        if let row = session.sortedExercises.first(where: { $0.catalogID == "barbell_bent_over_row" }) {
            for set in row.sortedSets where set.type == .working {
                set.weight = 135
                set.reps = 7
            }
        }

        if let fly = session.sortedExercises.first(where: { $0.catalogID == "cable_bench_chest_fly" }) {
            for set in fly.sortedSets where set.type == .working {
                set.weight = 30
                set.reps = 12
            }
        }

        if let pushdown = session.sortedExercises.first(where: { $0.catalogID == "cable_bar_pushdown" }) {
            for set in pushdown.sortedSets where set.type == .working {
                set.weight = 55
                set.reps = 12
            }
        }
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: components) ?? .now
    }

    private func clearSeededSets(from performance: ExercisePerformance) {
        performance.sets?.removeAll()
    }

    private func clearSeededSets(from prescription: ExercisePrescription) {
        prescription.sets?.removeAll()
    }
}

// MARK: - Shared Containers

private let sampleContainer = PreviewDataContainer()
private let sampleContainerWithIncomplete = PreviewDataContainer(includeIncompleteData: true)
private let sampleContainerWithSuggestions: PreviewDataContainer = {
    let container = PreviewDataContainer()
    container.loadSessionWithSuggestions()
    container.rebuildExerciseHistories()
    return container
}()
private let sampleContainerSuggestionGeneration: PreviewDataContainer = {
    let container = PreviewDataContainer()
    container.loadSuggestionGenerationScenario()
    container.rebuildExerciseHistories()
    return container
}()

// MARK: - Sample Accessors

@MainActor
func sampleCompletedSession() -> WorkoutSession {
    let sessions = (try? sampleContainer.context.fetch(WorkoutSession.completedSession)) ?? []
    if let session = sessions.first {
        return session
    }

    let fallback = WorkoutSession(title: "Chest Day", status: .done, endedAt: .now)
    fallback.preWorkoutContext?.feeling = .okay
    fallback.preWorkoutContext?.tookPreWorkout = true
    fallback.preWorkoutContext?.notes = "Slept fine, but appetite was low before training."
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleIncompleteSession() -> WorkoutSession {
    let sessions = (try? sampleContainerWithIncomplete.context.fetch(WorkoutSession.incomplete)) ?? []
    if let session = sessions.first {
        return session
    }

    let fallback = WorkoutSession(title: "New Workout")
    sampleContainerWithIncomplete.context.insert(fallback)
    return fallback
}

@MainActor
func sampleCompletedPlan() -> WorkoutPlan {
    let descriptor = FetchDescriptor(predicate: WorkoutPlan.completedPredicate)
    let plans = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let plan = plans.first(where: { $0.title == "Push Day" }) ?? plans.first {
        return plan
    }

    let fallback = WorkoutPlan(title: "Push Day", completed: true)
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleIncompletePlan() -> WorkoutPlan {
    let plans = (try? sampleContainerWithIncomplete.context.fetch(WorkoutPlan.incomplete)) ?? []
    if let plan = plans.first {
        return plan
    }

    let fallback = WorkoutPlan(title: "Back Day")
    sampleContainerWithIncomplete.context.insert(fallback)
    return fallback
}

@MainActor
func sampleEditingPlan() -> WorkoutPlan {
    let plan = sampleCompletedPlan()
    plan.isEditing = true
    return plan
}

@MainActor
func sampleWeeklySplit() -> WorkoutSplit {
    let descriptor = FetchDescriptor<WorkoutSplit>()
    let splits = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let split = splits.first(where: { $0.mode == .weekly }) {
        return split
    }

    let fallback = WorkoutSplit(mode: .weekly)
    fallback.days = (1...7).map { WorkoutSplitDay(weekday: $0, split: fallback) }
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleRotationSplit() -> WorkoutSplit {
    let descriptor = FetchDescriptor<WorkoutSplit>()
    let splits = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let split = splits.first(where: { $0.mode == .rotation }) {
        return split
    }

    let fallback = WorkoutSplit(title: "Upper/Lower", mode: .rotation)
    for i in 0..<3 {
        let day = WorkoutSplitDay(index: i, split: fallback, name: "Day \(i + 1)")
        fallback.days?.append(day)
    }
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleSessionWithSuggestions() -> WorkoutSession {
    let sessions = (try? sampleContainerWithSuggestions.context.fetch(WorkoutSession.incomplete)) ?? []
    if let session = sessions.first {
        return session
    }
    // Should have been created
    let fallback = WorkoutSession(title: "Suggestions Test (Fallback)")
    sampleContainerWithSuggestions.context.insert(fallback)
    return fallback
}

@MainActor
func sampleSuggestionGenerationSession() -> WorkoutSession {
    let summaryStatus = SessionStatus.summary.rawValue
    let predicate = #Predicate<WorkoutSession> { $0.status == summaryStatus }
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1
    if let session = (try? sampleContainerSuggestionGeneration.context.fetch(descriptor))?.first {
        return session
    }
    let fallback = WorkoutSession(title: "Suggestion Generation (Fallback)", status: .summary)
    sampleContainerSuggestionGeneration.context.insert(fallback)
    return fallback
}

// MARK: - View Modifiers

extension View {
    func sampleDataContainer() -> some View {
        self.modelContainer(sampleContainer.modelContainer)
    }

    func sampleDataContainerIncomplete() -> some View {
        self.modelContainer(sampleContainerWithIncomplete.modelContainer)
    }
    
    func sampleDataContainerSuggestions() -> some View {
        self.modelContainer(sampleContainerWithSuggestions.modelContainer)
    }

    func sampleDataContainerSuggestionGeneration() -> some View {
        self.modelContainer(sampleContainerSuggestionGeneration.modelContainer)
    }
}
