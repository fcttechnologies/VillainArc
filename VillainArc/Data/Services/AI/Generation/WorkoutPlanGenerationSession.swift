import Foundation
import FoundationModels
import Observation

@Observable
final class WorkoutPlanGenerationSession {
    let originalPrompt: String

    var generatedPlan: GeneratedWorkoutPlanDraft?
    var isGenerating = false
    var errorMessage: String?

    @ObservationIgnored private var lastSubmittedPrompt: String
    @ObservationIgnored private var generationTask: Task<Void, Never>?

    init(prompt: String) {
        self.originalPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastSubmittedPrompt = self.originalPrompt
    }

    func start() {
        generatePlan(from: originalPrompt)
    }

    func applyRequestedChanges(_ requestedChanges: String) {
        let trimmedChanges = requestedChanges.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChanges.isEmpty else { return }
        guard let generatedPlan else { return }

        let prompt = """
        Original request:
        \(originalPrompt)

        Current generated workout plan:
        \(generatedPlan.promptSummary)

        Update request:
        \(trimmedChanges)

        Return a full fresh workout plan that keeps the good parts of the current plan unless the update request changes them.
        """

        generatePlan(from: prompt)
    }

    func retry() {
        generatePlan(from: lastSubmittedPrompt)
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    deinit {
        generationTask?.cancel()
    }

    static func unavailableMessage(for availability: SystemLanguageModel.Availability) -> String {
        switch availability {
        case .available:
            return "Generation couldn’t start."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence to use plan generation."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still getting ready on this device. Try again in a moment."
        case .unavailable(.deviceNotEligible):
            return "This device doesn’t support Apple Intelligence plan generation."
        default:
            return "This feature isn’t available right now."
        }
    }

    private func generatePlan(from prompt: String) {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        generationTask?.cancel()
        lastSubmittedPrompt = trimmedPrompt
        generationTask = Task { [weak self] in
            await self?.runGeneration(prompt: trimmedPrompt)
        }
    }

    private func runGeneration(prompt: String) async {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            errorMessage = Self.unavailableMessage(for: model.availability)
            return
        }

        isGenerating = true
        errorMessage = nil
        generatedPlan = nil

        do {
            let session = LanguageModelSession(tools: [ExerciseCatalogSearchTool()], instructions: instructions)
            let stream = session.streamResponse(to: prompt, generating: AIWorkoutPlanGeneration.self)

            for try await snapshot in stream {
                guard !Task.isCancelled else { return }
                generatedPlan = GeneratedWorkoutPlanDraft(partial: snapshot.content)
            }
        } catch is CancellationError {
            return
        } catch let error as LanguageModelSession.GenerationError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = "Generation couldn’t finish right now."
        }

        isGenerating = false
        generationTask = nil
    }

    private var instructions: String {
        """
        You are Villain Arc's on-device workout plan writer.
        Generate a workout plan draft using only real exercises from the Villain Arc catalog.
        Always use the searchExercises tool before choosing an exercise.
        Only return exercises whose catalogID, name, muscles, and equipment came from the tool.
        Prefer a coherent exercise order, realistic set counts, and a sensible rep target for each exercise.
        Return the full refreshed plan every time, not partial edits.
        """
    }

    private func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .guardrailViolation:
            return "The request couldn’t be generated as written."
        case .exceededContextWindowSize:
            return "That request is too long to process on device."
        case .concurrentRequests:
            return "Generation is already in progress."
        case .unsupportedLanguageOrLocale:
            return "This language or locale isn’t supported for generation."
        case .assetsUnavailable:
            return "The on-device model isn’t ready yet."
        case .refusal:
            return "The model refused this request."
        case .rateLimited:
            return "Generation is temporarily rate limited. Try again in a moment."
        case .decodingFailure:
            return "The generated plan couldn’t be read correctly."
        default:
            return "Generation couldn’t finish right now."
        }
    }
}

@Observable
final class GeneratedWorkoutPlanDraft {
    var title: String
    var exercises: [GeneratedWorkoutPlanExerciseDraft]

