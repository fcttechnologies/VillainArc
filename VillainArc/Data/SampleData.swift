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
            PreWorkoutStatus.self,
            PostWorkoutEffort.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            RepRangePolicy.self,
            RestTimePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            PrescriptionChange.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [.init(schema: schema, isStoredInMemoryOnly: true)])

            syncExercises()
            loadCompletedPlan()
            loadCompletedSession()
            loadSampleSplits()
            if includeIncompleteData {
                loadIncompleteSession()
                loadIncompletePlan()
            }

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

    // MARK: - Completed Plan (Push Day)

    private func loadCompletedPlan() {
        let plan = WorkoutPlan(title: "Push Day", notes: "Chest and triceps focus", favorite: true, completed: true, lastUsed: date(2026, 1, 5, 8, 15))
        context.insert(plan)

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int, rest: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12, 60),
                (.working, 135, 10, 90),
                (.working, 155, 8, 90)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12, 60),
                (.working, 55, 10, 90),
                (.working, 60, 8, 90)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.working, 30, 12, 90),
                (.working, 35, 10, 90),
                (.working, 35, 10, 90)
            ]),
            ("cable_bar_pushdown", "triceps finisher", [
                (.working, 50, 12, 60),
                (.working, 55, 10, 60),
                (.working, 60, 8, 60)
            ])
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            prescription.notes = ex.notes

            if ex.id == "dumbbell_incline_bench_press" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 8
                prescription.repRange.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 12
                prescription.repRange.upperRange = 15
            } else if ex.id == "cable_bar_pushdown" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 10
                prescription.repRange.upperRange = 12
            }

            for s in ex.sets {
                let setPrescription = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: s.weight, targetReps: s.reps, targetRest: s.rest)
                prescription.sets.append(setPrescription)
            }

            plan.exercises.append(prescription)
        }
    }

    // MARK: - Completed Session (Chest Day)

    private func loadCompletedSession() {
        let session = WorkoutSession(title: "Chest Day", notes: "Testing sample", status: .done, startedAt: date(2026, 1, 5, 8, 15), endedAt: date(2026, 1, 5, 9, 5))
        context.insert(session)

        let postEffort = PostWorkoutEffort(effort: 7, notes: "Felt strong")
        session.postEffort = postEffort

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

            if ex.id == "dumbbell_incline_bench_press" {
                performance.repRange.activeMode = .range
                performance.repRange.lowerRange = 8
                performance.repRange.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                performance.repRange.activeMode = .range
                performance.repRange.lowerRange = 12
                performance.repRange.upperRange = 15
            }

            for (j, s) in ex.sets.enumerated() {
                let completedAt = session.startedAt.addingTimeInterval(Double((i * 3 + j + 1) * 120))
                let setPerf = SetPerformance(exercise: performance, setType: s.type, weight: s.weight, reps: s.reps, restSeconds: s.type == .warmup ? 60 : 90, index: j, complete: true, completedAt: completedAt)
                performance.sets.append(setPerf)
            }

            session.exercises.append(performance)
        }
    }

    // MARK: - Incomplete Session

    private func loadIncompleteSession() {
        let session = WorkoutSession(title: "Sample Workout")
        context.insert(session)

        let exercises: [(id: String, notes: String)] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8"),
            ("dumbbell_incline_bench_press", ""),
            ("cable_bench_chest_fly", "slow eccentric"),
            ("barbell_bent_over_row", "Back focus")
        ]

        let sampleReps = [12, 10, 8]
        let sampleWeights: [String: [Double]] = [
            "barbell_bench_press": [45, 135, 165],
            "dumbbell_incline_bench_press": [25, 60, 65],
            "cable_bench_chest_fly": [20, 35, 40],
            "barbell_bent_over_row": [45, 95, 115]
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let performance = ExercisePerformance(exercise: exercise, workoutSession: session, notes: ex.notes)

            let weights = sampleWeights[ex.id] ?? []
            for index in 0..<3 {
                let weight = index < weights.count ? weights[index] : 0
                let setPerf = SetPerformance(exercise: performance, setType: index == 0 ? .warmup : .working, weight: weight, reps: sampleReps[index], restSeconds: index == 0 ? 60 : 90, index: index)
                performance.sets.append(setPerf)
            }

            session.exercises.append(performance)
        }
    }

    // MARK: - Incomplete Plan

    private func loadIncompletePlan() {
        let plan = WorkoutPlan(title: "Back Day")
        context.insert(plan)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bent_over_row"]!)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)

        let set1 = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetRest: 60)
        prescription.sets.append(set1)

        let set2 = SetPrescription(exercisePrescription: prescription, targetRest: 90)
        prescription.sets.append(set2)

        plan.exercises.append(prescription)
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
        plan.exercises.append(benchPrescription)
        
        // Set 1 changes
        let s1 = SetPrescription(exercisePrescription: benchPrescription, setType: .warmup, targetWeight: 1135, targetReps: 10, index: 0)
        benchPrescription.sets.append(s1)
        
        // Set 2 changes
        let s2 = SetPrescription(exercisePrescription: benchPrescription, setType: .working, targetWeight: 155, targetReps: 8, index: 1)
        benchPrescription.sets.append(s2)
        
        let change1 = PrescriptionChange(catalogID: bench.catalogID, targetExercisePrescription: benchPrescription, targetSetPrescription: s1, changeType: .increaseWeight, previousValue: 135, newValue: 145, changeReasoning: "Hit all reps last 3 sessions")
        context.insert(change1)
        
        let change2 = PrescriptionChange(catalogID: bench.catalogID, targetExercisePrescription: benchPrescription, targetSetPrescription: s1, changeType: .decreaseReps, previousValue: 10, newValue: 8)
        context.insert(change2)
        
        let change3 = PrescriptionChange(catalogID: bench.catalogID, targetExercisePrescription: benchPrescription, targetSetPrescription: s2, changeType: .increaseWeight, previousValue: 155, newValue: 160)
        context.insert(change3)
        
        // Exercise 2: Incline DB (Group: Rep Range)
        let incline = Exercise(from: ExerciseCatalog.byID["dumbbell_incline_bench_press"]!)
        let inclinePrescription = ExercisePrescription(exercise: incline, workoutPlan: plan)
        inclinePrescription.repRange.activeMode = .target
        inclinePrescription.repRange.targetReps = 8
        plan.exercises.append(inclinePrescription)
        
        let change4 = PrescriptionChange(catalogID: incline.catalogID, targetExercisePrescription: inclinePrescription, changeType: .changeRepRangeMode, previousValue: Double(RepRangeMode.target.rawValue), newValue: Double(RepRangeMode.range.rawValue), changeReasoning: "Switching to range for hypertrophy phase")
        context.insert(change4)
        
        let change5 = PrescriptionChange(catalogID: incline.catalogID, targetExercisePrescription: inclinePrescription, changeType: .increaseRepRangeLower, previousValue: 8, newValue: 10)
        context.insert(change5)
        
        let change6 = PrescriptionChange(catalogID: incline.catalogID, targetExercisePrescription: inclinePrescription, changeType: .increaseRepRangeUpper, previousValue: 10, newValue: 12)
        context.insert(change6)
        
        // Exercise 3: Flys (Group: Rest Time)
        let flys = Exercise(from: ExerciseCatalog.byID["cable_bench_chest_fly"]!)
        let flysPrescription = ExercisePrescription(exercise: flys, workoutPlan: plan)
        flysPrescription.restTimePolicy.activeMode = .allSame
        flysPrescription.restTimePolicy.allSameSeconds = 60
        plan.exercises.append(flysPrescription)
        
        let change7 = PrescriptionChange(catalogID: flys.catalogID, targetExercisePrescription: flysPrescription, changeType: .increaseRestTimeSeconds, previousValue: 60, newValue: 90, changeReasoning: "Recovery needs increased")
        context.insert(change7)
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
            prescription.index = index
            prescription.repRange.activeMode = ex.repRange
            if ex.repRange == .range {
                prescription.repRange.lowerRange = ex.lower
                prescription.repRange.upperRange = ex.upper
            } else if ex.repRange == .target {
                prescription.repRange.targetReps = ex.target
            }

            for (setIndex, s) in ex.sets.enumerated() {
                let setPrescription = SetPrescription(exercisePrescription: prescription, setType: s.type, targetWeight: s.weight, targetReps: s.reps, targetRest: s.rest, index: setIndex)
                prescription.sets.append(setPrescription)
            }

            plan.exercises.append(prescription)
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

                for (setIndex, s) in ex.sets.enumerated() {
                    let completedAt = history.date.addingTimeInterval(Double((exerciseIndex * 3 + setIndex + 1) * 120))
                    let setPerf = SetPerformance(exercise: performance, setType: s.type, weight: s.weight, reps: s.reps, restSeconds: s.type == .warmup ? 60 : 90, index: setIndex, complete: true, completedAt: completedAt)
                    performance.sets.append(setPerf)
                }

                session.exercises.append(performance)
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
}

// MARK: - Shared Containers

private let sampleContainer = PreviewDataContainer()
private let sampleContainerWithIncomplete = PreviewDataContainer(includeIncompleteData: true)
private let sampleContainerWithSuggestions: PreviewDataContainer = {
    let container = PreviewDataContainer()
    container.loadSessionWithSuggestions()
    return container
}()
private let sampleContainerSuggestionGeneration: PreviewDataContainer = {
    let container = PreviewDataContainer()
    container.loadSuggestionGenerationScenario()
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
    if let plan = plans.first {
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
        fallback.days.append(day)
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
