import CoreSpotlight
import UniformTypeIdentifiers
import AppIntents
import SwiftData

@MainActor
enum SpotlightIndexer {
    static let workoutSessionIdentifierPrefix = "workoutSession:"
    static let workoutPlanIdentifierPrefix = "workoutPlan:"
    static let exerciseIdentifierPrefix = "exercise:"
    static let workoutSplitIdentifierPrefix = "workoutSplit:"
    private static let workoutSessionDomainIdentifier = "com.villainarc.workoutSession"
    private static let workoutPlanDomainIdentifier = "com.villainarc.workoutPlan"
    private static let exerciseDomainIdentifier = "com.villainarc.exercise"
    private static let workoutSplitDomainIdentifier = "com.villainarc.workoutSplit"

    static func index(workoutSession: WorkoutSession) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: workoutSession)], completionHandler: nil)
    }

    static func index(workoutPlan: WorkoutPlan) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: workoutPlan)], completionHandler: nil)
    }

    static func index(exercise: Exercise) {
        let history = exerciseHistory(for: exercise.catalogID)
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: exercise, history: history)], completionHandler: nil)
    }

    static func index(workoutSplit: WorkoutSplit) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: workoutSplit)], completionHandler: nil)
    }

    static func index(workoutSplits: [WorkoutSplit]) {
        let uniqueSplits = uniqueWorkoutSplits(from: workoutSplits)
        guard !uniqueSplits.isEmpty else { return }
        let items = uniqueSplits.map(makeSearchableItem(for:))
        CSSearchableIndex.default().indexSearchableItems(items, completionHandler: nil)
    }

    static func reindexAll(context: ModelContext) {
        var workoutDescriptor = WorkoutSession.completedSession
        workoutDescriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        let completedWorkouts = (try? context.fetch(workoutDescriptor)) ?? []

        var planDescriptor = WorkoutPlan.all
        planDescriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        let completedPlans = (try? context.fetch(planDescriptor)) ?? []

        var splitDescriptor = FetchDescriptor<WorkoutSplit>()
        splitDescriptor.relationshipKeyPathsForPrefetching = [\.days]
        let workoutSplits = (try? context.fetch(splitDescriptor)) ?? []

        // ExerciseHistory only exists when completed performances exist — it's the
        // single source of truth for exercise Spotlight eligibility.
        let histories = (try? context.fetch(FetchDescriptor<ExerciseHistory>())) ?? []
        let historyByCatalogID = Dictionary(uniqueKeysWithValues: histories.map { ($0.catalogID, $0) })
        let catalogIDs = histories.map(\.catalogID)
        let exercisesToIndex: [Exercise] = catalogIDs.isEmpty ? [] :
            (try? context.fetch(FetchDescriptor(predicate: #Predicate<Exercise> { catalogIDs.contains($0.catalogID) }))) ?? []

        let allItems = completedWorkouts.map(makeSearchableItem(for:))
            + completedPlans.map(makeSearchableItem(for:))
            + exercisesToIndex.map { makeSearchableItem(for: $0, history: historyByCatalogID[$0.catalogID]) }
            + workoutSplits.map(makeSearchableItem(for:))

        guard !allItems.isEmpty else {
            print("ℹ️ Spotlight rebuild skipped indexing (no items found)")
            return
        }

        CSSearchableIndex.default().indexSearchableItems(allItems, completionHandler: nil)
        print("✅ Spotlight rebuild queued: \(completedWorkouts.count) workouts, \(completedPlans.count) plans, \(exercisesToIndex.count) exercises, \(workoutSplits.count) splits")
    }

    static func deleteWorkoutSession(id: UUID) {
        delete(identifiers: [workoutSessionIdentifier(for: id)])
    }

    static func deleteWorkoutSessions(ids: [UUID]) {
        delete(identifiers: ids.map(workoutSessionIdentifier(for:)))
    }

    static func deleteWorkoutPlan(id: UUID) {
        delete(identifiers: [workoutPlanIdentifier(for: id)])
    }

    static func deleteWorkoutPlans(ids: [UUID]) {
        delete(identifiers: ids.map(workoutPlanIdentifier(for:)))
    }

    static func deleteExercise(catalogID: String) {
        delete(identifiers: [exerciseIdentifier(for: catalogID)])
    }

    static func deleteWorkoutSplit(id: UUID) {
        delete(identifiers: [workoutSplitIdentifier(for: id)])
    }

    static func deleteWorkoutSplit(_ split: WorkoutSplit) {
        deleteWorkoutSplit(id: workoutSplitID(for: split))
    }

    static func deleteWorkoutSplits(ids: [UUID]) {
        delete(identifiers: ids.map(workoutSplitIdentifier(for:)))
    }

    static func linkedWorkoutSplits(for workoutPlan: WorkoutPlan) -> [WorkoutSplit] {
        uniqueWorkoutSplits(from: (workoutPlan.splitDays ?? []).compactMap(\.split))
    }

    static func reindexLinkedWorkoutSplits(for workoutPlan: WorkoutPlan) {
        index(workoutSplits: linkedWorkoutSplits(for: workoutPlan))
    }

    private static func makeSearchableItem(for workoutSession: WorkoutSession) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        let displayTitle = workoutSession.title
        attributes.title = displayTitle
        attributes.displayName = displayTitle
        attributes.contentDescription = workoutSpotlightDescription(for: workoutSession)
        attributes.keywords = workoutSession.sortedExercises.map(\.name) + ["Workout"]
        let item = CSSearchableItem(uniqueIdentifier: workoutSessionIdentifier(for: workoutSession.id), domainIdentifier: workoutSessionDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutSessionEntity(workoutSession: workoutSession), priority: workoutSessionPriority(for: workoutSession))
        return item
    }

    private static func makeSearchableItem(for workoutPlan: WorkoutPlan) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = workoutPlan.title
        attributes.displayName = workoutPlan.title
        attributes.contentDescription = workoutPlanSpotlightDescription(for: workoutPlan)
        attributes.keywords = workoutPlan.sortedExercises.map(\.name) + ["Workout Plan"]
        let item = CSSearchableItem(uniqueIdentifier: workoutPlanIdentifier(for: workoutPlan.id), domainIdentifier: workoutPlanDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutPlanEntity(workoutPlan: workoutPlan), priority: workoutPlanPriority(for: workoutPlan))
        return item
    }

    private static func makeSearchableItem(for exercise: Exercise, history: ExerciseHistory?) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = exercise.name
        attributes.displayName = exercise.name
        attributes.alternateNames = exercise.systemAlternateNames
        attributes.contentDescription = exerciseSpotlightDescription(for: exercise)
        attributes.keywords = exerciseSpotlightKeywords(for: exercise)
        let item = CSSearchableItem(uniqueIdentifier: exerciseIdentifier(for: exercise.catalogID), domainIdentifier: exerciseDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(ExerciseEntity(exercise: exercise), priority: exercisePriority(for: exercise, history: history))
        return item
    }

    private static func makeSearchableItem(for workoutSplit: WorkoutSplit) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        let title = workoutSplitDisplayTitle(for: workoutSplit)
        attributes.title = title
        attributes.displayName = title
        attributes.contentDescription = workoutSplitSpotlightDescription(for: workoutSplit)
        attributes.keywords = workoutSplitSpotlightKeywords(for: workoutSplit)
        let item = CSSearchableItem(
            uniqueIdentifier: workoutSplitIdentifier(for: workoutSplitID(for: workoutSplit)),
            domainIdentifier: workoutSplitDomainIdentifier,
            attributeSet: attributes
        )
        item.associateAppEntity(WorkoutSplitEntity(workoutSplit: workoutSplit), priority: workoutSplitPriority(for: workoutSplit))
        return item
    }

    private static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers, completionHandler: nil)
    }

    private static func exerciseHistory(for catalogID: String) -> ExerciseHistory? {
        let context = SharedModelContainer.container.mainContext
        return try? context.fetch(ExerciseHistory.forCatalogID(catalogID)).first
    }

    static func workoutSessionIdentifier(for id: UUID) -> String {
        workoutSessionIdentifierPrefix + id.uuidString
    }

    static func workoutPlanIdentifier(for id: UUID) -> String {
        workoutPlanIdentifierPrefix + id.uuidString
    }

    static func exerciseIdentifier(for catalogID: String) -> String {
        exerciseIdentifierPrefix + catalogID
    }

    static func workoutSplitIdentifier(for id: UUID) -> String {
        workoutSplitIdentifierPrefix + id.uuidString
    }

    static func workoutSplitID(for workoutSplit: WorkoutSplit) -> UUID {
        workoutSplit.id
    }

    private static func workoutSessionPriority(for workoutSession: WorkoutSession) -> Int {
        var priority = 20
        priority += recencyPriorityBonus(for: workoutSession.endedAt ?? workoutSession.startedAt)
        priority += min(workoutSession.sortedExercises.count, 8)

        if workoutSession.workoutPlan != nil {
            priority += 4
        }
        if workoutSession.postEffort >= 8 {
            priority += 3
        }

        return priority
    }

    private static func workoutPlanPriority(for workoutPlan: WorkoutPlan) -> Int {
        var priority = 18
        priority += recencyPriorityBonus(for: workoutPlan.lastUsed)
        priority += min(workoutPlan.sortedExercises.count, 8)

        if workoutPlan.favorite {
            priority += 12
        }
        if !(workoutPlan.splitDays ?? []).isEmpty {
            priority += 8
        }

        return priority
    }

    private static func exercisePriority(for exercise: Exercise, history: ExerciseHistory?) -> Int {
        var priority = 16
        priority += recencyPriorityBonus(for: history?.lastCompletedAt ?? exercise.lastAddedAt)

        if exercise.favorite {
            priority += 10
        }
        if exercise.isCustom {
            priority += 6
        }
        if let history {
            priority += min(history.totalSessions, 12)
        }

        return priority
    }

    private static func workoutSplitPriority(for workoutSplit: WorkoutSplit) -> Int {
        var priority = 14

        if workoutSplit.isActive {
            priority += 18
        }
        if !workoutSplit.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            priority += 4
        }

        let days = workoutSplit.sortedDays
        priority += min(days.count, 7)
        priority += min(days.compactMap(\.workoutPlan).count, 6)

        return priority
    }

    private static func recencyPriorityBonus(for date: Date?) -> Int {
        guard let date else { return 0 }

        let daysAgo = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 365

        switch daysAgo {
        case ..<0:
            return 20
        case 0..<7:
            return 20
        case 7..<30:
            return 14
        case 30..<90:
            return 9
        case 90..<180:
            return 5
        default:
            return 0
        }
    }

    private static func exerciseSpotlightDescription(for exercise: Exercise) -> String {
        let alternateNames = exercise.systemAlternateNames
        guard !alternateNames.isEmpty else {
            return exercise.detailSubtitle
        }

        let aliases = ListFormatter.localizedString(byJoining: Array(alternateNames.prefix(3)))
        return "\(exercise.detailSubtitle). Also known as \(aliases)."
    }

    private static func exerciseSpotlightKeywords(for exercise: Exercise) -> [String] {
        var keywords: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else { return }
            keywords.append(trimmed)
        }

        add(exercise.name)
        exercise.systemAlternateNames.forEach(add)
        add(exercise.equipmentType.displayName)
        exercise.musclesTargeted.map(\.displayName).forEach(add)
        add("Exercise")

        return keywords
    }

    private static func workoutSplitDisplayTitle(for workoutSplit: WorkoutSplit) -> String {
        let trimmed = workoutSplit.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return workoutSplit.mode.defaultTitle
        }
        return trimmed
    }

    private static func workoutSplitSpotlightDescription(for workoutSplit: WorkoutSplit) -> String {
        let days = workoutSplit.sortedDays
        let modeLabel = workoutSplit.mode.summaryLabel
        let dayCount = days.count
        let daySummary = dayCount == 1 ? "1 day" : "\(dayCount) days"
        let highlightedNames = Array(days.prefix(4).map(splitDaySpotlightLabel(for:)))
        let namesSummary = ListFormatter.localizedString(byJoining: highlightedNames)
        let linkedPlanTitles = uniqueStrings(from: days.compactMap { $0.workoutPlan?.title })
        let planSummary = ListFormatter.localizedString(byJoining: Array(linkedPlanTitles.prefix(3)))
        let muscles = uniqueStrings(from: days.flatMap { $0.resolvedMuscles.map(\.displayName) })
        let muscleSummary = ListFormatter.localizedString(byJoining: Array(muscles.prefix(3)))

        var parts: [String] = [
            "\(modeLabel) with \(daySummary)."
        ]

        if !highlightedNames.isEmpty {
            parts.append("Includes \(namesSummary).")
        }
        if !planSummary.isEmpty {
            parts.append("Linked plans: \(planSummary).")
        }
        if !muscleSummary.isEmpty {
            parts.append("Targets \(muscleSummary).")
        }
        if workoutSplit.isActive {
            parts.append("Active split.")
        }

        return parts.joined(separator: " ")
    }

    private static func workoutSplitSpotlightKeywords(for workoutSplit: WorkoutSplit) -> [String] {
        var keywords: [String] = []
        var seen = Set<String>()

        func add(_ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else { return }
            keywords.append(trimmed)
        }

        add(workoutSplitDisplayTitle(for: workoutSplit))
        add(workoutSplit.mode.displayName)
        add("Workout Split")
        if workoutSplit.isActive {
            add("Active Split")
        }

        for day in workoutSplit.sortedDays {
            add(splitDaySpotlightLabel(for: day))
            if day.isRestDay {
                add("Rest Day")
            }
            if let planTitle = day.workoutPlan?.title {
                add(planTitle)
            }
            day.resolvedMuscles.map(\.displayName).forEach(add)
        }

        return keywords
    }

    private static func workoutSpotlightDescription(for workoutSession: WorkoutSession) -> String {
        let dateText = (workoutSession.endedAt ?? workoutSession.startedAt).formatted(date: .abbreviated, time: .omitted)
        let exerciseCount = workoutSession.sortedExercises.count
        let exerciseList = ListFormatter.localizedString(byJoining: Array(workoutSession.sortedExercises.prefix(4).map(\.name)))
        let exerciseSummary = exerciseList.isEmpty ? "No exercises recorded" : exerciseList

        var parts: [String] = [
            "Completed workout from \(dateText).",
            "\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises"): \(exerciseSummary)."
        ]

        if let planTitle = workoutSession.workoutPlan?.title.trimmingCharacters(in: .whitespacesAndNewlines), !planTitle.isEmpty {
            parts.append("Started from plan \(planTitle).")
        }
        if workoutSession.postEffort > 0 {
            parts.append("Effort \(workoutSession.postEffort) out of 10.")
        }

        return parts.joined(separator: " ")
    }

    private static func workoutPlanSpotlightDescription(for workoutPlan: WorkoutPlan) -> String {
        let exerciseCount = workoutPlan.sortedExercises.count
        let exerciseList = ListFormatter.localizedString(byJoining: Array(workoutPlan.sortedExercises.prefix(4).map(\.name)))
        let exerciseSummary = exerciseList.isEmpty ? "No exercises yet" : exerciseList
        let majorMuscles = Array(workoutPlan.majorMuscles.prefix(3).map(\.displayName))

        var parts: [String] = [
            "\(exerciseCount) \(exerciseCount == 1 ? "exercise" : "exercises"): \(exerciseSummary)."
        ]

        if !majorMuscles.isEmpty {
            let muscleSummary = ListFormatter.localizedString(byJoining: majorMuscles)
            parts.append("Targets \(muscleSummary).")
        }
        if let lastUsed = workoutPlan.lastUsed {
            let lastUsedText = lastUsed.formatted(date: .abbreviated, time: .omitted)
            parts.append("Last used \(lastUsedText).")
        }
        if workoutPlan.favorite {
            parts.append("Marked as favorite.")
        }

        return parts.joined(separator: " ")
    }

    private static func splitDaySpotlightLabel(for day: WorkoutSplitDay) -> String {
        let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        if let planTitle = day.workoutPlan?.title.trimmingCharacters(in: .whitespacesAndNewlines), !planTitle.isEmpty {
            return planTitle
        }
        if day.isRestDay {
            return "Rest Day"
        }
        return day.split?.mode == .weekly ? weekdayName(for: day.weekday) : "Day \(day.index + 1)"
    }

    private static func weekdayName(for weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1 && weekday <= symbols.count else { return "Day \(weekday)" }
        return symbols[weekday - 1]
    }

    private static func uniqueStrings(from values: [String]) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalized = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else { continue }
            unique.append(trimmed)
        }

        return unique
    }

    private static func uniqueWorkoutSplits(from workoutSplits: [WorkoutSplit]) -> [WorkoutSplit] {
        var unique: [WorkoutSplit] = []
        var seen = Set<String>()

        for split in workoutSplits {
            guard seen.insert(workoutSplitID(for: split).uuidString).inserted else { continue }
            unique.append(split)
        }

        return unique
    }
}