    init(title: String, exercises: [GeneratedWorkoutPlanExerciseDraft]) {
        self.title = title
        self.exercises = exercises
    }

    convenience init(_ content: AIWorkoutPlanGeneration) {
        self.init(
            title: content.title,
            exercises: content.exercises.map(GeneratedWorkoutPlanExerciseDraft.init)
        )
    }

    convenience init(partial content: AIWorkoutPlanGeneration.PartiallyGenerated) {
        self.init(
            title: content.title ?? "Generated Plan",
            exercises: (content.exercises ?? []).compactMap(GeneratedWorkoutPlanExerciseDraft.init(partial:))
        )
    }

    var promptSummary: String {
        let exerciseLines = exercises.map { exercise in
            "- \(exercise.name) [\(exercise.catalogID)] | muscles: \(exercise.musclesText) | equipment: \(exercise.equipmentType.displayName) | sets: \(exercise.setCount) | reps: \(exercise.repRangeText)"
        }

        return """
        Title: \(title)
        Exercises:
        \(exerciseLines.joined(separator: "\n"))
        """
    }

    func deleteExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
    }
}

struct GeneratedWorkoutPlanExerciseDraft: Identifiable, Hashable {
    let id: UUID
    var catalogID: String
    var name: String
    var musclesTargeted: [Muscle]
    var equipmentType: EquipmentType
    var repRange: GeneratedRepRangeDraft?
    var setCount: Int

    init(id: UUID = UUID(), catalogID: String, name: String, musclesTargeted: [Muscle], equipmentType: EquipmentType, repRange: GeneratedRepRangeDraft?, setCount: Int) {
        self.id = id
        self.catalogID = catalogID
        self.name = name
        self.musclesTargeted = musclesTargeted
        self.equipmentType = equipmentType
        self.repRange = repRange
        self.setCount = max(1, setCount)
    }

    init(_ content: AIWorkoutPlanExercise) {
        self.init(
            catalogID: content.exercise.catalogID,
            name: content.exercise.exerciseName,
            musclesTargeted: content.exercise.musclesTargeted,
            equipmentType: content.exercise.equipmentType,
            repRange: content.repRange.map(GeneratedRepRangeDraft.init),
            setCount: content.setCount
        )
    }

    init?(partial content: AIWorkoutPlanExercise.PartiallyGenerated) {
        guard let exercise = content.exercise else { return nil }
        guard let catalogID = exercise.catalogID, !catalogID.isEmpty else { return nil }

        self.init(
            catalogID: catalogID,
            name: exercise.exerciseName ?? "Exercise",
            musclesTargeted: exercise.musclesTargeted ?? [],
            equipmentType: exercise.equipmentType ?? .bodyweight,
            repRange: content.repRange.flatMap(GeneratedRepRangeDraft.init(partial:)),
            setCount: content.setCount ?? 1
        )
    }

    var musclesText: String {
        guard !musclesTargeted.isEmpty else { return "Unknown" }
        return ListFormatter.localizedString(byJoining: musclesTargeted.prefix(3).map(\.displayName))
    }

    var repRangeText: String {
        repRange?.displayText ?? "Not Set"
    }

    mutating func addSet() {
        setCount += 1
    }

    mutating func removeSet() {
        setCount = max(1, setCount - 1)
    }
}

struct GeneratedRepRangeDraft: Hashable {
    var mode: RepRangeMode
    var lower: Int?
    var upper: Int?
    var target: Int?

    init(_ content: AIRepRangeSnapshot) {
        mode = content.mode.repRangeMode
        lower = content.lower
        upper = content.upper
        target = content.target
    }

    init?(partial content: AIRepRangeSnapshot.PartiallyGenerated) {
        guard let mode = content.mode?.repRangeMode else { return nil }
        self.mode = mode
        lower = content.lower
        upper = content.upper
        target = content.target
    }

    var displayText: String {
        switch mode {
        case .range:
            if let lower, let upper {
                return "\(lower)-\(upper) reps"
            }
            return "Range"
        case .target:
            if let target {
                return "\(target) reps"
            }
            return "Target"
        case .notSet:
            return "Not Set"
        }
    }
}
