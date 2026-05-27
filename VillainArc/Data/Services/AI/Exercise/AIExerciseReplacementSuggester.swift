import Foundation
import FoundationModels

/// Asks the on-device system language model for three to five replacement candidates for a given
/// exercise, biased by the user's training context. Falls back gracefully when the model is
/// unavailable; the existing deterministic muscle-overlap ranker still renders the rest of the
/// picker.
struct AIExerciseReplacementSuggester {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    struct Input {
        let currentExerciseName: String
        let currentMuscles: [Muscle]
        let currentEquipment: EquipmentType
        let fitnessLevelDisplay: String?
        let trainingGoalDisplay: String?
        let excludedCatalogID: String

        var summary: String {
            var parts: [String] = []
            parts.append("Current: \(currentExerciseName) (\(currentEquipment.displayName)).")
            if !currentMuscles.isEmpty {
                parts.append("Muscles: \(currentMuscles.prefix(5).map(\.displayName).joined(separator: ", ")).")
            }
            if let fitnessLevelDisplay { parts.append("Fitness level: \(fitnessLevelDisplay).") }
            if let trainingGoalDisplay { parts.append("Training goal: \(trainingGoalDisplay).") }
            return parts.joined(separator: " ")
        }
    }

    static func suggest(input: Input) async -> [AIResolvedReplacementSuggestion] {
        guard isAvailable else { return [] }

        let session = LanguageModelSession(instructions: instructions)
        let prompt = Prompt {
            "Suggest 3 to 5 replacement exercises for the current exercise."
            ""
            "Context:"
            input.summary
            ""
            "Rules:"
            "- Suggestions must train the same primary muscles."
            "- Prefer movements available in a typical commercial gym."
            "- Vary equipment when sensible (a dumbbell or cable variant of a barbell movement is a good swap)."
            "- Do not suggest the same exercise the user is replacing."
            "- One-sentence reasoning per suggestion."
        }

        do {
            let response = try await session.respond(to: prompt, generating: AIReplacementSuggestionList.self)
            return resolve(suggestions: response.content.suggestions, excluding: input.excludedCatalogID)
        } catch {
            return []
        }
    }

    private static var instructions: String {
        """
        You suggest workout exercise replacements that train the same target muscles.
        Return three to five suggestions as an AIReplacementSuggestionList.
        Use familiar gym names like "Dumbbell Bench Press", "Cable Lat Pulldown", "Machine Chest Press".
        Use the EquipmentType enum for the equipment field.
        Vary equipment between suggestions when reasonable so the user has real choice.
        Keep each reasoning to one short sentence.
        """
    }

    // MARK: - Resolution

    private static func resolve(suggestions: [AIReplacementSuggestion], excluding excludedCatalogID: String) -> [AIResolvedReplacementSuggestion] {
        var seen = Set<String>()
        seen.insert(excludedCatalogID)

        var resolved: [AIResolvedReplacementSuggestion] = []
        for suggestion in suggestions {
            guard let catalogID = resolveCatalogID(name: suggestion.exerciseName, equipment: suggestion.equipment) else { continue }
            guard !seen.contains(catalogID) else { continue }
            seen.insert(catalogID)
            guard let catalogItem = ExerciseCatalog.all.first(where: { $0.id == catalogID }) else { continue }
            resolved.append(
                AIResolvedReplacementSuggestion(
                    catalogID: catalogID,
                    exerciseName: catalogItem.name,
                    equipment: catalogItem.equipmentType,
                    reasoning: suggestion.reasoning.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }
        return resolved
    }

    private static func resolveCatalogID(name: String, equipment: EquipmentType) -> String? {
        let normalized = normalize(name)

        if let exact = ExerciseCatalog.all.first(where: { item in
            item.equipmentType == equipment && normalize(item.name) == normalized
        }) {
            return exact.id
        }

        if let nameMatch = ExerciseCatalog.all.first(where: { normalize($0.name) == normalized }) {
            return nameMatch.id
        }

        if let aliasMatch = ExerciseCatalog.all.first(where: { item in
            item.aliases.contains { normalize($0) == normalized }
        }) {
            return aliasMatch.id
        }

        for item in ExerciseCatalog.all where item.equipmentType == equipment {
            for prefix in item.equipmentType.systemAlternateNamePrefixes {
                if normalize("\(prefix) \(item.name)") == normalized { return item.id }
            }
        }

        let tokens = normalized.split(separator: " ").filter { $0.count >= 3 }
        guard !tokens.isEmpty else { return nil }

        let scored = ExerciseCatalog.all.map { item -> (String, Int) in
            let itemName = normalize(item.name)
            var score = 0
            for token in tokens where itemName.contains(token) { score += 1 }
            if item.equipmentType == equipment { score += 2 }
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
}
