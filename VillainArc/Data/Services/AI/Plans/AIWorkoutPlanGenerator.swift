import Foundation
import FoundationModels

/// Drives the on-device language model to produce a structured workout plan from a free-text
/// description. After generation, fuzzy-matches each suggested exercise name against the catalog
/// so the materializer can build real `WorkoutPlan` rows from it.
struct AIWorkoutPlanGenerator {
    enum GenerationError: Error {
        case modelUnavailable
        case modelFailed
        case emptyResult
    }

    /// True when the system language model is available on this device. Caller should hide AI UI
    /// when this is false (older simulators, unsupported regions, Apple Intelligence disabled).
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Hard cap on the user-supplied free-text portion of the prompt. Long inputs
    /// don't add information value, slow generation, and give a larger surface for
    /// off-topic or adversarial content reaching the on-device model.
    static let maxUserPromptLength = 500

    static func generate(userPrompt: String, profileContext: AIPlanProfileContext) async -> Result<AIGeneratedPlanResult, GenerationError> {
        guard isAvailable else { return .failure(.modelUnavailable) }

        let session = LanguageModelSession(instructions: instructions)
        let safePrompt = sanitize(userPrompt: userPrompt)

        let prompt = Prompt {
            "Design a structured strength-training plan for this user."
            ""
            "User request:"
            safePrompt
            ""
            "User context:"
            profileContext.summary
            ""
            "Rules:"
            "- Use only the exercise types and equipment a typical commercial gym has."
            "- Compounds first each day, then accessory work."
            "- Stay within 3–8 exercises per day."
            "- Pick rep ranges that match the user's goal: 4–6 for strength, 6–10 for hypertrophy strength bias, 8–12 for hypertrophy, 12–20 for endurance/conditioning."
            "- Use realistic rest periods: 180–240s for heavy compounds, 60–120s for isolation."
            "- Keep names concise and use standard gym terminology."
        }

        do {
            let response = try await session.respond(to: prompt, generating: AIGeneratedPlan.self)
            let resolved = resolve(plan: response.content)
            guard !resolved.days.isEmpty else { return .failure(.emptyResult) }
            return .success(resolved)
        } catch {
            return .failure(.modelFailed)
        }
    }

    /// Trim, cap length, and strip control characters before the prompt reaches the model.
    /// Long inputs are truncated at a word boundary when possible so the request still reads cleanly.
    private static func sanitize(userPrompt: String) -> String {
        let trimmed = userPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .filter { !$0.properties.isDefaultIgnorableCodePoint && $0.value >= 0x20 || $0 == "\n" || $0 == "\t" }
            .map(Character.init)
        let normalized = String(trimmed)
        guard normalized.count > maxUserPromptLength else { return normalized }
        let cutIndex = normalized.index(normalized.startIndex, offsetBy: maxUserPromptLength)
        let head = normalized[..<cutIndex]
        if let lastSpace = head.lastIndex(where: { $0.isWhitespace }) {
            return String(head[..<lastSpace])
        }
        return String(head)
    }

    private static var instructions: String {
        """
        You are a structured workout-plan generator embedded in a strength-training iOS app.
        Return a complete AIGeneratedPlan with name, summary, daysPerWeek, and one entry per training day.
        Each day must list 3–8 exercises in execution order using common gym names like "Bench Press", "Squat", "Romanian Deadlift", "Lat Pulldown".
        Use Muscle enum values for muscleGroups. Use EquipmentType enum values for equipment.
        Set repsLow == repsHigh when you want a fixed target instead of a range.
        Set rpe to 0 only if you genuinely want it unset; otherwise pick a value between 6 and 10.
        Be conservative: stay close to the user's request, do not invent unusual exercises, and prefer well-known programs as a starting point.
        """
    }

    // MARK: - Resolution

