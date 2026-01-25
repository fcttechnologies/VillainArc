import AppIntents

struct ShowTemplatesListIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Templates"
    static let description = IntentDescription("Opens your template list.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.navigate(to: .templateList)
        return .result()
    }
}
