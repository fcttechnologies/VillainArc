import Foundation
import SwiftData

@Model final class ExercisePerformance {
    #Index<ExercisePerformance>([\.catalogID], [\.date], [\.catalogID, \.date])
    var id: UUID = UUID()
    var index: Int = 0
    var date: Date = Date()
    var catalogID: String = ""
    var name: String = ""
    var notes: String = ""
    var musclesTargeted: [Muscle] = []
    var equipmentType: EquipmentType = EquipmentType.bodyweight
    @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePerformance) var repRange: RepRangePolicy? = RepRangePolicy()
    var originalTargetSnapshot: ExerciseTargetSnapshot?
    var workoutSession: WorkoutSession?
    var activeInSession: WorkoutSession?
    @Relationship(inverse: \ExercisePrescription.activePerformance) var prescription: ExercisePrescription?
    @Relationship(inverse: \SuggestionEvent.triggerPerformance) var triggeredSuggestions: [SuggestionEvent]?
    @Relationship(inverse: \SuggestionEvaluation.performance) var suggestionEvaluations: [SuggestionEvaluation]?
    @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise) var sets: [SetPerformance]? = [SetPerformance]()

    var sortedSets: [SetPerformance] { (sets ?? []).sorted { $0.index < $1.index } }

    // Adding exercise in session
    init(exercise: Exercise, workoutSession: WorkoutSession) {
        index = workoutSession.exercises?.count ?? 0
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        self.workoutSession = workoutSession
        addSet()
    }

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(exercise: Exercise, workoutSession: WorkoutSession, notes: String = "", index: Int? = nil, repRangeMode: RepRangeMode? = nil, lowerRange: Int = 0, upperRange: Int = 0, targetReps: Int = 0) {
        self.init(exercise: exercise, workoutSession: workoutSession)
        self.notes = notes
        if let index { self.index = index }
        if let repRangeMode, let repRange = self.repRange {
            repRange.activeMode = repRangeMode
            switch repRangeMode {
            case .range:
                repRange.lowerRange = lowerRange
                repRange.upperRange = upperRange
            case .target: repRange.targetReps = targetReps
            case .notSet: break
            }
        }
    }

    // Adding exercise from plan
    init(workoutSession: WorkoutSession, exercisePrescription: ExercisePrescription) {
        index = exercisePrescription.index
        catalogID = exercisePrescription.catalogID
        name = exercisePrescription.name
        notes = exercisePrescription.notes
        musclesTargeted = exercisePrescription.musclesTargeted
        equipmentType = exercisePrescription.equipmentType
        repRange = RepRangePolicy(copying: exercisePrescription.repRange)
        originalTargetSnapshot = ExerciseTargetSnapshot(prescription: exercisePrescription)
        self.workoutSession = workoutSession
        prescription = exercisePrescription
        sets = exercisePrescription.sortedSets.map { SetPerformance(exercise: self, setPrescription: $0) }
    }

    func effectiveRestSeconds(after set: SetPerformance) -> Int {
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }), nextSet.type == .dropSet { return 0 }
        return set.restSeconds
    }

    func addSet(unit: WeightUnit = .kg) {
        if let restoredPrescription = nextRestorableTailPrescription() {
            let set = SetPerformance(exercise: self, setPrescription: restoredPrescription)
            set.weight = (unit.fromKg(set.weight) * 100).rounded() / 100
            sets?.append(set)
            reindexSetsByCurrentOrder()
            return
        }

        if let previous = sortedSets.last {
            sets?.append(SetPerformance(exercise: self, weight: previous.weight, reps: previous.reps, restSeconds: previous.restSeconds))
        } else {
            sets?.append(SetPerformance(exercise: self, restSeconds: RestTimeDefaults.restSeconds))
        }
    }

    func replaceWith(_ exercise: Exercise, keepSets: Bool, context: ModelContext) {
        guard catalogID != exercise.catalogID else { return }
        prescription?.activePerformance = nil
        catalogID = exercise.catalogID
        name = exercise.name
        notes = ""
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        repRange?.resetToDefault()
        exercise.updateLastAddedAt()
        prescription = nil
        originalTargetSnapshot = nil

        // This exercise is no longer tied to the original plan prescription.
        // Clear any per-set prescription links so stale targets don't show.
        for set in sets ?? [] {
            set.prescription?.activePerformance = nil
            set.prescription = nil
            set.originalTargetSetID = nil
        }

        if !keepSets {
            let existingSets = sortedSets
            sets = []
            for set in existingSets {
                set.prescription?.activePerformance = nil
                set.prescription = nil
                context.delete(set)
            }
            addSet()
        }
    }

    func deleteSet(_ set: SetPerformance) {
        sets?.removeAll(where: { $0 == set })
        reindexSets()
    }

    func reindexSets() { reindexSetsByCurrentOrder() }

    @discardableResult func applyCatalogMetadata(name: String, musclesTargeted: [Muscle], equipmentType: EquipmentType) -> Bool {
        var didChange = false

        if self.name != name {
            self.name = name
            didChange = true
        }
        if self.musclesTargeted != musclesTargeted {
            self.musclesTargeted = musclesTargeted
            didChange = true
        }
        if self.equipmentType != equipmentType {
            self.equipmentType = equipmentType
            didChange = true
        }

        return didChange
    }

    private func nextRestorableTailPrescription() -> SetPrescription? {
        restorableTailPrescriptions(limit: 1).first
    }

    private func reindexSetsByCurrentOrder() {
        for (index, set) in sortedSets.enumerated() { set.index = index }
    }

    private func restorableTailPrescriptions(limit: Int? = nil) -> [SetPrescription] {
        guard let prescription else { return [] }

        let usedPrescriptionIDs = Set(sortedSets.compactMap { $0.prescription?.id })
        let maxLinkedIndex = sortedSets.compactMap { $0.prescription?.index }.max() ?? -1

        let candidates = prescription.sortedSets.filter { !usedPrescriptionIDs.contains($0.id) && $0.index > maxLinkedIndex }
        if let limit {
            return Array(candidates.prefix(limit))
        }
        return candidates
    }

    func clearPrescriptionLinksForHistoricalUse() {
        prescription?.activePerformance = nil
        prescription = nil
        for set in sortedSets {
            set.originalTargetSetID = set.originalTargetSetID ?? set.prescription?.id
            set.prescription?.activePerformance = nil
            set.prescription = nil
        }
    }

    func detachFromDeletedPlan() {
        prescription?.activePerformance = nil
        prescription = nil
        originalTargetSnapshot = nil
        for set in sortedSets {
            set.prescription?.activePerformance = nil
            set.prescription = nil
            set.originalTargetSetID = nil
        }
    }
}