    private static func resolve(plan: AIGeneratedPlan) -> AIGeneratedPlanResult {
        var resolvedDays: [AIGeneratedPlanDayResult] = []
        var unresolved: [String] = []

        for day in plan.days {
            var resolvedExercises: [AIGeneratedPlanExerciseResult] = []
            for exercise in day.exercises {
                if let catalogID = resolveCatalogID(for: exercise) {
                    resolvedExercises.append(
                        AIGeneratedPlanExerciseResult(
                            catalogID: catalogID,
                            originalAIName: exercise.exerciseName,
                            sets: max(1, exercise.targetSets),
                            repsLow: clamp(exercise.repsLow, min: 1, max: 50),
                            repsHigh: clamp(max(exercise.repsHigh, exercise.repsLow), min: 1, max: 50),
                            restSeconds: clamp(exercise.restSeconds, min: 15, max: 600),
                            rpe: clamp(exercise.rpe, min: 0, max: 10)
                        )
                    )
                } else {
                    unresolved.append(exercise.exerciseName)
                }
            }

            guard !resolvedExercises.isEmpty else { continue }

            resolvedDays.append(
                AIGeneratedPlanDayResult(
                    name: day.name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? String(localized: "Workout"),
                    muscleGroups: Array(NSOrderedSet(array: day.muscleGroups)) as? [Muscle] ?? day.muscleGroups,
                    notes: day.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    exercises: resolvedExercises
                )
            )
        }

        return AIGeneratedPlanResult(
            name: plan.name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? String(localized: "AI Workout Plan"),
            summary: plan.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            daysPerWeek: clamp(plan.daysPerWeek, min: 1, max: 6),
            days: resolvedDays,
            unresolvedExerciseNames: unresolved
        )
    }

    private static func resolveCatalogID(for exercise: AIGeneratedPlanExercise) -> String? {
        let queryName = exercise.exerciseName.lowercased()
        let queryEquipment = exercise.equipment
        let normalized = normalize(queryName)

        // 1. Exact name + equipment match.
        if let exact = ExerciseCatalog.all.first(where: { item in
            item.equipmentType == queryEquipment && normalize(item.name) == normalized
        }) {
            return exact.id
        }

        // 2. Exact name match (any equipment).
        if let nameMatch = ExerciseCatalog.all.first(where: { normalize($0.name) == normalized }) {
            return nameMatch.id
        }

        // 3. Alias match.
        if let aliasMatch = ExerciseCatalog.all.first(where: { item in
            item.aliases.contains { normalize($0) == normalized }
        }) {
            return aliasMatch.id
        }

        // 4. Equipment prefix + name (e.g. "Barbell Bench Press" → barbell_bench_press).
        for item in ExerciseCatalog.all where item.equipmentType == queryEquipment {
            for prefix in item.equipmentType.systemAlternateNamePrefixes {
                let full = normalize("\(prefix) \(item.name)")
                if full == normalized { return item.id }
            }
        }

        // 5. Substring fallback against catalog id keywords. Prefer the requested equipment.
        let tokens = normalized.split(separator: " ").filter { $0.count >= 3 }
        guard !tokens.isEmpty else { return nil }

        let scored = ExerciseCatalog.all.map { item -> (String, Int) in
            let itemName = normalize(item.name)
            var score = 0
            for token in tokens where itemName.contains(token) { score += 1 }
            if item.equipmentType == queryEquipment { score += 2 }
            return (item.id, score)
        }
        .sorted { $0.1 > $1.1 }

        if let best = scored.first, best.1 >= max(2, tokens.count - 1) { return best.0 }
        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
    }

    private static func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
        Swift.min(upper, Swift.max(lower, value))
    }
}

// MARK: - Profile context

struct AIPlanProfileContext {
    let fitnessLevelDisplay: String?
    let trainingGoalDisplay: String?
    let weightUnit: String

    var summary: String {
        var parts: [String] = []
        if let fitnessLevelDisplay { parts.append("Fitness level: \(fitnessLevelDisplay).") }
        if let trainingGoalDisplay { parts.append("Training goal: \(trainingGoalDisplay).") }
        parts.append("Display weight unit: \(weightUnit).")
        return parts.joined(separator: " ")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
