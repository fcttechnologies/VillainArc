import AppIntents
import FCTMetrics
import SwiftData

struct DeleteCardioSessionIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentDeleteCardioSession

    static let title: LocalizedStringResource = "Delete Cardio Session"
    static let description = IntentDescription("Deletes a completed cardio session.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Delete \(\.$cardioSession)") }

    @Parameter(title: "Cardio Session", requestValueDialog: IntentDialog("Which cardio session would you like to delete?")) var cardioSession: CardioSessionEntity

    /// Deletes the app's own row and its recorded detail — the route and the machine intervals
    /// cascade with it. A Health workout mirrored from the same session is device-sourced and is
    /// only unlinked, so it stays in history as a standalone Apple Health workout.
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = SharedModelContainer.container.mainContext

            let sessionID = cardioSession.id
            guard let storedSession = try context.fetch(CardioSession.byID(sessionID)).first else { throw DeleteCardioSessionIntentError.cardioSessionNotFound }
            guard storedSession.statusValue == .done else { throw DeleteCardioSessionIntentError.cardioSessionIncomplete }

            let choice = try await requestChoice(
                between: [IntentChoiceOption(title: "Delete", style: .destructive), .cancel],
                dialog: IntentDialog("Delete \"\(cardioSession.title)\"? This action cannot be undone.")
            )
            guard choice.style == .destructive else { throw DeleteCardioSessionIntentError.cancelled }

            SpotlightIndexer.deleteCardioSession(id: sessionID)
            context.delete(storedSession)
            saveContext(context: context)
            return .result(dialog: "Cardio session deleted.")
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum DeleteCardioSessionIntentError: Error, CustomLocalizedStringResourceConvertible {
    case cardioSessionNotFound
    case cardioSessionIncomplete
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .cardioSessionNotFound: return "That cardio session is no longer available."
        case .cardioSessionIncomplete: return "Only completed cardio sessions can be deleted."
        case .cancelled: return "Delete cardio session canceled."
        }
    }
}
