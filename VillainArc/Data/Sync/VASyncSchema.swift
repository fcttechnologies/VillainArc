import FCTAccountProfile
import FCTServerSync
import Foundation
import SwiftData

/// Villain Arc's wire: which models sync, to which tables, under which version.
///
/// **What syncs is the app's own authored rows; no HealthKit MIRROR row rides the wire.** The whole
/// `Health*` mirror family, `WeightEntry`/`HydrationDay`/`HydrationEntry` (Apple Health is their
/// canon — VA exports what it authors there and re-imports it), `ExerciseHistory`/
/// `ProgressionPoint` (derived caches, rebuilt from source), `HealthSyncState` (per-device
/// anchors), and `RestTimeHistory` (a per-device last-used stamp with no correct cross-device
/// answer) all stay local. Named cost: weight and hydration history rides Apple Health's own
/// continuity, not the FCT account.
///
/// **`Exercise` stays local too, for a different reason**: it is reference data, not the user's.
/// The catalog ships in the binary and is seeded on every install, so syncing it made each account
/// store an identical copy of something nobody had personalised. Only `ExercisePreference` — the
/// sparse per-account state about a catalog entry — rides the wire. Because the catalog is
/// unsynced, the engine's `clearSyncedData` no longer reaches it, so a departing account's
/// exercise rows are cleared by `VASync.locallyClearedModels` instead.
///
/// The goals the user sets OVER that health data do sync, and one of them carries a health-sourced
/// number: `NewWeightGoalView` prefills the start weight from the latest `WeightEntry`, which is
/// itself imported from a HealthKit sample, so `va.weight_goal.start_weight` can hold a body weight
/// that originated in Apple Health. "Health data stays on the device" is therefore true of the
/// mirror and false as a blanket statement — say both facts, never just the first.
///
/// Rows sync in **every** state, drafts included: an incomplete session or an editing plan copy is
/// an ordinary row whose lifecycle LWW and tombstones already converge, and a per-state filter
/// would leave a completed session's children unpushed (a child row's history entry fires at its
/// save, not at its parent's completion). The one-active-flow rule therefore holds across devices,
/// which is the product's own invariant said cross-device.
///
/// **Villain Arc authors no bytes.** Every model here is records-only, so the app adopts no blob
/// store of its own: the one picture a person has is the FCT account's avatar, which the account
/// blob store carries under `<account>/account/` and `AccountAvatar` renders.
enum VASyncSchema {
    /// The app's path segment in the object store, and **the synced Postgres schema name** — one
    /// string deliberately: the per-app erase resolves its sweep prefix from the schema name.
    static let appSlug = "va"

    /// `<app>.<version>`. Bumped only when a migration changes what a row means on the wire.
    /// At `2`, the name and the birthday left `va.user_profile` — they are the account's.
    static let version = "va.2"

    /// Parents before children, so rows pulled in one cycle resolve their links on the same pass.
    /// `suggestion_event` sits after every table it names; `prescription_change` and
    /// `suggestion_evaluation` after it.
    static let schema = SyncSchema(
        version: version,
        tables: AccountSchema.tables + [
            .of(AppSettings.self),
            .of(EngineDonation.self),
            .of(UserProfile.self),
            .of(ExercisePreference.self),
            .of(TrainingGoal.self),
            .of(TrainingConditionPeriod.self),
            .of(WeightGoal.self),
            .of(StepsGoal.self),
            .of(SleepGoal.self),
            .of(HydrationGoal.self),
            .of(WorkoutPlan.self),
            .of(WorkoutSplit.self),
            .of(WorkoutSplitDay.self),
            .of(ExercisePrescription.self),
            .of(SetPrescription.self),
            .of(WorkoutSession.self),
            .of(PreWorkoutContext.self),
            .of(ExercisePerformance.self),
            .of(SetPerformance.self),
            .of(RepRangePolicy.self),
            .of(CardioSession.self),
            .of(CardioRoutePoint.self),
            .of(CardioMachineInterval.self),
            .of(SuggestionEvent.self),
            .of(SuggestionEvaluation.self),
            .of(PrescriptionChange.self),
        ]
    )
}

// MARK: - AppSettings (singleton, fixed uuid)

