import Foundation
import SwiftData

@Model
class RestTimeHistory {
    var seconds: Int = 0
    var lastUsed: Date = Date()
    
    init(seconds: Int) {
        self.seconds = seconds
    }
}

extension RestTimeHistory {
    static var recents: FetchDescriptor<RestTimeHistory> {
        FetchDescriptor(sortBy: [SortDescriptor(\RestTimeHistory.lastUsed, order: .reverse)])
    }

    @MainActor
    static func record(seconds: Int, context: ModelContext) {
        guard seconds > 0 else { return }
        
        let predicate = #Predicate<RestTimeHistory> { history in
            history.seconds == seconds
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        
        if let existing = try? context.fetch(descriptor).first {
            existing.lastUsed = Date.now
        } else {
            context.insert(RestTimeHistory(seconds: seconds))
        }
    }
}