enum ExerciseHistoryCopyMode: String, CaseIterable, Identifiable {
    case sets
    case setsAndNotes
    case setsAndRepRange
    case all

    nonisolated var id: String { rawValue }

    nonisolated var label: String {
        switch self {
        case .sets:
            return "Copy Sets"
        case .setsAndNotes:
            return "Copy Sets + Notes"
        case .setsAndRepRange:
            return "Copy Sets + Rep Range"
        case .all:
            return "Copy All"
        }
    }

    nonisolated var includesNotes: Bool {
        switch self {
        case .sets, .setsAndRepRange:
            return false
        case .setsAndNotes, .all:
            return true
        }
    }

    nonisolated var includesRepRange: Bool {
        switch self {
        case .sets, .setsAndNotes:
            return false
        case .setsAndRepRange, .all:
            return true
        }
    }
}

enum ExerciseHistoryCopyStrategy: Hashable {
    case replaceAll
    case replaceRemaining
}

extension ExercisePerformance: RestTimeEditable {}

extension ExercisePerformance {
    func applyAcceptedSuggestionEvent(_ event: SuggestionEvent, weightUnit: WeightUnit) {
        guard let prescription, prescription.id == event.targetExercisePrescription?.id else { return }

        if let targetSet = event.targetSetPrescription, let setPerformance = sortedSets.first(where: { $0.prescription?.id == targetSet.id }) {
            for change in event.sortedChanges { setPerformance.applyAcceptedSuggestionChange(change, weightUnit: weightUnit) }
        }

        syncRepRangeFromPrescription()
        originalTargetSnapshot = ExerciseTargetSnapshot(prescription: prescription)
    }

