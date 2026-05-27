import Foundation
import SwiftData

/// Turns a `PlanTemplate` (immutable static content) into real, user-owned `WorkoutPlan` and
/// `WorkoutSplit` rows. All target weights stay at `0` so the user fills them in based on their
/// own training maxes.
enum PlanTemplateMaterializer {
    /// Builds a single incomplete WorkoutPlan from one day of a template. The caller drops the
    /// returned plan into the editor flow so the user can review and save.
    static func makeIncompletePlan(template: PlanTemplate, day: PlanTemplateDay, context: ModelContext) -> WorkoutPlan {
        let plan = WorkoutPlan()
        plan.title = templateDayTitle(template: template, day: day)
        plan.notes = day.notes
        plan.completed = false
        context.insert(plan)
        attach(day: day, to: plan, context: context)
        return plan
    }

    /// Builds one completed WorkoutPlan per non-rest day in the template, plus a rotation split
    /// whose days link to those plans. Use when the user picks a "program" template from the
    /// split builder and wants the full schedule wired up at once.
    @discardableResult
    static func materializeProgram(template: PlanTemplate, activate: Bool, context: ModelContext) -> WorkoutSplit {
        let split = WorkoutSplit(title: template.name, mode: .rotation, isActive: false)
        context.insert(split)

        var orderedDays: [WorkoutSplitDay] = []
        for (index, day) in template.days.enumerated() {
            let splitDay = WorkoutSplitDay(index: index, split: split, name: day.name, isRestDay: day.isRestDay, targetMuscles: day.muscleGroups)
            if !day.isRestDay {
                let plan = WorkoutPlan(title: templateDayTitle(template: template, day: day), notes: day.notes, favorite: false, completed: true, lastUsed: nil)
                context.insert(plan)
                attach(day: day, to: plan, context: context)
                splitDay.workoutPlan = plan
            }
            split.days?.append(splitDay)
            orderedDays.append(splitDay)
        }

        if activate {
            if let activeSplits = try? context.fetch(WorkoutSplit.active) {
                for previous in activeSplits where previous !== split {
                    previous.isActive = false
                }
            }
            split.isActive = true
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }

        for plan in orderedDays.compactMap(\.workoutPlan) {
            SpotlightIndexer.index(workoutPlan: plan)
        }
        SpotlightIndexer.index(workoutSplit: split)

        return split
    }

    // MARK: - AI-generated

    /// Builds a single incomplete WorkoutPlan from one AI-generated day. The plan stays editable
    /// so the user can review and tweak before save.
    static func makeIncompletePlan(aiDay: AIGeneratedPlanDayResult, planTitle: String, planSummary: String, context: ModelContext) -> WorkoutPlan {
        let plan = WorkoutPlan()
        plan.title = planTitle
        plan.notes = planSummary.isEmpty ? aiDay.notes : planSummary
        plan.completed = false
        context.insert(plan)
        attachAI(day: aiDay, to: plan, context: context)
        return plan
    }

    /// Builds the full AI-generated multi-day program (plans + rotation split). Mirrors
    /// `materializeProgram` for templates.
    @discardableResult
    static func materializeProgram(aiResult: AIGeneratedPlanResult, activate: Bool, context: ModelContext) -> WorkoutSplit {
        let split = WorkoutSplit(title: aiResult.name, mode: .rotation, isActive: false)
        context.insert(split)

        var createdPlans: [WorkoutPlan] = []
        for (index, day) in aiResult.days.enumerated() {
            let splitDay = WorkoutSplitDay(index: index, split: split, name: day.name, isRestDay: false, targetMuscles: day.muscleGroups)
            let dayTitle = aiResult.days.count == 1 ? aiResult.name : "\(aiResult.name) — \(day.name)"
            let plan = WorkoutPlan(title: dayTitle, notes: day.notes, favorite: false, completed: true, lastUsed: nil)
            context.insert(plan)
            attachAI(day: day, to: plan, context: context)
            splitDay.workoutPlan = plan
            split.days?.append(splitDay)
            createdPlans.append(plan)
        }

        if activate {
            if let activeSplits = try? context.fetch(WorkoutSplit.active) {
                for previous in activeSplits where previous !== split {
                    previous.isActive = false
                }
            }
            split.isActive = true
            split.rotationCurrentIndex = 0
            split.rotationLastUpdatedDate = Calendar.current.startOfDay(for: .now)
        }

        for plan in createdPlans {
            SpotlightIndexer.index(workoutPlan: plan)
        }
        SpotlightIndexer.index(workoutSplit: split)

        return split
    }

    // MARK: - Internal

    private static func templateDayTitle(template: PlanTemplate, day: PlanTemplateDay) -> String {
        if template.trainingDayCount == 1 { return template.name }
        return "\(template.name) — \(day.name)"
    }

    private static func attach(day: PlanTemplateDay, to plan: WorkoutPlan, context: ModelContext) {
        for (exerciseIndex, templateExercise) in day.exercises.enumerated() {
            guard let exercise = resolveExercise(catalogID: templateExercise.catalogID, context: context) else { continue }
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            prescription.index = exerciseIndex

            if templateExercise.repsLow == templateExercise.repsHigh {
                prescription.repRange?.activeMode = .target
                prescription.repRange?.targetReps = templateExercise.repsLow
            } else {
                prescription.repRange?.activeMode = .range
                prescription.repRange?.lowerRange = templateExercise.repsLow
                prescription.repRange?.upperRange = templateExercise.repsHigh
            }

            // Replace the default single set ExercisePrescription inserts so we can build the
            // template's full set count from scratch.
            for set in prescription.sets ?? [] {
                context.delete(set)
            }
            prescription.sets?.removeAll()

            for setIndex in 0..<templateExercise.sets {
                let set = SetPrescription(
                    exercisePrescription: prescription,
                    targetWeight: 0,
                    targetReps: templateExercise.repsHigh,
                    targetRest: templateExercise.restSeconds,
                    targetRPE: templateExercise.rpe
                )
                set.index = setIndex
                set.type = templateExercise.setType
                prescription.sets?.append(set)
            }

            plan.exercises?.append(prescription)
            exercise.updateLastAddedAt()
        }
    }

    private static func resolveExercise(catalogID: String, context: ModelContext) -> Exercise? {
        try? context.fetch(Exercise.withCatalogID(catalogID)).first
    }

    private static func attachAI(day: AIGeneratedPlanDayResult, to plan: WorkoutPlan, context: ModelContext) {
        for (exerciseIndex, aiExercise) in day.exercises.enumerated() {
            guard let exercise = resolveExercise(catalogID: aiExercise.catalogID, context: context) else { continue }
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            prescription.index = exerciseIndex

            if aiExercise.repsLow == aiExercise.repsHigh {
                prescription.repRange?.activeMode = .target
                prescription.repRange?.targetReps = aiExercise.repsLow
            } else {
                prescription.repRange?.activeMode = .range
                prescription.repRange?.lowerRange = aiExercise.repsLow
                prescription.repRange?.upperRange = aiExercise.repsHigh
            }

            for set in prescription.sets ?? [] {
                context.delete(set)
            }
            prescription.sets?.removeAll()

            for setIndex in 0..<aiExercise.sets {
                let set = SetPrescription(
                    exercisePrescription: prescription,
                    targetWeight: 0,
                    targetReps: aiExercise.repsHigh,
                    targetRest: aiExercise.restSeconds,
                    targetRPE: aiExercise.rpe
                )
                set.index = setIndex
                prescription.sets?.append(set)
            }

            plan.exercises?.append(prescription)
            exercise.updateLastAddedAt()
        }
    }
}