extension AppSettings: SyncedModel {
    static var syncTableName: String { "va.app_settings" }
    static var syncIDKeyPath: KeyPath<AppSettings, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<AppSettings> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<AppSettings> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<AppSettings> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "auto_start_rest_timer": .bool(autoStartRestTimer),
            "auto_complete_set_after_rpe": .bool(autoCompleteSetAfterRPE),
            "auto_fill_plan_targets": .bool(autoFillPlanTargets),
            "assume_target_rpe_on_complete": .bool(assumeTargetRPEOnComplete),
            "prefers_target_reference_when_planned": .bool(prefersTargetReferenceWhenPlanned),
            "previous_set_reference_source": .string(previousSetReferenceSource.rawValue),
            "prompt_for_pre_workout_context": .bool(promptForPreWorkoutContext),
            "prompt_for_post_workout_effort": .bool(promptForPostWorkoutEffort),
            "retain_performances_for_learning": .bool(retainPerformancesForLearning),
            "keep_removed_health_data": .bool(keepRemovedHealthData),
            "live_activities_enabled": .bool(liveActivitiesEnabled),
            "steps_notification_mode": .int(Int64(stepsNotificationMode.rawValue)),
            "sleep_notification_mode": .int(Int64(sleepNotificationMode.rawValue)),
            "appearance_mode": .string(appearanceMode.rawValue),
            "weight_unit": .string(weightUnit.rawValue),
            "height_unit": .string(heightUnit.rawValue),
            "distance_unit": .string(distanceUnit.rawValue),
            "energy_unit": .string(energyUnit.rawValue),
            "temperature_unit": .string(temperatureUnit.rawValue),
            "hydration_unit": .string(hydrationUnit.rawValue),
            "hydration_notification_mode": .int(Int64(hydrationNotificationMode.rawValue)),
            "speed_unit": .string(speedUnit.rawValue),
            "favorite_cardio_kind": favoriteCardioKindRawValue.map(JSONValue.string) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["auto_start_rest_timer"]?.boolValue { autoStartRestTimer = value }
        if let value = row["auto_complete_set_after_rpe"]?.boolValue { autoCompleteSetAfterRPE = value }
        if let value = row["auto_fill_plan_targets"]?.boolValue { autoFillPlanTargets = value }
        if let value = row["assume_target_rpe_on_complete"]?.boolValue { assumeTargetRPEOnComplete = value }
        if let value = row["prefers_target_reference_when_planned"]?.boolValue { prefersTargetReferenceWhenPlanned = value }
        if let value = row["previous_set_reference_source"]?.stringValue,
           let source = PreviousSetReferenceSource(rawValue: value) { previousSetReferenceSource = source }
        if let value = row["prompt_for_pre_workout_context"]?.boolValue { promptForPreWorkoutContext = value }
        if let value = row["prompt_for_post_workout_effort"]?.boolValue { promptForPostWorkoutEffort = value }
        if let value = row["retain_performances_for_learning"]?.boolValue { retainPerformancesForLearning = value }
        if let value = row["keep_removed_health_data"]?.boolValue { keepRemovedHealthData = value }
        if let value = row["live_activities_enabled"]?.boolValue { liveActivitiesEnabled = value }
        if let value = row["steps_notification_mode"]?.intValue,
           let mode = StepsEventNotificationMode(rawValue: Int(value)) { stepsNotificationMode = mode }
        if let value = row["sleep_notification_mode"]?.intValue,
           let mode = SleepNotificationMode(rawValue: Int(value)) { sleepNotificationMode = mode }
        if let value = row["appearance_mode"]?.stringValue,
           let mode = AppAppearanceMode(rawValue: value) { appearanceMode = mode }
        if let value = row["weight_unit"]?.stringValue, let unit = WeightUnit(rawValue: value) { weightUnit = unit }
        if let value = row["height_unit"]?.stringValue, let unit = HeightUnit(rawValue: value) { heightUnit = unit }
        if let value = row["distance_unit"]?.stringValue, let unit = DistanceUnit(rawValue: value) { distanceUnit = unit }
        if let value = row["energy_unit"]?.stringValue, let unit = EnergyUnit(rawValue: value) { energyUnit = unit }
        if let value = row["temperature_unit"]?.stringValue, let unit = TemperatureUnit(rawValue: value) { temperatureUnit = unit }
        if let value = row["hydration_unit"]?.stringValue, let unit = HydrationUnit(rawValue: value) { hydrationUnit = unit }
        if let value = row["hydration_notification_mode"]?.intValue,
           let mode = HydrationEventNotificationMode(rawValue: Int(value)) { hydrationNotificationMode = mode }
        if let value = row["speed_unit"]?.stringValue, let unit = SpeedUnit(rawValue: value) { speedUnit = unit }
        if let value = row["favorite_cardio_kind"] { favoriteCardioKindRawValue = value.stringValue }
        return nil
    }
}

// MARK: - EngineDonation (singleton, fixed uuid)

