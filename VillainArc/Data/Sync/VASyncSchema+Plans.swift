import FCTServerSync
import Foundation
import SwiftData

// MARK: - WorkoutPlan

extension WorkoutPlan: SyncedModel {
    static var syncTableName: String { "va.workout_plan" }
    static var syncIDKeyPath: KeyPath<WorkoutPlan, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<WorkoutPlan> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<WorkoutPlan> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<WorkoutPlan> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
        exercises = []
    }

    func syncRow() -> [String: JSONValue] {
        [
            "title": .string(title),
            "notes": .string(notes),
            "favorite": .bool(favorite),
            "completed": .bool(completed),
            "is_editing": .bool(isEditing),
            "last_used": lastUsed.map(JSONValue.date) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["title"]?.stringValue { title = value }
        if let value = row["notes"]?.stringValue { notes = value }
        if let value = row["favorite"]?.boolValue { favorite = value }
        if let value = row["completed"]?.boolValue { completed = value }
        if let value = row["is_editing"]?.boolValue { isEditing = value }
        if let value = row["last_used"] { lastUsed = value.dateValue }
        return nil
    }
}

// MARK: - WorkoutSplit

extension WorkoutSplit: SyncedModel {
    static var syncTableName: String { "va.workout_split" }
    static var syncIDKeyPath: KeyPath<WorkoutSplit, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<WorkoutSplit> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<WorkoutSplit> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<WorkoutSplit> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init(mode: .weekly)
        id = syncID
        days = []
    }

    func syncRow() -> [String: JSONValue] {
        [
            "title": .string(title),
            "mode": .string(mode.rawValue),
            "is_active": .bool(isActive),
            "weekly_split_offset": .int(Int64(weeklySplitOffset)),
            "rotation_current_index": .int(Int64(rotationCurrentIndex)),
            "rotation_last_updated_date": rotationLastUpdatedDate.map(JSONValue.date) ?? .null,
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["title"]?.stringValue { title = value }
        if let value = row["mode"]?.stringValue, let mode = SplitMode(rawValue: value) { self.mode = mode }
        if let value = row["is_active"]?.boolValue { isActive = value }
        if let value = row["weekly_split_offset"]?.intValue { weeklySplitOffset = Int(value) }
        if let value = row["rotation_current_index"]?.intValue { rotationCurrentIndex = Int(value) }
        if let value = row["rotation_last_updated_date"] { rotationLastUpdatedDate = value.dateValue }
        return nil
    }
}

// MARK: - WorkoutSplitDay (two parents: the split, and an optional plan)

extension WorkoutSplitDay: SyncedModel {
    static var syncTableName: String { "va.workout_split_day" }
    static var syncIDKeyPath: KeyPath<WorkoutSplitDay, UUID> { \.id }

    static let splitRole = "split"
    static let planRole = "plan"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<WorkoutSplitDay> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<WorkoutSplitDay> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<WorkoutSplitDay> { FetchDescriptor() }

    func syncRow() -> [String: JSONValue] {
        [
            "name": .string(name),
            "index": .int(Int64(index)),
            "weekday": .int(Int64(weekday)),
            "is_rest_day": .bool(isRestDay),
            "target_muscles": .strings(targetMuscles.map(\.rawValue)),
            "split_id": .link(split?.id),
            "workout_plan_id": .link(workoutPlan?.id),
        ]
    }

    /// Scalars and the detaches; attaching is `applyLinks(_:)`'s job, since neither parent is
    /// guaranteed to have arrived.
    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["name"]?.stringValue { name = value }
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["weekday"]?.intValue { weekday = Int(value) }
        if let value = row["is_rest_day"]?.boolValue { isRestDay = value }
        if let value = row["target_muscles"]?.stringArray {
            targetMuscles = value.compactMap(Muscle.init(rawValue:))
        }
        if let link = row["split_id"], link.uuidValue == nil { split = nil }
        if let link = row["workout_plan_id"], link.uuidValue == nil { workoutPlan = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let splitID = row["split_id"]?.uuidValue { links.append(SyncLink(role: Self.splitRole, parent: splitID)) }
        if let planID = row["workout_plan_id"]?.uuidValue { links.append(SyncLink(role: Self.planRole, parent: planID)) }
        return links
    }

    static func relink(
        _ links: [UUID: [String: UUID]],
        in context: ModelContext
    ) throws -> [UUID: Set<String>] {
        guard !links.isEmpty else { return [:] }
        let splits = try arrivedParents(WorkoutSplit.self, links.values.compactMap { $0[splitRole] }, in: context)
        let plans = try arrivedParents(WorkoutPlan.self, links.values.compactMap { $0[planRole] }, in: context)
        guard !splits.isEmpty || !plans.isEmpty else { return [:] }

        var resolved: [UUID: Set<String>] = [:]
        for day in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[day.id] else { continue }
            var attached: Set<String> = []
            if attach(role: splitRole, of: roles, from: splits, assign: { if day.split !== $0 { day.split = $0 } }) {
                attached.insert(splitRole)
            }
            if attach(role: planRole, of: roles, from: plans, assign: { if day.workoutPlan !== $0 { day.workoutPlan = $0 } }) {
                attached.insert(planRole)
            }
            if !attached.isEmpty { resolved[day.id] = attached }
        }
        return resolved
    }
}

// MARK: - ExercisePrescription (parent: the plan)

