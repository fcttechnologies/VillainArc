import Foundation
import SwiftData

@Model
final class WeightEntry {
    #Index<WeightEntry>([\.recordedAt], [\.healthSampleUUID])

    var id: UUID = UUID()
    var recordedAt: Date = Date()
    var weight: Double = 0
    var note: String = ""
    var hasBeenExportedToHealth: Bool = false
    var healthSampleUUID: UUID?
    var isAvailableInHealthKit: Bool = false
    var lastSyncedAt: Date = Date()

    init(recordedAt: Date = .now, weight: Double = 0, note: String = "", hasBeenExportedToHealth: Bool = false, healthSampleUUID: UUID? = nil, isAvailableInHealthKit: Bool = false, lastSyncedAt: Date = .now) {
        self.recordedAt = recordedAt
        self.weight = weight
        self.note = note
        self.hasBeenExportedToHealth = hasBeenExportedToHealth
        self.healthSampleUUID = healthSampleUUID
        self.isAvailableInHealthKit = isAvailableInHealthKit
        self.lastSyncedAt = lastSyncedAt
    }
}

extension WeightEntry {
    static var history: FetchDescriptor<WeightEntry> {
        FetchDescriptor(sortBy: [SortDescriptor(\.recordedAt, order: .reverse)])
    }

    static var latest: FetchDescriptor<WeightEntry> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<WeightEntry> {
        var descriptor = history
        descriptor.fetchLimit = 14
        return descriptor
    }

    static func byHealthSampleUUID(_ id: UUID) -> FetchDescriptor<WeightEntry> {
        let predicate = #Predicate<WeightEntry> { $0.healthSampleUUID == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func byID(_ id: UUID) -> FetchDescriptor<WeightEntry> {
        let predicate = #Predicate<WeightEntry> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var entriesNeedingHealthExport: FetchDescriptor<WeightEntry> {
        let predicate = #Predicate<WeightEntry> { $0.hasBeenExportedToHealth == false }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.recordedAt, order: .reverse)])
    }

    static var unavailableEntries: FetchDescriptor<WeightEntry> {
        let predicate = #Predicate<WeightEntry> { $0.isAvailableInHealthKit == false && $0.healthSampleUUID != nil }
        return FetchDescriptor(predicate: predicate)
    }

    var isLinkedToHealth: Bool {
        healthSampleUUID != nil
    }
}
