import Foundation
import SwiftData

import FoundationModels

@MainActor
struct AISuggestionGenerator {
    static func generateSuggestions(for session: WorkoutSession) async -> [PrescriptionChange] {
        guard let plan = session.workoutPlan else { return [] }
        
        // Check if the on-device model is available
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            // Model unavailable (Apple Intelligence not enabled, device not eligible, or model not ready)
            return []
        }

        let tools: [any Tool] = [
            ExerciseHistoryContextTool(),
            RecentExercisePerformancesTool()
        ]

        var suggestions: [PrescriptionChange] = []

        for exercisePerf in session.sortedExercises {
            guard let prescription = exercisePerf.prescription else { continue }

            let input = AIExerciseSuggestionInput(
                catalogID: exercisePerf.catalogID,
                exerciseName: exercisePerf.name,
                primaryMuscle: prescription.musclesTargeted.first?.rawValue ?? "Unknown",
                prescription: AIExercisePrescriptionSnapshot(prescription: prescription),
                performance: AIExercisePerformanceSnapshot(performance: exercisePerf)
            )

            do {
                let modelSession = LanguageModelSession(tools: tools, instructions: instructions)
                let prompt = Prompt {
                    "You are a strength training coach. Suggest 0-5 precise, data-driven changes."
                    ""
                    input
                }
                let response = try await modelSession.respond(
                    to: prompt,
                    generating: AISuggestionOutput.self
                )

                let mapped = mapSuggestions(
                    response.content.suggestions,
                    session: session,
                    performance: exercisePerf,
                    prescription: prescription,
                    plan: plan
                )
                suggestions.append(contentsOf: mapped)
            } catch {
                // If the model fails, skip AI suggestions for this exercise.
                continue
            }
        }

