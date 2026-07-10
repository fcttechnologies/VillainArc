import AppIntents
import CoreTransferable
import SwiftData
import UniformTypeIdentifiers

struct CardioSessionFullContent: Codable {
    struct MachineInterval: Codable {
        let index: Int
        let speedKPH: Double?
        let inclinePercent: Double?
        let resistanceLevel: Double?
        let cadenceRPM: Double?
        let powerWatts: Double?
        let distanceMeters: Double
    }

    let id: UUID
    let title: String
    let kind: String
    let activity: String
    let environment: String
    let startedAt: Date?
    let endedAt: Date?
    let distanceMeters: Double
    let durationSeconds: Double
    let notes: String?
    let machineIntervals: [MachineInterval]
}

struct CardioSessionEntity: AppEntity, IndexedEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cardio Session")
    static let defaultQuery = CardioSessionEntityQuery()

    let id: UUID
    let title: String
    let kind: String
    let summary: String
    let startedAt: Date?
    let fullContent: CardioSessionFullContent

    var displayRepresentation: DisplayRepresentation {
        let subtitle = summary.isEmpty
            ? (startedAt?.formatted(date: .abbreviated, time: .omitted) ?? kind)
            : summary
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

@MainActor
extension CardioSessionEntity {
    init(cardioSession: CardioSession) {
        id = cardioSession.id
        title = cardioSession.displayTitle
        kind = cardioSession.typeTitle
        summary = cardioSession.spotlightSummary
        startedAt = cardioSession.startedAt
        let machineIntervals: [CardioSessionFullContent.MachineInterval] = cardioSession.usesMachineIntervals
            ? cardioSession.sortedMachineIntervals.map { interval in
                CardioSessionFullContent.MachineInterval(index: interval.index, speedKPH: interval.speedKPH, inclinePercent: interval.inclinePercent, resistanceLevel: interval.resistanceLevel, cadenceRPM: interval.cadenceRPM, powerWatts: interval.powerWatts, distanceMeters: interval.distanceMeters)
            }
            : []
        fullContent = CardioSessionFullContent(
            id: cardioSession.id,
            title: cardioSession.displayTitle,
            kind: cardioSession.typeTitle,
            activity: cardioSession.activity.title,
            environment: cardioSession.environment.title,
            startedAt: cardioSession.startedAt,
            endedAt: cardioSession.endedAt,
            distanceMeters: cardioSession.totalDistanceMeters,
            durationSeconds: cardioSession.duration,
            notes: cardioSession.notes.isEmpty ? nil : cardioSession.notes,
            machineIntervals: machineIntervals
        )
    }
}

extension CardioSessionEntity: Transferable {
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
            let dateText = entity.startedAt?.formatted(date: .abbreviated, time: .omitted) ?? ""
            let header = dateText.isEmpty ? entity.title : "\(entity.title) — \(dateText)"
            return "\(header)\n\(entity.summary)"
        }
    }
}

struct CardioSessionEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [CardioSessionEntity.ID]) async throws -> [CardioSessionEntity] {
        guard !identifiers.isEmpty else { return [] }
        let context = SharedModelContainer.container.mainContext
        var descriptor = CardioSession.completed(ids: identifiers)
        descriptor.relationshipKeyPathsForPrefetching = [\.machineIntervals]
        let sessions = (try? context.fetch(descriptor)) ?? []
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return identifiers.compactMap { byID[$0] }.map(CardioSessionEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [CardioSessionEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = CardioSession.recentCompleted(limit: 30)
        descriptor.relationshipKeyPathsForPrefetching = [\.machineIntervals]
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.map(CardioSessionEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CardioSessionEntity] {
        let context = SharedModelContainer.container.mainContext
        var descriptor = CardioSession.completedMatching(string, limit: 30)
        descriptor.relationshipKeyPathsForPrefetching = [\.machineIntervals]
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.map(CardioSessionEntity.init)
    }
}
