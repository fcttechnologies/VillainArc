import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class ExerciseProgressionAssistant {
    private static let defaultStarterQuestion = "How is my progression looking?"
    @ObservationIgnored private let model = SystemLanguageModel.default
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var baseContext: AIExerciseProgressionContext?
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var hasSeededConversationContext = false

    var latestInsight: AIExerciseProgressionInsight?
    var messages: [ExerciseProgressionMessage] = []
    var streamedReply = ""
    var isLoadingInsight = false
    var isResponding = false
    var errorMessage: String?

    var isModelAvailable: Bool {
        if case .available = model.availability {
            return true
        }
        return false
    }

    deinit {
        activeTask?.cancel()
    }

    func loadInitialInsightIfNeeded(context: AIExerciseProgressionContext) {
        guard latestInsight == nil else { return }
        loadInitialInsight(context: context)
    }

    func loadInitialInsight(context: AIExerciseProgressionContext) {
        activeTask?.cancel()
        isLoadingInsight = true
        errorMessage = nil

        activeTask = Task {
            defer {
                isLoadingInsight = false
                activeTask = nil
            }

            guard isModelAvailable else {
                errorMessage = "Apple Intelligence isn’t available on this device right now."
                return
            }

            let preparedContext = Self.preparedContext(from: context)
            baseContext = preparedContext
            messages.removeAll()
            streamedReply = ""
            session = makeSession()
            hasSeededConversationContext = false

            let prompt = Prompt {
                "Generate a concise exercise progression analysis from this workout history."
                ""
                preparedContext
            }

            do {
                guard let session else { return }
                let response = try await session.respond(to: prompt, generating: AIExerciseProgressionInsight.self)
                latestInsight = Self.validatedInsight(response.content)
                hasSeededConversationContext = true
            } catch is CancellationError {
                return
            } catch {
                errorMessage = "Unable to analyze progression right now. Please try again."
            }
        }
    }

    func ask(_ question: String) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }
        guard isModelAvailable else {
            errorMessage = "Apple Intelligence isn’t available on this device right now."
            return
        }

        activeTask?.cancel()
        streamedReply = ""
        errorMessage = nil
        isResponding = true
        messages.append(ExerciseProgressionMessage(role: .user, text: trimmedQuestion))

        activeTask = Task {
            defer {
                isResponding = false
                activeTask = nil
            }

            if !(await seedConversationContextIfNeeded()) {
                return
            }

            do {
                guard let session else { return }
                guard !session.isResponding else { return }
                let stream = session.streamResponse(to: trimmedQuestion)

                for try await partial in stream {
                    guard !Task.isCancelled else { return }
                    streamedReply = partial.content
                }

                let finalReply = streamedReply.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalReply.isEmpty {
                    messages.append(ExerciseProgressionMessage(role: .assistant, text: finalReply))
                }
                streamedReply = ""
            } catch is CancellationError {
                return
            } catch {
                errorMessage = "Unable to answer that right now. Please try again."
            }
        }
    }

    func resetConversation() {
        activeTask?.cancel()
        session = nil
        hasSeededConversationContext = false
        messages.removeAll()
        streamedReply = ""
        isResponding = false
        errorMessage = nil
    }

    private func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: Self.instructions)
    }

    private func seedConversationContextIfNeeded() async -> Bool {
        guard let baseContext else {
            errorMessage = "Exercise context is missing. Close and reopen this sheet to try again."
            return false
        }

        if session == nil {
            session = makeSession()
        }

        guard !hasSeededConversationContext else { return true }

        let prompt = Prompt {
            "Store this exercise history context for follow-up questions."
            ""
            Self.preparedContext(from: baseContext)
        }

        do {
            guard let session else { return false }
            _ = try await session.respond(to: prompt)
            hasSeededConversationContext = true
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "Unable to prepare the exercise context right now."
            return false
        }
    }

    private static func preparedContext(from context: AIExerciseProgressionContext) -> AIExerciseProgressionContext {
        AIExerciseProgressionContext(
            exercise: context.exercise,
            historySummary: context.historySummary,
            recentPerformances: context.recentPerformances,
            starterQuestion: context.starterQuestion?.isEmpty == false ? context.starterQuestion : defaultStarterQuestion
        )
    }

    private static func validatedInsight(_ insight: AIExerciseProgressionInsight) -> AIExerciseProgressionInsight {
        AIExerciseProgressionInsight(
            summary: insight.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            trend: insight.trend,
            positives: insight.positives.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            concerns: insight.concerns.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            nextStep: insight.nextStep.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: min(1.0, max(0.0, insight.confidence)),
            followUpSuggestions: insight.followUpSuggestions.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    private static var instructions: String {
        """
        You are a strength training analyst reviewing one exercise's recent progression.

        You will receive:
        - exercise identity
        - a compact history summary
        - only the most recent completed performances, sorted recent-first
        - an optional starter question

        Your job:
        - identify the most likely recent trend
        - explain that trend clearly and conservatively
        - point out specific positives and concerns from the recent data
        - suggest one practical next step
        - suggest a few useful follow-up questions

        Guidance:
        - Keep the initial insight concise and specific.
        - Focus on actual performance, not plan compliance.
        - Pay attention to set type labels when present. Working sets matter more than warmups for progression judgments.
        - If the exercise is bodyweight-based, avoid calling zero external weight a weakness.
        - Do not overstate certainty. Use lower confidence when the recent data is noisy or sparse.
        - Prefer explaining what you can see in the data over inventing hidden causes.

        When answering follow-up questions:
        - Stay grounded in the same exercise history context from this session.
        - Be direct and practical.
        - If the data is ambiguous, say so instead of guessing.
        """
    }
}
