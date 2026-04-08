import AppIntents
import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

struct WorkoutSplitFullContent: Codable {
    struct PlanReference: Codable, Hashable {
        let id: UUID
        let title: String
        let summary: String
    }

    struct Day: Codable, Hashable {
        let index: Int
        let weekday: Int
        let name: String?
        let isRestDay: Bool
        let targetMuscles: [String]
        let workoutPlan: PlanReference?
    }

    let id: UUID
    let title: String
    let summary: String
    let mode: String
    let isActive: Bool
    let weeklySplitOffset: Int
    let rotationCurrentIndex: Int
    let rotationLastUpdatedDate: Date?
    let days: [Day]
}

struct WorkoutSplitEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Workout Split")
    static let defaultQuery = WorkoutSplitEntityQuery()

    let id: UUID
    let title: String
    let summary: String
    let mode: String
    let isActive: Bool
    let dayNames: [String]
    let fullContent: WorkoutSplitFullContent

    var displayRepresentation: DisplayRepresentation {
        if summary.isEmpty {
            return DisplayRepresentation(title: "\(title)")
        }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(summary)")
    }
}

@MainActor
extension WorkoutSplitEntity {
    init(workoutSplit: WorkoutSplit) {
        let displayTitle = workoutSplitDisplayTitle(for: workoutSplit)
        let days = workoutSplit.sortedDays.map(makeDayContent)
        let summary = workoutSplitSummary(for: workoutSplit, days: days)

        id = workoutSplit.id
        title = displayTitle
        self.summary = summary
        mode = workoutSplit.mode.displayName
        isActive = workoutSplit.isActive
        dayNames = days.map { splitDayDisplayName(for: $0, mode: workoutSplit.mode) }
        fullContent = WorkoutSplitFullContent(
            id: workoutSplit.id,
            title: displayTitle,
            summary: summary,
            mode: workoutSplit.mode.displayName,
            isActive: workoutSplit.isActive,
            weeklySplitOffset: workoutSplit.weeklySplitOffset,
            rotationCurrentIndex: workoutSplit.rotationCurrentIndex,
            rotationLastUpdatedDate: workoutSplit.rotationLastUpdatedDate,
            days: days
        )
    }
}

extension WorkoutSplitEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { entity in
            try await MainActor.run {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                return try encoder.encode(entity.fullContent)
            }
        }

        ProxyRepresentation { entity in
            "\(entity.title)\n\(entity.summary)"
        }
    }
}

