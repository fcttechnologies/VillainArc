import FoundationModels

enum FoundationModelPrewarmer {
    static func warmup() { prewarm() }

    private static func prewarm() {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return }

        let session = LanguageModelSession()
        session.prewarm()
    }
}
