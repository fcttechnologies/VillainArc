import Foundation
import SwiftData

enum SystemState {
    static func userProfile(context: ModelContext) throws -> UserProfile? {
        try context.fetch(UserProfile.single).first
    }

    static func ensureUserProfile(context: ModelContext) throws -> UserProfile {
        if let existing = try userProfile(context: context) { return existing }

        let profile = UserProfile()
        context.insert(profile)
        try context.save()
        return profile
    }

    static func appSettings(context: ModelContext) throws -> AppSettings? {
        try context.fetch(AppSettings.single).first
    }

    static func ensureAppSettings(context: ModelContext) throws -> AppSettings {
        if let existing = try appSettings(context: context) { return existing }

        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }

    static func healthSyncState(context: ModelContext) throws -> HealthSyncState? {
        try context.fetch(HealthSyncState.single).first
    }

    static func ensureHealthSyncState(context: ModelContext) throws -> HealthSyncState {
        if let existing = try healthSyncState(context: context) { return existing }

        let syncState = HealthSyncState()
        context.insert(syncState)
        try context.save()
        return syncState
    }
}
