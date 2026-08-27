import FCTServerSync
import Foundation
import SwiftData

// MARK: - WorkoutSession (parent: an optional plan)

extension WorkoutSession: SyncedModel {
    static var syncTableName: String { "va.workout_session" }
    static var syncIDKeyPath: KeyPath<WorkoutSession, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<WorkoutSession> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<WorkoutSession> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<WorkoutSession> { FetchDescriptor() }

    /// What deliberately does NOT ride the row: `activeExercise` (a live-logging pointer on the
    /// device running the workout), and the `healthWorkout` link (the Apple Health mirror is
    /// device-sourced; each device's mirror importer relinks against its own Health store).
    /// `has_been_exported_to_health` DOES ride: Apple Health syncs the sample itself across the
    /// user's devices, so "this workout has reached Health somewhere" is account-level truth that
    /// stops a second device exporting a duplicate.
    func syncRow() -> [String: JSONValue] {
        [
            "title": .string(title),
            "notes": .string(notes),
            "is_hidden": .bool(isHidden),
            "status": .string(status),
            "started_at": .date(startedAt),
            "ended_at": endedAt.map(JSONValue.date) ?? .null,
            "post_effort": .int(Int64(postEffort)),
            "has_been_exported_to_health": .bool(hasBeenExportedToHealth),
            "workout_plan_id": .link(workoutPlan?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["title"]?.stringValue { title = value }
        if let value = row["notes"]?.stringValue { notes = value }
        if let value = row["is_hidden"]?.boolValue { isHidden = value }
        if let value = row["status"]?.stringValue { status = value }
        if let value = row["started_at"]?.dateValue { startedAt = value }
        if let value = row["ended_at"] { endedAt = value.dateValue }
        if let value = row["post_effort"]?.intValue { postEffort = Int(value) }
        if let value = row["has_been_exported_to_health"]?.boolValue { hasBeenExportedToHealth = value }

        guard let link = row["workout_plan_id"] else { return nil }
        guard let planID = link.uuidValue else {
            workoutPlan = nil
            return nil
        }
        return planID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let plans = try arrivedParents(WorkoutPlan.self, pairs.values, in: context)
        guard !plans.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for session in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let planID = pairs[session.id], let plan = plans[planID] else { continue }
            if session.workoutPlan !== plan { session.workoutPlan = plan }
            resolved.insert(session.id)
        }
        return resolved
    }
}

// MARK: - PreWorkoutContext (parent: the session, 1:1)

extension PreWorkoutContext: SyncedModel {
    static var syncTableName: String { "va.pre_workout_context" }
    static var syncIDKeyPath: KeyPath<PreWorkoutContext, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<PreWorkoutContext> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<PreWorkoutContext> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<PreWorkoutContext> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "feeling": .string(feeling.rawValue),
            "took_pre_workout": .bool(tookPreWorkout),
            "workout_session_id": .link(workoutSession?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["feeling"]?.stringValue, let mood = MoodLevel(rawValue: value) { feeling = mood }
        if let value = row["took_pre_workout"]?.boolValue { tookPreWorkout = value }

        guard let link = row["workout_session_id"] else { return nil }
        guard let sessionID = link.uuidValue else {
            workoutSession = nil
            return nil
        }
        return sessionID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let sessions = try arrivedParents(WorkoutSession.self, pairs.values, in: context)
        guard !sessions.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for context_ in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let sessionID = pairs[context_.id], let session = sessions[sessionID] else { continue }
            if context_.workoutSession !== session { context_.workoutSession = session }
            resolved.insert(context_.id)
        }
        return resolved
    }
}

// MARK: - ExercisePerformance (two parents: the session, and an optional prescription)

extension ExercisePerformance: SyncedModel {
    static var syncTableName: String { "va.exercise_performance" }
    static var syncIDKeyPath: KeyPath<ExercisePerformance, UUID> { \.id }

    static let sessionRole = "session"
    static let prescriptionRole = "prescription"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<ExercisePerformance> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<ExercisePerformance> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<ExercisePerformance> { FetchDescriptor() }

