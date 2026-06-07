import AppIntents
import SwiftData

struct GetHeartRateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Heart Rate"
    static let description = IntentDescription("Tells you your heart vitals for today — resting heart rate, range, and variability.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let heart = try context.fetch(HealthHeart.forDay(.now)).first else {
            return .result(dialog: "You don't have heart rate data for today yet.")
        }

        var parts: [String] = []
        if let resting = heart.restingHeartRate {
            parts.append("your resting heart rate is \(formattedHeartRateText(resting))")
        }
        if let minRate = heart.minHeartRate, let maxRate = heart.maxHeartRate {
            parts.append("your heart rate ranged from \(formattedHeartRateValue(minRate)) to \(formattedHeartRateText(maxRate))")
        }
        if let walking = heart.walkingHeartRateAverage {
            parts.append("your walking average is \(formattedHeartRateText(walking))")
        }
        if let hrv = heart.heartRateVariabilitySDNN {
            parts.append("your heart rate variability is \(hrv.formatted(.number.precision(.fractionLength(0)))) ms")
        }

        guard !parts.isEmpty else {
            return .result(dialog: "You don't have heart rate data for today yet.")
        }

        return .result(dialog: "Today, \(ListFormatter.localizedString(byJoining: parts)).")
    }
}
