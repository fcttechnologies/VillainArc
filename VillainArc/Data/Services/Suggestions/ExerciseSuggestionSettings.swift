import Foundation
import SwiftData

func deleteUnresolvedSuggestionEvents(forCatalogID catalogID: String, context: ModelContext) {
    let prescriptions = (try? context.fetch(ExercisePrescription.matching(catalogID: catalogID))) ?? []
    var seenEventIDs = Set<UUID>()

    for prescription in prescriptions {
        let exerciseEvents = Array(prescription.suggestionEvents ?? [])
        let setEvents = prescription.sortedSets.flatMap { $0.suggestionEvents ?? [] }

        for event in exerciseEvents + setEvents {
            guard seenEventIDs.insert(event.id).inserted else { continue }
            guard event.outcome == .pending else { continue }
            context.delete(event)
        }
    }
}
