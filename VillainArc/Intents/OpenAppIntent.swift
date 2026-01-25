import AppIntents

struct OpenAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Villain Arc"
    static let supportedModes: IntentModes = .foreground
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
