import Foundation
import SwiftData

@Model
final class ExercisePerformance {
    #Index<ExercisePerformance>([\.catalogID], [\.date])

    var id: UUID = UUID()
    var index: Int = 0
    var date: Date = Date()
    var catalogID: String = ""
    var name: String = ""
    var notes: String = ""
    var musclesTargeted: [Muscle] = []
    var equipmentType: EquipmentType = EquipmentType.bodyweight
    @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePerformance)
    var repRange: RepRangePolicy? = RepRangePolicy()
    var originalTargetSnapshot: ExerciseTargetSnapshot?
    var workoutSession: WorkoutSession?
    var activeInSession: WorkoutSession?
    @Relationship(deleteRule: .nullify, inverse: \ExercisePrescription.activePerformance)
    var prescription: ExercisePrescription?
    @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise)
    var sets: [SetPerformance]? = [SetPerformance]()
    
    var sortedSets: [SetPerformance] {
        (sets ?? []).sorted { $0.index < $1.index }
    }
    
    // Adding exercise in session
    init(exercise: Exercise, workoutSession: WorkoutSession) {
        index = workoutSession.exercises?.count ?? 0
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        repRange = RepRangePolicy()
        self.workoutSession = workoutSession
        addSet()
    }

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(exercise: Exercise, workoutSession: WorkoutSession, notes: String = "", index: Int? = nil, repRangeMode: RepRangeMode? = nil, lowerRange: Int = 0, upperRange: Int = 0, targetReps: Int = 0) {
        self.init(exercise: exercise, workoutSession: workoutSession)
        self.notes = notes
        if let index {
            self.index = index
        }
        if let repRangeMode, let repRange = self.repRange {
            repRange.activeMode = repRangeMode
            switch repRangeMode {
            case .range:
                repRange.lowerRange = lowerRange
                repRange.upperRange = upperRange
            case .target:
                repRange.targetReps = targetReps
            case .notSet:
                break
            }
        }
    }
    
    // Adding exercise from plan
    @MainActor
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
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }),
           nextSet.type == .dropSet {
            return 0
        }
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

    func replaceWith(_ exercise: Exercise, keepSets: Bool) {
        guard catalogID != exercise.catalogID else { return }
        prescription?.activePerformance = nil
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
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
            for set in sets ?? [] {
                modelContext?.delete(set)
            }
            sets?.removeAll()
            addSet()
        }
    }

    func deleteSet(_ set: SetPerformance) {
        sets?.removeAll(where: { $0 == set })
        reindexSets()
    }

    func reindexSets() {
        reindexSetsByCurrentOrder()
    }

    @discardableResult
    func applyCatalogMetadata(name: String, musclesTargeted: [Muscle], equipmentType: EquipmentType) -> Bool {
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
        guard let prescription else { return nil }

        let usedPrescriptionIDs = Set(sortedSets.compactMap { $0.prescription?.id })
        let maxLinkedIndex = sortedSets.compactMap { $0.prescription?.index }.max() ?? -1

        return prescription.sortedSets.first { !usedPrescriptionIDs.contains($0.id) && $0.index > maxLinkedIndex }
    }

    private func reindexSetsByCurrentOrder() {
        for (index, set) in sortedSets.enumerated() {
            set.index = index
        }
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
}

extension ExercisePerformance: RestTimeEditable {}

extension ExercisePerformance {
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

    @discardableResult
    func syncDateToLatestCompletedSet(sessionFinishedAt: Date? = nil) -> Date {
        guard allSetsComplete else { return date }
        if let latestCompletedSetAt {
            date = latestCompletedSetAt
            return latestCompletedSetAt
        }

        if let sessionFinishedAt {
            date = sessionFinishedAt
        }

        return date
    }

    var bestEstimated1RM: Double? {
        sets?.compactMap(\.estimated1RM).max()
    }

    var bestWeight: Double? {
        let maxWeight = sets?.map(\.weight).max() ?? 0
        return maxWeight > 0 ? maxWeight : nil
    }

    var bestReps: Int? {
        let maxReps = sets?.map(\.reps).max() ?? 0
        return maxReps > 0 ? maxReps : nil
    }

    var totalCompletedReps: Int {
        sets?.reduce(0) { $0 + $1.reps } ?? 0
    }

    var totalVolume: Double {
        sets?.reduce(0) { $0 + $1.volume } ?? 0
    }

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
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.sets]
        return descriptor
    }
    
    static func matching(catalogID: String) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }

    static func matching(catalogID: String, includingSessionID sessionID: UUID) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && (item.workoutSession?.status == done || item.workoutSession?.id == sessionID)
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }

    static func matching(catalogIDs: [String]) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            catalogIDs.contains(item.catalogID) && item.workoutSession?.status == done
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }

    static func matching(catalogIDs: [String], includingSessionID sessionID: UUID) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            catalogIDs.contains(item.catalogID) && (item.workoutSession?.status == done || item.workoutSession?.id == sessionID)
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }

    static func withCatalogID(_ catalogID: String) -> FetchDescriptor<ExercisePerformance> {
        let predicate = #Predicate<ExercisePerformance> { $0.catalogID == catalogID }
        return FetchDescriptor(predicate: predicate)
    }

    static var completedAll: FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.workoutSession?.status == done
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }
}
