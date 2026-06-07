import AppIntents
import SwiftData

struct GetRespiratoryRateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Respiratory Rate"
    static let description = IntentDescription("Tells you your respiratory rate range for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let respiratory = try context.fetch(HealthRespiratoryRate.forDay(.now)).first else {
            return .result(dialog: "You don't have respiratory rate data for today yet.")
        }

        let unit = String(localized: "breaths per minute")
        switch (respiratory.minRate, respiratory.maxRate) {
        case let (minRate?, maxRate?):
            if minRate == maxRate {
                return .result(dialog: "Today, your respiratory rate is \(minRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
            }
            return .result(dialog: "Today, your respiratory rate ranged from \(minRate.formatted(.number.precision(.fractionLength(0)))) to \(maxRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
        case let (minRate?, nil):
            return .result(dialog: "Today, your lowest respiratory rate was \(minRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
        case let (nil, maxRate?):
            return .result(dialog: "Today, your highest respiratory rate was \(maxRate.formatted(.number.precision(.fractionLength(0)))) \(unit).")
        case (nil, nil):
            return .result(dialog: "You don't have respiratory rate data for today yet.")
        }
    }
}
