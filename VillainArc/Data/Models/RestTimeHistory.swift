import Foundation
import SwiftData

@Model
class RestTimeHistory {
    var seconds: Int
    var lastUsed: Date
    
    init(seconds: Int, lastUsed: Date = Date.now) {
        self.seconds = seconds
        self.lastUsed = lastUsed
    }
}

extension RestTimeHistory {
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