    /// `activeInSession` never rides: it is the live "this exercise is open" pointer on the
    /// device running the workout.
    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "date": .date(date),
            "catalog_id": .string(catalogID),
            "name": .string(name),
            "notes": .string(notes),
            "muscles_targeted": .strings(musclesTargeted.map(\.rawValue)),
            "equipment_type": .string(equipmentType.rawValue),
            "original_target_snapshot": originalTargetSnapshot.map(JSONValue.encoding) ?? .null,
            "workout_session_id": .link(workoutSession?.id),
            "exercise_prescription_id": .link(prescription?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["date"]?.dateValue { date = value }
        if let value = row["catalog_id"]?.stringValue { catalogID = value }
        if let value = row["name"]?.stringValue { name = value }
        if let value = row["notes"]?.stringValue { notes = value }
        if let value = row["muscles_targeted"]?.stringArray {
            musclesTargeted = value.compactMap(Muscle.init(rawValue:))
        }
        if let value = row["equipment_type"]?.stringValue,
           let type = EquipmentType(rawValue: value) { equipmentType = type }
        if let value = row["original_target_snapshot"] {
            originalTargetSnapshot = value.decoded(as: ExerciseTargetSnapshot.self)
        }
        if let link = row["workout_session_id"], link.uuidValue == nil { workoutSession = nil }
        if let link = row["exercise_prescription_id"], link.uuidValue == nil { prescription = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let sessionID = row["workout_session_id"]?.uuidValue {
            links.append(SyncLink(role: Self.sessionRole, parent: sessionID))
        }
        if let prescriptionID = row["exercise_prescription_id"]?.uuidValue {
            links.append(SyncLink(role: Self.prescriptionRole, parent: prescriptionID))
        }
        return links
    }

    static func relink(
        _ links: [UUID: [String: UUID]],
        in context: ModelContext
    ) throws -> [UUID: Set<String>] {
        guard !links.isEmpty else { return [:] }
        let sessions = try arrivedParents(WorkoutSession.self, links.values.compactMap { $0[sessionRole] }, in: context)
        let prescriptions = try arrivedParents(ExercisePrescription.self, links.values.compactMap { $0[prescriptionRole] }, in: context)
        guard !sessions.isEmpty || !prescriptions.isEmpty else { return [:] }

        var resolved: [UUID: Set<String>] = [:]
        for performance in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[performance.id] else { continue }
            var attached: Set<String> = []
            if attach(role: sessionRole, of: roles, from: sessions, assign: {
                if performance.workoutSession !== $0 { performance.workoutSession = $0 }
            }) {
                attached.insert(sessionRole)
            }
            if attach(role: prescriptionRole, of: roles, from: prescriptions, assign: {
                if performance.prescription !== $0 { performance.prescription = $0 }
            }) {
                attached.insert(prescriptionRole)
            }
            if !attached.isEmpty { resolved[performance.id] = attached }
        }
        return resolved
    }
}

// MARK: - SetPerformance (two parents: the performance, and an optional set prescription)

extension SetPerformance: SyncedModel {
    static var syncTableName: String { "va.set_performance" }
    static var syncIDKeyPath: KeyPath<SetPerformance, UUID> { \.id }

