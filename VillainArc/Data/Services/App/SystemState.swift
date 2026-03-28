import Foundation
import SwiftData

@MainActor enum SystemState {
    static func ensureUserProfile(context: ModelContext) throws -> UserProfile {
        if let existing = try context.fetch(UserProfile.single).first { return existing }

        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    static func ensureAppSettings(context: ModelContext) throws -> AppSettings {
        if let existing = try context.fetch(AppSettings.single).first { return existing }

        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    static func ensureHealthSyncState(context: ModelContext) throws -> HealthSyncState {
        if let existing = try context.fetch(HealthSyncState.single).first { return existing }

        let syncState = HealthSyncState()
        context.insert(syncState)
        try context.save()
        return syncState
    }
}
