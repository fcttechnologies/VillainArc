import AppIntents
import SwiftData

struct ExportAllHealthJSONIntent: AppIntent {
    static let title: LocalizedStringResource = "Export All Health Data (JSON)"
    static let description = IntentDescription("Returns your full tracked Villain Arc health history as a JSON file — weight, sleep, steps and distance, energy, heart, respiratory rate, wrist temperature, and hydration. Save the file to sync it elsewhere.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)
        let export = try buildHealthFullExport(context: context)
        return .result(value: try healthExportJSONFile(export, filename: "villain-arc-health-export.json"))
    }
}
