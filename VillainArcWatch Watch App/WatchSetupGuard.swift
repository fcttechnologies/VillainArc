import SwiftData

enum WatchSetupGuard {
    static func isReady(context: ModelContext) -> Bool {
        guard (try? context.fetch(AppSettings.single).first) != nil else { return false }
        guard let profile = try? context.fetch(UserProfile.single).first else { return false }
        guard profile.firstMissingStep == nil else { return false }

        let exerciseCount = (try? context.fetchCount(Exercise.catalogExercises)) ?? 0
        return exerciseCount > 0
    }

    static func syncState(context: ModelContext) -> State {
        let hasSettings = (try? context.fetch(AppSettings.single).first) != nil
        let profile = try? context.fetch(UserProfile.single).first
        let exerciseCount = (try? context.fetchCount(Exercise.catalogExercises)) ?? 0

        if hasSettings, let profile, profile.firstMissingStep == nil, exerciseCount > 0 {
            return .ready
        }

        let hasPartialData = hasSettings || profile != nil || exerciseCount > 0
        return hasPartialData ? .syncingFromPhone : .requiresPhoneSetup
    }

    enum State: Equatable {
        case syncingFromPhone
        case requiresPhoneSetup
        case ready
    }
}