extension ExercisePrescription: SyncedModel {
    static var syncTableName: String { "va.exercise_prescription" }
    static var syncIDKeyPath: KeyPath<ExercisePrescription, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<ExercisePrescription> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<ExercisePrescription> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<ExercisePrescription> { FetchDescriptor() }

    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "catalog_id": .string(catalogID),
            "name": .string(name),
            "notes": .string(notes),
            "muscles_targeted": .strings(musclesTargeted.map(\.rawValue)),
            "equipment_type": .string(equipmentType.rawValue),
            "workout_plan_id": .link(workoutPlan?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["catalog_id"]?.stringValue { catalogID = value }
        if let value = row["name"]?.stringValue { name = value }
        if let value = row["notes"]?.stringValue { notes = value }
        if let value = row["muscles_targeted"]?.stringArray {
            musclesTargeted = value.compactMap(Muscle.init(rawValue:))
        }
        if let value = row["equipment_type"]?.stringValue,
           let type = EquipmentType(rawValue: value) { equipmentType = type }

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
        for prescription in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let planID = pairs[prescription.id], let plan = plans[planID] else { continue }
            if prescription.workoutPlan !== plan { prescription.workoutPlan = plan }
            resolved.insert(prescription.id)
        }
        return resolved
    }
}

// MARK: - SetPrescription (parent: the exercise prescription)

extension SetPrescription: SyncedModel {
    static var syncTableName: String { "va.set_prescription" }
    static var syncIDKeyPath: KeyPath<SetPrescription, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<SetPrescription> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<SetPrescription> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<SetPrescription> { FetchDescriptor() }

    func syncRow() -> [String: JSONValue] {
        [
            "index": .int(Int64(index)),
            "type": .int(Int64(type.rawValue)),
            "target_weight": .double(targetWeight),
            "target_reps": .int(Int64(targetReps)),
            "target_rest": .int(Int64(targetRest)),
            "target_rpe": .int(Int64(targetRPE)),
            "exercise_prescription_id": .link(exercise?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["index"]?.intValue { index = Int(value) }
        if let value = row["type"]?.intValue, let type = ExerciseSetType(rawValue: Int(value)) { self.type = type }
        if let value = row["target_weight"]?.doubleValue { targetWeight = value }
        if let value = row["target_reps"]?.intValue { targetReps = Int(value) }
        if let value = row["target_rest"]?.intValue { targetRest = Int(value) }
        if let value = row["target_rpe"]?.intValue { targetRPE = Int(value) }

        guard let link = row["exercise_prescription_id"] else { return nil }
        guard let prescriptionID = link.uuidValue else {
            exercise = nil
            return nil
        }
        return prescriptionID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let prescriptions = try arrivedParents(ExercisePrescription.self, pairs.values, in: context)
        guard !prescriptions.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for set in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let prescriptionID = pairs[set.id], let prescription = prescriptions[prescriptionID] else { continue }
            if set.exercise !== prescription { set.exercise = prescription }
            resolved.insert(set.id)
        }
        return resolved
    }
}

// MARK: - RepRangePolicy (two parents, either-or: a performance or a prescription)

extension RepRangePolicy: SyncedModel {
    static var syncTableName: String { "va.rep_range_policy" }
    static var syncIDKeyPath: KeyPath<RepRangePolicy, UUID> { \.id }

    static let performanceRole = "performance"
    static let prescriptionRole = "prescription"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<RepRangePolicy> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<RepRangePolicy> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<RepRangePolicy> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "active_mode": .int(Int64(activeMode.rawValue)),
            "lower_range": .int(Int64(lowerRange)),
            "upper_range": .int(Int64(upperRange)),
            "target_reps": .int(Int64(targetReps)),
            "exercise_performance_id": .link(exercisePerformance?.id),
            "exercise_prescription_id": .link(exercisePrescription?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["active_mode"]?.intValue, let mode = RepRangeMode(rawValue: Int(value)) { activeMode = mode }
        if let value = row["lower_range"]?.intValue { lowerRange = Int(value) }
        if let value = row["upper_range"]?.intValue { upperRange = Int(value) }
        if let value = row["target_reps"]?.intValue { targetReps = Int(value) }
        if let link = row["exercise_performance_id"], link.uuidValue == nil { exercisePerformance = nil }
        if let link = row["exercise_prescription_id"], link.uuidValue == nil { exercisePrescription = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let performanceID = row["exercise_performance_id"]?.uuidValue {
            links.append(SyncLink(role: Self.performanceRole, parent: performanceID))
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
        let performances = try arrivedParents(ExercisePerformance.self, links.values.compactMap { $0[performanceRole] }, in: context)
        let prescriptions = try arrivedParents(ExercisePrescription.self, links.values.compactMap { $0[prescriptionRole] }, in: context)
        guard !performances.isEmpty || !prescriptions.isEmpty else { return [:] }

        var resolved: [UUID: Set<String>] = [:]
        for policy in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[policy.id] else { continue }
            var attached: Set<String> = []
            if attach(role: performanceRole, of: roles, from: performances, assign: {
                if policy.exercisePerformance !== $0 { policy.exercisePerformance = $0 }
            }) {
                attached.insert(performanceRole)
            }
            if attach(role: prescriptionRole, of: roles, from: prescriptions, assign: {
                if policy.exercisePrescription !== $0 { policy.exercisePrescription = $0 }
            }) {
                attached.insert(prescriptionRole)
            }
            if !attached.isEmpty { resolved[policy.id] = attached }
        }
        return resolved
    }
}
