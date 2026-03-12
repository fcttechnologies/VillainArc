import Foundation

struct RepRangeSnapshot: Codable, Sendable {
    var mode: RepRangeMode
    var lower: Int
    var upper: Int
    var target: Int

    private enum CodingKeys: String, CodingKey {
        case mode
        case lower
        case upper
        case target
    }

    nonisolated init(mode: RepRangeMode, lower: Int, upper: Int, target: Int) {
        self.mode = mode
        self.lower = lower
        self.upper = upper
        self.target = target
    }

    nonisolated init(policy: RepRangePolicy?) {
        mode = policy?.activeMode ?? .notSet
        lower = policy?.lowerRange ?? 8
        upper = policy?.upperRange ?? 12
        target = policy?.targetReps ?? 8
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(RepRangeMode.self, forKey: .mode)
        lower = try container.decode(Int.self, forKey: .lower)
        upper = try container.decode(Int.self, forKey: .upper)
        target = try container.decode(Int.self, forKey: .target)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(lower, forKey: .lower)
        try container.encode(upper, forKey: .upper)
        try container.encode(target, forKey: .target)
    }

    nonisolated static var empty: Self {
        Self(mode: .notSet, lower: 8, upper: 12, target: 8)
    }
}

struct SetTargetSnapshot: Codable, Sendable {
    var index: Int
    var type: ExerciseSetType
    var targetWeight: Double
    var targetReps: Int
    var targetRest: Int
    var targetRPE: Int

    private enum CodingKeys: String, CodingKey {
        case index
        case type
        case targetWeight
        case targetReps
        case targetRest
        case targetRPE
    }

    nonisolated init(index: Int, type: ExerciseSetType, targetWeight: Double, targetReps: Int, targetRest: Int, targetRPE: Int) {
        self.index = index
        self.type = type
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetRest = targetRest
        self.targetRPE = targetRPE
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        type = try container.decode(ExerciseSetType.self, forKey: .type)
        targetWeight = try container.decode(Double.self, forKey: .targetWeight)
        targetReps = try container.decode(Int.self, forKey: .targetReps)
        targetRest = try container.decode(Int.self, forKey: .targetRest)
        targetRPE = try container.decode(Int.self, forKey: .targetRPE)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(type, forKey: .type)
        try container.encode(targetWeight, forKey: .targetWeight)
        try container.encode(targetReps, forKey: .targetReps)
        try container.encode(targetRest, forKey: .targetRest)
        try container.encode(targetRPE, forKey: .targetRPE)
    }

    init(prescription: SetPrescription) {
        index = prescription.index
        type = prescription.type
        targetWeight = prescription.targetWeight
        targetReps = prescription.targetReps
        targetRest = prescription.targetRest
        targetRPE = prescription.targetRPE
    }
}

struct SetPerformanceSnapshot: Codable, Sendable {
    var index: Int
    var type: ExerciseSetType
    var weight: Double
    var reps: Int
    var restSeconds: Int
    var rpe: Int

    private enum CodingKeys: String, CodingKey {
        case index
        case type
        case weight
        case reps
        case restSeconds
        case rpe
    }

    nonisolated init(index: Int, type: ExerciseSetType, weight: Double, reps: Int, restSeconds: Int, rpe: Int) {
        self.index = index
        self.type = type
        self.weight = weight
        self.reps = reps
        self.restSeconds = restSeconds
        self.rpe = rpe
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        type = try container.decode(ExerciseSetType.self, forKey: .type)
        weight = try container.decode(Double.self, forKey: .weight)
        reps = try container.decode(Int.self, forKey: .reps)
        restSeconds = try container.decode(Int.self, forKey: .restSeconds)
        rpe = try container.decode(Int.self, forKey: .rpe)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(type, forKey: .type)
        try container.encode(weight, forKey: .weight)
        try container.encode(reps, forKey: .reps)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(rpe, forKey: .rpe)
    }

    init(set: SetPerformance) {
        index = set.index
        type = set.type
        weight = set.weight
        reps = set.reps
        restSeconds = set.restSeconds
        rpe = set.rpe
    }
}

struct ExerciseTargetSnapshot: Codable, Sendable {
    var repRange: RepRangeSnapshot
    var sets: [SetTargetSnapshot]

    private enum CodingKeys: String, CodingKey {
        case repRange
        case sets
    }

    nonisolated init(repRange: RepRangeSnapshot, sets: [SetTargetSnapshot]) {
        self.repRange = repRange
        self.sets = sets
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        repRange = try container.decode(RepRangeSnapshot.self, forKey: .repRange)
        sets = try container.decode([SetTargetSnapshot].self, forKey: .sets)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(repRange, forKey: .repRange)
        try container.encode(sets, forKey: .sets)
    }

    nonisolated static var empty: Self {
        Self(repRange: .empty, sets: [])
    }

    init(prescription: ExercisePrescription) {
        repRange = RepRangeSnapshot(policy: prescription.repRange)
        sets = prescription.sortedSets.map { SetTargetSnapshot(prescription: $0) }
    }
}

struct ExercisePerformanceSnapshot: Codable, Sendable {
    var notes: String
    var repRange: RepRangeSnapshot
    var sets: [SetPerformanceSnapshot]

    private enum CodingKeys: String, CodingKey {
        case notes
        case repRange
        case sets
    }

    nonisolated init(notes: String, repRange: RepRangeSnapshot, sets: [SetPerformanceSnapshot]) {
        self.notes = notes
        self.repRange = repRange
        self.sets = sets
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notes = try container.decode(String.self, forKey: .notes)
        repRange = try container.decode(RepRangeSnapshot.self, forKey: .repRange)
        sets = try container.decode([SetPerformanceSnapshot].self, forKey: .sets)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(notes, forKey: .notes)
        try container.encode(repRange, forKey: .repRange)
        try container.encode(sets, forKey: .sets)
    }

    nonisolated static var empty: Self {
        Self(notes: "", repRange: .empty, sets: [])
    }

    init(performance: ExercisePerformance) {
        notes = performance.notes
        repRange = RepRangeSnapshot(policy: performance.repRange)
        sets = performance.sortedSets.map { SetPerformanceSnapshot(set: $0) }
    }
}