        return suggestions
    }

    private static var instructions: String {
        """
        You are an expert strength training coach. Analyze prescriptions vs performance and propose safe, incremental changes.

        Output Rules:
        - Exercise-level changes must use targetSetIndex = -1.
        - Set-level changes must use a valid set index (0-based).
        - Only output quantifiable changes (numbers).
        - Always include a short, user-facing reasoning.
        - Avoid duplicate or contradictory changes for the same target.
        - If unsure or don't have enough information to make a suggestion, return no suggestions.
        - Only suggest Change Rep Range Mode when current mode is Not Set and history supports the choice.

        Evidence-Guided Rule Patterns You May Use:
        - Increase weight when the user has hit the top of their rep range for 2 sessions in a row, and make another suggestion to reset reps to the bottom of their rep range.
        - Increase weight when the user exceeds a target by at least 1 rep for 2 sessions.
        - Increase weight with a larger jump when reps exceed the top by 4+ (range) or 5+ (target) for 2 sessions.
        - Increase reps by 1 when the user repeats the same reps at the same weight for 2 sessions within the rep range.
        - Decrease weight if they fall below the lower bound in 2 of the last 3 sessions while attempting prescribed load.
        - Decrease weight if they consistently reduce load to hit reps.
        - Update prescription weight if they use the same different weight for ~3 sessions.
        - Increase rest if rest is shorter than prescribed and reps drop, or if a plateau coincides with struggling reps.

        Tools available:
        1. getExerciseHistoryContext(catalogID: String)
           - Returns cached aggregate stats (PRs, trends, typical patterns) across ALL sessions
           - Very token-efficient, call this first for historical context

        2. getRecentExercisePerformances(catalogID: String, limit: Int)
           - Returns last N detailed performances (max 5, sorted recent-first)
           - Use for set-by-set analysis, plateau detection, consistency checks
           - Start with limit=2-3 for efficiency, use 5 for deeper analysis
        """
    }

    private static func mapSuggestions(_ suggestions: [AISuggestion], session: WorkoutSession, performance: ExercisePerformance, prescription: ExercisePrescription, plan: WorkoutPlan) -> [PrescriptionChange] {
        suggestions.compactMap { suggestion in
            buildChange(from: suggestion, session: session, performance: performance, prescription: prescription, plan: plan)
        }
    }

    private static func buildChange(from suggestion: AISuggestion, session: WorkoutSession, performance: ExercisePerformance, prescription: ExercisePrescription, plan: WorkoutPlan) -> PrescriptionChange? {
        let changeType = suggestion.changeType.changeType
        let isExerciseLevel = suggestion.changeType.isExerciseLevel
        let setIndex = suggestion.targetSetIndex

        if isExerciseLevel == false && setIndex < 0 {
            return nil
        }

        if isExerciseLevel && setIndex >= 0 {
            // Ignore set index for exercise-level changes.
        }

        let change = PrescriptionChange()
        change.source = .ai
        change.catalogID = performance.catalogID
        change.sessionFrom = session
        change.targetPlan = plan
        change.changeType = changeType
        change.changeReasoning = suggestion.reasoning
        change.createdAt = Date()
        change.decision = .pending
        change.outcome = .pending
        change.sourceExercisePerformance = performance

        if isExerciseLevel {
            if changeType == .changeRepRangeMode {
                guard prescription.repRange.activeMode == .notSet else { return nil }
            }

            if changeType == .increaseRestTimeSeconds || changeType == .decreaseRestTimeSeconds {
                guard prescription.restTimePolicy.activeMode == .allSame else { return nil }
            }

            change.targetExercisePrescription = prescription
            change.previousValue = previousExerciseValue(for: changeType, prescription: prescription)
            change.newValue = normalizedExerciseValue(for: changeType, value: suggestion.newValue)
        } else {
            guard let setPrescription = prescription.sortedSets.first(where: { $0.index == setIndex }) else {
                return nil
            }
            change.targetSetPrescription = setPrescription
            change.targetExercisePrescription = prescription

            if let sourceSet = performance.sortedSets.first(where: { $0.index == setIndex }) {
                change.sourceSetPerformance = sourceSet
            }

            change.previousValue = previousSetValue(for: changeType, set: setPrescription)
            change.newValue = normalizedSetValue(for: changeType, value: suggestion.newValue)
        }

        if let previous = change.previousValue,
           let newValue = change.newValue,
           abs(previous - newValue) < 0.0001 {
            return nil
        }

        return change
    }

    private static func previousSetValue(for changeType: ChangeType, set: SetPrescription) -> Double? {
        switch changeType {
        case .increaseWeight, .decreaseWeight:
            return set.targetWeight
        case .increaseReps, .decreaseReps:
            return Double(set.targetReps)
        case .increaseRest, .decreaseRest:
            return Double(set.targetRest)
        default:
            return nil
        }
    }

    private static func previousExerciseValue(for changeType: ChangeType, prescription: ExercisePrescription) -> Double? {
        switch changeType {
        case .changeRepRangeMode:
            return Double(prescription.repRange.activeMode.rawValue)
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return Double(prescription.restTimePolicy.allSameSeconds)
        default:
            return nil
        }
    }

    private static func normalizedSetValue(for changeType: ChangeType, value: Double) -> Double? {
        switch changeType {
        case .increaseWeight, .decreaseWeight:
            let rounded = MetricsCalculator.roundToNearestPlate(value)
            return max(0, rounded)
        case .increaseReps, .decreaseReps:
            return Double(max(1, Int(value.rounded())))
        case .increaseRest, .decreaseRest:
            return Double(max(0, Int(value.rounded())))
        default:
            return nil
        }
    }

    private static func normalizedExerciseValue(for changeType: ChangeType, value: Double) -> Double? {
        switch changeType {
        case .changeRepRangeMode:
            let rawValue = Int(value.rounded())
            guard let mode = RepRangeMode(rawValue: rawValue),
                  mode != .notSet else { return nil }
            return Double(mode.rawValue)
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return Double(max(0, Int(value.rounded())))
        default:
            return nil
        }
    }
}
