import AppIntents
import SwiftData

struct GetHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Hydration"
    static let description = IntentDescription("Tells you how much water you've had today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let day = try context.fetch(HydrationDay.forDay(.now)).first
        let total = day?.totalVolume ?? 0

        guard total > 0 else {
            return .result(dialog: "You haven't logged any water today yet.")
        }

        let totalText = settings.hydrationUnit.display(total)
        if let target = day?.goalTargetML, target > 0 {
            let targetText = settings.hydrationUnit.display(target)
            if day?.goalCompleted == true {
                return .result(dialog: "Today you've had \(totalText) of water and hit your \(targetText) goal.")
            }
            return .result(dialog: "Today you've had \(totalText) of water, against your \(targetText) goal.")
        }
        return .result(dialog: "Today you've had \(totalText) of water.")
    }
}