extension EngineDonation: SyncedModel {
    static var syncTableName: String { "va.engine_donation" }
    static var syncIDKeyPath: KeyPath<EngineDonation, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<EngineDonation> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<EngineDonation> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<EngineDonation> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(donating: false)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "donating": .bool(donating),
            "decided_at": .date(decidedAt),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["donating"]?.boolValue { donating = value }
        if let value = row["decided_at"]?.dateValue { decidedAt = value }
        return nil
    }
}

// MARK: - UserProfile (singleton, fixed uuid)

extension UserProfile: SyncedModel {
    static var syncTableName: String { "va.user_profile" }
    static var syncIDKeyPath: KeyPath<UserProfile, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<UserProfile> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<UserProfile> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<UserProfile> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "gender": .string(gender.rawValue),
            "date_joined": .date(dateJoined),
            "height_cm": heightCm.map(JSONValue.double) ?? .null,
            "fitness_level": fitnessLevel.map { .string($0.rawValue) } ?? .null,
            "fitness_level_set_at": fitnessLevelSetAt.map(JSONValue.date) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["gender"]?.stringValue, let gender = UserGender(rawValue: value) { self.gender = gender }
        if let value = row["date_joined"]?.dateValue { dateJoined = value }
        if let value = row["height_cm"] { heightCm = value.doubleValue }
        if let value = row["fitness_level"] {
            fitnessLevel = value.stringValue.flatMap(FitnessLevel.init(rawValue:))
        }
        if let value = row["fitness_level_set_at"] { fitnessLevelSetAt = value.dateValue }
        // The level and the moment it was chosen are one fact. A timestamp left standing over a
        // null level is a pair no write path produces, and `firstMissingStep` reads it as still
        // missing — so the step returns however many times the user answers it.
        if fitnessLevel == nil { fitnessLevelSetAt = nil }
        return nil
    }
}

// MARK: - ExercisePreference (the only part of a catalog exercise that syncs)

/// The exercise catalog itself does not ride the wire: it ships in the app binary and is seeded
/// locally on every install, so every account stored an identical copy of a catalog nobody had
/// personalised. What syncs is the sparse per-account preference — a row per exercise the user
/// actually touched — and the five catalog columns (`name`, `muscles_targeted`, `aliases`,
/// `equipment_type`, and the catalog id itself as content) are derived from the bundle instead.
extension ExercisePreference: SyncedModel {
    static var syncTableName: String { "va.exercise_preference" }
    static var syncIDKeyPath: KeyPath<ExercisePreference, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<ExercisePreference> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<ExercisePreference> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<ExercisePreference> { FetchDescriptor() }

    func syncRow() -> [String: JSONValue] {
        [
            "catalog_id": .string(catalogID),
            "favorite": .bool(favorite),
            "last_added_at": lastAddedAt.map(JSONValue.date) ?? .null,
            "suggestions_enabled": .bool(suggestionsEnabled),
            "preferred_weight_change": preferredWeightChange.map(JSONValue.double) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["catalog_id"]?.stringValue { catalogID = value }
        if let value = row["favorite"]?.boolValue { favorite = value }
        if let value = row["last_added_at"] { lastAddedAt = value.dateValue }
        if let value = row["suggestions_enabled"]?.boolValue { suggestionsEnabled = value }
        if let value = row["preferred_weight_change"] { preferredWeightChange = value.doubleValue }
        // The app reads `Exercise`, never this row, so a pulled preference is only real once it
        // reaches the exercise it names. An exercise this build's catalog lacks leaves the row
        // stored and unapplied until the seed introduces it.
        if let exercise = resolvedExercise() { apply(to: exercise) }
        return nil
    }
}

// MARK: - TrainingGoal

extension TrainingGoal: SyncedModel {
    static var syncTableName: String { "va.training_goal" }
    static var syncIDKeyPath: KeyPath<TrainingGoal, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<TrainingGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<TrainingGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<TrainingGoal> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(kind: .generalTraining)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "started_on_day": .date(startedOnDay),
            "ended_on_day": endedOnDay.map(JSONValue.date) ?? .null,
            "kind": .string(kind.rawValue),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["started_on_day"]?.dateValue { startedOnDay = value }
        if let value = row["ended_on_day"] { endedOnDay = value.dateValue }
        if let value = row["kind"]?.stringValue, let kind = TrainingGoalKind(rawValue: value) { self.kind = kind }
        return nil
    }
}

// MARK: - TrainingConditionPeriod

