import AppIntents
import FCTMetrics
import SwiftData

struct OpenCardioSessionIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenCardioSession

    static let title: LocalizedStringResource = "Open Cardio Session"
    static let description = IntentDescription("Opens a specific cardio session.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$cardioSession)") }

    @Parameter(title: "Cardio Session", requestValueDialog: IntentDialog("Which cardio session would you like to open?")) var cardioSession: CardioSessionEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let sessionID = cardioSession.id
        let predicate = #Predicate<CardioSession> { $0.id == sessionID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedSession = try context.fetch(descriptor).first else { throw OpenCardioSessionError.sessionNotFound }
        guard storedSession.statusValue == .done else { throw OpenCardioSessionError.sessionIncomplete }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.navigate(to: AppRouter.detailDestination(for: storedSession))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenCardioSessionError: Error, CustomLocalizedStringResourceConvertible {
    case sessionNotFound
    case sessionIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .sessionNotFound: return "That cardio session is no longer available."
        case .sessionIncomplete: return "Finish the cardio session before opening its details."
        }
    }
}
