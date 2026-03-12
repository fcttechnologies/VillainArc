import FoundationModels

enum FoundationModelPrewarmer {
    static func warmup() {
        Task(priority: .utility) {
            prewarm()
        }
    }

    private static func prewarm() {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return }

        let session = LanguageModelSession()
        session.prewarm()
    }
}
