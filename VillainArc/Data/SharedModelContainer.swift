import SwiftData
import Foundation

enum SharedModelContainer {

    static let appGroupID = "group.com.fcttechnologies.VillainArcCont"
    static let sharedDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            fatalError("App Group defaults not found for \(appGroupID). Check App Groups capability + entitlements.")
        }
        return defaults
    }()

    static let schema = Schema([
        WorkoutSession.self,
        PreWorkoutContext.self,
        ExercisePerformance.self,
        SetPerformance.self,
        Exercise.self,
        UserProfile.self,
        ExerciseHistory.self,
        ProgressionPoint.self,
        RepRangePolicy.self,
        RestTimeHistory.self,
        WorkoutPlan.self,
        ExercisePrescription.self,
        SetPrescription.self,
        WorkoutSplit.self,
        WorkoutSplitDay.self,
        PrescriptionChange.self
    ])

    static let container: ModelContainer = {
        do {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                .appendingPathComponent("VillainArc.store")
            else {
                fatalError("App Group container URL not found for \(appGroupID). Check App Groups capability + entitlements.")
            }

            let configuration = ModelConfiguration(
                nil,
                schema: schema,
                url: url,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont")
            )

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()
}

enum WorkoutPreferences {
    static let autoStartRestTimerKey = "autoStartRestTimer"
    static let autoCompleteSetAfterRPEKey = "autoCompleteSetAfterRPE"
    static let liveActivitiesEnabledKey = "workoutLiveActivitiesEnabled"
    static let restTimerNotificationsEnabledKey = "restTimerNotificationsEnabled"

    static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        let defaults = SharedModelContainer.sharedDefaults
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    static var autoStartRestTimerEnabled: Bool {
        bool(forKey: autoStartRestTimerKey, default: true)
    }

    static var autoCompleteSetAfterRPEEnabled: Bool {
        bool(forKey: autoCompleteSetAfterRPEKey, default: false)
    }

    static var liveActivitiesEnabled: Bool {
        bool(forKey: liveActivitiesEnabledKey, default: true)
    }

    static var restTimerNotificationsEnabled: Bool {
        bool(forKey: restTimerNotificationsEnabledKey, default: true)
    }
}
