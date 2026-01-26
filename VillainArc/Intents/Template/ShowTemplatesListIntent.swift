import AppIntents

struct ShowTemplatesListIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Templates"
    static let description = IntentDescription("Opens your template list.")
    static let supportedModes: IntentModes = .foreground

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .templateList)
        return .result()
    }
}