    static let exerciseRole = "exercise"
    static let prescriptionRole = "prescription"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<SetPerformance> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<SetPerformance> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<SetPerformance> { FetchDescriptor() }

    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "original_target_set_id": .link(originalTargetSetID),
            "type": .int(Int64(type.rawValue)),
            "weight": .double(weight),
            "reps": .int(Int64(reps)),
            "rest_seconds": .int(Int64(restSeconds)),
            "rpe": .int(Int64(rpe)),
            "complete": .bool(complete),
            "completed_at": completedAt.map(JSONValue.date) ?? .null,
            "exercise_performance_id": .link(exercise?.id),
            "set_prescription_id": .link(prescription?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["original_target_set_id"] { originalTargetSetID = value.uuidValue }
        if let value = row["type"]?.intValue, let type = ExerciseSetType(rawValue: Int(value)) { self.type = type }
        if let value = row["weight"]?.doubleValue { weight = value }
        if let value = row["reps"]?.intValue { reps = Int(value) }
        if let value = row["rest_seconds"]?.intValue { restSeconds = Int(value) }
        if let value = row["rpe"]?.intValue { rpe = Int(value) }
        if let value = row["complete"]?.boolValue { complete = value }
        if let value = row["completed_at"] { completedAt = value.dateValue }
        if let link = row["exercise_performance_id"], link.uuidValue == nil { exercise = nil }
        if let link = row["set_prescription_id"], link.uuidValue == nil { prescription = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let performanceID = row["exercise_performance_id"]?.uuidValue {
            links.append(SyncLink(role: Self.exerciseRole, parent: performanceID))
        }
        if let prescriptionID = row["set_prescription_id"]?.uuidValue {
            links.append(SyncLink(role: Self.prescriptionRole, parent: prescriptionID))
        }
        return links
    }

    static func relink(
        _ links: [UUID: [String: UUID]],
        in context: ModelContext
    ) throws -> [UUID: Set<String>] {
        guard !links.isEmpty else { return [:] }
        let performances = try arrivedParents(ExercisePerformance.self, links.values.compactMap { $0[exerciseRole] }, in: context)
        let prescriptions = try arrivedParents(SetPrescription.self, links.values.compactMap { $0[prescriptionRole] }, in: context)
        guard !performances.isEmpty || !prescriptions.isEmpty else { return [:] }

        var resolved: [UUID: Set<String>] = [:]
        for set in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[set.id] else { continue }
            var attached: Set<String> = []
            if attach(role: exerciseRole, of: roles, from: performances, assign: {
                if set.exercise !== $0 { set.exercise = $0 }
            }) {
                attached.insert(exerciseRole)
            }
            if attach(role: prescriptionRole, of: roles, from: prescriptions, assign: {
                if set.prescription !== $0 { set.prescription = $0 }
            }) {
                attached.insert(prescriptionRole)
            }
            if !attached.isEmpty { resolved[set.id] = attached }
        }
        return resolved
    }
}

// MARK: - CardioSession

