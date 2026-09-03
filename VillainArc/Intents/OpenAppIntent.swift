import AppIntents
import FCTMetrics

struct OpenAppIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenApp

    static let title: LocalizedStringResource = "Open Villain Arc"
    static let supportedModes: IntentModes = .foreground
    
    func perform() async throws -> some IntentResult {
        func run() async throws -> some IntentResult {
            return .result()
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