struct WorkoutSplitEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    private func makeSplitDescriptor(
        predicate: Predicate<WorkoutSplit>? = nil
    ) -> FetchDescriptor<WorkoutSplit> {
        var descriptor: FetchDescriptor<WorkoutSplit>
        if let predicate {
            descriptor = FetchDescriptor(predicate: predicate)
        } else {
            descriptor = FetchDescriptor()
        }

        descriptor.relationshipKeyPathsForPrefetching = [\.days]
        descriptor.propertiesToFetch = WorkoutSplit.entityProjectionProperties
        return descriptor
    }

    @MainActor
    func entities(for identifiers: [WorkoutSplitEntity.ID]) async throws -> [WorkoutSplitEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        let ids = identifiers
        let predicate = #Predicate<WorkoutSplit> { ids.contains($0.id) }
        let splits = (try? context.fetch(makeSplitDescriptor(predicate: predicate))) ?? []
        let byID = Dictionary(splits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return identifiers.compactMap { byID[$0] }.map(WorkoutSplitEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkoutSplitEntity] {
        let context = SharedModelContainer.container.mainContext
        let splits = (try? context.fetch(makeSplitDescriptor())) ?? []
        return sortedWorkoutSplits(splits).map(WorkoutSplitEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkoutSplitEntity] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = SharedModelContainer.container.mainContext
        guard !trimmed.isEmpty else {
            let splits = (try? context.fetch(makeSplitDescriptor())) ?? []
            let orderedSplits = sortedWorkoutSplits(splits)
            return orderedSplits.map(WorkoutSplitEntity.init)
        }

        let titleMatches = (try? context.fetch(WorkoutSplit.matchingTitle(trimmed))) ?? []
        let orderedTitleMatches = sortedWorkoutSplits(titleMatches)
        if !orderedTitleMatches.isEmpty {
            return orderedTitleMatches.map(WorkoutSplitEntity.init)
        }

        let fallbackSplits = (try? context.fetch(makeSplitDescriptor())) ?? []
        let orderedFallbackSplits = sortedWorkoutSplits(fallbackSplits)

        return orderedFallbackSplits
            .map(WorkoutSplitEntity.init)
            .filter { entity in
                entity.title.localizedStandardContains(trimmed)
                    || entity.summary.localizedStandardContains(trimmed)
                    || entity.dayNames.contains(where: { $0.localizedStandardContains(trimmed) })
            }
    }
}

private func makeDayContent(for day: WorkoutSplitDay) -> WorkoutSplitFullContent.Day {
    WorkoutSplitFullContent.Day(
        index: day.index,
        weekday: day.weekday,
        name: normalizedSplitDayName(day.name),
        isRestDay: day.isRestDay,
        targetMuscles: day.resolvedMuscles.map(\.displayName),
        workoutPlan: workoutPlanReferenceContent(for: day.workoutPlan)
    )
}

private func workoutPlanReferenceContent(for workoutPlan: WorkoutPlan?) -> WorkoutSplitFullContent.PlanReference? {
    guard let workoutPlan else { return nil }
    return WorkoutSplitFullContent.PlanReference(id: workoutPlan.id, title: workoutPlan.title, summary: workoutPlan.spotlightSummary)
}

private func normalizedSplitDayName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func splitDayDisplayName(for day: WorkoutSplitFullContent.Day, mode: SplitMode) -> String {
    if let name = day.name {
        return name
    }
    if let planTitle = day.workoutPlan?.title, !planTitle.isEmpty {
        return planTitle
    }
    if day.isRestDay {
        return String(localized: "Rest Day")
    }
    switch mode {
    case .weekly:
        return weekdayName(for: day.weekday)
    case .rotation:
        return String(localized: "Day \(day.index + 1)")
    }
}

private func weekdayName(for weekday: Int) -> String {
    let symbols = Calendar.current.weekdaySymbols
    guard weekday >= 1 && weekday <= symbols.count else { return "Day \(weekday)" }
    return symbols[weekday - 1]
}

private func workoutSplitDisplayTitle(for split: WorkoutSplit) -> String {
    let trimmed = split.title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return split.mode.defaultTitle
    }
    return trimmed
}

private func workoutSplitSummary(for split: WorkoutSplit, days: [WorkoutSplitFullContent.Day]) -> String {
    let dayCount = days.count
    let base = split.mode.summaryLabel
    let dayText = "\(dayCount) \(dayCount == 1 ? "day" : "days")"
    let context = SharedModelContainer.container.mainContext
    let resolution = SplitScheduleResolver.resolve(split, context: context, syncProgress: false)

    if resolution.isPaused, let conditionStatusText = resolution.conditionStatusText {
        return "\(base) • \(dayText) • \(conditionStatusText)"
    }

    guard let currentDay = resolution.splitDay else {
        return "\(base) • \(dayText)"
    }

    let currentDayContent = makeDayContent(for: currentDay)
    let currentLabel = splitDayDisplayName(for: currentDayContent, mode: split.mode)

    let labelPrefix = split.mode == .weekly ? String(localized: "Today") : String(localized: "Current")
    return "\(base) • \(dayText) • \(labelPrefix): \(currentLabel)"
}

private func sortedWorkoutSplits(_ splits: [WorkoutSplit]) -> [WorkoutSplit] {
    splits.sorted { lhs, rhs in
        if lhs.isActive != rhs.isActive {
            return lhs.isActive && !rhs.isActive
        }
        return workoutSplitDisplayTitle(for: lhs).localizedStandardCompare(workoutSplitDisplayTitle(for: rhs)) == .orderedAscending
    }
}