    private func syncRepRangeFromPrescription() {
        guard let prescriptionRepRange = prescription?.repRange else { return }

        if repRange == nil { repRange = RepRangePolicy() }

        repRange?.activeMode = prescriptionRepRange.activeMode
        repRange?.lowerRange = prescriptionRepRange.lowerRange
        repRange?.upperRange = prescriptionRepRange.upperRange
        repRange?.targetReps = prescriptionRepRange.targetReps
    }
}

extension ExercisePerformance {
    var hasLoggedDataForHistoryReplacement: Bool {
        sortedSets.contains { set in
            set.complete || set.reps > 0 || set.weight > 0 || set.rpe > 0
        }
    }

    var completedSetCount: Int {
        sortedSets.reduce(into: 0) { result, set in
            if set.complete {
                result += 1
            }
        }
    }

    var completedPrefixCount: Int {
        sortedSets.prefix(while: { $0.complete }).count
    }

    var canSafelyCopyIntoRemainingSets: Bool {
        completedSetCount > 0 && completedPrefixCount == completedSetCount
    }

    func applyHistoryCopy(_ snapshot: ExercisePerformanceSnapshot, mode: ExerciseHistoryCopyMode, strategy: ExerciseHistoryCopyStrategy, weightUnit: WeightUnit? = nil, context: ModelContext) {
        switch strategy {
        case .replaceAll:
            syncSets(from: snapshot.sets, startingAt: 0, weightUnit: weightUnit, context: context)
        case .replaceRemaining:
            let remainingSnapshots = Array(snapshot.sets.dropFirst(completedPrefixCount))
            syncSets(from: remainingSnapshots, startingAt: completedPrefixCount, weightUnit: weightUnit, context: context)
        }

        if mode.includesNotes {
            notes = snapshot.notes
        }

        if mode.includesRepRange {
            if repRange == nil {
                repRange = RepRangePolicy()
            }
            repRange?.apply(snapshot: snapshot.repRange)
        }
    }

    private func syncSets(from snapshots: [SetPerformanceSnapshot], startingAt startIndex: Int, weightUnit: WeightUnit?, context: ModelContext) {
        let currentSets = sortedSets
        let targetSets = Array(currentSets.dropFirst(startIndex))
        var restorableTail = restorableTailPrescriptions(limit: max(0, snapshots.count - targetSets.count))

        for (index, snapshot) in snapshots.enumerated() {
            let targetIndex = startIndex + index
            let displayWeight = convertedWeightForActiveCopy(snapshot.weight, unit: weightUnit)

            if index < targetSets.count {
                let set = targetSets[index]
                set.index = targetIndex
                set.type = snapshot.type
                set.weight = displayWeight
                set.reps = snapshot.reps
                set.restSeconds = snapshot.restSeconds
                set.rpe = 0
                set.complete = false
                set.completedAt = nil
            } else {
                let set: SetPerformance
                if let restoredPrescription = restorableTail.first {
                    restorableTail.removeFirst()
                    set = SetPerformance(exercise: self, setPrescription: restoredPrescription)
                    set.weight = displayWeight
                    set.reps = snapshot.reps
                    set.restSeconds = snapshot.restSeconds
                } else {
                    set = SetPerformance(exercise: self, weight: displayWeight, reps: snapshot.reps, restSeconds: snapshot.restSeconds)
                }
                set.index = targetIndex
                set.type = snapshot.type
                set.rpe = 0
                set.complete = false
                set.completedAt = nil
                sets?.append(set)
            }
        }

        if targetSets.count > snapshots.count {
            for set in targetSets.dropFirst(snapshots.count) {
                sets?.removeAll { $0.id == set.id }
                context.delete(set)
            }
        }

        reindexSets()
    }

