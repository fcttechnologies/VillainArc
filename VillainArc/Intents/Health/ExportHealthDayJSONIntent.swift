import AppIntents
import SwiftData

struct ExportHealthDayJSONIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Health Day (JSON)"
    static let description = IntentDescription("Returns one day of your tracked Villain Arc health data (weight, sleep, steps, distance, energy) as JSON. Leave the date empty for today. Useful for saving to a file or syncing elsewhere.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Export health data for \(\.$date) as JSON")
    }

    @Parameter(title: "Date", description: "The day to export. Leave empty for today.")
    var date: Date?

    nonisolated func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: date ?? .now, context: context)
        return .result(value: try healthExportJSONFile(healthDayExportRecord(from: snapshot), filename: "villain-arc-health-day.json"))
    }
}