extension CardioSession: SyncedModel {
    static var syncTableName: String { "va.cardio_session" }
    static var syncIDKeyPath: KeyPath<CardioSession, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<CardioSession> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<CardioSession> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<CardioSession> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    /// `health_workout_uuid` rides as authored state (the Health sample's name, which Apple's own
    /// Health sync carries across devices); the `healthWorkout` mirror link stays device-local.
    func syncRow() -> [String: JSONValue] {
        [
            "title": .string(title),
            "notes": .string(notes),
            "post_effort": .int(Int64(postEffort)),
            "activity": .string(activityRawValue),
            "environment": .string(environmentRawValue),
            "capture_mode": .string(captureModeRawValue),
            "status": .string(status),
            "source": .string(sourceRawValue),
            "started_at": startedAt.map(JSONValue.date) ?? .null,
            "ended_at": endedAt.map(JSONValue.date) ?? .null,
            "total_distance_meters": .double(totalDistanceMeters),
            "average_heart_rate_bpm": averageHeartRateBPM.map(JSONValue.double) ?? .null,
            "active_energy_kilocalories": activeEnergyKilocalories.map(JSONValue.double) ?? .null,
            "elevation_gain_meters": elevationGainMeters.map(JSONValue.double) ?? .null,
            "health_workout_uuid": .link(healthWorkoutUUID),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["title"]?.stringValue { title = value }
        if let value = row["notes"]?.stringValue { notes = value }
        if let value = row["post_effort"]?.intValue { postEffort = Int(value) }
        if let value = row["activity"]?.stringValue { activityRawValue = value }
        if let value = row["environment"]?.stringValue { environmentRawValue = value }
        if let value = row["capture_mode"]?.stringValue { captureModeRawValue = value }
        if let value = row["status"]?.stringValue { status = value }
        if let value = row["source"]?.stringValue { sourceRawValue = value }
        if let value = row["started_at"] { startedAt = value.dateValue }
        if let value = row["ended_at"] { endedAt = value.dateValue }
        if let value = row["total_distance_meters"]?.doubleValue { totalDistanceMeters = value }
        if let value = row["average_heart_rate_bpm"] { averageHeartRateBPM = value.doubleValue }
        if let value = row["active_energy_kilocalories"] { activeEnergyKilocalories = value.doubleValue }
        if let value = row["elevation_gain_meters"] { elevationGainMeters = value.doubleValue }
        if let value = row["health_workout_uuid"] { healthWorkoutUUID = value.uuidValue }
        return nil
    }
}

// MARK: - CardioRoutePoint (parent: the session)

extension CardioRoutePoint: SyncedModel {
    static var syncTableName: String { "va.cardio_route_point" }
    static var syncIDKeyPath: KeyPath<CardioRoutePoint, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<CardioRoutePoint> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<CardioRoutePoint> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<CardioRoutePoint> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(index: 0, latitude: 0, longitude: 0, timestamp: .distantPast)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "altitude": altitude.map(JSONValue.double) ?? .null,
            "timestamp": .date(timestamp),
            "horizontal_accuracy": .double(horizontalAccuracy),
            "vertical_accuracy": verticalAccuracy.map(JSONValue.double) ?? .null,
            "course": course.map(JSONValue.double) ?? .null,
            "speed_meters_per_second": speedMetersPerSecond.map(JSONValue.double) ?? .null,
            "session_id": .link(session?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["latitude"]?.doubleValue { latitude = value }
        if let value = row["longitude"]?.doubleValue { longitude = value }
        if let value = row["altitude"] { altitude = value.doubleValue }
        if let value = row["timestamp"]?.dateValue { timestamp = value }
        if let value = row["horizontal_accuracy"]?.doubleValue { horizontalAccuracy = value }
        if let value = row["vertical_accuracy"] { verticalAccuracy = value.doubleValue }
        if let value = row["course"] { course = value.doubleValue }
        if let value = row["speed_meters_per_second"] { speedMetersPerSecond = value.doubleValue }

        guard let link = row["session_id"] else { return nil }
        guard let sessionID = link.uuidValue else {
            session = nil
            return nil
        }
        return sessionID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let sessions = try arrivedParents(CardioSession.self, pairs.values, in: context)
        guard !sessions.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for point in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let sessionID = pairs[point.id], let session = sessions[sessionID] else { continue }
            if point.session !== session { point.session = session }
            resolved.insert(point.id)
        }
        return resolved
    }
}

// MARK: - CardioMachineInterval (parent: the session)

extension CardioMachineInterval: SyncedModel {
    static var syncTableName: String { "va.cardio_machine_interval" }
    static var syncIDKeyPath: KeyPath<CardioMachineInterval, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<CardioMachineInterval> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<CardioMachineInterval> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<CardioMachineInterval> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(index: 0)
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "speed_kph": speedKPH.map(JSONValue.double) ?? .null,
            "incline_percent": inclinePercent.map(JSONValue.double) ?? .null,
            "resistance_level": resistanceLevel.map(JSONValue.double) ?? .null,
            "cadence_rpm": cadenceRPM.map(JSONValue.double) ?? .null,
            "power_watts": powerWatts.map(JSONValue.double) ?? .null,
            "added_at": .date(addedAt),
            "distance_meters": .double(distanceMeters),
            "session_id": .link(session?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["speed_kph"] { speedKPH = value.doubleValue }
        if let value = row["incline_percent"] { inclinePercent = value.doubleValue }
        if let value = row["resistance_level"] { resistanceLevel = value.doubleValue }
        if let value = row["cadence_rpm"] { cadenceRPM = value.doubleValue }
        if let value = row["power_watts"] { powerWatts = value.doubleValue }
        if let value = row["added_at"]?.dateValue { addedAt = value }
        if let value = row["distance_meters"]?.doubleValue { distanceMeters = value }

        guard let link = row["session_id"] else { return nil }
        guard let sessionID = link.uuidValue else {
            session = nil
            return nil
        }
        return sessionID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let sessions = try arrivedParents(CardioSession.self, pairs.values, in: context)
        guard !sessions.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for interval in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let sessionID = pairs[interval.id], let session = sessions[sessionID] else { continue }
            if interval.session !== session { interval.session = session }
            resolved.insert(interval.id)
        }
        return resolved
    }
}
