import AppIntents
import SwiftData

struct GetHeartRateForDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Heart Rate For Day"
    static let description = IntentDescription("Tells you heart vitals for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get heart rate for \(\.$date)")
    }

    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try heartRateDialog(for: date, context: context)))
    }
}

struct GetRespiratoryRateForDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Respiratory Rate For Day"
    static let description = IntentDescription("Tells you respiratory rate for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get respiratory rate for \(\.$date)")
    }

    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try respiratoryRateDialog(for: date, context: context)))
    }
}

struct GetWristTemperatureForDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wrist Temperature For Day"
    static let description = IntentDescription("Tells you sleeping wrist temperature for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get wrist temperature for \(\.$date)")
    }

    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try wristTemperatureDialog(for: date, context: context)))
    }
}

struct GetHydrationForDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Hydration For Day"
    static let description = IntentDescription("Tells you hydration intake for a specific day.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get hydration for \(\.$date)")
    }

    @Parameter(title: "Date") var date: Date

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try hydrationDialog(for: date, context: context)))
    }
}