extension TrainingConditionPeriod: SyncedModel {
    static var syncTableName: String { "va.training_condition_period" }
    static var syncIDKeyPath: KeyPath<TrainingConditionPeriod, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<TrainingConditionPeriod> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<TrainingConditionPeriod> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<TrainingConditionPeriod> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(kind: .recovering, trainingImpact: .contextOnly)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "kind": .string(kind.rawValue),
            "training_impact": .string(trainingImpact.rawValue),
            "start_date": .date(startDate),
            "end_date": endDate.map(JSONValue.date) ?? .null,
            "affected_muscles": affectedMuscles.map { .strings($0.map(\.rawValue)) } ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["kind"]?.stringValue, let kind = TrainingConditionKind(rawValue: value) { self.kind = kind }
        if let value = row["training_impact"]?.stringValue,
           let impact = TrainingImpact(rawValue: value) { trainingImpact = impact }
        if let value = row["start_date"]?.dateValue { startDate = value }
        if let value = row["end_date"] { endDate = value.dateValue }
        if let value = row["affected_muscles"] {
            affectedMuscles = value.stringArray.map { $0.compactMap(Muscle.init(rawValue:)) }
        }
        return nil
    }
}

// MARK: - WeightGoal

extension WeightGoal: SyncedModel {
    static var syncTableName: String { "va.weight_goal" }
    static var syncIDKeyPath: KeyPath<WeightGoal, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<WeightGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<WeightGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<WeightGoal> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "type": .string(type.rawValue),
            "started_at": .date(startedAt),
            "ended_at": endedAt.map(JSONValue.date) ?? .null,
            "end_reason": endReason.map { .string($0.rawValue) } ?? .null,
            "start_weight": .double(startWeight),
            "target_weight": .double(targetWeight),
            "target_date": targetDate.map(JSONValue.date) ?? .null,
            "target_rate_per_week": targetRatePerWeek.map(JSONValue.double) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["type"]?.stringValue, let type = WeightGoalType(rawValue: value) { self.type = type }
        if let value = row["started_at"]?.dateValue { startedAt = value }
        if let value = row["ended_at"] { endedAt = value.dateValue }
        if let value = row["end_reason"] {
            endReason = value.stringValue.flatMap(WeightGoalEndReason.init(rawValue:))
        }
        if let value = row["start_weight"]?.doubleValue { startWeight = value }
        if let value = row["target_weight"]?.doubleValue { targetWeight = value }
        if let value = row["target_date"] { targetDate = value.dateValue }
        if let value = row["target_rate_per_week"] { targetRatePerWeek = value.doubleValue }
        return nil
    }
}

// MARK: - StepsGoal

extension StepsGoal: SyncedModel {
    static var syncTableName: String { "va.steps_goal" }
    static var syncIDKeyPath: KeyPath<StepsGoal, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<StepsGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<StepsGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<StepsGoal> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(targetSteps: 0)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "started_on_day": .date(startedOnDay),
            "ended_on_day": endedOnDay.map(JSONValue.date) ?? .null,
            "target_steps": .int(Int64(targetSteps)),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["started_on_day"]?.dateValue { startedOnDay = value }
        if let value = row["ended_on_day"] { endedOnDay = value.dateValue }
        if let value = row["target_steps"]?.intValue { targetSteps = Int(value) }
        return nil
    }
}

// MARK: - SleepGoal

extension SleepGoal: SyncedModel {
    static var syncTableName: String { "va.sleep_goal" }
    static var syncIDKeyPath: KeyPath<SleepGoal, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<SleepGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<SleepGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<SleepGoal> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(targetSleepDuration: 0)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "started_on_day": .date(startedOnDay),
            "ended_on_day": endedOnDay.map(JSONValue.date) ?? .null,
            "target_sleep_seconds": .double(targetSleepDuration),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["started_on_day"]?.dateValue { startedOnDay = value }
        if let value = row["ended_on_day"] { endedOnDay = value.dateValue }
        if let value = row["target_sleep_seconds"]?.doubleValue { targetSleepDuration = value }
        return nil
    }
}

// MARK: - HydrationGoal

extension HydrationGoal: SyncedModel {
    static var syncTableName: String { "va.hydration_goal" }
    static var syncIDKeyPath: KeyPath<HydrationGoal, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<HydrationGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<HydrationGoal> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<HydrationGoal> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(targetML: 0)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "started_on_day": .date(startedOnDay),
            "ended_on_day": endedOnDay.map(JSONValue.date) ?? .null,
            "target_ml": .double(targetML),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["started_on_day"]?.dateValue { startedOnDay = value }
        if let value = row["ended_on_day"] { endedOnDay = value.dateValue }
        if let value = row["target_ml"]?.doubleValue { targetML = value }
        return nil
    }
}
