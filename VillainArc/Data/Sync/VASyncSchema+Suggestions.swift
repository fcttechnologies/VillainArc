import FCTServerSync
import Foundation
import SwiftData

// MARK: - SuggestionEvent (four parents, all optional, resolved per role)

extension SuggestionEvent: SyncedModel {
    static var syncTableName: String { "va.suggestion_event" }
    static var syncIDKeyPath: KeyPath<SuggestionEvent, UUID> { \.id }

    static let sessionRole = "session"
    static let exercisePrescriptionRole = "exercise_prescription"
    static let setPrescriptionRole = "set_prescription"
    static let performanceRole = "performance"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<SuggestionEvent> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<SuggestionEvent> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<SuggestionEvent> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
        evaluations = []
        changes = []
    }

    func syncRow() -> [String: JSONValue] {
        [
            "source": .string(source.rawValue),
            "category": .string(category.rawValue),
            "catalog_id": .string(catalogID),
            "trigger_target_set_id": .link(triggerTargetSetID),
            "decision": .string(decision.rawValue),
            "outcome": .string(outcome.rawValue),
            "rule_id": ruleID.map { .string($0.rawValue) } ?? .null,
            "decision_reason": decisionReason.map { .string($0.rawValue) } ?? .null,
            "user_feedback": userFeedback.map { .string($0.rawValue) } ?? .null,
            "training_style": .string(trainingStyle.rawValue),
            "required_evaluation_count": .int(Int64(requiredEvaluationCount)),
            "weight_step_used": weightStepUsed.map(JSONValue.double) ?? .null,
            "suggestion_confidence": .double(suggestionConfidence),
            "created_at": .date(createdAt),
            "evaluated_at": evaluatedAt.map(JSONValue.date) ?? .null,
            "change_reasoning": changeReasoning.map(JSONValue.string) ?? .null,
            "outcome_reason": outcomeReason.map(JSONValue.string) ?? .null,
            "session_from_id": .link(sessionFrom?.id),
            "target_exercise_prescription_id": .link(targetExercisePrescription?.id),
            "target_set_prescription_id": .link(targetSetPrescription?.id),
            "trigger_performance_id": .link(triggerPerformance?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["source"]?.stringValue, let source = SuggestionSource(rawValue: value) { self.source = source }
        if let value = row["category"]?.stringValue, let category = SuggestionCategory(rawValue: value) { self.category = category }
        if let value = row["catalog_id"]?.stringValue { catalogID = value }
        if let value = row["trigger_target_set_id"] { triggerTargetSetID = value.uuidValue }
        if let value = row["decision"]?.stringValue, let decision = Decision(rawValue: value) { self.decision = decision }
        if let value = row["outcome"]?.stringValue, let outcome = Outcome(rawValue: value) { self.outcome = outcome }
        if let value = row["rule_id"] { ruleID = value.stringValue.flatMap(SuggestionRule.init(rawValue:)) }
        if let value = row["decision_reason"] { decisionReason = value.stringValue.flatMap(DecisionReason.init(rawValue:)) }
        if let value = row["user_feedback"] { userFeedback = value.stringValue.flatMap(UserFeedback.init(rawValue:)) }
        if let value = row["training_style"]?.stringValue,
           let style = TrainingStyle(rawValue: value) { trainingStyle = style }
        if let value = row["required_evaluation_count"]?.intValue { requiredEvaluationCount = Int(value) }
        if let value = row["weight_step_used"] { weightStepUsed = value.doubleValue }
        if let value = row["suggestion_confidence"]?.doubleValue { suggestionConfidence = value }
        if let value = row["created_at"]?.dateValue { createdAt = value }
        if let value = row["evaluated_at"] { evaluatedAt = value.dateValue }
        if let value = row["change_reasoning"] { changeReasoning = value.stringValue }
        if let value = row["outcome_reason"] { outcomeReason = value.stringValue }
        if let link = row["session_from_id"], link.uuidValue == nil { sessionFrom = nil }
        if let link = row["target_exercise_prescription_id"], link.uuidValue == nil { targetExercisePrescription = nil }
        if let link = row["target_set_prescription_id"], link.uuidValue == nil { targetSetPrescription = nil }
        if let link = row["trigger_performance_id"], link.uuidValue == nil { triggerPerformance = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let id = row["session_from_id"]?.uuidValue { links.append(SyncLink(role: Self.sessionRole, parent: id)) }
        if let id = row["target_exercise_prescription_id"]?.uuidValue {
            links.append(SyncLink(role: Self.exercisePrescriptionRole, parent: id))
        }
        if let id = row["target_set_prescription_id"]?.uuidValue {
            links.append(SyncLink(role: Self.setPrescriptionRole, parent: id))
        }
        if let id = row["trigger_performance_id"]?.uuidValue {
            links.append(SyncLink(role: Self.performanceRole, parent: id))
        }
        return links
    }

    static func relink(
        _ links: [UUID: [String: UUID]],
        in context: ModelContext
    ) throws -> [UUID: Set<String>] {
        guard !links.isEmpty else { return [:] }
        let sessions = try arrivedParents(WorkoutSession.self, links.values.compactMap { $0[sessionRole] }, in: context)
        let exercisePrescriptions = try arrivedParents(
            ExercisePrescription.self, links.values.compactMap { $0[exercisePrescriptionRole] }, in: context
        )
        let setPrescriptions = try arrivedParents(
            SetPrescription.self, links.values.compactMap { $0[setPrescriptionRole] }, in: context
        )
        let performances = try arrivedParents(
            ExercisePerformance.self, links.values.compactMap { $0[performanceRole] }, in: context
        )
        guard !sessions.isEmpty || !exercisePrescriptions.isEmpty || !setPrescriptions.isEmpty || !performances.isEmpty else {
            return [:]
        }

        var resolved: [UUID: Set<String>] = [:]
        for event in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[event.id] else { continue }
            var attached: Set<String> = []
            if attach(role: sessionRole, of: roles, from: sessions, assign: {
                if event.sessionFrom !== $0 { event.sessionFrom = $0 }
            }) {
                attached.insert(sessionRole)
            }
            if attach(role: exercisePrescriptionRole, of: roles, from: exercisePrescriptions, assign: {
                if event.targetExercisePrescription !== $0 { event.targetExercisePrescription = $0 }
            }) {
                attached.insert(exercisePrescriptionRole)
            }
            if attach(role: setPrescriptionRole, of: roles, from: setPrescriptions, assign: {
                if event.targetSetPrescription !== $0 { event.targetSetPrescription = $0 }
            }) {
                attached.insert(setPrescriptionRole)
            }
            if attach(role: performanceRole, of: roles, from: performances, assign: {
                if event.triggerPerformance !== $0 { event.triggerPerformance = $0 }
            }) {
                attached.insert(performanceRole)
            }
            if !attached.isEmpty { resolved[event.id] = attached }
        }
        return resolved
    }
}

// MARK: - SuggestionEvaluation (two parents: the event, and the performance)

extension SuggestionEvaluation: SyncedModel {
    static var syncTableName: String { "va.suggestion_evaluation" }
    static var syncIDKeyPath: KeyPath<SuggestionEvaluation, UUID> { \.id }

    static let eventRole = "event"
    static let performanceRole = "performance"

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<SuggestionEvaluation> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<SuggestionEvaluation> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<SuggestionEvaluation> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "source_workout_session_id": .link(sourceWorkoutSessionID),
            "partial_outcome": .string(partialOutcome.rawValue),
            "confidence": .double(confidence),
            "reason": .string(reason),
            "evaluated_at": .date(evaluatedAt),
            "event_id": .link(event?.id),
            "performance_id": .link(performance?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["source_workout_session_id"]?.uuidValue { sourceWorkoutSessionID = value }
        if let value = row["partial_outcome"]?.stringValue,
           let outcome = Outcome(rawValue: value) { partialOutcome = outcome }
        if let value = row["confidence"]?.doubleValue { confidence = value }
        if let value = row["reason"]?.stringValue { reason = value }
        if let value = row["evaluated_at"]?.dateValue { evaluatedAt = value }
        if let link = row["event_id"], link.uuidValue == nil { event = nil }
        if let link = row["performance_id"], link.uuidValue == nil { performance = nil }
        return nil
    }

    @discardableResult
    func applyLinks(_ row: [String: JSONValue]) -> [SyncLink] {
        _ = apply(row)
        var links: [SyncLink] = []
        if let id = row["event_id"]?.uuidValue { links.append(SyncLink(role: Self.eventRole, parent: id)) }
        if let id = row["performance_id"]?.uuidValue { links.append(SyncLink(role: Self.performanceRole, parent: id)) }
        return links
    }

    static func relink(
        _ links: [UUID: [String: UUID]],
        in context: ModelContext
    ) throws -> [UUID: Set<String>] {
        guard !links.isEmpty else { return [:] }
        let events = try arrivedParents(SuggestionEvent.self, links.values.compactMap { $0[eventRole] }, in: context)
        let performances = try arrivedParents(
            ExercisePerformance.self, links.values.compactMap { $0[performanceRole] }, in: context
        )
        guard !events.isEmpty || !performances.isEmpty else { return [:] }

        var resolved: [UUID: Set<String>] = [:]
        for evaluation in try context.fetch(descriptor(forSyncIDs: Array(links.keys))) {
            guard let roles = links[evaluation.id] else { continue }
            var attached: Set<String> = []
            if attach(role: eventRole, of: roles, from: events, assign: {
                if evaluation.event !== $0 { evaluation.event = $0 }
            }) {
                attached.insert(eventRole)
            }
            if attach(role: performanceRole, of: roles, from: performances, assign: {
                if evaluation.performance !== $0 { evaluation.performance = $0 }
            }) {
                attached.insert(performanceRole)
            }
            if !attached.isEmpty { resolved[evaluation.id] = attached }
        }
        return resolved
    }
}

// MARK: - PrescriptionChange (parent: the event)

extension PrescriptionChange: SyncedModel {
    static var syncTableName: String { "va.prescription_change" }
    static var syncIDKeyPath: KeyPath<PrescriptionChange, UUID> { \.id }

    static func descriptor(forSyncIDs ids: [UUID]) -> FetchDescriptor<PrescriptionChange> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.id) })
    }

    static func descriptor(forPersistentIDs ids: [PersistentIdentifier]) -> FetchDescriptor<PrescriptionChange> {
        FetchDescriptor(predicate: #Predicate { ids.contains($0.persistentModelID) })
    }

    static var allRecordsDescriptor: FetchDescriptor<PrescriptionChange> { FetchDescriptor() }

    convenience init(syncID: UUID) {
        self.init()
        id = syncID
    }

    func syncRow() -> [String: JSONValue] {
        [
            "change_type": .string(changeType.rawValue),
            "previous_value": .double(previousValue),
            "new_value": .double(newValue),
            "event_id": .link(event?.id),
        ]
    }

    @discardableResult
    func apply(_ row: [String: JSONValue]) -> UUID? {
        if let value = row["change_type"]?.stringValue, let type = ChangeType(rawValue: value) { changeType = type }
        if let value = row["previous_value"]?.doubleValue { previousValue = value }
        if let value = row["new_value"]?.doubleValue { newValue = value }

        guard let link = row["event_id"] else { return nil }
        guard let eventID = link.uuidValue else {
            event = nil
            return nil
        }
        return eventID
    }

    static func relink(_ pairs: [UUID: UUID], in context: ModelContext) throws -> Set<UUID> {
        guard !pairs.isEmpty else { return [] }
        let events = try arrivedParents(SuggestionEvent.self, pairs.values, in: context)
        guard !events.isEmpty else { return [] }

        var resolved: Set<UUID> = []
        for change in try context.fetch(descriptor(forSyncIDs: Array(pairs.keys))) {
            guard let eventID = pairs[change.id], let event = events[eventID] else { continue }
            if change.event !== event { change.event = event }
            resolved.insert(change.id)
        }
        return resolved
    }
}