    private func convertedWeightForActiveCopy(_ storedKgWeight: Double, unit: WeightUnit?) -> Double {
        guard let unit else { return storedKgWeight }
        return roundedWeightDisplayValue(storedKgWeight, unit: unit)
    }

    var latestCompletedSetAt: Date? {
        sortedSets.compactMap { set in
            guard set.complete else { return nil }
            return set.completedAt
        }
        .max()
    }

    var allSetsComplete: Bool {
        let sets = sortedSets
        return !sets.isEmpty && sets.allSatisfy(\.complete)
    }

    @discardableResult func syncDateToLatestCompletedSet(sessionFinishedAt: Date? = nil) -> Date {
        guard allSetsComplete else { return date }
        if let latestCompletedSetAt {
            date = latestCompletedSetAt
            return latestCompletedSetAt
        }

        if let sessionFinishedAt { date = sessionFinishedAt }

        return date
    }

    var bestEstimated1RM: Double? { sets?.compactMap(\.estimated1RM).max() }

    var bestWeight: Double? {
        let maxWeight = sets?.map(\.weight).max() ?? 0
        return maxWeight > 0 ? maxWeight : nil
    }

    var bestReps: Int? {
        let maxReps = sets?.map(\.reps).max() ?? 0
        return maxReps > 0 ? maxReps : nil
    }

    var totalCompletedReps: Int { sets?.reduce(0) { $0 + $1.reps } ?? 0 }

    var totalVolume: Double { sets?.reduce(0) { $0 + $1.volume } ?? 0 }

    static func historicalBestEstimated1RM(in performances: [ExercisePerformance]) -> Double? {
        performances.compactMap(\.bestEstimated1RM).max()
    }

    static func historicalBestWeight(in performances: [ExercisePerformance]) -> Double? {
        performances.compactMap(\.bestWeight).max()
    }

    static func historicalBestReps(in performances: [ExercisePerformance]) -> Int? {
        performances.compactMap(\.bestReps).max()
    }

    static func historicalBestVolume(in performances: [ExercisePerformance]) -> Double? {
        let maxVolume = performances.map(\.totalVolume).max() ?? 0
        return maxVolume > 0 ? maxVolume : nil
    }

    static func lastCompleted(for exercise: ExercisePerformance) -> FetchDescriptor<ExercisePerformance> {
        let catalogID = exercise.catalogID
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in item.catalogID == catalogID && item.workoutSession?.status == done && item.workoutSession?.isHidden == false }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.sets]
        return descriptor
    }

    static func matching(catalogID: String, includingHidden: Bool = false) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = includingHidden ? #Predicate<ExercisePerformance> { item in item.catalogID == catalogID && item.workoutSession?.status == done } : #Predicate<ExercisePerformance> { item in item.catalogID == catalogID && item.workoutSession?.status == done && item.workoutSession?.isHidden == false }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.sets, \.repRange]
        return descriptor
    }

    static func matching(catalogIDs: [String]) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in catalogIDs.contains(item.catalogID) && item.workoutSession?.status == done && item.workoutSession?.isHidden == false }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.sets, \.workoutSession]
        return descriptor
    }

    static func forSession(_ sessionID: UUID, catalogIDs: [String]) -> FetchDescriptor<ExercisePerformance> {
        let predicate = #Predicate<ExercisePerformance> { item in item.workoutSession?.id == sessionID && catalogIDs.contains(item.catalogID) }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.sets, \.workoutSession]
        return descriptor
    }

    static func withCatalogID(_ catalogID: String) -> FetchDescriptor<ExercisePerformance> {
        let predicate = #Predicate<ExercisePerformance> { $0.catalogID == catalogID }
        return FetchDescriptor(predicate: predicate)
    }

    static func forCatalogIDs(_ catalogIDs: [String]) -> FetchDescriptor<ExercisePerformance> {
        let predicate = #Predicate<ExercisePerformance> { item in catalogIDs.contains(item.catalogID) }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.relationshipKeyPathsForPrefetching = [\.sets, \.repRange, \.workoutSession]
        return descriptor
    }

    static var completedAll: FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in item.workoutSession?.status == done && item.workoutSession?.isHidden == false }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }
}
