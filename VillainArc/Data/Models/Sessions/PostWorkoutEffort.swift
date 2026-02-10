import Foundation
import SwiftData

@Model
class PostWorkoutEffort {
    var effort: Int = 0
    var notes: String = ""
    
    init(effort: Int = 0, notes: String = "") {
        self.effort = effort
        self.notes = notes
    }
}
