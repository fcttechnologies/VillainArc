import AppIntents
import SwiftData

struct ExportHealthRangeJSONIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Health Range (JSON)"
    static let description = IntentDescription("Returns a range of days of your tracked Villain Arc health data as a JSON array, one record per day from the start date to the end date.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Export health data from \(\.$startDate) to \(\.$endDate) as JSON")
    }

    @Parameter(title: "Start Date")
    var startDate: Date

    @Parameter(title: "End Date")
    var endDate: Date

    nonisolated func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let context = makeHealthIntentReadContext()
        let records = try healthDayExportRecords(start: startDate, end: endDate, context: context)
        let json = try healthExportJSONString(records)
        return .result(value: json)
    }
}
